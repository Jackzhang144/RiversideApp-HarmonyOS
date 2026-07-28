import {
  ForumComposerMode,
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';
import {
  applyComposerTool,
  ComposerEdit,
  ComposerTool,
  insertComposerText
} from '../models/AuthoringModels';
import { filterComposerEmojis, insertComposerEmoji } from '../models/ComposerEmojiModels';
import { RepositoryResult, RepositoryResultKind } from '../core/RepositoryResult';
import {
  applyComposerMention,
  ComposerMentionQuery,
  ComposerMentionRequestGate,
  ComposerMentionUser,
  findComposerMentionQuery
} from '../models/ComposerMentionModels';
import { ChatEmoji } from '../models/ChatModels';
import { Category } from '../models/ForumModels';
import { ForumComposerToolbar } from './ForumComposerToolbar';

const COMPACT_REPLY_BODY_HEIGHT: number = 104;
const EXPANDED_BODY_HEIGHT: number = 240;

@Component
export struct ForumComposer {
  scroller: Scroller = new Scroller();
  @Prop presentation: ForumComposerPresentation = ForumComposerPresentation.reply(
    0,
    '',
    null,
    '',
    ForumComposerStatus.EDITING,
    ''
  );
  @Prop categories: Array<Category> = [];
  @Prop selectedCategoryId: number | null = null;
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop emojiLoading: boolean = false;
  @State emojiPickerVisible: boolean = false;
  @State emojiQuery: string = '';
  @State private replyBodyExpanded: boolean = false;
  onTitleChange: (title: string) => void = (_title: string): void => {};
  onCategoryChange: (categoryId: number) => void = (_categoryId: number): void => {};
  onBodyChange: (body: string) => void = (_body: string): void => {};
  onSubmit: () => void = (): void => {};
  onSaveDraft: () => void = (): void => {};
  onDiscard: () => void = (): void => {};
  onReauthenticate: () => void = (): void => {};
  onSelectMedia: () => void = (): void => {};
  onCancelMedia: () => void = (): void => {};
  onRetryMedia: () => void = (): void => {};
  onRemoveMedia: () => void = (): void => {};
  onLoadEmojis: () => void = (): void => {};
  onLoadMentionUsers: (term: string) => Promise<RepositoryResult<Array<ComposerMentionUser>>> =
    async (_term: string): Promise<RepositoryResult<Array<ComposerMentionUser>>> => {
      return RepositoryResult.success<Array<ComposerMentionUser>>([]);
    };
  @State private mentionUsers: Array<ComposerMentionUser> = [];
  @State private mentionLoading: boolean = false;
  @State private mentionMessage: string = '';
  private readonly bodyController: TextAreaController = new TextAreaController();
  private readonly mentionRequestGate: ComposerMentionRequestGate = new ComposerMentionRequestGate();
  private mentionTimer: number = -1;
  private selectionStart: number = 0;
  private selectionEnd: number = 0;

  aboutToDisappear(): void {
    this.cancelMentionTimer();
    this.mentionRequestGate.invalidate();
  }

  private cancelMentionTimer(): void {
    if (this.mentionTimer >= 0) {
      clearTimeout(this.mentionTimer);
      this.mentionTimer = -1;
    }
  }

  private resetMentionSuggestions(): void {
    this.mentionUsers = [];
    this.mentionLoading = false;
    this.mentionMessage = '';
  }

  private scheduleMentionSearch(source: string, cursor: number): void {
    this.cancelMentionTimer();
    this.mentionRequestGate.invalidate();
    const query: ComposerMentionQuery | null = findComposerMentionQuery(source, cursor);
    if (query === null) {
      this.resetMentionSuggestions();
      return;
    }
    this.resetMentionSuggestions();
    this.mentionTimer = setTimeout((): void => {
      this.mentionTimer = -1;
      this.loadMentionUsers(query.term);
    }, 300);
  }

  private async loadMentionUsers(term: string): Promise<void> {
    const generation: number = this.mentionRequestGate.issue();
    this.mentionLoading = true;
    const result: RepositoryResult<Array<ComposerMentionUser>> = await this.onLoadMentionUsers(term);
    if (!this.mentionRequestGate.isCurrent(generation)) {
      return;
    }
    this.mentionLoading = false;
    if (result.kind === RepositoryResultKind.SUCCESS && result.data !== null) {
      this.mentionUsers = result.data;
      this.mentionMessage = result.data.length === 0 ? '没有匹配的用户' : '';
      return;
    }
    this.mentionUsers = [];
    this.mentionMessage = result.kind === RepositoryResultKind.UNAUTHORIZED
      ? '登录后可搜索用户'
      : result.message;
  }

  private handleBodyChange(value: string): void {
    this.onBodyChange(value);
    this.scheduleMentionSearch(value, Math.min(this.selectionEnd, value.length));
  }

  private selectMention(user: ComposerMentionUser): void {
    const edit: ComposerEdit | null = applyComposerMention(
      this.presentation.bodyDraft,
      this.selectionEnd,
      user.username
    );
    if (edit === null) {
      this.resetMentionSuggestions();
      return;
    }
    this.applyEdit(edit);
    this.resetMentionSuggestions();
    this.mentionRequestGate.invalidate();
  }

  private categoryOptions(): Array<SelectOption> {
    const options: Array<SelectOption> = [];
    for (const category of this.categories) {
      options.push({ value: category.name });
    }
    return options;
  }

  private selectedCategoryIndex(): number {
    return this.categories.findIndex(
      (category: Category): boolean => category.id === this.selectedCategoryId
    );
  }

  private selectedCategoryName(): string {
    const selected: Category | undefined = this.categories.find(
      (category: Category): boolean => category.id === this.selectedCategoryId
    );
    return selected?.name ?? '请选择分类';
  }

  private bodyEditorHeight(): number {
    if (this.presentation.mode !== ForumComposerMode.REPLY) {
      return EXPANDED_BODY_HEIGHT;
    }
    return this.replyBodyExpanded ? EXPANDED_BODY_HEIGHT : COMPACT_REPLY_BODY_HEIGHT;
  }

  private bodyLabel(): string {
    return this.presentation.mode === ForumComposerMode.REPLY ||
      this.presentation.mode === ForumComposerMode.EDIT_POST
      ? '回复内容'
      : '正文';
  }

  @Builder
  private ComposerContext(): void {
    Row({ space: 8 }) {
      SymbolGlyph(this.presentation.mode === ForumComposerMode.REPLY
        ? $r('sys.symbol.message')
        : $r('sys.symbol.square_and_pencil'))
        .fontSize(18)
        .fontColor([$r('app.color.brand_primary')])
      Column({ space: 2 }) {
        Text(this.presentation.contextTitle)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
        Text(this.presentation.contextDescription)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(this.presentation.contextBadge)
        .fontSize(11)
        .fontColor($r('app.color.text_link'))
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius($r('app.float.card_corner_radius'))
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius($r('app.float.card_corner_radius'))
  }

  private applyTool(tool: ComposerTool): void {
    const edit: ComposerEdit = applyComposerTool(
      this.presentation.bodyDraft,
      this.selectionStart,
      this.selectionEnd,
      tool
    );
    this.applyEdit(edit);
  }

  private insertText(text: string): void {
    this.applyEdit(insertComposerText(
      this.presentation.bodyDraft,
      this.selectionStart,
      this.selectionEnd,
      text
    ));
  }

  private insertEmoji(name: string): void {
    const edit: ComposerEdit | null = insertComposerEmoji(
      this.presentation.bodyDraft,
      this.selectionStart,
      this.selectionEnd,
      name
    );
    if (edit === null) {
      return;
    }
    this.applyEdit(edit);
    this.emojiPickerVisible = false;
  }

  private visibleEmojis(): Array<ChatEmoji> {
    return filterComposerEmojis(this.emojis, this.emojiQuery);
  }

  private toggleEmojiPicker(): void {
    this.emojiPickerVisible = !this.emojiPickerVisible;
    if (this.emojiPickerVisible) {
      this.onLoadEmojis();
    }
  }

  private applyEdit(edit: ComposerEdit): void {
    this.selectionStart = edit.selectionStart;
    this.selectionEnd = edit.selectionEnd;
    this.onBodyChange(edit.text);
    setTimeout((): void => {
      this.bodyController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  @Builder
  private MentionSuggestions(): void {
    if (this.mentionLoading || this.mentionUsers.length > 0 || this.mentionMessage.length > 0) {
      Column({ space: 4 }) {
        if (this.mentionLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18)
            Text($r('app.string.chat_mention_loading')).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(8)
        } else if (this.mentionUsers.length > 0) {
          ForEach(this.mentionUsers, (user: ComposerMentionUser) => {
            Row({ space: 8 }) {
              Text(`@${user.username}`).fontSize(14).fontWeight(FontWeight.Medium)
              if (user.name.length > 0) {
                Text(user.name)
                  .fontSize(12)
                  .fontColor($r('sys.color.font_secondary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
              }
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 8, bottom: 8 })
            .onClick((): void => this.selectMention(user))
            .accessibilityText(`提及用户 ${user.username}`)
          }, (user: ComposerMentionUser): string => user.username)
        } else {
          Text(this.mentionMessage)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding(8)
        }
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(10)
    }
  }

  @Builder
  private EmojiPicker(): void {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('Emoji')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Button($r('app.string.action_close'), { type: ButtonType.Normal })
          .height(30)
          .fontSize(11)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_secondary'))
          .onClick((): void => {
            this.emojiPickerVisible = false;
          })
      }
      .width('100%')
      TextInput({ text: this.emojiQuery, placeholder: $r('app.string.composer_emoji_search_placeholder') })
        .width('100%')
        .height(38)
        .fontSize(12)
        .enabled(this.presentation.canEdit())
        .backgroundColor($r('sys.color.comp_background_primary'))
        .onChange((value: string): void => {
          this.emojiQuery = value;
        })
        .accessibilityText($r('app.string.composer_emoji_search_accessibility'))
      if (this.emojiLoading && this.emojis.length === 0) {
        Row({ space: 8 }) {
          LoadingProgress().width(24).height(24)
          Text($r('app.string.composer_emoji_loading'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .height(92)
        .justifyContent(FlexAlign.Center)
      } else if (this.visibleEmojis().length === 0) {
        Column({ space: 8 }) {
          Text(this.emojis.length === 0 ? '未读取到 Emoji' : '没有匹配的 Emoji')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
          if (this.emojis.length === 0) {
            Button($r('app.string.common_retry'))
              .height(32)
              .fontSize(11)
              .onClick(this.onLoadEmojis)
          }
        }
        .height(92)
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.visibleEmojis(), (emoji: ChatEmoji) => {
            GridItem() {
              Button() {
                Column({ space: 3 }) {
                  Image(emoji.imageUrl())
                    .width(28)
                    .height(28)
                    .objectFit(ImageFit.Contain)
                  Text(emoji.name)
                    .fontSize(8)
                    .fontColor($r('sys.color.font_tertiary'))
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }
              }
              .width('100%')
              .height(54)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .enabled(this.presentation.canEdit())
              .onClick((): void => this.insertEmoji(emoji.name))
              .accessibilityText(`插入 Emoji ${emoji.name}`)
            }
          }, (emoji: ChatEmoji): string => emoji.name)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr')
        .columnsGap(7)
        .rowsGap(7)
        .height(230)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius($r('app.float.card_corner_radius'))
  }

  @Builder
  private ComposerTools(): void {
    ForumComposerToolbar({
      toolbarEnabled: this.presentation.canEdit(),
      imageEnabled: this.presentation.imageActionAvailable,
      mentionEnabled: this.presentation.mentionActionAvailable,
      onToolSelected: (tool: ComposerTool): void => this.applyTool(tool),
      onEmojiSelected: (): void => this.toggleEmojiPicker(),
      onImageSelected: (): void => this.onSelectMedia(),
      onMentionSelected: (): void => this.insertText('@')
    })
  }

  @Builder
  private MediaStatus(): void {
    if (this.presentation.hasMediaStatus()) {
      Column({ space: 8 }) {
        Text(this.presentation.mediaStatusText())
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        Row({ space: 8 }) {
          if (this.presentation.canCancelMedia()) {
            Button($r('app.string.composer_upload_cancel'))
              .height(34)
              .fontSize(12)
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('app.color.status_error'))
              .onClick(this.onCancelMedia)
          }
          if (this.presentation.canRetryMedia()) {
            Button($r('app.string.composer_upload_retry'))
              .height(34)
              .fontSize(12)
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('app.color.text_link'))
              .onClick(this.onRetryMedia)
          }
          if (this.presentation.canRemoveMedia()) {
            Button($r('app.string.composer_upload_remove_status'))
              .height(34)
              .fontSize(12)
              .backgroundColor($r('sys.color.background_secondary'))
              .fontColor($r('sys.color.font_secondary'))
              .onClick(this.onRemoveMedia)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(10)
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius(10)
    }
  }

  @Builder
  private StatusMessage(): void {
    if (this.presentation.message.length > 0) {
      Text(this.presentation.message)
        .fontSize(12)
        .fontColor(
          this.presentation.status === ForumComposerStatus.ERROR || this.presentation.needsAuthentication()
            ? $r('sys.color.font_emphasize')
            : $r('sys.color.font_secondary')
        )
        .width('100%')
    }
  }

  @Builder
  private ComposerActions(): void {
    if (this.presentation.needsAuthentication()) {
      Button($r('app.string.composer_reauthenticate'))
        .width('100%')
        .height(44)
        .onClick(this.onReauthenticate)
        .accessibilityText($r('app.string.composer_reauthenticate_accessibility'))
    } else {
      Row({ space: 10 }) {
        if (this.presentation.showsDraftActions) {
          Button($r('app.string.composer_discard'))
            .layoutWeight(0.8)
            .height(44)
            .enabled(!this.presentation.isBusy())
            .backgroundColor(Color.Transparent)
            .fontColor($r('app.color.status_error'))
            .onClick(this.onDiscard)
            .accessibilityText($r('app.string.composer_discard_accessibility'))
          Button($r('app.string.composer_save_draft'))
            .layoutWeight(1)
            .height(44)
            .enabled(this.presentation.canEdit())
            .backgroundColor($r('sys.color.background_secondary'))
            .fontColor($r('app.color.text_link'))
            .onClick(this.onSaveDraft)
            .accessibilityText($r('app.string.composer_save_draft_accessibility'))
        }
        Button(this.presentation.submitLabel())
          .layoutWeight(1)
          .height(44)
          .enabled(this.presentation.canSubmit())
          .onClick(this.onSubmit)
          .accessibilityText(this.presentation.status === ForumComposerStatus.ERROR
            ? '再次确认后显式重试发布'
            : this.presentation.submitLabel())
      }
      .width('100%')
    }
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        this.ComposerContext()
        if (this.presentation.showsTitleInput) {
          TextInput({
            text: this.presentation.titleDraft,
            placeholder: this.presentation.titlePlaceholder
          })
            .height(44)
            .enabled(this.presentation.canEdit())
            .backgroundColor($r('sys.color.comp_background_primary'))
            .border({ width: 1, color: $r('sys.color.comp_divider') })
            .borderRadius($r('app.float.card_corner_radius'))
            .onChange((value: string): void => this.onTitleChange(value))
            .accessibilityText($r('app.string.composer_topic_title_accessibility'))
        }
        if (this.presentation.showsCategoryInput) {
          Column({ space: 6 }) {
            Text($r('app.string.composer_category_label'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
            Select(this.categoryOptions())
              .selected(this.selectedCategoryIndex())
              .value(this.selectedCategoryName())
              .width('100%')
              .height(44)
              .backgroundColor($r('sys.color.comp_background_primary'))
              .border({ width: 1, color: $r('sys.color.comp_divider') })
              .borderRadius(22)
              .enabled(this.presentation.canEdit() && this.categories.length > 0)
              .onSelect((index: number, _value: string): void => {
                const category: Category | undefined = this.categories[index];
                if (category !== undefined) {
                  this.onCategoryChange(category.id);
                }
              })
              .accessibilityText($r('app.string.composer_category_accessibility'))
          }
          .width('100%')
        }
        Row({ space: 6 }) {
          Text(this.bodyLabel())
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          if (this.presentation.mode === ForumComposerMode.REPLY) {
            Button() {
              SymbolGlyph(this.replyBodyExpanded
                ? $r('sys.symbol.arrow_down_right_and_arrow_up_left')
                : $r('sys.symbol.arrow_up_left_and_arrow_down_right'))
                .fontSize(17)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .width(32)
            .height(32)
            .borderRadius(16)
            .backgroundColor(Color.Transparent)
            .onClick((): void => {
              this.replyBodyExpanded = !this.replyBodyExpanded;
            })
            .accessibilityText(this.replyBodyExpanded ? '收起回复编辑框' : '展开回复编辑框')
            if (this.presentation.bodyDraft.trim().length > 0) {
              Button(this.presentation.submitLabel(), { type: ButtonType.Normal })
                .height(32)
                .fontSize(12)
                .padding({ left: 14, right: 14 })
                .enabled(this.presentation.canSubmit())
                .backgroundColor($r('app.color.brand_primary'))
                .fontColor($r('app.color.on_accent'))
                .onClick(this.onSubmit)
                .accessibilityText(this.presentation.status === ForumComposerStatus.ERROR
                  ? '再次确认后显式重试发布'
                  : this.presentation.submitLabel())
            }
          }
        }
        .width('100%')
        .height(32)
        .alignItems(VerticalAlign.Center)
        this.ComposerTools()
        if (this.emojiPickerVisible) {
          this.EmojiPicker()
        }
        TextArea({
          text: this.presentation.bodyDraft,
          placeholder: this.presentation.bodyPlaceholder,
          controller: this.bodyController
        })
          .height(this.bodyEditorHeight())
          .enabled(this.presentation.canEdit())
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('sys.color.comp_divider') })
          .borderRadius($r('app.float.card_corner_radius'))
          .animation({ duration: 180, curve: Curve.EaseInOut })
          .onChange((value: string): void => this.handleBodyChange(value))
          .onTextSelectionChange((selectionStart: number, selectionEnd: number): void => {
            this.selectionStart = selectionStart;
            this.selectionEnd = selectionEnd;
            this.scheduleMentionSearch(this.presentation.bodyDraft, selectionEnd);
          })
          .accessibilityText(
            this.presentation.mode === ForumComposerMode.REPLY ||
            this.presentation.mode === ForumComposerMode.EDIT_POST
              ? '回复内容'
              : '帖子正文'
          )
        this.MentionSuggestions()
        Text(`${this.presentation.characterCount()} 字 · 支持 Markdown`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
        this.MediaStatus()
        this.StatusMessage()
        this.ComposerActions()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
  }
}
