import {
  ForumComposerMode,
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';
import {
  applyComposerTool,
  ComposerEdit,
  ComposerTool
} from '../models/AuthoringModels';
import { filterComposerEmojis, insertComposerEmoji } from '../models/ComposerEmojiModels';
import { ChatEmoji } from '../models/ChatModels';
import { Category } from '../models/ForumModels';

@Component
export struct ForumComposer {
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
  private readonly bodyController: TextAreaController = new TextAreaController();
  private selectionStart: number = 0;
  private selectionEnd: number = 0;

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
    return selected?.name ?? '请选择 Category';
  }

  @Builder
  private ComposerContext(): void {
    Row({ space: 8 }) {
      SymbolGlyph(this.presentation.mode === ForumComposerMode.REPLY
        ? $r('sys.symbol.message')
        : $r('sys.symbol.square_and_pencil'))
        .fontSize(18)
        .fontColor(['#317AF7'])
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
        .fontColor('#2068C9')
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor('#EAF2FF')
        .borderRadius(12)
    }
    .width('100%')
    .padding(12)
    .backgroundColor('#F5F7FA')
    .borderRadius(12)
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
  private ToolButton(label: string, tool: ComposerTool, accessibilityText: string): void {
    Button(label)
      .height(34)
      .fontSize(12)
      .enabled(this.presentation.canEdit())
      .backgroundColor('#EAF2FF')
      .fontColor('#2068C9')
      .margin({ right: 7, bottom: 7 })
      .onClick((): void => this.applyTool(tool))
      .accessibilityText(accessibilityText)
  }

  @Builder
  private EmojiPicker(): void {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text('Emoji')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Button('关闭', { type: ButtonType.Normal })
          .height(30)
          .fontSize(11)
          .backgroundColor('#F5F6F8')
          .fontColor($r('sys.color.font_secondary'))
          .onClick((): void => {
            this.emojiPickerVisible = false;
          })
      }
      .width('100%')
      TextInput({ text: this.emojiQuery, placeholder: '按名称搜索 Emoji' })
        .width('100%')
        .height(38)
        .fontSize(12)
        .enabled(this.presentation.canEdit())
        .backgroundColor('#FFFFFF')
        .onChange((value: string): void => {
          this.emojiQuery = value;
        })
        .accessibilityText('搜索 Emoji 名称')
      if (this.emojiLoading && this.emojis.length === 0) {
        Row({ space: 8 }) {
          LoadingProgress().width(24).height(24)
          Text('正在读取 Emoji 列表')
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
            Button('重试')
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
              .backgroundColor('#FFFFFF')
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
    .backgroundColor('#F5F7FA')
    .borderRadius(12)
  }

  @Builder
  private ComposerTools(): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      this.ToolButton('B', ComposerTool.BOLD, '粗体')
      this.ToolButton('I', ComposerTool.ITALIC, '斜体')
      this.ToolButton('H1', ComposerTool.HEADING_1, '一级标题')
      this.ToolButton('H2', ComposerTool.HEADING_2, '二级标题')
      this.ToolButton('H3', ComposerTool.HEADING_3, '三级标题')
      this.ToolButton('H4', ComposerTool.HEADING_4, '四级标题')
      this.ToolButton('链接', ComposerTool.LINK, '插入链接')
      this.ToolButton('引用', ComposerTool.QUOTE, '块引用')
      this.ToolButton('代码', ComposerTool.CODE_BLOCK, '代码块')
      this.ToolButton('`code`', ComposerTool.INLINE_CODE, '行内代码')
      this.ToolButton('• 列表', ComposerTool.BULLET_LIST, '无序列表')
      this.ToolButton('1. 列表', ComposerTool.ORDERED_LIST, '有序列表')
      this.ToolButton('☐', ComposerTool.CHECKLIST, 'Checklist')
      this.ToolButton('☑', ComposerTool.CHECKLIST_DONE, '已完成 Checklist')
      this.ToolButton('Spoiler', ComposerTool.SPOILER, 'Spoiler')
      this.ToolButton('目录', ComposerTool.TABLE_OF_CONTENTS, '目录')
      this.ToolButton('单选投票', ComposerTool.POLL_SINGLE, '插入单选投票模板')
      this.ToolButton('多选投票', ComposerTool.POLL_MULTIPLE, '插入多选投票模板')
      this.ToolButton('表格', ComposerTool.TABLE, '插入表格')
      this.ToolButton('公式', ComposerTool.MATH, '插入公式')
      Button('😀')
        .height(34)
        .fontSize(16)
        .enabled(this.presentation.canEdit())
        .backgroundColor('#EAF2FF')
        .margin({ right: 7, bottom: 7 })
        .onClick((): void => this.toggleEmojiPicker())
        .accessibilityText('打开 Emoji 选择器')
      Button() {
        SymbolGlyph($r('sys.symbol.ohos_photo'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width(42)
      .height(34)
      .enabled(this.presentation.imageActionAvailable)
      .backgroundColor('#F5F6F8')
      .margin({ right: 7, bottom: 7 })
      .onClick(this.onSelectMedia)
      .accessibilityText(this.presentation.imageActionAccessibilityText)
      Button('@')
        .width(42)
        .height(34)
        .fontSize(16)
        .enabled(this.presentation.mentionActionAvailable)
        .backgroundColor('#F5F6F8')
        .fontColor($r('sys.color.font_tertiary'))
        .margin({ right: 7, bottom: 7 })
        .accessibilityText(this.presentation.mentionActionAccessibilityText)
    }
    .width('100%')
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
            Button('取消上传')
              .height(34)
              .fontSize(12)
              .backgroundColor('#F5F6F8')
              .fontColor('#C62828')
              .onClick(this.onCancelMedia)
          }
          if (this.presentation.canRetryMedia()) {
            Button('重试上传')
              .height(34)
              .fontSize(12)
              .backgroundColor('#EAF2FF')
              .fontColor('#2068C9')
              .onClick(this.onRetryMedia)
          }
          if (this.presentation.canRemoveMedia()) {
            Button('移除状态')
              .height(34)
              .fontSize(12)
              .backgroundColor('#F5F6F8')
              .fontColor($r('sys.color.font_secondary'))
              .onClick(this.onRemoveMedia)
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding(10)
      .backgroundColor('#F5F7FA')
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
  private PrimaryAction(): void {
    if (this.presentation.needsAuthentication()) {
      Button('重新登录后继续')
        .width('100%')
        .height(48)
        .onClick(this.onReauthenticate)
        .accessibilityText('重新登录并保留编辑器草稿')
    } else {
      Button(this.presentation.submitLabel())
        .width('100%')
        .height(48)
        .enabled(this.presentation.canSubmit())
        .onClick(this.onSubmit)
        .accessibilityText(this.presentation.status === ForumComposerStatus.ERROR
          ? '再次确认后显式重试发布'
          : this.presentation.submitLabel())
    }
  }

  @Builder
  private DraftActions(): void {
    if (this.presentation.showsDraftActions) {
      Row({ space: 10 }) {
        Button('保存草稿')
          .layoutWeight(1)
          .height(42)
          .enabled(this.presentation.canEdit())
          .backgroundColor('#EAF2FF')
          .fontColor('#2068C9')
          .onClick(this.onSaveDraft)
          .accessibilityText('保存服务端草稿')
        Button('舍弃')
          .layoutWeight(1)
          .height(42)
          .enabled(!this.presentation.isBusy())
          .backgroundColor('#F5F6F8')
          .fontColor('#C62828')
          .onClick(this.onDiscard)
          .accessibilityText('舍弃草稿并关闭编辑器')
      }
      .width('100%')
    }
  }

  build() {
    Scroll() {
      Column({ space: 12 }) {
        this.ComposerContext()
        if (this.presentation.showsTitleInput) {
          TextInput({
            text: this.presentation.titleDraft,
            placeholder: this.presentation.titlePlaceholder
          })
            .height(44)
            .enabled(this.presentation.canEdit())
            .backgroundColor('#F5F6F8')
            .onChange((value: string): void => this.onTitleChange(value))
            .accessibilityText('Topic 标题')
        }
        if (this.presentation.showsCategoryInput) {
          Column({ space: 6 }) {
            Text('Category')
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .width('100%')
            Select(this.categoryOptions())
              .selected(this.selectedCategoryIndex())
              .value(this.selectedCategoryName())
              .width('100%')
              .enabled(this.presentation.canEdit() && this.categories.length > 0)
              .onSelect((index: number, _value: string): void => {
                const category: Category | undefined = this.categories[index];
                if (category !== undefined) {
                  this.onCategoryChange(category.id);
                }
              })
              .accessibilityText('选择 Topic Category')
          }
          .width('100%')
        }
        TextArea({
          text: this.presentation.bodyDraft,
          placeholder: this.presentation.bodyPlaceholder,
          controller: this.bodyController
        })
          .height(190)
          .enabled(this.presentation.canEdit())
          .backgroundColor('#F5F6F8')
          .borderRadius(10)
          .onChange((value: string): void => this.onBodyChange(value))
          .onTextSelectionChange((selectionStart: number, selectionEnd: number): void => {
            this.selectionStart = selectionStart;
            this.selectionEnd = selectionEnd;
          })
          .accessibilityText(
            this.presentation.mode === ForumComposerMode.REPLY ||
            this.presentation.mode === ForumComposerMode.EDIT_POST
              ? 'Reply 内容'
              : 'Topic 正文'
          )
        Text(`${this.presentation.characterCount()} 字符 · 支持 Markdown 与服务端草稿`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
        this.ComposerTools()
        if (this.emojiPickerVisible) {
          this.EmojiPicker()
        }
        this.MediaStatus()
        this.StatusMessage()
        this.DraftActions()
        this.PrimaryAction()
      }
      .width('100%')
      .constraintSize({ minHeight: '100%' })
      .padding({ left: 16, right: 16, top: 8, bottom: 16 })
    }
    .width('100%')
    .height('100%')
    .edgeEffect(EdgeEffect.Spring)
  }
}
