import {
  ChatChannel,
  ChatMessage,
  ChatMessagePage,
  ChatSearchResult
} from '../models/ChatModels';
import { MediaUploadResult } from '../models/MediaModels';

export enum ChatStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
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

  public withChannel(channel: ChatChannel): ChatConversationState {
    return new ChatConversationState(
      this.kind,
      channel,
      this.messages,
      this.canLoadMorePast,
      this.canLoadMoreFuture,
      this.loadingPast,
      this.loadingFuture,
      this.message
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
