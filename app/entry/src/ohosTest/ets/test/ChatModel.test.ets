import { describe, expect, it } from '@ohos/hypium';
import {
  ChatAuthenticationLifecycle,
  ChatMetadataProvider,
  ChatModel,
  ChatStateKind
} from '../../../main/ets/app/ChatModel';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { ComposerEdit } from '../../../main/ets/models/AuthoringModels';
import {
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatReaction,
  ChatReactionAction,
  ChatSearchResult,
  ChatSendConfirmation,
  ChatSendRequest
} from '../../../main/ets/models/ChatModels';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind
} from '../../../main/ets/models/MediaModels';
import { MediaProgressListener, MediaTransportOperation } from '../../../main/ets/network/ForumMediaTransport';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { ChatRepository } from '../../../main/ets/repositories/ChatRepository';
import { MediaRepository, MediaUploadOperation } from '../../../main/ets/repositories/MediaRepository';

class StubChatRepository implements ChatRepository {
  public channelResults: Array<RepositoryResult<Array<ChatChannel>>> = [];
  public messageResults: Array<RepositoryResult<ChatMessagePage>> = [];
  public messageTasks: Array<Promise<RepositoryResult<ChatMessagePage>>> = [];
  public messageErrors: Array<string> = [];
  public directResults: Array<RepositoryResult<ChatChannel>> = [];
  public sendResults: Array<RepositoryResult<ChatSendConfirmation>> = [];
  public sendTasks: Array<Promise<RepositoryResult<ChatSendConfirmation>>> = [];
  public booleanResults: Array<RepositoryResult<boolean>> = [];
  public emojiResults: Array<RepositoryResult<Array<ChatEmoji>>> = [];
  public searchResults: Array<RepositoryResult<Array<ChatSearchResult>>> = [];
  public messageChannelIds: Array<number> = [];
  public messageQueries: Array<ChatMessageQuery> = [];
  public sentRequests: Array<ChatSendRequest> = [];
  public reactionActions: Array<ChatReactionAction> = [];
  public markReadIds: Array<number> = [];
  public leaveChannelIds: Array<number> = [];

  public async loadChatChannels(): Promise<RepositoryResult<Array<ChatChannel>>> {
    return this.channelResults.shift() ?? RepositoryResult.failure<Array<ChatChannel>>('missing channel result');
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
    return this.messageResults.shift() ?? RepositoryResult.failure<ChatMessagePage>('missing message result');
  }

  public async openDirectChat(_username: string): Promise<RepositoryResult<ChatChannel>> {
    return this.directResults.shift() ?? RepositoryResult.failure<ChatChannel>('missing direct result');
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
    return this.sendResults.shift() ?? RepositoryResult.failure<ChatSendConfirmation>('missing send result');
  }

  public async reactToChatMessage(
    _channelId: number,
    _messageId: number,
    _emoji: string,
    action: ChatReactionAction
  ): Promise<RepositoryResult<boolean>> {
    this.reactionActions.push(action);
    return this.booleanResults.shift() ?? RepositoryResult.failure<boolean>('missing reaction result');
  }

  public async deleteChatMessage(_channelId: number, _messageId: number): Promise<RepositoryResult<boolean>> {
    return this.booleanResults.shift() ?? RepositoryResult.failure<boolean>('missing delete result');
  }

  public async restoreChatMessage(_channelId: number, _messageId: number): Promise<RepositoryResult<boolean>> {
    return this.booleanResults.shift() ?? RepositoryResult.failure<boolean>('missing restore result');
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

  public async leaveChatChannel(channelId: number): Promise<RepositoryResult<boolean>> {
    this.leaveChannelIds.push(channelId);
    return this.booleanResults.shift() ?? RepositoryResult.failure<boolean>('missing leave result');
  }
}

class DeferredChatMessageResult {
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

class DeferredChatPageResult {
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

class StubMediaTransportOperation implements MediaTransportOperation {
  public readonly completion: Promise<HttpTextResult> = Promise.resolve(HttpTextResult.failure(0, 'unused'));
  public cancelled: boolean = false;

