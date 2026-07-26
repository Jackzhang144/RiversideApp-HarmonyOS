import { hilog } from '@kit.PerformanceAnalysisKit';
import { RepositoryResult } from '../core/RepositoryResult';
import { ComposerEdit } from '../models/AuthoringModels';
import { insertChatEmojiText } from '../models/ChatComposerEditing';
import {
  ChatChannel,
  ChatChannelNotificationLevel,
  ChatChannelNotificationSettings,
  ChatChannelNotificationUpdate,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatPinnedMessage,
  ChatPinnedMessagePage,
  ChatReactionAction,
  ChatSendConfirmation,
  ChatSendRequest
} from '../models/ChatModels';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState
} from '../models/MediaModels';
import { ChatRepository } from '../repositories/ChatRepository';
import { MediaRepository } from '../repositories/MediaRepository';
import {
  ChatChannelState,
  ChatComposerState,
  ChatConversationState,
  ChatPinnedMessageState,
  ChatStateKind
} from './ChatStateModels';
import { MediaUploadCoordinator } from './MediaUploadCoordinator';
import { ChatSearchCoordinator } from './ChatSearchCoordinator';

const CHAT_MODEL_LOG_DOMAIN: number = 0x0000;
const CHAT_MODEL_LOG_TAG: string = 'ChatModel';

function chatRefreshErrorName(error: Object): string {
  return error instanceof Error ? error.name : 'UnknownError';
}

function chatRefreshErrorMessage(error: Object): string {
  if (error instanceof Error) {
    return error.message.slice(0, 256);
  }
  try {
    return JSON.stringify(error).slice(0, 256);
  } catch (_) {
    return 'unserializable error';
  }
}

export interface ChatAuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}

export interface ChatMetadataProvider {
  nextStagedId(): string;
  nowIso(): string;
}

export class DefaultChatMetadataProvider implements ChatMetadataProvider {
  private sequence: number = 0;

  public nextStagedId(): string {
    this.sequence += 1;
    return `hm-${Date.now()}-${this.sequence}`;
  }

  public nowIso(): string {
    return new Date().toISOString();
  }
}

export class ChatModel {
  public channelState: ChatChannelState = ChatChannelState.initial();
  public conversationState: ChatConversationState = ChatConversationState.initial();
  public pinnedMessageState: ChatPinnedMessageState = ChatPinnedMessageState.initial();
  public composerState: ChatComposerState = new ChatComposerState();
  public readonly search: ChatSearchCoordinator;
  public emojis: Array<ChatEmoji> = [];

  private readonly repository: ChatRepository;
  private readonly mediaCoordinator: MediaUploadCoordinator;
  private readonly authenticationLifecycle: ChatAuthenticationLifecycle | null;
  private readonly metadataProvider: ChatMetadataProvider;
  private channelRequestVersion: number = 0;
  private conversationRequestVersion: number = 0;
  private pinnedMessageRequestVersion: number = 0;
  private activeConversationRefresh: Promise<void> | null = null;
  private activeConversationRefreshVersion: number | null = null;
  private readProgressChannelId: number = 0;
  private confirmedReadMessageId: number = 0;
  private pendingReadMessageId: number = 0;
  private readProgressTask: Promise<void> | null = null;

  public constructor(
    repository: ChatRepository,
    mediaRepository: MediaRepository | null = null,
    authenticationLifecycle: ChatAuthenticationLifecycle | null = null,
    metadataProvider: ChatMetadataProvider = new DefaultChatMetadataProvider()
  ) {
    this.repository = repository;
    this.authenticationLifecycle = authenticationLifecycle;
    this.metadataProvider = metadataProvider;
    this.mediaCoordinator = new MediaUploadCoordinator(
      mediaRepository,
      async (): Promise<void> => this.notifyUnauthorized()
    );
    this.search = new ChatSearchCoordinator(
      repository,
      async (): Promise<void> => this.notifyUnauthorized()
    );
  }

