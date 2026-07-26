import {
  ChatAuthenticationLifecycle,
  ChatMetadataProvider,
  ChatModel
} from '../../../../main/ets/app/ChatModel';
import { ChatStateKind } from '../../../../main/ets/app/ChatStateModels';
import { RepositoryResult } from '../../../../main/ets/core/RepositoryResult';
import { ComposerEdit } from '../../../../main/ets/models/AuthoringModels';
import {
  ChatChannel,
  ChatChannelNotificationSettings,
  ChatChannelNotificationUpdate,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatPinnedMessagePage,
  ChatReaction,
  ChatReactionAction,
  ChatSearchResult,
  ChatSendConfirmation,
  ChatSendRequest
} from '../../../../main/ets/models/ChatModels';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind
} from '../../../../main/ets/models/MediaModels';
import { MediaProgressListener, MediaTransportOperation } from '../../../../main/ets/network/ForumMediaTransport';
import { HttpTextResult } from '../../../../main/ets/network/DiscourseHttpClient';
import { ChatRepository } from '../../../../main/ets/repositories/ChatRepository';
import { MediaRepository, MediaUploadOperation } from '../../../../main/ets/repositories/MediaRepository';

export class StubChatRepository implements ChatRepository {
  public channelResults: Array<RepositoryResult<Array<ChatChannel>>> = [];
  public messageResults: Array<RepositoryResult<ChatMessagePage>> = [];
  public messageTasks: Array<Promise<RepositoryResult<ChatMessagePage>>> = [];
  public messageErrors: Array<string> = [];
  public directResults: Array<RepositoryResult<ChatChannel>> = [];
  public sendResults: Array<RepositoryResult<ChatSendConfirmation>> = [];
  public sendTasks: Array<Promise<RepositoryResult<ChatSendConfirmation>>> = [];
  public booleanResults: Array<RepositoryResult<boolean>> = [];
  public notificationSettingsResults: Array<RepositoryResult<ChatChannelNotificationSettings>> = [];
  public pinnedMessageResults: Array<RepositoryResult<ChatPinnedMessagePage>> = [];
  public emojiResults: Array<RepositoryResult<Array<ChatEmoji>>> = [];
  public searchResults: Array<RepositoryResult<Array<ChatSearchResult>>> = [];
  public messageChannelIds: Array<number> = [];
  public messageQueries: Array<ChatMessageQuery> = [];
  public sentRequests: Array<ChatSendRequest> = [];
  public reactionActions: Array<ChatReactionAction> = [];
  public markReadIds: Array<number> = [];
  public leaveChannelIds: Array<number> = [];
  public notificationUpdates: Array<ChatChannelNotificationUpdate> = [];
  public pinnedMessageChannelIds: Array<number> = [];
  public markedPinChannelIds: Array<number> = [];
  public pinnedMessageIds: Array<number> = [];
  public unpinnedMessageIds: Array<number> = [];

  public async loadChatChannels(): Promise<RepositoryResult<Array<ChatChannel>>> {
    return this.channelResults.shift() ?? RepositoryResult.unknown<Array<ChatChannel>>('missing channel result');
  }

  public async loadChatMessages(
    channelId: number,
    query: ChatMessageQuery
  ): Promise<RepositoryResult<ChatMessagePage>> {
    this.messageChannelIds.push(channelId);
    this.messageQueries.push(query);
    const messageError: string | undefined = this.messageErrors.shift();
    if (messageError !== undefined) {
      throw new Error(messageError);
    }
    const task: Promise<RepositoryResult<ChatMessagePage>> | undefined = this.messageTasks.shift();
    if (task !== undefined) return task;
    return this.messageResults.shift() ?? RepositoryResult.unknown<ChatMessagePage>('missing message result');
  }

  public async openDirectChat(_username: string): Promise<RepositoryResult<ChatChannel>> {
    return this.directResults.shift() ?? RepositoryResult.unknown<ChatChannel>('missing direct result');
  }

  public async markChatRead(_channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    this.markReadIds.push(messageId);
    return RepositoryResult.success<boolean>(true);
  }

  public async sendChatMessage(request: ChatSendRequest): Promise<RepositoryResult<ChatSendConfirmation>> {
    this.sentRequests.push(request);
    const task: Promise<RepositoryResult<ChatSendConfirmation>> | undefined = this.sendTasks.shift();
    if (task !== undefined) {
      return task;
    }
    return this.sendResults.shift() ?? RepositoryResult.unknown<ChatSendConfirmation>('missing send result');
  }

  public async reactToChatMessage(
    _channelId: number,
    _messageId: number,
    _emoji: string,
    action: ChatReactionAction
  ): Promise<RepositoryResult<boolean>> {
    this.reactionActions.push(action);
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing reaction result');
  }

  public async deleteChatMessage(_channelId: number, _messageId: number): Promise<RepositoryResult<boolean>> {
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing delete result');
  }

  public async restoreChatMessage(_channelId: number, _messageId: number): Promise<RepositoryResult<boolean>> {
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing restore result');
  }

  public async loadPinnedChatMessages(channelId: number): Promise<RepositoryResult<ChatPinnedMessagePage>> {
    this.pinnedMessageChannelIds.push(channelId);
    return this.pinnedMessageResults.shift() ??
      RepositoryResult.unknown<ChatPinnedMessagePage>('missing pinned message result');
  }

  public async markChatPinsRead(channelId: number): Promise<RepositoryResult<boolean>> {
    this.markedPinChannelIds.push(channelId);
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing mark pins read result');
  }

  public async pinChatMessage(_channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    this.pinnedMessageIds.push(messageId);
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing pin result');
  }

