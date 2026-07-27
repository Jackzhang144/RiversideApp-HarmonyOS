import { KeyboardAvoidMode, SymbolGlyphModifier } from '@kit.ArkUI';
import {
  ChatComposerState,
  ChatConversationState,
  ChatPinnedMessageState,
  ChatStateKind
} from '../app/ChatStateModels';
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
  ChatChannelNotificationLevel,
  chatChannelNotificationLevelLabel,
  ChatEmoji,
  ChatMessage,
  ChatPinnedMessage,
  ChatReaction,
  ChatReactionAction,
  ChatReactionUser
} from '../models/ChatModels';
import { MediaUploadResult, MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import { imageViewerTransitionId } from '../models/ImageViewerModels';
import {
  ImageAspectRatio,
  resolveImageAspectRatio,
  updateImageAspectRatios
} from '../models/ImageAspectRatioModels';
import { RemoteContentImage } from './RemoteContentImage';
import {
  ChatMessageContextCapabilities,
  ChatMessageFragment,
  ChatMessageFragmentKind,
  chatEmojiGroups,
  filterChatReactionEmojis,
  initialChatMessageIndex,
  isChatMessageGroupStart,
  presentChatMessageBody,
  presentChatText,
  resolveChatMessageContextCapabilities,
  selectQuickChatEmojis,
  visibleChatMessageId
} from './ChatMessagePresentation';
import { compactActivityTime } from './ActivityTimePresentation';
import { UserAvatar } from './UserAvatar';

const CHAT_QUICK_REACTION_LIMIT: number = 5;
const CHAT_MESSAGE_BUBBLE_MAX_WIDTH: number = 238;
const CHAT_MESSAGE_CONTENT_MAX_WIDTH: number = 216;
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
  @Prop @Watch('synchronizeMessageViewport') state: ChatConversationState = ChatConversationState.initial();
  @Prop composer: ChatComposerState = new ChatComposerState();
  @Prop pinnedMessageState: ChatPinnedMessageState = ChatPinnedMessageState.initial();
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop uploadState: MediaUploadState | null = null;
  @Prop currentUsername: string = '';
  @Prop initialFocusMessageId: number | null = null;
  @State emojiQuery: string = '';
  @State emojiPickerVisible: boolean = false;
  @State reactionSheetVisible: boolean = false;
  @State reactionMessageId: number | null = null;
  @State reactionEmojiQuery: string = '';
  @State reactionEmojiGroup: string = '';
  @State channelSettingsVisible: boolean = false;
  @State channelSettingsSaving: boolean = false;
  @State channelSettingsMessage: string = '';
  @State pinnedPanelActive: boolean = false;
  @State pinnedMessageSavingId: number = 0;
  @State mentionUsers: Array<ComposerMentionUser> = [];
  @State mentionLoading: boolean = false;
  @State mentionMessage: string = '';
  @State imageRatios: Array<ImageAspectRatio> = [];
  onRetry: () => void = (): void => {};
  onLoadOlder: () => void = (): void => {};
  onLoadNewer: () => void = (): void => {};
  onReadProgress: (messageId: number) => void = (_messageId: number): void => {};
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
  onOpenImage: (url: string, transitionId: string) => void = (
    _url: string,
    _transitionId: string
  ): void => {};
  onOpenProfile: (username: string) => void = (_username: string): void => {};
  onUpdateNotificationLevel: (level: ChatChannelNotificationLevel) => Promise<boolean> =
    async (_level: ChatChannelNotificationLevel): Promise<boolean> => false;
  onSetChannelMuted: (muted: boolean) => Promise<boolean> =
    async (_muted: boolean): Promise<boolean> => false;
  onLoadPinnedMessages: () => void = (): void => {};
  onOpenPinnedMessage: (messageId: number) => void = (_messageId: number): void => {};
  onSetMessagePinned: (messageId: number, pinned: boolean) => Promise<boolean> =
    async (_messageId: number, _pinned: boolean): Promise<boolean> => false;
  onLeaveChannel: () => void = (): void => {};
  private readonly composerController: TextAreaController = new TextAreaController();
  private readonly mentionRequestGate: ComposerMentionRequestGate = new ComposerMentionRequestGate();
  messageScroller: Scroller = new Scroller();
  private mentionTimer: number = -1;
  private reactionSheetTimer: number = -1;
  private readProgressTimer: number = -1;
  private pendingReadMessageId: number = 0;
  private viewportChannelId: number = 0;
  private viewportMessageCount: number = 0;
  private viewportFirstMessageId: number = 0;
  private viewportLastMessageId: number = 0;
  private visibleStartIndex: number = 0;
  private visibleEndIndex: number = -1;
  private viewportReady: boolean = false;
  private pastBoundaryArmed: boolean = false;
  private futureBoundaryArmed: boolean = false;
  private pastLoadRequested: boolean = false;
  private futureLoadRequested: boolean = false;
  private historyAnchorMessageId: number = 0;
  private composerSelectionStart: number = 0;
  private composerSelectionEnd: number = 0;
  private previousKeyboardAvoidMode: KeyboardAvoidMode | null = null;

  aboutToAppear(): void {
    this.previousKeyboardAvoidMode = this.getUIContext().getKeyboardAvoidMode();
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.synchronizeMessageViewport();
  }

  aboutToDisappear(): void {
    this.cancelMentionTimer();
    this.cancelReactionSheetTimer();
    this.cancelReadProgressTimer();
    this.flushReadProgress();
    this.mentionRequestGate.invalidate();
    if (this.previousKeyboardAvoidMode !== null) {
      this.getUIContext().setKeyboardAvoidMode(this.previousKeyboardAvoidMode);
      this.previousKeyboardAvoidMode = null;
    }
  }

  private cancelMentionTimer(): void {
    if (this.mentionTimer >= 0) {
      clearTimeout(this.mentionTimer);
      this.mentionTimer = -1;
    }
  }

  private cancelReactionSheetTimer(): void {
    if (this.reactionSheetTimer >= 0) {
      clearTimeout(this.reactionSheetTimer);
      this.reactionSheetTimer = -1;
    }
  }

  private cancelReadProgressTimer(): void {
    if (this.readProgressTimer >= 0) {
      clearTimeout(this.readProgressTimer);
      this.readProgressTimer = -1;
    }
  }

  private scheduleReadProgress(visibleIndex: number): void {
    if (!this.viewportReady) {
      return;
    }
    const messageId: number | null = visibleChatMessageId(this.state.messages, visibleIndex);
    if (messageId === null) {
      return;
    }
    this.pendingReadMessageId = Math.max(this.pendingReadMessageId, messageId);
    this.cancelReadProgressTimer();
    this.readProgressTimer = setTimeout((): void => {
      this.readProgressTimer = -1;
      this.flushReadProgress();
    }, 1000);
  }

  private flushReadProgress(): void {
    const messageId: number = this.pendingReadMessageId;
    this.pendingReadMessageId = 0;
    if (messageId > 0) {
      this.onReadProgress(messageId);
    }
  }

  private chatImageTransitionId(messageId: number, index: number): string {
    return imageViewerTransitionId(`chat-message-${messageId}`, index);
  }

  private chatImageAspectRatio(url: string): number {
    return resolveImageAspectRatio(this.imageRatios, url);
  }

  private recordChatImageRatio(url: string, width: number, height: number): void {
    this.imageRatios = updateImageAspectRatios(this.imageRatios, url, width, height);
  }

  private synchronizeMessageViewport(): void {
    const channelId: number = this.state.channel?.id ?? 0;
    const messages: Array<ChatMessage> = this.state.messages;
    if (channelId <= 0 || messages.length === 0) {
      if (channelId !== this.viewportChannelId) {
        this.viewportReady = false;
        this.viewportChannelId = channelId;
        this.viewportMessageCount = 0;
        this.viewportFirstMessageId = 0;
        this.viewportLastMessageId = 0;
        this.visibleStartIndex = 0;
        this.visibleEndIndex = -1;
      }
      return;
    }

    const previousCount: number = this.viewportMessageCount;
    const previousFirstMessageId: number = this.viewportFirstMessageId;
    const previousLastMessageId: number = this.viewportLastMessageId;
    const channelChanged: boolean = channelId !== this.viewportChannelId;
    const initialViewport: boolean = channelChanged || previousCount === 0;
    const wasAtLatest: boolean = previousCount > 0 && this.visibleEndIndex >= previousCount - 1;
    const firstMessageId: number = messages[0].id;
    const lastMessageId: number = messages[messages.length - 1].id;
    const appendedMessages: boolean = !initialViewport && firstMessageId === previousFirstMessageId &&
      lastMessageId !== previousLastMessageId && messages.length > previousCount;
    const futurePaginationAppend: boolean = this.futureLoadRequested;

    this.viewportChannelId = channelId;
    this.viewportMessageCount = messages.length;
    this.viewportFirstMessageId = firstMessageId;
    this.viewportLastMessageId = lastMessageId;

    if (initialViewport) {
      this.viewportReady = false;
      this.pastLoadRequested = false;
      this.futureLoadRequested = false;
      this.historyAnchorMessageId = 0;
      setTimeout((): void => {
        if (this.state.channel?.id !== channelId || this.state.messages.length === 0) {
          return;
        }
        const targetIndex: number = initialChatMessageIndex(this.state.messages, this.initialFocusMessageId);
        if (targetIndex >= 0) {
          const alignment: ScrollAlign = this.initialFocusMessageId === null ? ScrollAlign.END : ScrollAlign.CENTER;
          this.messageScroller.scrollToIndex(targetIndex, false, alignment);
          this.visibleStartIndex = targetIndex;
          this.visibleEndIndex = targetIndex;
          this.viewportReady = true;
          this.scheduleReadProgress(targetIndex);
        }
      }, 50);
      return;
    }

    if (this.pastLoadRequested && !this.state.loadingPast) {
      const anchorIndex: number = messages.findIndex(
        (message: ChatMessage): boolean => message.id === this.historyAnchorMessageId
      );
      this.pastLoadRequested = false;
      this.historyAnchorMessageId = 0;
      if (anchorIndex >= 0 && firstMessageId !== previousFirstMessageId) {
        setTimeout((): void => this.messageScroller.scrollToIndex(anchorIndex, false, ScrollAlign.START), 50);
      }
    }
    if (this.futureLoadRequested && !this.state.loadingFuture) {
      this.futureLoadRequested = false;
    }
    if (appendedMessages && wasAtLatest && !futurePaginationAppend) {
      setTimeout((): void => {
        this.messageScroller.scrollToIndex(this.state.messages.length - 1, false, ScrollAlign.END);
      }, 50);
    }
  }

  private requestOlderMessages(): void {
    if (
      !this.pastBoundaryArmed ||
      this.pastLoadRequested ||
      this.state.loadingPast ||
      !this.state.canLoadMorePast ||
      this.state.messages.length === 0
    ) {
      return;
    }
    const anchorMessageId: number | null = visibleChatMessageId(this.state.messages, this.visibleStartIndex);
    if (anchorMessageId === null) {
      return;
    }
    this.pastBoundaryArmed = false;
    this.pastLoadRequested = true;
    this.historyAnchorMessageId = anchorMessageId;
    this.onLoadOlder();
  }

  private requestNewerMessages(): void {
    if (
      !this.futureBoundaryArmed ||
      this.futureLoadRequested ||
      this.state.loadingFuture ||
      !this.state.canLoadMoreFuture ||
      this.state.messages.length === 0
    ) {
      return;
    }
    this.futureBoundaryArmed = false;
    this.futureLoadRequested = true;
    this.onLoadNewer();
  }

  private handleVisibleMessageRange(startIndex: number, endIndex: number): void {
    if (this.state.messages.length === 0) {
      return;
    }
    this.visibleStartIndex = Math.max(0, Math.min(startIndex, this.state.messages.length - 1));
    this.visibleEndIndex = Math.max(this.visibleStartIndex, Math.min(endIndex, this.state.messages.length - 1));
    this.scheduleReadProgress(this.visibleEndIndex);
    if (this.visibleStartIndex <= 2) {
      this.requestOlderMessages();
    }
    if (this.visibleEndIndex >= this.state.messages.length - 3) {
      this.requestNewerMessages();
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

  private canSend(): boolean {
    return this.canWrite() &&
      !this.composer.sending &&
      (this.composer.draft.trim().length > 0 || this.composer.uploads.length > 0);
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

  private reactionEmojiGroups(): Array<string> {
    return chatEmojiGroups(this.emojis);
  }

  private visibleReactionEmojis(): Array<ChatEmoji> {
    return filterChatReactionEmojis(this.emojis, this.reactionEmojiGroup, this.reactionEmojiQuery);
  }

  private visibleEmojis(): Array<ChatEmoji> {
    const query: string = this.emojiQuery.trim().toLowerCase();
    return this.emojis.filter((emoji: ChatEmoji): boolean => query.length === 0 ||
      emoji.name.toLowerCase().includes(query) || emoji.group.toLowerCase().includes(query)).slice(0, 40);
  }

  private displayUsername(message: ChatMessage): string {
    return message.username.length > 0 ? message.username : '未知用户';
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

  private openReactionSheet(message: ChatMessage): void {
    this.reactionMessageId = message.id;
    this.reactionEmojiQuery = '';
    this.reactionEmojiGroup = '';
    this.getUIContext().getContextMenuController().close();
    this.cancelReactionSheetTimer();
    this.reactionSheetTimer = setTimeout((): void => {
      this.reactionSheetTimer = -1;
      if (this.messageForId(message.id) !== null) {
        this.reactionSheetVisible = true;
      }
    }, 120);
  }

  private selectReactionFromSheet(emoji: ChatEmoji): void {
    const message: ChatMessage | null = this.messageForId(this.reactionMessageId);
    if (message === null) {
      this.reactionSheetVisible = false;
      return;
    }
    this.toggleQuickReaction(message, emoji);
    this.reactionSheetVisible = false;
  }

  private reactionGroupLabel(group: string): ResourceStr {
    const normalizedGroup: string = group.trim().toLowerCase();
    if (normalizedGroup === 'smileys_&_emotion') {
      return $r('app.string.chat_reaction_group_emotion');
    }
    if (normalizedGroup === 'people_&_body' || normalizedGroup === 'people') {
      return $r('app.string.chat_reaction_group_people');
    }
    if (normalizedGroup === 'animals_&_nature') {
      return $r('app.string.chat_reaction_group_animals');
    }
    if (normalizedGroup === 'food_&_drink') {
      return $r('app.string.chat_reaction_group_food');
    }
    if (normalizedGroup === 'travel_&_places') {
      return $r('app.string.chat_reaction_group_travel');
    }
    if (normalizedGroup === 'activities') {
      return $r('app.string.chat_reaction_group_activities');
    }
    if (normalizedGroup === 'objects') {
      return $r('app.string.chat_reaction_group_objects');
    }
    if (normalizedGroup === 'symbols') {
      return $r('app.string.chat_reaction_group_symbols');
    }
    if (normalizedGroup === 'flags') {
      return $r('app.string.chat_reaction_group_flags');
    }
    if (normalizedGroup === 'custom') {
      return $r('app.string.chat_reaction_group_custom');
    }
    return group.replace(/_/g, ' ');
  }

  private showChannelActions(): void {
    const channel: ChatChannel | null = this.state.channel;
    if (channel === null) {
      return;
    }
    this.channelSettingsMessage = '';
    this.channelSettingsVisible = true;
  }

  private notificationLevelIcon(level: ChatChannelNotificationLevel): Resource {
    if (level === ChatChannelNotificationLevel.ALWAYS) return $r('sys.symbol.bell');
    if (level === ChatChannelNotificationLevel.MENTION) return $r('sys.symbol.at');
    return $r('sys.symbol.eye_slash');
  }

  private notificationLevelDescription(level: ChatChannelNotificationLevel): string {
    if (level === ChatChannelNotificationLevel.ALWAYS) return '频道内每条新消息都会提醒';
    if (level === ChatChannelNotificationLevel.MENTION) return '有人提及你时才提醒';
    return '保留未读计数，但不发送提醒';
  }

  private async saveNotificationLevel(level: ChatChannelNotificationLevel): Promise<void> {
    const channel: ChatChannel | null = this.state.channel;
    if (channel === null || this.channelSettingsSaving || channel.notificationLevel === level) return;
    this.channelSettingsSaving = true;
    this.channelSettingsMessage = '';
    const succeeded: boolean = await this.onUpdateNotificationLevel(level);
    this.channelSettingsSaving = false;
    if (!succeeded) {
      this.channelSettingsMessage = '通知设置未保存，请稍后重试';
    }
  }

  private async saveChannelMuted(muted: boolean): Promise<void> {
    const channel: ChatChannel | null = this.state.channel;
    if (channel === null || this.channelSettingsSaving || channel.muted === muted) return;
    this.channelSettingsSaving = true;
    this.channelSettingsMessage = '';
    const succeeded: boolean = await this.onSetChannelMuted(muted);
    this.channelSettingsSaving = false;
    if (!succeeded) {
      this.channelSettingsMessage = '频道静音状态未保存，请稍后重试';
    }
  }

  private showPinnedMessages(): void {
    this.onLoadPinnedMessages();
    this.pinnedPanelActive = true;
  }

  private async togglePinnedMessage(message: ChatMessage): Promise<void> {
    if (this.pinnedMessageSavingId > 0) {
      return;
    }
    this.pinnedMessageSavingId = message.id;
    await this.onSetMessagePinned(message.id, !message.pinned);
    this.pinnedMessageSavingId = 0;
  }

  private pinnedByText(item: ChatPinnedMessage): string {
    if (item.pinnedByUsername.length === 0) {
      return '已置顶';
    }
    return item.pinnedByUsername === this.currentUsername
      ? '由你置顶'
      : `由 ${item.pinnedByUsername} 置顶`;
  }

  @Builder
  private PinnedMessagesEntry(): void {
    Row({ space: 12 }) {
      Stack({ alignContent: Alignment.TopEnd }) {
        SymbolGlyph($r('sys.symbol.pin_fill'))
          .fontSize(21)
          .fontColor([$r('app.color.brand_primary')])
          .width(38)
          .height(38)
          .padding(8)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(19)
        if (this.state.channel?.hasUnseenPins === true) {
          Circle()
            .width(9)
            .height(9)
            .fill($r('app.color.status_error'))
            .stroke($r('sys.color.comp_background_primary'))
            .strokeWidth(2)
        }
      }
      .width(40)
      .height(40)
      Column({ space: 3 }) {
        Text('置顶消息')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(`${this.state.channel?.pinnedMessagesCount ?? 0} 条频道置顶`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_forward'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(68)
    .padding({ left: 12, right: 14 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => this.showPinnedMessages())
    .accessibilityText(`置顶消息，${this.state.channel?.pinnedMessagesCount ?? 0} 条`)
  }

  @Builder
  private NotificationLevelRow(level: ChatChannelNotificationLevel): void {
    Row({ space: 12 }) {
      SymbolGlyph(this.notificationLevelIcon(level))
        .fontSize(21)
        .fontColor([
          this.state.channel?.notificationLevel === level
            ? $r('app.color.brand_primary')
            : $r('sys.color.font_secondary')
        ])
        .width(38)
        .height(38)
        .padding(8)
        .backgroundColor(this.state.channel?.notificationLevel === level
          ? $r('app.color.brand_tint_surface')
          : $r('sys.color.background_secondary'))
        .borderRadius(19)
      Column({ space: 3 }) {
        Text(chatChannelNotificationLevelLabel(level))
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(this.notificationLevelDescription(level))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.state.channel?.notificationLevel === level) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(21)
          .fontColor([$r('app.color.brand_primary')])
      }
    }
    .width('100%')
    .height(66)
    .padding({ left: 12, right: 14 })
    .backgroundColor(this.state.channel?.notificationLevel === level
      ? $r('app.color.brand_selected_surface')
      : Color.Transparent)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .enabled(!this.channelSettingsSaving)
    .onClick((): void => {
      this.saveNotificationLevel(level);
    })
    .accessibilityText(
      `${chatChannelNotificationLevelLabel(level)}${this.state.channel?.notificationLevel === level ? '，已选择' : ''}`
    )
  }

  @Builder
  private ChannelSettingsSheet(): void {
    Column({ space: 14 }) {
      Row({ space: 12 }) {
        SymbolGlyph(this.state.channel?.isDirectMessage === true
          ? $r('sys.symbol.envelope')
          : $r('sys.symbol.message'))
          .fontSize(22)
          .fontColor([$r('app.color.brand_primary')])
          .width(44)
          .height(44)
          .padding(10)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(22)
        Column({ space: 3 }) {
          Text(this.state.channel?.title ?? '聊天设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(this.state.channel?.isDirectMessage === true ? '直接消息' : (this.state.channel?.subtitle ?? '频道'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.channelSettingsSaving) {
          LoadingProgress().width(24).height(24)
        }
      }
      .width('100%')

      if (
        this.state.channel?.pinningEnabled === true ||
        (this.state.channel?.pinnedMessagesCount ?? 0) > 0 ||
        this.state.channel?.canManagePins === true
      ) {
        this.PinnedMessagesEntry()
      }

      Text('消息提醒')
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .padding({ left: 6 })
      Column() {
        this.NotificationLevelRow(ChatChannelNotificationLevel.NEVER)
        Divider().margin({ left: 62, right: 14 }).color($r('sys.color.comp_divider'))
        this.NotificationLevelRow(ChatChannelNotificationLevel.MENTION)
        Divider().margin({ left: 62, right: 14 }).color($r('sys.color.comp_divider'))
        this.NotificationLevelRow(ChatChannelNotificationLevel.ALWAYS)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .clip(true)

      Row({ space: 12 }) {
        SymbolGlyph($r('sys.symbol.bell'))
          .fontSize(21)
          .fontColor([$r('sys.color.font_secondary')])
          .width(38)
          .height(38)
          .padding(8)
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(19)
        Column({ space: 3 }) {
          Text('频道静音')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text('暂停此频道的声音和推送提醒')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.state.channel?.muted === true })
          .enabled(!this.channelSettingsSaving)
          .onChange((value: boolean): void => {
            this.saveChannelMuted(value);
          })
          .accessibilityText(`频道静音，${this.state.channel?.muted === true ? '已开启' : '已关闭'}`)
      }
      .width('100%')
      .height(68)
      .padding({ left: 12, right: 14 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })

      if (this.channelSettingsMessage.length > 0) {
        Text(this.channelSettingsMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
          .textAlign(TextAlign.Center)
      }

      if (this.state.channel?.isDirectMessage === false) {
        Button() {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(18)
              .fontColor([$r('app.color.status_error')])
            Text($r('app.string.chat_leave_channel'))
              .fontSize(14)
              .fontColor($r('app.color.status_error'))
          }
        }
        .width('100%')
        .height(44)
        .backgroundColor(Color.Transparent)
        .enabled(!this.channelSettingsSaving)
        .onClick((): void => {
          this.channelSettingsVisible = false;
          this.onLeaveChannel();
        })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 28 })
  }

  @Builder
  private PinnedMessageCard(item: ChatPinnedMessage): void {
    Column({ space: 9 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.pin_fill'))
          .fontSize(15)
          .fontColor([$r('app.color.brand_primary')])
        Text(this.pinnedByText(item))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_link'))
          .layoutWeight(1)
        Text(compactActivityTime(item.pinnedAt))
          .fontSize(10)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .width('100%')
      Row({ space: 9 }) {
        UserAvatar({
          avatarUrl: item.message.avatarUrl,
          displayName: this.displayUsername(item.message),
          avatarSize: 32,
          avatarAccessibilityText: `${this.displayUsername(item.message)} 的头像`,
          showFlair: false
        })
        Column({ space: 5 }) {
          Text(this.displayUsername(item.message))
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
          this.MessageBody(item.message)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      if (item.message.uploadUrls.length > 0) {
        Image(absoluteChatUrl(item.message.uploadUrls[0]))
          .width('100%')
          .height(132)
          .objectFit(ImageFit.Cover)
          .borderRadius(12)
          .backgroundColor($r('sys.color.background_secondary'))
      }
    }
    .width('100%')
    .padding(13)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => {
      this.channelSettingsVisible = false;
      this.pinnedPanelActive = false;
      this.onOpenPinnedMessage(item.chatMessageId);
    })
    .accessibilityText(`${this.pinnedByText(item)}，${item.message.displayText()}`)
  }

  @Builder
  private PinnedMessagesSheet(): void {
    Column({ space: 12 }) {
      Row({ space: 10 }) {
        Button() {
          SymbolGlyph($r('sys.symbol.chevron_backward'))
            .fontSize(18)
            .fontColor([$r('sys.color.font_primary')])
        }
        .width(40)
        .height(40)
        .borderRadius(20)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .onClick((): void => {
          this.pinnedPanelActive = false;
        })
        .accessibilityText('返回聊天设置')
        SymbolGlyph($r('sys.symbol.pin_fill'))
          .fontSize(21)
          .fontColor([$r('app.color.brand_primary')])
          .width(42)
          .height(42)
          .padding(10)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(21)
        Column({ space: 2 }) {
          Text('置顶消息')
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
          Text(this.state.channel?.title ?? '当前频道')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (
          this.pinnedMessageState.kind === ChatStateKind.LOADING &&
          this.pinnedMessageState.pinnedMessages.length > 0
        ) {
          LoadingProgress().width(24).height(24)
        }
      }
      .width('100%')

      if (
        this.pinnedMessageState.kind === ChatStateKind.LOADING &&
        this.pinnedMessageState.pinnedMessages.length === 0
      ) {
        Column({ space: 10 }) {
          LoadingProgress().width(34).height(34)
          Text('正在加载置顶消息')
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (
        this.pinnedMessageState.kind === ChatStateKind.EMPTY ||
        this.pinnedMessageState.kind === ChatStateKind.INITIAL
      ) {
        Column({ space: 10 }) {
          SymbolGlyph($r('sys.symbol.pin'))
            .fontSize(32)
            .fontColor([$r('sys.color.font_tertiary')])
          Text('此频道暂无置顶消息')
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (
        this.pinnedMessageState.kind === ChatStateKind.ERROR &&
        this.pinnedMessageState.pinnedMessages.length === 0
      ) {
        Column({ space: 10 }) {
          Text(this.pinnedMessageState.message)
            .fontSize(13)
            .fontColor($r('app.color.status_error'))
            .textAlign(TextAlign.Center)
          Button('重新加载')
            .height(40)
            .backgroundColor($r('app.color.brand_primary'))
            .fontColor($r('app.color.on_accent'))
            .onClick((): void => this.onLoadPinnedMessages())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List({ space: 10 }) {
          ForEach(this.pinnedMessageState.pinnedMessages, (item: ChatPinnedMessage): void => {
            ListItem() {
              this.PinnedMessageCard(item)
            }
          }, (item: ChatPinnedMessage): string => item.id.toString())
        }
        .width('100%')
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 6, bottom: 22 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private ChannelPanelSheet(): void {
    Stack() {
      Column() {
        this.ChannelSettingsSheet()
      }
      .width('100%')
      .height('100%')
      .opacity(this.pinnedPanelActive ? 0 : 1)
      .translate({ x: this.pinnedPanelActive ? -28 : 0 })
      .hitTestBehavior(this.pinnedPanelActive ? HitTestMode.None : HitTestMode.Default)
      .animation({ duration: 220, curve: Curve.EaseOut })
      Column() {
        this.PinnedMessagesSheet()
      }
      .width('100%')
      .height('100%')
      .opacity(this.pinnedPanelActive ? 1 : 0)
      .translate({ x: this.pinnedPanelActive ? 0 : 28 })
      .hitTestBehavior(this.pinnedPanelActive ? HitTestMode.Default : HitTestMode.None)
      .animation({ duration: 220, curve: Curve.EaseOut })
    }
    .width('100%')
    .height('100%')
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
  private QuickReactionMoreButton(message: ChatMessage): void {
    Button() {
      SymbolGlyph($r('sys.symbol.square_grid_2x2'))
        .fontSize(22)
        .fontColor([$r('sys.color.font_primary')])
    }
    .width(40)
    .height(40)
    .borderRadius(20)
    .backgroundColor(Color.Transparent)
    .gesture(TapGesture().onAction((): void => this.openReactionSheet(message)))
    .accessibilityText($r('app.string.chat_reaction_more_accessibility'))
  }

  @Builder
  private QuickReactionBar(message: ChatMessage): void {
    Row({ space: 4 }) {
      ForEach(this.quickReactionEmojis(), (emoji: ChatEmoji): void => {
        this.QuickReactionButton(message, emoji)
      }, (emoji: ChatEmoji): string => emoji.name)
      this.QuickReactionMoreButton(message)
    }
    .width(280)
    .height(54)
    .padding({ left: 7, right: 7 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(27)
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
        if (capabilities.canPin) {
          MenuItem({
            symbolStartIcon: new SymbolGlyphModifier(message.pinned
              ? $r('sys.symbol.pin_slash')
              : $r('sys.symbol.pin')),
            content: message.pinned ? '取消置顶' : '置顶消息'
          })
            .enabled(this.pinnedMessageSavingId === 0)
            .onClick((): void => {
              this.togglePinnedMessage(message);
            })
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
  private ReactionGroupButton(group: string, label: ResourceStr): void {
    Button(label, { type: ButtonType.Normal })
      .height(36)
      .padding({ left: 14, right: 14 })
      .fontSize(13)
      .fontColor(this.reactionEmojiGroup === group
        ? $r('app.color.text_link')
        : $r('sys.color.font_secondary'))
      .backgroundColor(this.reactionEmojiGroup === group
        ? $r('app.color.brand_selected_surface')
        : Color.Transparent)
      .border({ width: 1, color: this.reactionEmojiGroup === group
        ? $r('app.color.brand_primary')
        : $r('sys.color.comp_divider') })
      .borderRadius(12)
      .onClick((): void => {
        this.reactionEmojiGroup = group;
      })
  }

  @Builder
  private ReactionSheetEmojiButton(emoji: ChatEmoji): void {
    Button() {
      Image(emoji.imageUrl())
        .width(34)
        .height(34)
        .objectFit(ImageFit.Contain)
    }
    .width('100%')
    .height(50)
    .backgroundColor(Color.Transparent)
    .onClick((): void => this.selectReactionFromSheet(emoji))
    .accessibilityText(`使用 ${emoji.name} 回应`)
  }

  @Builder
  private ReactionPickerSheet(): void {
    Column({ space: 12 }) {
      List({ space: 8 }) {
        ListItem() {
          this.ReactionGroupButton('', $r('app.string.chat_reaction_group_all'))
        }
        ForEach(this.reactionEmojiGroups(), (group: string): void => {
          ListItem() {
            this.ReactionGroupButton(group, this.reactionGroupLabel(group))
          }
        }, (group: string): string => group)
      }
      .width('100%')
      .height(52)
      .padding({ bottom: 10 })
      .listDirection(Axis.Horizontal)
      .edgeEffect(EdgeEffect.Spring)

      TextInput({
        text: this.reactionEmojiQuery,
        placeholder: $r('app.string.chat_reaction_search_placeholder')
      })
        .width('100%')
        .height(44)
        .fontSize(14)
        .backgroundColor($r('sys.color.background_secondary'))
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .borderRadius(12)
        .onChange((value: string): void => {
          this.reactionEmojiQuery = value;
        })
        .accessibilityText($r('app.string.chat_reaction_search_placeholder'))

      if (this.visibleReactionEmojis().length === 0) {
        Column() {
          Text($r('app.string.chat_reaction_empty'))
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Grid() {
          ForEach(this.visibleReactionEmojis(), (emoji: ChatEmoji): void => {
            GridItem() {
              this.ReactionSheetEmojiButton(emoji)
            }
          }, (emoji: ChatEmoji): string => emoji.name)
        }
        .columnsTemplate('1fr 1fr 1fr 1fr 1fr 1fr 1fr 1fr')
        .columnsGap(4)
        .rowsGap(4)
        .layoutWeight(1)
        .width('100%')
        .edgeEffect(EdgeEffect.Spring)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 4, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
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
    .constraintSize({ maxWidth: CHAT_MESSAGE_CONTENT_MAX_WIDTH })
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
    .constraintSize({ maxWidth: CHAT_MESSAGE_CONTENT_MAX_WIDTH })
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
      UserAvatar({
        avatarUrl: message.avatarUrl,
        displayName: this.displayUsername(message),
        avatarSize: 32,
        interactive: true,
        avatarAccessibilityText: `查看用户 ${this.displayUsername(message)}`,
        showFlair: false,
        onActivate: (): void => this.onOpenProfile(message.username)
      })
    } else {
      Blank().width(32).height(1)
    }
  }

  @Builder
  private MessageMetadata(message: ChatMessage): void {
    Row({ space: 7 }) {
      Text(this.displayUsername(message))
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Text(compactActivityTime(message.createdAt))
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
    }
    .constraintSize({ maxWidth: CHAT_MESSAGE_BUBBLE_MAX_WIDTH })
    .justifyContent(message.username === this.currentUsername ? FlexAlign.End : FlexAlign.Start)
  }

  @Builder
  private MessageBubbleSurface(message: ChatMessage): void {
    Column({ space: 7 }) {
      if (message.pinned) {
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.pin_fill'))
            .fontSize(13)
            .fontColor([$r('app.color.brand_primary')])
          Text('已置顶')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_link'))
        }
        .height(20)
        .padding({ left: 7, right: 7 })
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(10)
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
        ForEach(message.uploadUrls, (url: string, index: number): void => {
          RemoteContentImage({
            url: absoluteChatUrl(url),
            imageAspectRatio: this.chatImageAspectRatio(absoluteChatUrl(url)),
            displayWidth: CHAT_MESSAGE_CONTENT_MAX_WIDTH,
            cornerRadius: 10,
            transitionId: this.chatImageTransitionId(message.id, index),
            failureText: $r('app.string.rich_post_image_failed'),
            onLoaded: (width: number, height: number): void => {
              this.recordChatImageRatio(absoluteChatUrl(url), width, height);
            },
            onOpen: (): void => this.onOpenImage(
              absoluteChatUrl(url),
              this.chatImageTransitionId(message.id, index)
            )
          })
            .accessibilityText($r('app.string.chat_image_open_accessibility'))
        }, (url: string, index: number): string => `${index}-${url}`)
      }

      if (message.reactions.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(message.reactions, (reaction: ChatReaction): void => {
            this.ReactionChip(message, reaction)
          }, (reaction: ChatReaction): string => reaction.emoji)
        }
        .constraintSize({ maxWidth: CHAT_MESSAGE_CONTENT_MAX_WIDTH })
      }
    }
    .constraintSize({ minWidth: 56, maxWidth: CHAT_MESSAGE_BUBBLE_MAX_WIDTH })
    .alignItems(HorizontalAlign.Start)
    .padding({ left: 11, right: 11, top: 8, bottom: 8 })
    .backgroundColor(message.username === this.currentUsername
      ? $r('app.color.brand_selected_surface')
      : $r('sys.color.comp_background_primary'))
    .borderRadius(16)
    .border({
      width: message.username === this.currentUsername ? 0 : 1,
      color: $r('sys.color.comp_divider')
    })
  }

  @Builder
  private MessageBubble(message: ChatMessage, groupStart: boolean): void {
    Column({ space: 4 }) {
      if (groupStart) {
        this.MessageMetadata(message)
      }
      this.MessageBubbleSurface(message)
    }
    .constraintSize({ maxWidth: CHAT_MESSAGE_BUBBLE_MAX_WIDTH })
    .alignItems(message.username === this.currentUsername ? HorizontalAlign.End : HorizontalAlign.Start)
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
      .width('88%')
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
    .margin({ top: groupStart ? 12 : 4 })
    .opacity(this.reactionSheetVisible && this.reactionMessageId !== message.id ? 0.32 : 1)
  }

  @Builder
  private MessageList(): void {
    Stack({ alignContent: Alignment.Top }) {
      List({ space: 0, scroller: this.messageScroller }) {
        ForEach(this.state.messages, (message: ChatMessage, index: number): void => {
          ListItem() {
            this.MessageRow(message, isChatMessageGroupStart(this.state.messages, index))
          }
        }, (message: ChatMessage): string => message.id.toString())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 10 })
      .clip(true)
      .cachedCount(3, true)
      .backgroundColor($r('sys.color.background_secondary'))
      .edgeEffect(EdgeEffect.Spring)
      .stackFromEnd(true)
      .onScrollStart((): void => {
        this.pastBoundaryArmed = true;
        this.futureBoundaryArmed = true;
      })
      .onScrollIndex((startIndex: number, endIndex: number): void => {
        this.handleVisibleMessageRange(startIndex, endIndex);
      })
      .onReachStart((): void => this.requestOlderMessages())
      .onReachEnd((): void => this.requestNewerMessages())

      if (this.state.loadingPast) {
        Row({ space: 6 }) {
          LoadingProgress().width(16).height(16)
          Text($r('app.string.chat_message_loading_more'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
        }
        .height(28)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .position({ top: 6 })
        .hitTestBehavior(HitTestMode.None)
      } else if (this.state.message.length > 0) {
        Text(this.state.message)
          .fontSize(11)
          .fontColor($r('app.color.status_error'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(14)
          .position({ top: 6 })
          .hitTestBehavior(HitTestMode.None)
      }

      if (this.state.loadingFuture) {
        Row({ space: 6 }) {
          LoadingProgress().width(16).height(16)
          Text($r('app.string.chat_message_loading_more'))
            .fontSize(11)
            .fontColor($r('sys.color.font_secondary'))
        }
        .height(28)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .position({ bottom: 6 })
        .hitTestBehavior(HitTestMode.None)
      }
    }
    .layoutWeight(1)
    .width('100%')
    .clip(false)
    .backgroundColor($r('sys.color.background_secondary'))
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
              UserAvatar({
                avatarUrl: absoluteChatUrl(user.avatarTemplate.replace('{size}', '48')),
                displayName: user.name.length > 0 ? user.name : user.username,
                avatarSize: 28,
                avatarAccessibilityText: `${user.username} 的头像`,
                showFlair: false
              })
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
        Button({ type: ButtonType.Normal }) {
          SymbolGlyph($r('sys.symbol.xmark'))
            .fontSize(15)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(28)
        .height(28)
        .borderRadius(14)
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
              Button({ type: ButtonType.Normal }) {
                SymbolGlyph($r('sys.symbol.xmark'))
                  .fontSize(13)
                  .fontColor([$r('sys.color.font_primary')])
              }
              .width(24)
              .height(24)
              .borderRadius(12)
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
      Row({ space: 4 }) {
        Button() {
          SymbolGlyph($r('sys.symbol.ohos_photo'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
        }
          .width(36)
          .height(36)
          .borderRadius(18)
          .backgroundColor(Color.Transparent)
          .enabled(!this.composer.sending && this.canWrite())
          .onClick(this.onSelectImages).accessibilityText($r('app.string.chat_image_select_accessibility'))
        TextArea({
          text: this.composer.draft,
          placeholder: $r('app.string.chat_composer_placeholder'),
          controller: this.composerController
        })
          .layoutWeight(1)
          .constraintSize({ minHeight: 42, maxHeight: 100 })
          .backgroundColor(Color.Transparent)
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
            .width(36)
            .height(36)
            .borderRadius(18)
            .backgroundColor(this.emojiPickerVisible
              ? $r('app.color.brand_selected_surface')
              : Color.Transparent)
            .enabled(this.canWrite())
            .onClick((): void => { this.emojiPickerVisible = !this.emojiPickerVisible; })
            .accessibilityText($r('app.string.chat_emoji_toggle_accessibility'))
        }
        Button() {
          SymbolGlyph($r('sys.symbol.paperplane'))
            .fontSize(19)
            .fontColor([
              this.canSend()
                ? $r('app.color.on_accent')
                : $r('sys.color.font_tertiary')
            ])
        }
          .width(40)
          .height(40)
          .borderRadius(20)
          .backgroundColor(this.canSend()
            ? $r('app.color.brand_primary')
            : Color.Transparent)
          .enabled(this.canSend())
          .onClick(this.onSend).accessibilityText($r('app.string.chat_send_accessibility'))
      }
      .width('100%')
      .padding({ left: 5, right: 4, top: 3, bottom: 3 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(24)
      if (this.composer.message.length > 0) {
        Text(this.composer.message).fontSize(11)
          .fontColor(this.composer.sending ? $r('sys.color.font_secondary') : $r('app.color.status_error')).width('100%')
      }
    }
    .width('100%')
    .padding({ left: 10, right: 10, top: 7, bottom: 14 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    Column() {
      if (this.state.channel !== null) {
        Column() {
          Row({ space: 9 }) {
            SymbolGlyph(this.state.channel.isDirectMessage
              ? $r('sys.symbol.envelope')
              : $r('sys.symbol.message'))
              .fontSize(16)
              .fontColor([$r('app.color.brand_primary')])
              .width(30)
              .height(30)
              .padding(7)
              .backgroundColor($r('app.color.brand_tint_surface'))
              .borderRadius(10)
            Text(this.state.channel.isDirectMessage
              ? '直接消息'
              : `频道 · ${this.state.channel.subtitle}`)
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
            Button() {
              SymbolGlyph($r('sys.symbol.info_circle'))
                .fontSize(19)
                .fontColor([$r('sys.color.font_secondary')])
            }
            .width(34)
            .height(34)
            .borderRadius(17)
            .backgroundColor(Color.Transparent)
            .onClick((): void => this.showChannelActions())
            .accessibilityText($r('app.string.chat_channel_actions_accessibility'))
          }
          .width('100%')
          .height(42)
          .padding({ left: 8, right: 5 })
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('sys.color.comp_divider') })
          .borderRadius(16)
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 5, bottom: 3 })
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
    .width('100%').height('100%').clip(false)
    .backgroundColor($r('sys.color.background_secondary'))
    .bindSheet($$this.reactionSheetVisible, this.ReactionPickerSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      detentSelection: SheetSize.MEDIUM,
      preferType: SheetType.BOTTOM,
      showClose: false,
      dragBar: true,
      backgroundColor: $r('sys.color.comp_background_primary'),
      maskColor: Color.Transparent,
      enableOutsideInteractive: false,
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
      onDisappear: (): void => {
        this.reactionSheetVisible = false;
        this.reactionMessageId = null;
        this.reactionEmojiQuery = '';
        this.reactionEmojiGroup = '';
      }
    })
    .bindSheet($$this.channelSettingsVisible, this.ChannelPanelSheet(), {
      detents: [SheetSize.LARGE],
      detentSelection: SheetSize.LARGE,
      preferType: SheetType.BOTTOM,
      showClose: true,
      dragBar: true,
      backgroundColor: $r('sys.color.background_secondary'),
      maskColor: Color.Transparent,
      enableOutsideInteractive: false,
      onDisappear: (): void => {
        this.channelSettingsVisible = false;
        this.channelSettingsMessage = '';
        this.pinnedPanelActive = false;
      }
    })
  }
}