  public async loadChannels(): Promise<void> {
    this.channelRequestVersion += 1;
    const requestVersion: number = this.channelRequestVersion;
    const existing: Array<ChatChannel> = this.channelState.channels;
    this.channelState = ChatChannelState.loading(existing);
    const result: RepositoryResult<Array<ChatChannel>> = await this.repository.loadChatChannels();
    if (requestVersion !== this.channelRequestVersion) {
      return;
    }
    if (result.isUnauthorized()) {
      this.channelState = ChatChannelState.failure(existing, result.message);
      await this.notifyUnauthorized();
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.channelState = ChatChannelState.failure(existing, result.message);
      return;
    }
    this.channelState = ChatChannelState.fromChannels(result.data);
  }

  public async refreshForForeground(): Promise<void> {
    await Promise.all([
      this.loadChannels(),
      this.refreshActiveConversationIncrementally()
    ]);
  }

  public async updateCurrentChannelNotificationLevel(level: ChatChannelNotificationLevel): Promise<boolean> {
    return await this.updateCurrentChannelNotifications(ChatChannelNotificationUpdate.level(level));
  }

  public async setCurrentChannelMuted(muted: boolean): Promise<boolean> {
    return await this.updateCurrentChannelNotifications(ChatChannelNotificationUpdate.mute(muted));
  }

  private async updateCurrentChannelNotifications(update: ChatChannelNotificationUpdate): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    const requestVersion: number = this.conversationRequestVersion;
    const result: RepositoryResult<ChatChannelNotificationSettings> =
      await this.repository.updateChatChannelNotifications(channel.id, update);
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = this.conversationState.withPagination(
        this.conversationState.loadingPast,
        this.conversationState.loadingFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    const updatedChannel: ChatChannel = channel.withNotificationSettings(result.data);
    this.conversationState = this.conversationState.withChannel(updatedChannel);
    this.channelState = ChatChannelState.fromChannels(this.channelState.channels.map(
      (candidate: ChatChannel): ChatChannel => candidate.id === updatedChannel.id ? updatedChannel : candidate
    ));
    return true;
  }

  public async loadPinnedMessages(): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    this.pinnedMessageRequestVersion += 1;
    const pinnedRequestVersion: number = this.pinnedMessageRequestVersion;
    const conversationRequestVersion: number = this.conversationRequestVersion;
    const existing: Array<ChatPinnedMessage> = this.pinnedMessageState.pinnedMessages;
    this.pinnedMessageState = ChatPinnedMessageState.loading(existing);
    const result: RepositoryResult<ChatPinnedMessagePage> =
      await this.repository.loadPinnedChatMessages(channel.id);
    if (
      pinnedRequestVersion !== this.pinnedMessageRequestVersion ||
      !this.isCurrentConversation(conversationRequestVersion, channel.id)
    ) {
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.pinnedMessageState = ChatPinnedMessageState.failure(existing, result.message);
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    this.pinnedMessageState = ChatPinnedMessageState.fromPage(result.data);
    const pinnedMessageIds: Array<number> = result.data.pinnedMessages.map(
      (item: ChatPinnedMessage): number => item.chatMessageId
    );
    this.conversationState = this.conversationState.withMessages(
      this.conversationState.messages.map((message: ChatMessage): ChatMessage =>
        message.withPinned(pinnedMessageIds.includes(message.id))
      )
    );
    this.updateCurrentChannelPinSummary(result.data.pinnedMessages.length, result.data.hasUnseenPins);
    const markedRead: RepositoryResult<boolean> = await this.repository.markChatPinsRead(channel.id);
    if (
      pinnedRequestVersion === this.pinnedMessageRequestVersion &&
      this.isCurrentConversation(conversationRequestVersion, channel.id) &&
      markedRead.isSuccess() && markedRead.data === true
    ) {
      this.updateCurrentChannelPinSummary(result.data.pinnedMessages.length, false);
    } else if (markedRead.isUnauthorized()) {
      await this.notifyUnauthorized();
    }
    return true;
  }