  public async unpinChatMessage(_channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    this.unpinnedMessageIds.push(messageId);
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing unpin result');
  }

  public async loadChatEmojis(): Promise<RepositoryResult<Array<ChatEmoji>>> {
    return this.emojiResults.shift() ?? RepositoryResult.success<Array<ChatEmoji>>([]);
  }

  public async searchChat(
    _query: string,
    _offset: number,
    _limit: number
  ): Promise<RepositoryResult<Array<ChatSearchResult>>> {
    return this.searchResults.shift() ?? RepositoryResult.success<Array<ChatSearchResult>>([]);
  }

  public async updateChatChannelNotifications(
    _channelId: number,
    update: ChatChannelNotificationUpdate
  ): Promise<RepositoryResult<ChatChannelNotificationSettings>> {
    this.notificationUpdates.push(update);
    return this.notificationSettingsResults.shift() ??
      RepositoryResult.unknown<ChatChannelNotificationSettings>('missing notification settings result');
  }

  public async leaveChatChannel(channelId: number): Promise<RepositoryResult<boolean>> {
    this.leaveChannelIds.push(channelId);
    return this.booleanResults.shift() ?? RepositoryResult.unknown<boolean>('missing leave result');
  }
}

export class DeferredChatMessageResult {
  public readonly promise: Promise<RepositoryResult<ChatSendConfirmation>>;
  private resolvePromise: (result: RepositoryResult<ChatSendConfirmation>) => void =
    (_result: RepositoryResult<ChatSendConfirmation>): void => {};

  public constructor() {
    this.promise = new Promise<RepositoryResult<ChatSendConfirmation>>(
      (resolve: (result: RepositoryResult<ChatSendConfirmation>) => void): void => {
        this.resolvePromise = resolve;
      }
    );
  }

  public resolve(result: RepositoryResult<ChatSendConfirmation>): void {
    this.resolvePromise(result);
  }
}

export class DeferredChatPageResult {
  public readonly promise: Promise<RepositoryResult<ChatMessagePage>>;
  private resolvePromise: (result: RepositoryResult<ChatMessagePage>) => void =
    (_result: RepositoryResult<ChatMessagePage>): void => {};

  public constructor() {
    this.promise = new Promise<RepositoryResult<ChatMessagePage>>(
      (resolve: (result: RepositoryResult<ChatMessagePage>) => void): void => {
        this.resolvePromise = resolve;
      }
    );
  }

  public resolve(result: RepositoryResult<ChatMessagePage>): void {
    this.resolvePromise(result);
  }
}

export class StubMediaTransportOperation implements MediaTransportOperation {
  public readonly completion: Promise<HttpTextResult> = Promise.resolve(HttpTextResult.failure(0, 'unused'));
  public cancelled: boolean = false;

  public cancel(): void {
    this.cancelled = true;
  }
}

export class StubMediaRepository implements MediaRepository {
  public results: Array<RepositoryResult<MediaUploadResult>> = [];
  public requests: Array<MediaUploadRequest> = [];

  public upload(request: MediaUploadRequest, onProgress: MediaProgressListener): MediaUploadOperation {
    this.requests.push(request);
    onProgress(request.media.sizeBytes, request.media.sizeBytes);
    const result: RepositoryResult<MediaUploadResult> = this.results.shift() ??
      RepositoryResult.unknown<MediaUploadResult>('missing upload result');
    return new MediaUploadOperation(new StubMediaTransportOperation(), Promise.resolve(result));
  }
}

export class StubAuthenticationLifecycle implements ChatAuthenticationLifecycle {
  public calls: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.calls += 1;
  }
}

export class FixedChatMetadataProvider implements ChatMetadataProvider {
  public nextStagedId(): string {
    return 'hm-fixed-stage';
  }

  public nowIso(): string {
    return '2026-07-12T12:00:00.000Z';
  }
}

export function channel(id: number = 55): ChatChannel {
  return new ChatChannel(id, '测试频道', '频道', '最后消息', '2026-07-12T09:00:00Z', false, 2, 9, 'member', 'test');
}

export function silencedChannel(): ChatChannel {
  return new ChatChannel(
    57,
    '只读频道',
    '频道',
    '',
    '',
    false,
    0,
    0,
    '',
    'readonly',
    true,
    true,
    false
  );
}

export function directChannel(id: number, lastMessageAt: string = ''): ChatChannel {
  return new ChatChannel(id, '测试私聊', 'member', '', lastMessageAt, true, 0, 0, '', `dm-${id}`);
}

export function message(
  id: number,
  text: string,
  createdAt: string,
  reactions: Array<ChatReaction> = [],
  deleted: boolean = false
): ChatMessage {
  return new ChatMessage(id, 'member', '', text, '', [], reactions, null, createdAt, deleted);
}

export function searchResult(id: number): ChatSearchResult {
  return new ChatSearchResult(
    message(id, `搜索结果 ${id}`, `2026-07-12T09:${id.toString().padStart(2, '0')}:00Z`),
    channel()
  );
}

export function cachedImage(): CachedMedia {
  const media: CachedMedia | null = CachedMedia.create(
    'chat-image',
    '/data/storage/el2/base/cache/media/chat.png',
    'internal://cache/media/chat.png',
    'chat.png',
    'image/png',
    1024
  );
  if (media === null) {
    throw new Error('测试媒体创建失败');
  }
  return media;
}

export function uploadedImage(): MediaUploadResult {
  const result: MediaUploadResult | null = MediaUploadResult.create(
    801,
    '/uploads/default/original/chat.png',
    'upload://chat',
    'chat.png',
    '![chat.png](upload://chat)'
  );
  if (result === null) {
    throw new Error('测试上传结果创建失败');
  }
  return result;
}
