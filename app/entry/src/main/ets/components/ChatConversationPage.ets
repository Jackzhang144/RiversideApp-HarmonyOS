import { SymbolGlyphModifier } from '@kit.ArkUI';
import { ChatComposerState, ChatConversationState, ChatStateKind } from '../app/ChatStateModels';
import { RepositoryResult, RepositoryResultKind } from '../core/RepositoryResult';
import { ComposerEdit } from '../models/AuthoringModels';
import { applyChatComposerMention, findChatComposerMention } from '../models/ChatComposerEditing';
import {
  ComposerMentionQuery,
  ComposerMentionRequestGate,
  ComposerMentionUser
} from '../models/ComposerMentionModels';
import {
  absoluteChatUrl,
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatReaction,
  ChatReactionAction,
  ChatReactionUser
} from '../models/ChatModels';
import { MediaUploadResult, MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import {
  ChatMessageContextCapabilities,
  ChatMessageFragment,
  ChatMessageFragmentKind,
  formatChatMessageTimestamp,
  isChatMessageGroupStart,
  presentChatMessageBody,
  presentChatText,
  resolveChatMessageContextCapabilities,
  selectQuickChatEmojis
} from './ChatMessagePresentation';

const CHAT_QUICK_REACTION_LIMIT: number = 5;
const CHAT_REACTION_SUBMENU_LIMIT: number = 20;
const CHAT_QUICK_REACTION_PREFERRED_NAMES: Array<string> = [
  'heart',
  '+1',
  '-1',
  'laughing',
  'open_mouth',
  'thinking'
];

@Component
export struct ChatConversationPage {
  @Prop state: ChatConversationState = ChatConversationState.initial();
  @Prop composer: ChatComposerState = new ChatComposerState();
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop uploadState: MediaUploadState | null = null;
  @Prop currentUsername: string = '';
  @State emojiQuery: string = '';
  @State emojiPickerVisible: boolean = false;
  @State mentionUsers: Array<ComposerMentionUser> = [];
  @State mentionLoading: boolean = false;
  @State mentionMessage: string = '';
  onRetry: () => void = (): void => {};
  onLoadOlder: () => void = (): void => {};
  onLoadNewer: () => void = (): void => {};
  onDraftChange: (value: string) => void = (_value: string): void => {};
  onSend: () => void = (): void => {};
  onSelectImages: () => void = (): void => {};
  onRetryUpload: () => void = (): void => {};
  onCancelUpload: () => void = (): void => {};
  onRemoveUpload: (uploadId: number) => void = (_uploadId: number): void => {};
  onReply: (messageId: number) => void = (_messageId: number): void => {};
  onCancelReply: () => void = (): void => {};
  onMention: (username: string) => void = (_username: string): void => {};
  onLoadMentionUsers: (term: string) => Promise<RepositoryResult<Array<ComposerMentionUser>>> =
    async (_term: string): Promise<RepositoryResult<Array<ComposerMentionUser>>> => {
      return RepositoryResult.success<Array<ComposerMentionUser>>([]);
    };
  onInsertEmoji: (name: string, selectionStart: number, selectionEnd: number) => ComposerEdit | null =
    (_name: string, _selectionStart: number, _selectionEnd: number): ComposerEdit | null => null;
  onReact: (messageId: number, emoji: string, action: ChatReactionAction) => void =
    (_messageId: number, _emoji: string, _action: ChatReactionAction): void => {};
  onDelete: (messageId: number) => void = (_messageId: number): void => {};
  onRestore: (messageId: number) => void = (_messageId: number): void => {};
  onCopyMessage: (message: string) => void = (_message: string): void => {};
  onCopyMessageLink: (channelId: number, channelSlug: string, messageId: number) => void =
    (_channelId: number, _channelSlug: string, _messageId: number): void => {};
  onOpenImage: (url: string) => void = (_url: string): void => {};
  onOpenProfile: (username: string) => void = (_username: string): void => {};
  onLeaveChannel: () => void = (): void => {};
  private readonly composerController: TextAreaController = new TextAreaController();
  private readonly mentionRequestGate: ComposerMentionRequestGate = new ComposerMentionRequestGate();
  private mentionTimer: number = -1;
  private composerSelectionStart: number = 0;
  private composerSelectionEnd: number = 0;

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
    const query: ComposerMentionQuery | null = findChatComposerMention(source, cursor);
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
    let result: RepositoryResult<Array<ComposerMentionUser>>;
    try {
      result = await this.onLoadMentionUsers(term);
    } catch (_) {
      if (this.mentionRequestGate.isCurrent(generation)) {
        this.mentionLoading = false;
        this.mentionUsers = [];
        this.mentionMessage = '搜索用户失败，请稍后重试';
      }
      return;
    }
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

  private handleDraftChange(value: string): void {
    this.onDraftChange(value);
    this.scheduleMentionSearch(value, Math.min(this.composerSelectionEnd, value.length));
  }

  private selectMention(user: ComposerMentionUser): void {
    const edit: ComposerEdit | null = applyChatComposerMention(
      this.composer.draft,
      this.composerSelectionEnd,
      user.username
    );
    if (edit === null) {
      this.resetMentionSuggestions();
      return;
    }
    this.onDraftChange(edit.text);
    this.composerSelectionStart = edit.selectionStart;
    this.composerSelectionEnd = edit.selectionEnd;
    this.resetMentionSuggestions();
    this.mentionRequestGate.invalidate();
    setTimeout((): void => {
      this.composerController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  private insertEmoji(name: string): void {
    const edit: ComposerEdit | null = this.onInsertEmoji(
      name,
      this.composerSelectionStart,
      this.composerSelectionEnd
    );
    if (edit === null) {
      return;
    }
    this.composerSelectionStart = edit.selectionStart;
    this.composerSelectionEnd = edit.selectionEnd;
    setTimeout((): void => {
      this.composerController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  private messageForId(messageId: number | null): ChatMessage | null {
    if (messageId === null) {
      return null;
    }
    return this.state.messages.find((message: ChatMessage): boolean => message.id === messageId) ?? null;
  }

  private emojiForReaction(reaction: ChatReaction): ChatEmoji | null {
    const name: string = reaction.emoji.replace(/reaction\.|emoji\.|:/g, '');
    return this.emojis.find((emoji: ChatEmoji): boolean => emoji.name === name) ?? null;
  }

  private emojiUrlForReaction(reaction: ChatReaction): string {
    const emoji: ChatEmoji | null = this.emojiForReaction(reaction);
    return emoji?.imageUrl() ?? '';
  }

  private canWrite(): boolean {
    return this.state.channel !== null && !this.state.channel.userSilenced;
  }

  private messageContextCapabilities(message: ChatMessage): ChatMessageContextCapabilities {
    return resolveChatMessageContextCapabilities(
      message,
      this.state.channel,
      this.currentUsername,
      this.emojis.length > 0
    );
  }

  private quickReactionEmojis(): Array<ChatEmoji> {
    return selectQuickChatEmojis(
      this.emojis,
      CHAT_QUICK_REACTION_PREFERRED_NAMES,
      CHAT_QUICK_REACTION_LIMIT
    );
  }

  private reactionSubmenuEmojis(): Array<ChatEmoji> {
    return selectQuickChatEmojis(
      this.emojis,
      CHAT_QUICK_REACTION_PREFERRED_NAMES,
      CHAT_REACTION_SUBMENU_LIMIT
    );
  }

  private visibleEmojis(): Array<ChatEmoji> {
    const query: string = this.emojiQuery.trim().toLowerCase();
    return this.emojis.filter((emoji: ChatEmoji): boolean => query.length === 0 ||
      emoji.name.toLowerCase().includes(query) || emoji.group.toLowerCase().includes(query)).slice(0, 40);
  }

  private displayUsername(message: ChatMessage): string {
    return message.username.length > 0 ? message.username : '未知用户';
  }

  private avatarInitial(message: ChatMessage): string {
    const username: string = this.displayUsername(message);
    return username.slice(0, 1).toUpperCase();
  }

  private copyMessageLink(message: ChatMessage): void {
    const channel: ChatChannel | null = this.state.channel;
    if (channel !== null) {
      this.onCopyMessageLink(channel.id, channel.slug, message.id);
    }
  }

  private messageHasReaction(message: ChatMessage, emoji: ChatEmoji): boolean {
    return message.reactions.some((reaction: ChatReaction): boolean => {
      const reactionName: string = reaction.emoji.replace(/reaction\.|emoji\.|:/g, '');
      return reactionName === emoji.name && reaction.reacted;
    });
  }

  private toggleQuickReaction(message: ChatMessage, emoji: ChatEmoji): void {
    this.onReact(
      message.id,
      emoji.name,
      this.messageHasReaction(message, emoji) ? ChatReactionAction.REMOVE : ChatReactionAction.ADD
    );
  }

  private showChannelActions(): void {
    const channel: ChatChannel | null = this.state.channel;
    if (channel === null || channel.isDirectMessage) {
      return;
    }
    this.getUIContext().showActionSheet({
      title: channel.title,
      message: channel.subtitle,
      sheets: [{
        title: $r('app.string.chat_leave_channel'),
        action: (): void => this.onLeaveChannel()
      }],
      cancel: (): void => {}
    });
  }

  @Builder
  private QuickReactionButton(message: ChatMessage, emoji: ChatEmoji): void {
    Button() {
      Image(emoji.imageUrl())
        .width(24)
        .height(24)
        .objectFit(ImageFit.Contain)
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor(this.messageHasReaction(message, emoji)
      ? $r('app.color.brand_selected_surface')
      : Color.Transparent)
    .gesture(TapGesture().onAction((): void => this.toggleQuickReaction(message, emoji)))
    .accessibilityText(`使用 ${emoji.name} 回应`)
  }

  @Builder
  private QuickReactionBar(message: ChatMessage): void {
    Row({ space: 4 }) {
      ForEach(this.quickReactionEmojis(), (emoji: ChatEmoji): void => {
        this.QuickReactionButton(message, emoji)
      }, (emoji: ChatEmoji): string => emoji.name)
    }
    .width(236)
    .height(54)
    .padding({ left: 7, right: 7 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(27)
  }

  @Builder
  private ReactionSubmenu(message: ChatMessage): void {
    Menu() {
      ForEach(this.reactionSubmenuEmojis(), (emoji: ChatEmoji): void => {
        MenuItem({
          startIcon: emoji.imageUrl(),
          content: `:${emoji.name}:`
        })
          .onClick((): void => this.toggleQuickReaction(message, emoji))
      }, (emoji: ChatEmoji): string => emoji.name)
    }
  }

  @Builder
  private MessageContextMenu(
    message: ChatMessage,
    capabilities: ChatMessageContextCapabilities
  ): void {
    Menu() {
      if (capabilities.canReact) {
        MenuItem(this.QuickReactionBar(message))
          .padding(0)
          .margin({ bottom: 9 })
          .backgroundColor(Color.Transparent)
      }
      MenuItemGroup() {
        if (capabilities.canReply) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.arrowshape_turn_up_left')),
            content: $r('app.string.action_reply')
          })
            .onClick((): void => this.onReply(message.id))
        }
        if (capabilities.canReact) {
          MenuItem({
            startIcon: this.quickReactionEmojis()[0].imageUrl(),
            content: $r('app.string.chat_reaction_add'),
            builder: this.ReactionSubmenu(message)
          })
        }
        MenuItem({
          symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.square_and_square')),
          content: $r('app.string.action_copy')
        })
          .onClick((): void => this.onCopyMessage(message.message))
        if (capabilities.canCopyLink) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.link')),
            content: $r('app.string.action_copy_link')
          })
            .onClick((): void => this.copyMessageLink(message))
        }
        if (capabilities.canMention) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier($r('sys.symbol.at')),
            content: `@${message.username}`
          })
            .onClick((): void => this.onMention(message.username))
        }
        if (capabilities.canDelete || capabilities.canRestore) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier(capabilities.canRestore
              ? $r('sys.symbol.arrow_clockwise')
              : $r('sys.symbol.trash')),
            content: capabilities.canRestore
              ? $r('app.string.action_restore')
              : $r('app.string.action_delete')
          })
            .contentFontColor($r('app.color.status_error'))
            .onClick((): void => {
              if (capabilities.canRestore) {
                this.onRestore(message.id);
              } else {
                this.onDelete(message.id);
              }
            })
        }
      }
      .width(288)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(18)
      .clip(true)
    }
    .width(300)
    .backgroundColor(Color.Transparent)
  }

  @Builder
  private MessageBody(message: ChatMessage): void {
    Text() {
      ForEach(presentChatMessageBody(message, this.emojis), (fragment: ChatMessageFragment) => {
        if (fragment.kind === ChatMessageFragmentKind.EMOJI) {
          ImageSpan(fragment.imageUrl)
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(fragment.text)
        }
      }, (fragment: ChatMessageFragment, index: number): string => `${index}-${fragment.text}`)
    }
    .fontSize(14)
    .lineHeight(21)
    .fontColor(message.deleted ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
    .fontStyle(message.deleted ? FontStyle.Italic : FontStyle.Normal)
    .width('100%')
  }

  @Builder
  private ReplyPreviewText(value: string): void {
    Text() {
      ForEach(presentChatText(value, this.emojis), (fragment: ChatMessageFragment) => {
        if (fragment.kind === ChatMessageFragmentKind.EMOJI) {
          ImageSpan(fragment.imageUrl)
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(fragment.text)
        }
      }, (fragment: ChatMessageFragment, index: number): string => `${index}-${fragment.text}`)
    }
    .fontSize(11)
    .fontColor($r('sys.color.font_secondary'))
    .maxLines(2)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
  }

  @Builder
  private LoadingState(): void {
    Column({ space: 12 }) {
      LoadingProgress().width(36).height(36)
      Text($r('app.string.chat_message_loading')).fontSize(13).fontColor($r('sys.color.font_secondary'))
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  private ErrorState(): void {
    Column({ space: 12 }) {
      Text($r('app.string.chat_message_load_failed')).fontSize(20).fontWeight(FontWeight.Bold)
      Text(this.state.message).fontSize(13).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
      Button($r('app.string.common_retry')).onClick(this.onRetry)
    }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ReactionChip(message: ChatMessage, reaction: ChatReaction): void {
    Row({ space: 4 }) {
      if (this.emojiUrlForReaction(reaction).length > 0) {
        Image(this.emojiUrlForReaction(reaction))
          .width(18).height(18).objectFit(ImageFit.Contain)
      } else {
        Text(`:${reaction.emoji.replace(/:/g, '')}:`).fontSize(11)
      }
      Text(reaction.count.toString()).fontSize(11).fontColor($r('sys.color.font_secondary'))
    }
    .height(28).padding({ left: 8, right: 8 }).borderRadius(14)
    .backgroundColor($r('sys.color.background_secondary'))
    .onClick((): void => this.onReact(
      message.id,
      reaction.emoji,
      reaction.reacted ? ChatReactionAction.REMOVE : ChatReactionAction.ADD
    ))
    .accessibilityText(
      `${reaction.emoji}，${reaction.count} 人${reaction.users.length > 0
        ? `，${reaction.users.map((user: ChatReactionUser): string => user.username).join('、')}` : ''}`
    )
  }

  @Builder
  private AuthorAvatar(message: ChatMessage, visible: boolean): void {
    if (visible) {
      if (message.avatarUrl.length > 0) {
        Image(message.avatarUrl)
          .width(36)
          .height(36)
          .objectFit(ImageFit.Cover)
          .borderRadius($r('app.float.forum_author_avatar_corner_radius'))
          .onClick((): void => this.onOpenProfile(message.username))
          .accessibilityText(`查看用户 ${this.displayUsername(message)}`)
      } else {
        Text(this.avatarInitial(message))
          .width(36)
          .height(36)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius($r('app.float.forum_author_avatar_corner_radius'))
          .onClick((): void => this.onOpenProfile(message.username))
          .accessibilityText(`查看用户 ${this.displayUsername(message)}`)
      }
    } else {
      Blank().width(36).height(1)
    }
  }

  @Builder
  private MessageBubbleSurface(message: ChatMessage, groupStart: boolean): void {
    Column({ space: 7 }) {
      if (groupStart) {
        Row({ space: 8 }) {
          Text(this.displayUsername(message))
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(formatChatMessageTimestamp(message.createdAt))
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
            .layoutWeight(1)
            .textAlign(message.username === this.currentUsername ? TextAlign.End : TextAlign.Start)
        }
        .width('100%')
      }

      if (message.replyTo !== null) {
        Column({ space: 3 }) {
          Text(`回复 ${message.replyTo.username}`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_link'))
          this.ReplyPreviewText(message.replyTo.excerpt)
        }
        .width('100%')
        .padding({ left: 9, right: 9, top: 7, bottom: 7 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(8)
        .border({ width: { left: 3 }, color: $r('app.color.quote_border') })
      }

      this.MessageBody(message)

      if (!message.deleted && message.uploadUrls.length > 0) {
        ForEach(message.uploadUrls, (url: string): void => {
          Image(absoluteChatUrl(url))
            .width('100%')
            .height(180)
            .borderRadius(10)
            .objectFit(ImageFit.Contain)
            .backgroundColor($r('sys.color.background_secondary'))
            .onClick((): void => this.onOpenImage(absoluteChatUrl(url)))
            .accessibilityText($r('app.string.chat_image_open_accessibility'))
        }, (url: string): string => url)
      }

      if (message.reactions.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(message.reactions, (reaction: ChatReaction): void => {
            this.ReactionChip(message, reaction)
          }, (reaction: ChatReaction): string => reaction.emoji)
        }
        .width('100%')
      }
    }
    .width('100%')
    .padding({ left: 11, right: 11, top: 9, bottom: 9 })
    .backgroundColor(message.username === this.currentUsername
      ? $r('app.color.brand_tint_surface')
      : $r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({
      width: message.username === this.currentUsername ? 0 : 1,
      color: $r('sys.color.comp_divider')
    })
  }

  @Builder
  private MessageBubble(message: ChatMessage, groupStart: boolean): void {
    Column() {
      this.MessageBubbleSurface(message, groupStart)
    }
    .layoutWeight(1)
    .accessibilityText(`${this.displayUsername(message)}：${message.displayText()}，长按显示消息操作`)
  }

  @Builder
  private MessageContextPreview(message: ChatMessage): void {
    Row({ space: 8 }) {
      if (message.username !== this.currentUsername) {
        this.AuthorAvatar(message, true)
      }
      this.MessageBubble(message, true)
      if (message.username === this.currentUsername) {
        this.AuthorAvatar(message, true)
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
  }

  @Builder
  private MessageRow(message: ChatMessage, groupStart: boolean): void {
    Row() {
      Row({ space: 8 }) {
        if (message.username !== this.currentUsername) {
          this.AuthorAvatar(message, groupStart)
        }
        this.MessageBubble(message, groupStart)
        if (message.username === this.currentUsername) {
          this.AuthorAvatar(message, groupStart)
        }
      }
      .width('91%')
      .alignItems(VerticalAlign.Top)
      .bindContextMenu(
        this.MessageContextMenu(message, this.messageContextCapabilities(message)),
        ResponseType.LongPress,
        {
          preview: groupStart ? MenuPreviewMode.IMAGE : this.MessageContextPreview(message),
          previewBorderRadius: 0,
          previewScaleMode: PreviewScaleMode.MAINTAIN,
          previewAnimationOptions: {
            scale: [0.98, 1.0],
            hoverScale: [1.0, 1.02],
            hoverScaleInterruption: true
          },
          placement: message.username === this.currentUsername ? Placement.TopRight : Placement.TopLeft,
          layoutRegionMargin: { left: 12, right: 12, top: 16, bottom: 16 },
          backgroundColor: Color.Transparent,
          backgroundBlurStyle: BlurStyle.NONE,
          borderRadius: 0,
          mask: true,
          hapticFeedbackMode: HapticFeedbackMode.ENABLED
        }
      )
    }
    .width('100%')
    .justifyContent(message.username === this.currentUsername ? FlexAlign.End : FlexAlign.Start)
    .margin({ top: groupStart ? 10 : 3 })
  }

  @Builder
  private MessageList(): void {
    List({ space: 0 }) {
      if (this.state.canLoadMorePast || this.state.loadingPast || this.state.message.length > 0) {
        ListItem() {
          Column({ space: 5 }) {
            if (this.state.message.length > 0) {
              Text(this.state.message).fontSize(11).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
            }
            if (this.state.canLoadMorePast || this.state.loadingPast) {
              Button(this.state.loadingPast
                ? $r('app.string.chat_message_loading_more')
                : $r('app.string.chat_message_load_older'), { type: ButtonType.Normal })
                .enabled(!this.state.loadingPast)
                .height(32)
                .fontSize(12)
                .fontColor($r('app.color.text_link'))
                .backgroundColor(Color.Transparent)
                .onClick(this.onLoadOlder)
            }
          }.width('100%').padding({ top: 4, bottom: 4 })
        }
      }
      ForEach(this.state.messages, (message: ChatMessage, index: number): void => {
        ListItem() {
          this.MessageRow(message, isChatMessageGroupStart(this.state.messages, index))
        }
      }, (message: ChatMessage): string => message.id.toString())
      if (this.state.canLoadMoreFuture || this.state.loadingFuture) {
        ListItem() {
          Button(this.state.loadingFuture
            ? $r('app.string.chat_message_loading_more')
            : $r('app.string.chat_message_load_newer'), { type: ButtonType.Normal })
            .width('100%')
            .height(32)
            .fontSize(12)
            .fontColor($r('app.color.text_link'))
            .backgroundColor(Color.Transparent)
            .enabled(!this.state.loadingFuture)
            .onClick(this.onLoadNewer)
        }
      }
    }
    .layoutWeight(1).width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.background_secondary')).edgeEffect(EdgeEffect.Spring)
    .onReachEnd(this.onLoadNewer)
  }

  @Builder
  private EmojiBar(): void {
    if (this.emojiPickerVisible && this.emojis.length > 0) {
      Column({ space: 7 }) {
        TextInput({ text: this.emojiQuery, placeholder: $r('app.string.chat_emoji_search_placeholder') })
          .width('100%')
          .height(36)
          .fontSize(12)
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(18)
          .enabled(this.canWrite())
          .onChange((value: string): void => { this.emojiQuery = value; })
        List({ space: 6 }) {
          ForEach(this.visibleEmojis(), (emoji: ChatEmoji): void => {
            ListItem() {
              Button() {
                Image(emoji.imageUrl()).width(22).height(22).objectFit(ImageFit.Contain)
              }
              .width(36)
              .height(36)
              .borderRadius(18)
              .backgroundColor($r('sys.color.background_secondary'))
              .enabled(this.canWrite())
              .onClick((): void => this.insertEmoji(emoji.name))
              .accessibilityText(`插入 Emoji ${emoji.name}`)
            }
          }, (emoji: ChatEmoji): string => emoji.name)
        }
        .width('100%')
        .height(42)
        .listDirection(Axis.Horizontal)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .padding({ left: 2, right: 2, top: 2, bottom: 2 })
    }
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
              if (user.avatarTemplate.length > 0) {
                Image(absoluteChatUrl(user.avatarTemplate.replace('{size}', '48')))
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .objectFit(ImageFit.Cover)
              }
              Column({ space: 2 }) {
                Text(`@${user.username}`).fontSize(13).fontWeight(FontWeight.Medium)
                if (user.name.length > 0) {
                  Text(user.name).fontSize(11).fontColor($r('sys.color.font_secondary')).maxLines(1)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .onClick((): void => this.selectMention(user))
            .accessibilityText(`提及用户 ${user.username}`)
          }, (user: ComposerMentionUser): string => user.username)
        } else {
          Text(this.mentionMessage).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding(8)
        }
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(10)
    }
  }

  @Builder
  private ReplyComposerBar(reply: ChatMessage | null): void {
    if (reply !== null) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(`回复 ${reply.username}`)
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_link'))
          this.ReplyPreviewText(reply.displayText())
        }
        .layoutWeight(1)
        Button('×', { type: ButtonType.Normal })
          .width(28)
          .height(28)
          .fontSize(18)
          .backgroundColor(Color.Transparent)
          .onClick(this.onCancelReply)
          .accessibilityText($r('app.string.action_cancel'))
      }
      .width('100%')
      .padding({ left: 10, right: 6, top: 7, bottom: 7 })
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius(8)
      .border({ width: { left: 3 }, color: $r('app.color.quote_border') })
    }
  }

  @Builder
  private Composer(): void {
    Column({ space: 8 }) {
      this.ReplyComposerBar(this.messageForId(this.composer.replyToMessageId))
      if (this.composer.uploads.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.composer.uploads, (upload: MediaUploadResult): void => {
            Stack({ alignContent: Alignment.TopEnd }) {
              Image(absoluteChatUrl(upload.url.length > 0 ? upload.url : upload.shortUrl))
                .width(64)
                .height(64)
                .objectFit(ImageFit.Cover)
                .borderRadius(8)
              Button('×', { type: ButtonType.Normal })
                .width(24)
                .height(24)
                .fontSize(14)
                .backgroundColor($r('sys.color.comp_background_primary'))
                .onClick((): void => this.onRemoveUpload(upload.id))
                .accessibilityText(`移除图片 ${upload.originalFilename}`)
            }
            .width(64)
            .height(64)
            .margin({ right: 8, bottom: 8 })
          }, (upload: MediaUploadResult): string => upload.id.toString())
        }
        .width('100%')
      }
      if (this.uploadState !== null) {
        Row({ space: 8 }) {
          Text(this.uploadState.message.length > 0
            ? this.uploadState.message
            : `图片上传 ${this.uploadState.progressPercent}%`)
            .fontSize(11).fontColor(this.uploadState.kind === MediaUploadStateKind.FAILED
              ? $r('app.color.status_error')
              : $r('sys.color.font_secondary'))
            .layoutWeight(1)
          if (this.uploadState.canCancel()) {
            Button($r('app.string.action_cancel')).height(28).fontSize(10).onClick(this.onCancelUpload)
          } else if (this.uploadState.canRetry()) {
            Button($r('app.string.common_retry')).height(28).fontSize(10).onClick(this.onRetryUpload)
          }
        }.width('100%')
      }
      this.EmojiBar()
      this.MentionSuggestions()
      Row({ space: 7 }) {
        Button() {
          SymbolGlyph($r('sys.symbol.ohos_photo'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_primary')])
        }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor($r('sys.color.background_secondary'))
          .enabled(!this.composer.sending && this.canWrite())
          .onClick(this.onSelectImages).accessibilityText($r('app.string.chat_image_select_accessibility'))
        TextArea({
          text: this.composer.draft,
          placeholder: $r('app.string.chat_composer_placeholder'),
          controller: this.composerController
        })
          .layoutWeight(1)
          .constraintSize({ minHeight: 42, maxHeight: 100 })
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(20)
          .enabled(this.canWrite()).onChange((value: string): void => {
            this.handleDraftChange(value);
          })
          .onTextSelectionChange((selectionStart: number, selectionEnd: number): void => {
            this.composerSelectionStart = selectionStart;
            this.composerSelectionEnd = selectionEnd;
            this.scheduleMentionSearch(this.composer.draft, selectionEnd);
          })
        if (this.emojis.length > 0) {
          Button() {
            Image(this.emojis[0].imageUrl())
              .width(20)
              .height(20)
              .objectFit(ImageFit.Contain)
          }
            .width(40)
            .height(40)
            .borderRadius(20)
            .backgroundColor(this.emojiPickerVisible
              ? $r('app.color.brand_selected_surface')
              : $r('sys.color.background_secondary'))
            .enabled(this.canWrite())
            .onClick((): void => { this.emojiPickerVisible = !this.emojiPickerVisible; })
            .accessibilityText($r('app.string.chat_emoji_toggle_accessibility'))
        }
        Button() { SymbolGlyph($r('sys.symbol.paperplane')).fontSize(20) }
          .width(44)
          .height(44)
          .borderRadius(22)
          .enabled(this.canWrite() && !this.composer.sending &&
            (this.composer.draft.trim().length > 0 || this.composer.uploads.length > 0))
          .onClick(this.onSend).accessibilityText($r('app.string.chat_send_accessibility'))
      }
      .width('100%')
      if (this.composer.message.length > 0) {
        Text(this.composer.message).fontSize(11)
          .fontColor(this.composer.sending ? $r('sys.color.font_secondary') : $r('app.color.status_error')).width('100%')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 1 }, color: $r('sys.color.comp_divider') })
  }

  build() {
    Column() {
      if (this.state.channel !== null && !this.state.channel.isDirectMessage) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.message'))
            .fontSize(16)
            .fontColor([$r('sys.color.font_secondary')])
          Text(this.state.channel.subtitle)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Button() {
            Text('···').fontSize(18).fontWeight(FontWeight.Bold)
          }
          .width(36)
          .height(32)
          .borderRadius(16)
          .backgroundColor(Color.Transparent)
          .onClick((): void => this.showChannelActions())
          .accessibilityText($r('app.string.chat_channel_actions_accessibility'))
        }
        .width('100%')
        .height(42)
        .padding({ left: 12, right: 8 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })
      }
      if (this.state.channel?.userSilenced === true) {
        Text($r('app.string.chat_silenced_message'))
          .fontSize(11).fontColor($r('app.color.status_error')).width('100%')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.background_secondary'))
      }
      if (this.state.kind === ChatStateKind.LOADING) {
        this.LoadingState()
      } else if (this.state.kind === ChatStateKind.ERROR) {
        this.ErrorState()
      } else {
        this.MessageList()
        this.Composer()
      }
    }
    .width('100%').height('100%').backgroundColor($r('sys.color.background_secondary'))
  }
}