  public async setMessagePinned(messageId: number, pinned: boolean): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    const message: ChatMessage | null = this.conversationState.messages.find(
      (candidate: ChatMessage): boolean => candidate.id === messageId
    ) ?? null;
    if (
      channel === null ||
      !channel.canManagePins ||
      message === null ||
      message.deleted ||
      message.pinned === pinned
    ) {
      return false;
    }
    const conversationRequestVersion: number = this.conversationRequestVersion;
    const result: RepositoryResult<boolean> = pinned
      ? await this.repository.pinChatMessage(channel.id, messageId)
      : await this.repository.unpinChatMessage(channel.id, messageId);
    if (!this.isCurrentConversation(conversationRequestVersion, channel.id)) {
      return false;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    this.conversationState = this.conversationState.withMessages(
      this.conversationState.messages.map((candidate: ChatMessage): ChatMessage =>
        candidate.id === messageId ? candidate.withPinned(pinned) : candidate
      )
    );
    const nextCount: number = pinned
      ? channel.pinnedMessagesCount + 1
      : Math.max(0, channel.pinnedMessagesCount - 1);
    this.updateCurrentChannelPinSummary(nextCount, channel.hasUnseenPins);
    if (!pinned && this.pinnedMessageState.kind !== ChatStateKind.INITIAL) {
      this.pinnedMessageState = ChatPinnedMessageState.fromPage(new ChatPinnedMessagePage(
        this.pinnedMessageState.pinnedMessages.filter(
          (item: ChatPinnedMessage): boolean => item.chatMessageId !== messageId
        ),
        false,
        ''
      ));
    } else if (this.pinnedMessageState.kind !== ChatStateKind.INITIAL) {
      await this.loadPinnedMessages();
    }
    return true;
  }

