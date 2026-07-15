import { RepositoryResult } from '../core/RepositoryResult';
import {
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatReactionAction,
  ChatSearchResult,
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
import { MediaRepository, MediaUploadOperation } from '../repositories/MediaRepository';

export enum ChatStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
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

export class ChatChannelState {
  public readonly kind: ChatStateKind;
  public readonly channels: Array<ChatChannel>;
  public readonly message: string;
  public readonly refreshing: boolean;

  private constructor(
    kind: ChatStateKind,
    channels: Array<ChatChannel>,
    message: string,
    refreshing: boolean
  ) {
    this.kind = kind;
    this.channels = channels;
    this.message = message;
    this.refreshing = refreshing;
  }

  public static initial(): ChatChannelState {
    return new ChatChannelState(ChatStateKind.INITIAL, [], '', false);
  }

  public static loading(channels: Array<ChatChannel> = []): ChatChannelState {
    return channels.length === 0
      ? new ChatChannelState(ChatStateKind.LOADING, [], '', false)
      : new ChatChannelState(ChatStateKind.CONTENT, channels, '', true);
  }

  public static fromChannels(channels: Array<ChatChannel>): ChatChannelState {
    return new ChatChannelState(
      channels.length === 0 ? ChatStateKind.EMPTY : ChatStateKind.CONTENT,
      channels,
      '',
      false
    );
  }

  public static failure(channels: Array<ChatChannel>, message: string): ChatChannelState {
    return new ChatChannelState(
      channels.length === 0 ? ChatStateKind.ERROR : ChatStateKind.CONTENT,
      channels,
      message,
      false
    );
  }
}

export class ChatConversationState {
  public readonly kind: ChatStateKind;
  public readonly channel: ChatChannel | null;
  public readonly messages: Array<ChatMessage>;
  public readonly canLoadMorePast: boolean;
  public readonly canLoadMoreFuture: boolean;
  public readonly loadingPast: boolean;
  public readonly loadingFuture: boolean;
  public readonly message: string;

  private constructor(
    kind: ChatStateKind,
    channel: ChatChannel | null,
    messages: Array<ChatMessage>,
    canLoadMorePast: boolean,
    canLoadMoreFuture: boolean,
    loadingPast: boolean,
    loadingFuture: boolean,
    message: string
  ) {
    this.kind = kind;
    this.channel = channel;
    this.messages = messages;
    this.canLoadMorePast = canLoadMorePast;
    this.canLoadMoreFuture = canLoadMoreFuture;
    this.loadingPast = loadingPast;
    this.loadingFuture = loadingFuture;
    this.message = message;
  }

  public static initial(): ChatConversationState {
    return new ChatConversationState(ChatStateKind.INITIAL, null, [], false, false, false, false, '');
  }

  public static loading(channel: ChatChannel): ChatConversationState {
    return new ChatConversationState(ChatStateKind.LOADING, channel, [], false, false, false, false, '');
  }

  public static fromPage(channel: ChatChannel, page: ChatMessagePage): ChatConversationState {
    return new ChatConversationState(
      page.messages.length === 0 ? ChatStateKind.EMPTY : ChatStateKind.CONTENT,
      channel,
      page.messages,
      page.canLoadMorePast,
      page.canLoadMoreFuture,
      false,
      false,
      ''
    );
  }

  public static failure(channel: ChatChannel, messages: Array<ChatMessage>, message: string): ChatConversationState {
    return new ChatConversationState(
      messages.length === 0 ? ChatStateKind.ERROR : ChatStateKind.CONTENT,
      channel,
      messages,
      false,
      false,
      false,
      false,
      message
    );
  }

  public withPagination(loadingPast: boolean, loadingFuture: boolean, message: string = ''): ChatConversationState {
    return new ChatConversationState(
      this.kind,
      this.channel,
      this.messages,
      this.canLoadMorePast,
      this.canLoadMoreFuture,
      loadingPast,
      loadingFuture,
      message
    );
  }

  public withMessages(
    messages: Array<ChatMessage>,
    canLoadMorePast: boolean = this.canLoadMorePast,
    canLoadMoreFuture: boolean = this.canLoadMoreFuture,
    message: string = ''
  ): ChatConversationState {
    return new ChatConversationState(
      messages.length === 0 ? ChatStateKind.EMPTY : ChatStateKind.CONTENT,
      this.channel,
      messages,
      canLoadMorePast,
      canLoadMoreFuture,
      false,
      false,
      message
    );
  }
}

export class ChatComposerState {
  public readonly draft: string;
  public readonly uploads: Array<MediaUploadResult>;
  public readonly replyToMessageId: number | null;
  public readonly sending: boolean;
  public readonly message: string;

  public constructor(
    draft: string = '',
    uploads: Array<MediaUploadResult> = [],
    replyToMessageId: number | null = null,
    sending: boolean = false,
    message: string = ''
  ) {
    this.draft = draft;
    this.uploads = uploads;
    this.replyToMessageId = replyToMessageId;
    this.sending = sending;
    this.message = message;
  }

  public withDraft(draft: string): ChatComposerState {
    return new ChatComposerState(draft, this.uploads, this.replyToMessageId, false, '');
  }

  public withReply(messageId: number | null): ChatComposerState {
    return new ChatComposerState(this.draft, this.uploads, messageId, false, '');
  }

  public withUpload(upload: MediaUploadResult): ChatComposerState {
    const uploads: Array<MediaUploadResult> = this.uploads.filter(
      (candidate: MediaUploadResult): boolean => candidate.id !== upload.id
    );
    uploads.push(upload);
    return new ChatComposerState(this.draft, uploads, this.replyToMessageId, false, '');
  }

  public withoutUpload(uploadId: number): ChatComposerState {
    return new ChatComposerState(
      this.draft,
      this.uploads.filter((upload: MediaUploadResult): boolean => upload.id !== uploadId),
      this.replyToMessageId,
      false,
      ''
    );
  }

  public submitting(): ChatComposerState {
    return new ChatComposerState(this.draft, this.uploads, this.replyToMessageId, true, '正在发送消息');
  }

  public failure(message: string): ChatComposerState {
    return new ChatComposerState(this.draft, this.uploads, this.replyToMessageId, false, message);
  }
}

export class ChatSearchState {
  public readonly kind: ChatStateKind;
  public readonly query: string;
  public readonly results: Array<ChatSearchResult>;
  public readonly hasMore: boolean;
  public readonly loadingMore: boolean;
  public readonly message: string;

  public constructor(
    kind: ChatStateKind = ChatStateKind.INITIAL,
    query: string = '',
    results: Array<ChatSearchResult> = [],
    hasMore: boolean = false,
    loadingMore: boolean = false,
    message: string = ''
  ) {
    this.kind = kind;
    this.query = query;
    this.results = results;
    this.hasMore = hasMore;
    this.loadingMore = loadingMore;
    this.message = message;
  }
}

export class ChatModel {
  public channelState: ChatChannelState = ChatChannelState.initial();
  public conversationState: ChatConversationState = ChatConversationState.initial();
  public composerState: ChatComposerState = new ChatComposerState();
  public searchState: ChatSearchState = new ChatSearchState();
  public emojis: Array<ChatEmoji> = [];

  private readonly repository: ChatRepository;
  private readonly mediaRepository: MediaRepository | null;
  private readonly authenticationLifecycle: ChatAuthenticationLifecycle | null;
  private readonly metadataProvider: ChatMetadataProvider;
  private channelRequestVersion: number = 0;
  private conversationRequestVersion: number = 0;
  private searchRequestVersion: number = 0;
  private activeUpload: MediaUploadOperation | null = null;
  private activeUploadState: MediaUploadState | null = null;
  private activeUploadListener: ((state: MediaUploadState) => void) | null = null;

  public constructor(
    repository: ChatRepository,
    mediaRepository: MediaRepository | null = null,
    authenticationLifecycle: ChatAuthenticationLifecycle | null = null,
    metadataProvider: ChatMetadataProvider = new DefaultChatMetadataProvider()
  ) {
    this.repository = repository;
    this.mediaRepository = mediaRepository;
    this.authenticationLifecycle = authenticationLifecycle;
    this.metadataProvider = metadataProvider;
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
      this.refreshActiveConversationForForeground()
    ]);
  }

  private async refreshActiveConversationForForeground(): Promise<void> {
    const channel: ChatChannel | null = this.conversationState.channel;
    if (channel === null) return;
    const existing: Array<ChatMessage> = this.conversationState.messages;
    const query: ChatMessageQuery | null = existing.length === 0
      ? ChatMessageQuery.latest()
      : ChatMessageQuery.around(existing[existing.length - 1].id, 'future');
    if (query === null) return;
    const requestVersion: number = this.conversationRequestVersion;
    this.conversationState = this.conversationState.withPagination(false, true);
    const result: RepositoryResult<ChatMessagePage> = await this.repository.loadChatMessages(channel.id, query);
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
    await this.markLatestRead(requestVersion, channel.id);
  }

  public async openChannel(channel: ChatChannel): Promise<void> {
    await this.openChannelWithQuery(channel, ChatMessageQuery.initial());
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
    const requestVersion: number = this.conversationRequestVersion;
    this.conversationState = ChatConversationState.loading(channel);
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
    await this.markLatestRead(requestVersion, channel.id);
  }

  public closeChannel(): void {
    this.cancelUpload();
    this.conversationRequestVersion += 1;
    this.conversationState = ChatConversationState.initial();
    this.composerState = new ChatComposerState();
  }

  public reset(): void {
    this.cancelUpload();
    this.channelRequestVersion += 1;
    this.conversationRequestVersion += 1;
    this.searchRequestVersion += 1;
    this.channelState = ChatChannelState.initial();
    this.conversationState = ChatConversationState.initial();
    this.composerState = new ChatComposerState();
    this.searchState = new ChatSearchState();
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
    await this.markLatestRead(requestVersion, channel.id);
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

  public insertEmoji(name: string): void {
    const normalized: string = name.trim().replace(/:/g, '');
    if (normalized.length > 0) {
      this.updateDraft(`${this.composerState.draft}:${normalized}:`);
    }
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
    let state: MediaUploadState = MediaUploadState.selected(media);
    onStateChange(state);
    if (this.mediaRepository === null) {
      state = state.failed('图片上传服务不可用');
      onStateChange(state);
      return state;
    }
    if (this.activeUpload !== null) {
      state = state.failed('已有图片正在上传');
      onStateChange(state);
      return state;
    }
    state = state.uploading(0, media.sizeBytes);
    this.activeUploadState = state;
    this.activeUploadListener = onStateChange;
    onStateChange(state);
    const operation: MediaUploadOperation = this.mediaRepository.upload(
      MediaUploadRequest.chat(media),
      (uploadedBytes: number, totalBytes: number): void => {
        if (this.activeUploadState !== null) {
          state = state.uploading(uploadedBytes, totalBytes);
          this.activeUploadState = state;
          onStateChange(state);
        }
      }
    );
    this.activeUpload = operation;
    const result: RepositoryResult<MediaUploadResult> = await operation.completion;
    if (this.activeUpload !== operation) {
      return state.cancelled();
    }
    this.clearActiveUpload();
    if (!result.isSuccess() || result.data === null) {
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      state = state.failed(result.message);
      onStateChange(state);
      return state;
    }
    this.composerState = this.composerState.withUpload(result.data);
    state = state.succeeded(result.data);
    onStateChange(state);
    return state;
  }

  public cancelUpload(): void {
    const operation: MediaUploadOperation | null = this.activeUpload;
    const state: MediaUploadState | null = this.activeUploadState;
    const listener: ((state: MediaUploadState) => void) | null = this.activeUploadListener;
    if (operation === null || state === null || listener === null) {
      return;
    }
    operation.cancel();
    listener(state.cancelled());
    this.clearActiveUpload();
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
    await this.markLatestRead(this.conversationRequestVersion, channel.id);
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

  public async search(query: string): Promise<void> {
    const normalized: string = query.trim();
    this.searchRequestVersion += 1;
    const requestVersion: number = this.searchRequestVersion;
    if (normalized.length === 0) {
      this.searchState = new ChatSearchState();
      return;
    }
    this.searchState = new ChatSearchState(ChatStateKind.LOADING, normalized);
    const result: RepositoryResult<Array<ChatSearchResult>> = await this.repository.searchChat(normalized, 0, 20);
    if (requestVersion !== this.searchRequestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.searchState = new ChatSearchState(ChatStateKind.ERROR, normalized, [], false, false, result.message);
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return;
    }
    this.searchState = new ChatSearchState(
      result.data.length === 0 ? ChatStateKind.EMPTY : ChatStateKind.CONTENT,
      normalized,
      result.data,
      result.data.length === 20
    );
  }

  public async loadMoreSearch(): Promise<void> {
    if (!this.searchState.hasMore || this.searchState.loadingMore || this.searchState.query.length === 0) {
      return;
    }
    const requestVersion: number = this.searchRequestVersion;
    const previous: ChatSearchState = this.searchState;
    this.searchState = new ChatSearchState(
      previous.kind,
      previous.query,
      previous.results,
      previous.hasMore,
      true
    );
    const result: RepositoryResult<Array<ChatSearchResult>> = await this.repository.searchChat(
      previous.query,
      previous.results.length,
      20
    );
    if (requestVersion !== this.searchRequestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.searchState = new ChatSearchState(
        previous.kind,
        previous.query,
        previous.results,
        previous.hasMore,
        false,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.notifyUnauthorized();
      }
      return;
    }
    this.searchState = new ChatSearchState(
      ChatStateKind.CONTENT,
      previous.query,
      mergeChatSearchResults(previous.results, result.data),
      result.data.length === 20
    );
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
    this.closeChannel();
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
    await this.markLatestRead(requestVersion, channel.id);
    return true;
  }

  private async markLatestRead(requestVersion: number, channelId: number): Promise<void> {
    if (!this.isCurrentConversation(requestVersion, channelId) || this.conversationState.messages.length === 0) {
      return;
    }
    const latestId: number = this.conversationState.messages[this.conversationState.messages.length - 1].id;
    const result: RepositoryResult<boolean> = await this.repository.markChatRead(channelId, latestId);
    if (!this.isCurrentConversation(requestVersion, channelId)) {
      return;
    }
    if (result.isUnauthorized()) {
      await this.notifyUnauthorized();
      return;
    }
    if (result.isSuccess() && result.data === true) {
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
  }

  private isCurrentConversation(requestVersion: number, channelId: number): boolean {
    return requestVersion === this.conversationRequestVersion &&
      this.conversationState.channel?.id === channelId;
  }

  private clearActiveUpload(): void {
    this.activeUpload = null;
    this.activeUploadState = null;
    this.activeUploadListener = null;
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

function mergeChatSearchResults(
  existing: Array<ChatSearchResult>,
  incoming: Array<ChatSearchResult>
): Array<ChatSearchResult> {
  const merged: Array<ChatSearchResult> = existing.slice();
  for (const candidate of incoming) {
    if (!merged.some((result: ChatSearchResult): boolean => result.message.id === candidate.message.id)) {
      merged.push(candidate);
    }
  }
  return merged;
}