  public cancel(): void {
    this.cancelled = true;
  }
}

class StubMediaRepository implements MediaRepository {
  public results: Array<RepositoryResult<MediaUploadResult>> = [];
  public requests: Array<MediaUploadRequest> = [];

  public upload(request: MediaUploadRequest, onProgress: MediaProgressListener): MediaUploadOperation {
    this.requests.push(request);
    onProgress(request.media.sizeBytes, request.media.sizeBytes);
    const result: RepositoryResult<MediaUploadResult> = this.results.shift() ??
      RepositoryResult.failure<MediaUploadResult>('missing upload result');
    return new MediaUploadOperation(new StubMediaTransportOperation(), Promise.resolve(result));
  }
}

class StubAuthenticationLifecycle implements ChatAuthenticationLifecycle {
  public calls: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.calls += 1;
  }
}

class FixedChatMetadataProvider implements ChatMetadataProvider {
  public nextStagedId(): string {
    return 'hm-fixed-stage';
  }

  public nowIso(): string {
    return '2026-07-12T12:00:00.000Z';
  }
}

function channel(id: number = 55): ChatChannel {
  return new ChatChannel(id, '测试频道', '频道', '最后消息', '2026-07-12T09:00:00Z', false, 2, 9, 'member', 'test');
}

function silencedChannel(): ChatChannel {
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

function directChannel(id: number, lastMessageAt: string = ''): ChatChannel {
  return new ChatChannel(id, '测试私聊', 'member', '', lastMessageAt, true, 0, 0, '', `dm-${id}`);
}

function message(
  id: number,
  text: string,
  createdAt: string,
  reactions: Array<ChatReaction> = [],
  deleted: boolean = false
): ChatMessage {
  return new ChatMessage(id, 'member', '', text, '', [], reactions, null, createdAt, deleted);
}

function cachedImage(): CachedMedia {
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

function uploadedImage(): MediaUploadResult {
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

export default function chatModelTest(): void {
  describe('ChatModel public behavior', () => {
    it('inserts Emoji at a cursor, replaces a selection, and preserves Unicode offsets', 0, () => {
      const model: ChatModel = new ChatModel(new StubChatRepository());
      model.updateDraft('前缀后缀');

      const middle: ComposerEdit | null = model.insertEmoji('wave', 2, 2);
      expect(middle?.text).assertEqual('前缀:wave:后缀');
      expect(middle?.selectionStart).assertEqual(8);

      model.updateDraft('Hello选中World');
      const replacement: ComposerEdit | null = model.insertEmoji('heart', 5, 7);
      expect(replacement?.text).assertEqual('Hello:heart:World');
      expect(replacement?.selectionStart).assertEqual(12);

      model.updateDraft('甲😀乙');
      const unicode: ComposerEdit | null = model.insertEmoji('庆祝🎉', 3, 3);
      expect(unicode?.text).assertEqual('甲😀:庆祝🎉:乙');
      expect(unicode?.selectionStart).assertEqual(9);
      expect(unicode?.selectionEnd).assertEqual(9);
    });

    it('loads from last read, keeps server order, paginates and marks the real latest id read', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        repository.channelResults.push(RepositoryResult.success<Array<ChatChannel>>([channel()]));
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(8, '较早', '2026-07-12T08:00:00Z'),
            message(9, '较新', '2026-07-12T09:00:00Z')
          ], true, false)),
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(7, '最早', '2026-07-12T07:00:00Z'),
            message(8, '重复', '2026-07-12T08:00:00Z')
          ], false, false))
        );
        const model: ChatModel = new ChatModel(repository);

        await model.loadChannels();
        await model.openChannel(channel());
        await model.loadOlder();