  private updateCurrentChannelPinSummary(pinnedMessagesCount: number, hasUnseenPins: boolean): void {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return;
    }
    const updatedChannel: ChatChannel = channel.withPinSummary(pinnedMessagesCount, hasUnseenPins);
    this.conversationState = this.conversationState.withChannel(updatedChannel);
    this.channelState = ChatChannelState.fromChannels(this.channelState.channels.map(
      (candidate: ChatChannel): ChatChannel => candidate.id === updatedChannel.id ? updatedChannel : candidate
    ));
  }

  public async refreshActiveConversationIncrementally(): Promise<void> {
    const requestVersion: number = this.conversationRequestVersion;
    const existingRefresh: Promise<void> | null = this.activeConversationRefresh;
    if (existingRefresh !== null && this.activeConversationRefreshVersion === requestVersion) {
      await existingRefresh;
      return;
    }
    const refresh: Promise<void> = this.performActiveConversationIncrementalRefresh(requestVersion);
    this.activeConversationRefresh = refresh;
    this.activeConversationRefreshVersion = requestVersion;
    try {
      await refresh;
    } finally {
      if (this.activeConversationRefresh === refresh) {
        this.activeConversationRefresh = null;
        this.activeConversationRefreshVersion = null;
      }
    }
  }

  private async performActiveConversationIncrementalRefresh(requestVersion: number): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null || this.conversationState.kind === ChatStateKind.LOADING ||
      this.conversationState.loadingPast || this.conversationState.loadingFuture) {
      return;
    }
    const existing: Array<ChatMessage> = this.conversationState.messages;
    const query: ChatMessageQuery | null = existing.length === 0
      ? ChatMessageQuery.latest()
      : ChatMessageQuery.around(existing[existing.length - 1].id, 'future');
    if (query === null) return;
    this.conversationState = this.conversationState.withPagination(false, true);
    let result: RepositoryResult<ChatMessagePage>;
    try {
      result = await this.repository.loadChatMessages(channel.id, query);
    } catch (error) {
      hilog.error(
        CHAT_MODEL_LOG_DOMAIN,
        CHAT_MODEL_LOG_TAG,
        'Unexpected active Chat refresh failure: %{public}s: %{private}s',
        chatRefreshErrorName(error),
        chatRefreshErrorMessage(error)
      );
      if (this.isCurrentConversation(requestVersion, channel.id)) {
        this.conversationState = this.conversationState.withPagination(
          false,
          false,
          '刷新 Chat 会话失败，请稍后重试'
        );
      }
      return;
    }
    if (!this.isCurrentConversation(requestVersion, channel.id)) return;
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = this.conversationState.withPagination(false, false, result.message);
      if (result.isUnauthorized()) await this.notifyUnauthorized();
      return;
    }
    const currentMessages: Array<ChatMessage> = this.conversationState.messages;
    this.conversationState = currentMessages.length === 0
      ? ChatConversationState.fromPage(channel, result.data)
      : this.conversationState.withMessages(
        mergeChatMessages(currentMessages, result.data.messages),
        this.conversationState.canLoadMorePast,
        result.data.canLoadMoreFuture
      );
  }

  public async openChannel(channel: ChatChannel): Promise<void> {
    await this.openChannelWithQuery(channel, ChatMessageQuery.latest());
  }

  public async openChannelAt(channel: ChatChannel, messageId: number): Promise<void> {
    const query: ChatMessageQuery | null = ChatMessageQuery.target(messageId);
    if (query !== null) {
      await this.openChannelWithQuery(channel, query);
    }
  }

  public async retryConversation(): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel !== null) {
      await this.openChannel(channel);
    }
  }

  private async openChannelWithQuery(channel: ChatChannel, query: ChatMessageQuery): Promise<void> {
    this.cancelUpload();
    this.conversationRequestVersion += 1;
    this.pinnedMessageRequestVersion += 1;
    const requestVersion: number = this.conversationRequestVersion;
    this.resetReadProgress(channel.id);
    this.conversationState = ChatConversationState.loading(channel);
    this.pinnedMessageState = ChatPinnedMessageState.initial();
    this.composerState = new ChatComposerState();
    const result: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(
      channel.id,
      query
    );
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return;
    }
    if (result.isUnauthorized()) {
      this.conversationState = ChatConversationState.failure(channel, [], result.message);
      await this.notifyUnauthorized();
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = ChatConversationState.failure(channel, [], result.message);
      return;
    }
    this.conversationState = ChatConversationState.fromPage(channel, result.data);
  }

  public async closeChannel(): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    const shouldCleanupEmptyDirectMessage: boolean = channel !== null &&
      channel.isDirectMessage &&
      channel.lastMessageAt.trim().length === 0 &&
      !this.conversationState.messages.some((message: ChatMessage): boolean => message.id > 0);
    this.cancelUpload();
    this.conversationRequestVersion += 1;
    this.pinnedMessageRequestVersion += 1;
    this.resetReadProgress(0);
    this.conversationState = ChatConversationState.initial();
    this.pinnedMessageState = ChatPinnedMessageState.initial();
    this.composerState = new ChatComposerState();
    if (shouldCleanupEmptyDirectMessage && channel !== null) {
      await this.leaveEmptyDirectMessageBestEffort(channel.id);
    }
  }

  private async leaveEmptyDirectMessageBestEffort(channelId: number): Promise<void> {
    try {
      const result: RepositoryResult<boolean> = await this.repository.leaveChatChannel(channelId);
      if (result.isSuccess() && result.data === true) {
        this.channelState = ChatChannelState.fromChannels(this.channelState.channels.filter(
          (channel: ChatChannel): boolean => channel.id !== channelId
        ));
      } else if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
    } catch (_) {
      // Closing an unused draft conversation remains best-effort.
    }
  }

  public reset(): void {
    this.cancelUpload();
    this.channelRequestVersion += 1;
    this.conversationRequestVersion += 1;
    this.pinnedMessageRequestVersion += 1;
    this.resetReadProgress(0);
    this.channelState = ChatChannelState.initial();
    this.conversationState = ChatConversationState.initial();
    this.pinnedMessageState = ChatPinnedMessageState.initial();
    this.composerState = new ChatComposerState();
    this.search.reset();
    this.emojis = [];
  }

  public async loadOlder(): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (
      channel === null ||
      this.conversationState.messages.length === 0 ||
      !this.conversationState.canLoadMorePast ||
      this.conversationState.loadingPast
    ) {
      return;
    }
    const targetId: number = this.conversationState.messages[0].id;
    const query: ChatMessageQuery | null = ChatMessageQuery.around(targetId, 'past');
    if (query === null) {
      return;
    }
    const requestVersion: number = this.conversationRequestVersion;
    this.conversationState = this.conversationState.withPagination(true, false);
    const result: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(channel.id, query);
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return;
    }
    if (result.isUnauthorized()) {
      this.conversationState = this.conversationState.withPagination(false, false, result.message);
      await this.notifyUnauthorized();
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = this.conversationState.withPagination(false, false, result.message);
      return;
    }
    this.conversationState = this.conversationState.withMessages(
      mergeChatMessages(this.conversationState.messages, result.data.messages),
      result.data.canLoadMorePast,
      this.conversationState.canLoadMoreFuture
    );
  }

  public async loadNewer(): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (
      channel === null ||
      this.conversationState.messages.length === 0 ||
      !this.conversationState.canLoadMoreFuture ||
      this.conversationState.loadingFuture
    ) {
      return;
    }
    const targetId: number = this.conversationState.messages[this.conversationState.messages.length - 1].id;
    const query: ChatMessageQuery | null = ChatMessageQuery.around(targetId, 'future');
    if (query === null) {
      return;
    }
    const requestVersion: number = this.conversationRequestVersion;
    this.conversationState = this.conversationState.withPagination(false, true);
    const result: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(channel.id, query);
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = this.conversationState.withPagination(false, false, result.message);
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return;
    }
    this.conversationState = this.conversationState.withMessages(
      mergeChatMessages(this.conversationState.messages, result.data.messages),
      this.conversationState.canLoadMorePast,
      result.data.canLoadMoreFuture
    );
  }

  public updateDraft(draft: string): void {
    if (!this.composerState.sending) {
      this.composerState = this.composerState.withDraft(draft);
    }
  }

  public replyTo(messageId: number | null): void {
    if (this.composerState.sending) {
      return;
    }
    const validId: number | null = messageId !== null && Number.isSafeInteger(messageId) && messageId > 0
      ? messageId
      : null;
    this.composerState = this.composerState.withReply(validId);
  }

  public insertMention(username: string): void {
    const normalized: string = username.trim().replace(/^@+/, '');
    if (normalized.length > 0) {
      this.updateDraft(`${this.composerState.draft}${this.composerState.draft.endsWith(' ') ||
        this.composerState.draft.length === 0 ? '' : ' '}@${normalized} `);
    }
  }

  public insertEmoji(name: string, selectionStart: number, selectionEnd: number): ComposerEdit | null {
    if (this.composerState.sending) {
      return null;
    }
    const edit: ComposerEdit | null = insertChatEmojiText(
      this.composerState.draft,
      selectionStart,
      selectionEnd,
      name
    );
    if (edit !== null) {
      this.updateDraft(edit.text);
    }
    return edit;
  }

  public removeUpload(uploadId: number): void {
    if (!this.composerState.sending) {
      this.composerState = this.composerState.withoutUpload(uploadId);
    }
  }

  public async uploadImage(
    media: CachedMedia,
    onStateChange: (state: MediaUploadState) => void
  ): Promise<MediaUploadState> {
    return this.mediaCoordinator.upload(
      media,
      MediaUploadRequest.chat(media),
      onStateChange,
      (result: MediaUploadResult): boolean => {
        this.composerState = this.composerState.withUpload(result);
        return true;
      },
      '图片上传结果未插入消息草稿'
    );
  }

  public cancelUpload(): void {
    this.mediaCoordinator.cancelUpload();
  }

  public async send(): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null || this.composerState.sending) {
      return false;
    }
    if (channel.userSilenced) {
      this.composerState = this.composerState.failure('服务端不允许当前账号在此频道发言');
      return false;
    }
    const request: ChatSendRequest | null = ChatSendRequest.create(
      channel.id,
      this.composerState.draft,
      this.composerState.uploads.map((upload: MediaUploadResult): number => upload.id),
      this.composerState.replyToMessageId,
      this.metadataProvider.nextStagedId(),
      this.metadataProvider.nowIso()
    );
    if (request === null) {
      this.composerState = this.composerState.failure('请输入消息或先上传图片');
      return false;
    }
    const preserved: ChatComposerState = this.composerState;
    const requestVersion: number = this.conversationRequestVersion;
    this.composerState = preserved.submitting();
    const result: RepositoryResult<ChatSendConfirmation> = await this.repository.sendChatMessage(request);
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return false;
    }
    if (result.isUnauthorized()) {
      this.composerState = preserved.failure(result.message);
      await this.notifyUnauthorized();
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.composerState = preserved.failure(result.message);
      return false;
    }
    this.composerState = new ChatComposerState();
    let confirmedMessage: ChatMessage | null = result.data.message;
    if (confirmedMessage === null) {
      const confirmedMessageId: number = result.data.messageId;
      const query: ChatMessageQuery | null = ChatMessageQuery.target(confirmedMessageId);
      if (query !== null) {
        const synchronized: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(
          channel.id,
          query
        );
        if (!this.isCurrentConversation(requestVersion, channel.id)) {
          return false;
        }
        if (synchronized.isSuccess() && synchronized.data !== null) {
          confirmedMessage = synchronized.data.messages.find(
            (message: ChatMessage): boolean => message.id === confirmedMessageId
          ) ?? null;
        } else if (synchronized.isUnauthorized()) {
          await this.notifyUnauthorized();
          if (!this.isCurrentConversation(requestVersion, channel.id)) {
            return false;
          }
        }
      }
    }
    if (confirmedMessage !== null) {
      this.conversationState = this.conversationState.withMessages(
        mergeChatMessages(this.conversationState.messages, [confirmedMessage])
      );
    } else {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        '消息已发送，等待服务端同步'
      );
    }
    return true;
  }

  public async react(messageId: number, emoji: string, action: ChatReactionAction): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    const result: RepositoryResult<boolean> = await this.repository.reactToChatMessage(
      channel.id,
      messageId,
      emoji,
      action
    );
    if (!result.isSuccess() || result.data !== true) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    return this.refreshConversation();
  }

  public async deleteMessage(messageId: number): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    const result: RepositoryResult<boolean> = await this.repository.deleteChatMessage(channel.id, messageId);
    if (!result.isSuccess() || result.data !== true) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    return this.refreshConversation();
  }

  public async restoreMessage(messageId: number): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    const result: RepositoryResult<boolean> = await this.repository.restoreChatMessage(channel.id, messageId);
    if (!result.isSuccess() || result.data !== true) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    return this.refreshConversation();
  }

  public async loadEmojis(): Promise<void> {
    if (this.emojis.length > 0) {
      return;
    }
    const result: RepositoryResult<Array<ChatEmoji>> = await this.repository.loadChatEmojis();
    if (result.isSuccess() && result.data !== null) {
      this.emojis = result.data;
    } else if (result.isUnauthorized()) {
      await this.notifyUnauthorized();
    }
  }

  public async openDirectChat(username: string): Promise<boolean> {
    const result: RepositoryResult<ChatChannel> = await this.repository.openDirectChat(username);
    if (!result.isSuccess() || result.data === null) {
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    await this.openChannel(result.data);
    return this.conversationState.kind === ChatStateKind.CONTENT || this.conversationState.kind === ChatStateKind.EMPTY;
  }

  public async leaveCurrentChannel(): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null || channel.isDirectMessage) {
      return false;
    }
    const result: RepositoryResult<boolean> = await this.repository.leaveChatChannel(channel.id);
    if (!result.isSuccess() || result.data !== true) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    await this.closeChannel();
    await this.loadChannels();
    return true;
  }

  private async refreshConversation(): Promise<boolean> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) {
      return false;
    }
    const requestVersion: number = this.conversationRequestVersion;
    const result: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(
      channel.id,
      ChatMessageQuery.latest()
    );
    if (!this.isCurrentConversation(requestVersion, channel.id)) {
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.conversationState = this.conversationState.withMessages(
        this.conversationState.messages,
        this.conversationState.canLoadMorePast,
        this.conversationState.canLoadMoreFuture,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return false;
    }
    this.conversationState = ChatConversationState.fromPage(channel, result.data);
    return true;
  }

  public async markReadThrough(messageId: number): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (
      channel === null ||
      !Number.isSafeInteger(messageId) ||
      messageId <= 0 ||
      !this.conversationState.messages.some((message: ChatMessage): boolean => message.id === messageId)
    ) {
      return;
    }
    if (this.readProgressChannelId !== channel.id) {
      this.resetReadProgress(channel.id);
    }
    if (messageId <= this.confirmedReadMessageId || messageId <= this.pendingReadMessageId) {
      return;
    }
    this.pendingReadMessageId = messageId;
    const existingTask: Promise<void> | null = this.readProgressTask;
    if (existingTask !== null) {
      await existingTask;
      return;
    }
    const requestVersion: number = this.conversationRequestVersion;
    const task: Promise<void> = this.flushReadProgress(requestVersion, channel.id);
    this.readProgressTask = task;
    try {
      await task;
    } finally {
      if (this.readProgressTask === task) {
        this.readProgressTask = null;
      }
    }
  }

  private async flushReadProgress(requestVersion: number, channelId: number): Promise<void> {
    while (
      this.isCurrentConversation(requestVersion, channelId) &&
      this.pendingReadMessageId > this.confirmedReadMessageId
    ) {
      const targetMessageId: number = this.pendingReadMessageId;
      const result: RepositoryResult<boolean> = await this.repository.markChatRead(channelId, targetMessageId);
      if (!this.isCurrentConversation(requestVersion, channelId)) {
        return;
      }
      if (!result.isSuccess() || result.data !== true) {
        this.pendingReadMessageId = this.confirmedReadMessageId;
        if (result.isUnauthorized()) {
          await this.notifyUnauthorized();
        }
        return;
      }
      this.confirmedReadMessageId = targetMessageId;
      this.clearChannelUnreadCount(channelId);
    }
  }

  private clearChannelUnreadCount(channelId: number): void {
    this.channelState = ChatChannelState.fromChannels(this.channelState.channels.map(
      (channel: ChatChannel): ChatChannel => channel.id === channelId
        ? new ChatChannel(
          channel.id,
          channel.title,
          channel.subtitle,
          channel.preview,
          channel.lastMessageAt,
          channel.isDirectMessage,
          0,
          channel.lastMessageId,
          channel.lastMessageUsername,
          channel.slug,
          channel.userSilenced,
          channel.canDeleteSelf,
          channel.canDeleteOthers
        )
        : channel
    ));
  }

  private resetReadProgress(channelId: number): void {
    this.readProgressChannelId = channelId;
    this.confirmedReadMessageId = 0;
    this.pendingReadMessageId = 0;
    this.readProgressTask = null;
  }

  private isCurrentConversation(requestVersion: number, channelId: number): boolean {
    return requestVersion === this.conversationRequestVersion &&
      this.conversationState.channel?.id === channelId;
  }

  private async notifyUnauthorized(): Promise<void> {
    await this.authenticationLifecycle?.handleUnauthorized();
  }
}

function mergeChatMessages(existing: Array<ChatMessage>, incoming: Array<ChatMessage>): Array<ChatMessage> {
  const merged: Array<ChatMessage> = existing.slice();
  for (const candidate of incoming) {
    const index: number = merged.findIndex((message: ChatMessage): boolean => message.id === candidate.id);
    if (index >= 0) {
      merged[index] = candidate;
    } else {
      merged.push(candidate);
    }
  }
  merged.sort((left: ChatMessage, right: ChatMessage): number => {
    if (left.createdAt.length === 0 && right.createdAt.length > 0) {
      return 1;
    }
    if (right.createdAt.length === 0 && left.createdAt.length > 0) {
      return -1;
    }
    const time: number = left.createdAt.localeCompare(right.createdAt);
    return time !== 0 ? time : left.id - right.id;
  });
  return merged;
}