        expect(model.channelState.kind).assertEqual(ChatStateKind.CONTENT);
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('7,8,9');
        expect(repository.messageQueries[0].fetchFromLastRead).assertTrue();
        expect(repository.messageQueries[1].targetMessageId).assertEqual(8);
        expect(repository.messageQueries[1].direction).assertEqual('past');
        expect(repository.markReadIds[0]).assertEqual(9);
        done();
      });

    it('opens a Chat search result around its server message id', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(
        new ChatMessagePage([message(30, '命中', '2026-07-12T11:00:00Z')], true, true)
      ));
      const model: ChatModel = new ChatModel(repository);

      await model.openChannelAt(channel(), 30);

      expect(repository.messageQueries[0].targetMessageId).assertEqual(30);
      expect(repository.messageQueries[0].direction).assertEqual('');
      expect(model.conversationState.messages[0].id).assertEqual(30);
      done();
    });

    it('refreshes channels and the active conversation on foreground without clearing the draft', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(9, '前台前消息', '2026-07-12T09:00:00Z')
          ], false, false)),
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(10, '前台新消息', '2026-07-12T10:00:00Z')
          ], false, false))
        );
        repository.channelResults.push(RepositoryResult.success<Array<ChatChannel>>([channel()]));
        const model: ChatModel = new ChatModel(repository);
        await model.openChannel(channel());
        model.updateDraft('保留中的草稿');

        await model.refreshForForeground();

        expect(repository.messageQueries[1].targetMessageId).assertEqual(9);
        expect(repository.messageQueries[1].direction).assertEqual('future');
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('9,10');
        expect(model.composerState.draft).assertEqual('保留中的草稿');
        expect(model.channelState.kind).assertEqual(ChatStateKind.CONTENT);
        done();
      });

    it('publicly refreshes only the active conversation incrementally', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(41, '轮询前消息', '2026-07-12T09:00:00Z')
        ], false, false)),
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(42, '轮询新增消息', '2026-07-12T10:00:00Z')
        ], false, false))
      );
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());
      model.updateDraft('轮询期间保留草稿');

      await model.refreshActiveConversationIncrementally();

      expect(repository.messageQueries[1].targetMessageId).assertEqual(41);
      expect(repository.messageQueries[1].direction).assertEqual('future');
      expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
        .assertEqual('41,42');
      expect(model.composerState.draft).assertEqual('轮询期间保留草稿');
      done();
    });

    it('shares one in-flight incremental conversation refresh across callers', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      const delayed: DeferredChatPageResult = new DeferredChatPageResult();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
        message(51, '并发刷新前消息', '2026-07-12T09:00:00Z')
      ], false, false)));
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());
      repository.messageTasks.push(delayed.promise);

      const first: Promise<void> = model.refreshActiveConversationIncrementally();
      const duplicate: Promise<void> = model.refreshActiveConversationIncrementally();

      expect(repository.messageQueries.length).assertEqual(2);
      delayed.resolve(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
        message(52, '并发刷新结果', '2026-07-12T10:00:00Z')
      ], false, false)));
      await Promise.all([first, duplicate]);
      expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
        .assertEqual('51,52');
      done();
    });

    it('shares the active conversation refresh between foreground and timer callers', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        const delayed: DeferredChatPageResult = new DeferredChatPageResult();
        repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(61, '统一互斥前消息', '2026-07-12T09:00:00Z')
        ], false, false)));
        repository.channelResults.push(RepositoryResult.success<Array<ChatChannel>>([channel()]));
        const model: ChatModel = new ChatModel(repository);
        await model.openChannel(channel());
        repository.messageTasks.push(delayed.promise);

        const timerRefresh: Promise<void> = model.refreshActiveConversationIncrementally();
        const foregroundRefresh: Promise<void> = model.refreshForForeground();

        expect(repository.messageQueries.length).assertEqual(2);
        delayed.resolve(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(62, '统一互斥结果', '2026-07-12T10:00:00Z')
        ], false, false)));
        await Promise.all([timerRefresh, foregroundRefresh]);
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('61,62');
        done();
      });

    it('recovers polling state after an unexpected repository exception', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
        message(71, '异常前消息', '2026-07-12T09:00:00Z')
      ], false, false)));
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());
      repository.messageErrors.push('controlled repository failure');

      await model.refreshActiveConversationIncrementally();

      expect(model.conversationState.loadingFuture).assertFalse();
      expect(model.conversationState.message.length > 0).assertTrue();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
        message(72, '异常恢复消息', '2026-07-12T10:00:00Z')
      ], false, false)));
      await model.refreshActiveConversationIncrementally();
      expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
        .assertEqual('71,72');
      done();
    });

    it('does not let a stale conversation refresh block the newly opened conversation', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        const staleRefresh: DeferredChatPageResult = new DeferredChatPageResult();
        repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(81, '旧会话消息', '2026-07-12T09:00:00Z')
        ], false, false)));
        const model: ChatModel = new ChatModel(repository);
        await model.openChannel(channel(55));
        repository.messageTasks.push(staleRefresh.promise);
        const staleTask: Promise<void> = model.refreshActiveConversationIncrementally();

        model.closeChannel();
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(91, '新会话首屏', '2026-07-12T10:00:00Z')
          ], false, false)),
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(92, '新会话轮询', '2026-07-12T11:00:00Z')
          ], false, false))
        );
        await model.openChannel(channel(56));

        await model.refreshActiveConversationIncrementally();

        expect(repository.messageChannelIds.join(',')).assertEqual('55,55,56,56');
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('91,92');
        staleRefresh.resolve(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(82, '过期结果', '2026-07-12T12:00:00Z')
        ], false, false)));
        await staleTask;
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('91,92');
        done();
      });

    it('merges a delayed foreground response with messages confirmed while it was loading', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        const delayed: DeferredChatPageResult = new DeferredChatPageResult();
        repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '已有消息', '2026-07-12T09:00:00Z')
        ], false, false)));
        repository.channelResults.push(RepositoryResult.success<Array<ChatChannel>>([channel()]));
        repository.sendResults.push(RepositoryResult.success<ChatSendConfirmation>(new ChatSendConfirmation(
          10,
          message(10, '刷新期间发送', '2026-07-12T10:00:00Z')
        )));
        const model: ChatModel = new ChatModel(repository);
        await model.openChannel(channel());
        model.updateDraft('刷新期间发送');
        repository.messageTasks.push(delayed.promise);

        const refreshTask: Promise<void> = model.refreshForForeground();
        expect(await model.send()).assertTrue();
        delayed.resolve(RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(11, '服务器新消息', '2026-07-12T11:00:00Z')
        ], false, false)));
        await refreshTask;

        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('9,10,11');
        done();
      });

    it('clears protected Chat state when the authenticated session resets', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.channelResults.push(RepositoryResult.success<Array<ChatChannel>>([channel()]));
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(
        new ChatMessagePage([message(30, '会话消息', '2026-07-12T11:00:00Z')], false, false)
      ));
      const model: ChatModel = new ChatModel(repository);
      await model.loadChannels();
      await model.openChannel(channel());
      model.updateDraft('尚未发送');

      model.reset();

      expect(model.channelState.kind).assertEqual(ChatStateKind.INITIAL);
      expect(model.conversationState.channel).assertNull();
      expect(model.composerState.draft).assertEqual('');
      expect(model.searchState.kind).assertEqual(ChatStateKind.INITIAL);
      done();
    });

    it('preserves text reply and uploaded images on send failure then clears only after server confirmation', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        const mediaRepository: StubMediaRepository = new StubMediaRepository();
        mediaRepository.results.push(RepositoryResult.success<MediaUploadResult>(uploadedImage()));
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(
            new ChatMessagePage([message(9, '原消息', '2026-07-12T09:00:00Z')], false, false)
          ),
          RepositoryResult.success<ChatMessagePage>(
            new ChatMessagePage([message(10, '带图回复', '2026-07-12T12:00:00Z')], false, false)
          )
        );
        repository.sendResults.push(
          RepositoryResult.failure<ChatSendConfirmation>('发送失败'),
          RepositoryResult.success<ChatSendConfirmation>(new ChatSendConfirmation(10))
        );
        const model: ChatModel = new ChatModel(
          repository,
          mediaRepository,
          null,
          new FixedChatMetadataProvider()
        );
        await model.openChannel(channel());
        model.updateDraft('带图回复');
        model.replyTo(9);
        await model.uploadImage(cachedImage(), (_state: MediaUploadState): void => {});

        const failed: boolean = await model.send();
        expect(failed).assertFalse();
        expect(model.composerState.draft).assertEqual('带图回复');
        expect(model.composerState.replyToMessageId).assertEqual(9);
        expect(model.composerState.uploads.length).assertEqual(1);
        expect(model.conversationState.messages.length).assertEqual(1);

        const sent: boolean = await model.send();
        expect(sent).assertTrue();
        expect(repository.sentRequests[0].uploadIds[0]).assertEqual(801);
        expect(repository.sentRequests[0].inReplyToId).assertEqual(9);
        expect(model.conversationState.messages.map((item: ChatMessage): number => item.id).join(','))
          .assertEqual('9,10');
        expect(model.composerState.draft).assertEqual('');
        expect(model.composerState.uploads.length).assertEqual(0);
        done();
      });

    it('ignores a delayed send response after switching to another Chat channel', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      const delayed: DeferredChatMessageResult = new DeferredChatMessageResult();
      repository.messageResults.push(
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '频道一', '2026-07-12T09:00:00Z')
        ], false, false)),
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(20, '频道二', '2026-07-12T10:00:00Z')
        ], false, false))
      );
      repository.sendTasks.push(delayed.promise);
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel(55));
      model.updateDraft('频道一草稿');
      const sendTask: Promise<boolean> = model.send();

      await model.openChannel(channel(66));
      model.updateDraft('频道二草稿');
      delayed.resolve(RepositoryResult.success<ChatSendConfirmation>(new ChatSendConfirmation(
        10,
        message(10, '频道一已发送', '2026-07-12T11:00:00Z')
      )));

      expect(await sendTask).assertFalse();
      expect(model.conversationState.channel?.id).assertEqual(66);
      expect(model.conversationState.messages[0].id).assertEqual(20);
      expect(model.composerState.draft).assertEqual('频道二草稿');
      done();
    });

    it('clears a server-confirmed draft without inventing a message when synchronization is delayed', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(9, '已有消息', '2026-07-12T09:00:00Z')
          ], false, false)),
          RepositoryResult.failure<ChatMessagePage>('同步暂不可用')
        );
        repository.sendResults.push(
          RepositoryResult.success<ChatSendConfirmation>(new ChatSendConfirmation(10))
        );
        const model: ChatModel = new ChatModel(repository);
        await model.openChannel(channel());
        model.updateDraft('已提交消息');

        expect(await model.send()).assertTrue();
        expect(model.composerState.draft).assertEqual('');
        expect(model.conversationState.messages.length).assertEqual(1);
        expect(model.conversationState.message).assertEqual('消息已发送，等待服务端同步');
        done();
      });

    it('blocks sending when the server marks the current user as silenced', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(
        new ChatMessagePage([message(9, '只读历史', '2026-07-12T09:00:00Z')], false, false)
      ));
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(silencedChannel());
      model.updateDraft('不应发送');

      expect(await model.send()).assertFalse();
      expect(repository.sentRequests.length).assertEqual(0);
      expect(model.composerState.message).assertEqual('服务端不允许当前账号在此频道发言');
      done();
    });

    it('keeps an upload retryable and never inserts a failed upload into the draft', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      const mediaRepository: StubMediaRepository = new StubMediaRepository();
      mediaRepository.results.push(
        RepositoryResult.failure<MediaUploadResult>('上传失败'),
        RepositoryResult.success<MediaUploadResult>(uploadedImage())
      );
      const model: ChatModel = new ChatModel(repository, mediaRepository);
      model.updateDraft('说明');

      const failed: MediaUploadState = await model.uploadImage(
        cachedImage(),
        (_state: MediaUploadState): void => {}
      );
      const succeeded: MediaUploadState = await model.uploadImage(
        cachedImage(),
        (_state: MediaUploadState): void => {}
      );

      expect(failed.kind).assertEqual(MediaUploadStateKind.FAILED);
      expect(model.composerState.draft).assertEqual('说明');
      expect(succeeded.kind).assertEqual(MediaUploadStateKind.SUCCEEDED);
      expect(model.composerState.uploads.length).assertEqual(1);
      done();
    });

    it('refreshes Reaction state only after a successful server write', 0, async (done: Function) => {
      const oldReaction: ChatReaction = new ChatReaction('heart', 1, false, []);
      const newReaction: ChatReaction = new ChatReaction('heart', 2, true, []);
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '消息', '2026-07-12T09:00:00Z', [oldReaction])
        ], false, false)),
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '消息', '2026-07-12T09:00:00Z', [newReaction])
        ], false, false))
      );
      repository.booleanResults.push(
        RepositoryResult.failure<boolean>('Reaction 失败'),
        RepositoryResult.success<boolean>(true)
      );
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());

      const failed: boolean = await model.react(9, 'heart', ChatReactionAction.ADD);
      expect(failed).assertFalse();
      expect(model.conversationState.messages[0].reactions[0].count).assertEqual(1);
      const succeeded: boolean = await model.react(9, 'heart', ChatReactionAction.ADD);
      expect(succeeded).assertTrue();
      expect(model.conversationState.messages[0].reactions[0].count).assertEqual(2);
      expect(model.conversationState.messages[0].reactions[0].reacted).assertTrue();
      done();
    });

    it('applies delete and restore only after the server confirms each transition', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '消息', '2026-07-12T09:00:00Z')
        ], false, false)),
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '', '2026-07-12T09:00:00Z', [], true)
        ], false, false)),
        RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
          message(9, '消息', '2026-07-12T09:00:00Z')
        ], false, false))
      );
      repository.booleanResults.push(
        RepositoryResult.failure<boolean>('删除失败'),
        RepositoryResult.success<boolean>(true),
        RepositoryResult.success<boolean>(true)
      );
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());

      expect(await model.deleteMessage(9)).assertFalse();
      expect(model.conversationState.messages[0].deleted).assertFalse();
      expect(model.conversationState.message).assertEqual('删除失败');
      expect(await model.deleteMessage(9)).assertTrue();
      expect(model.conversationState.messages[0].deleted).assertTrue();
      expect(await model.restoreMessage(9)).assertTrue();
      expect(model.conversationState.messages[0].deleted).assertFalse();
      done();
    });

    it('keeps a failed leave operation visible and retryable in the conversation', 0, async (done: Function) => {
      const repository: StubChatRepository = new StubChatRepository();
      repository.messageResults.push(RepositoryResult.success<ChatMessagePage>(
        new ChatMessagePage([message(9, '频道消息', '2026-07-12T09:00:00Z')], false, false)
      ));
      repository.booleanResults.push(RepositoryResult.failure<boolean>('离开失败'));
      const model: ChatModel = new ChatModel(repository);
      await model.openChannel(channel());

      expect(await model.leaveCurrentChannel()).assertFalse();
      expect(model.conversationState.channel?.id).assertEqual(55);
      expect(model.conversationState.message).assertEqual('离开失败');
      done();
    });

    it('best-effort removes only an empty direct message when its conversation closes', 0,
      async (done: Function) => {
        const repository: StubChatRepository = new StubChatRepository();
        repository.directResults.push(
          RepositoryResult.success<ChatChannel>(directChannel(77)),
          RepositoryResult.success<ChatChannel>(directChannel(88, '2026-07-15T10:00:00Z')),
          RepositoryResult.success<ChatChannel>(directChannel(99))
        );
        repository.messageResults.push(
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([], false, false)),
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([], false, false)),
          RepositoryResult.success<ChatMessagePage>(new ChatMessagePage([
            message(15, '已有消息', '2026-07-15T10:00:00Z')
          ], false, false))
        );
        repository.booleanResults.push(RepositoryResult.success<boolean>(true));
        const model: ChatModel = new ChatModel(repository);

        expect(await model.openDirectChat('empty')).assertTrue();
        await model.closeChannel();
        expect(await model.openDirectChat('existing')).assertTrue();
        await model.closeChannel();
        expect(await model.openDirectChat('nonempty')).assertTrue();
        await model.closeChannel();

        expect(repository.leaveChannelIds.join(',')).assertEqual('77');
        expect(model.conversationState.channel).assertNull();
        done();
      });
  });
}
