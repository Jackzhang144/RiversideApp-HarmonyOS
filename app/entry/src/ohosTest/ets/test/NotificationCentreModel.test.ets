import { describe, expect, it } from '@ohos/hypium';
import {
  NotificationAuthenticationLifecycle,
  NotificationCentreModel,
  NotificationCentreStateKind
} from '../../../main/ets/app/NotificationCentreModel';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  NotificationBucket,
  NotificationItem,
  NotificationItemKind
} from '../../../main/ets/models/NotificationModels';
import { NotificationRepository } from '../../../main/ets/repositories/NotificationRepository';

class StubNotificationRepository implements NotificationRepository {
  public results: Array<RepositoryResult<Array<NotificationItem>>> = [];
  public markAllReadResults: Array<RepositoryResult<boolean>> = [];
  public requests: Array<string> = [];
  public markAllReadCallCount: number = 0;

  public async loadNotificationItems(
    username: string,
    bucket: NotificationBucket,
    page: number,
    offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    this.requests.push(`${username}:${bucket}:${page}:${offset}`);
    return this.results.shift() ?? RepositoryResult.unknown<Array<NotificationItem>>('missing notification result');
  }

  public async markAllRead(): Promise<RepositoryResult<boolean>> {
    this.markAllReadCallCount += 1;
    return this.markAllReadResults.shift() ??
      RepositoryResult.unknown<boolean>('missing mark-all-read result');
  }
}

class StubNotificationAuthenticationLifecycle implements NotificationAuthenticationLifecycle {
  public callCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.callCount += 1;
  }
}

class ControlledNotificationResult {
  public readonly promise: Promise<RepositoryResult<Array<NotificationItem>>>;
  private resolver: ((result: RepositoryResult<Array<NotificationItem>>) => void) | null = null;

  public constructor() {
    this.promise = new Promise<RepositoryResult<Array<NotificationItem>>>(
      (resolve: (result: RepositoryResult<Array<NotificationItem>>) => void): void => {
        this.resolver = resolve;
      }
    );
  }

  public complete(result: RepositoryResult<Array<NotificationItem>>): void {
    const resolve: ((result: RepositoryResult<Array<NotificationItem>>) => void) | null = this.resolver;
    this.resolver = null;
    resolve?.(result);
  }
}

class CachedRefreshNotificationRepository implements NotificationRepository {
  public readonly refreshResult: ControlledNotificationResult = new ControlledNotificationResult();
  private requestCount: number = 0;

  public async loadNotificationItems(
    _username: string,
    _bucket: NotificationBucket,
    _page: number,
    _offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    this.requestCount += 1;
    if (this.requestCount === 1) {
      return RepositoryResult.success<Array<NotificationItem>>([activity(1, '缓存消息')]);
    }
    return this.refreshResult.promise;
  }

  public async markAllRead(): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.success<boolean>(true);
  }
}

function activity(id: number, title: string): NotificationItem {
  return new NotificationItem(id, NotificationItemKind.ACTIVITY, title, {
    topicId: id + 100,
    postId: id + 1000,
    postNumber: id,
    actorUsername: 'river'
  });
}

export default function notificationCentreModelTest(): void {
  describe('NotificationCentreModel', () => {
    it('loads a selected bucket and advances both page and item offset', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      repository.results.push(
        RepositoryResult.success<Array<NotificationItem>>([activity(1, '第一页')]),
        RepositoryResult.success<Array<NotificationItem>>([activity(2, '第二页')]),
        RepositoryResult.success<Array<NotificationItem>>([])
      );
      const model: NotificationCentreModel = new NotificationCentreModel(repository);

      await model.load('jack', NotificationBucket.REPLIES);
      await model.loadMore();
      await model.loadMore();

      expect(repository.requests.join(','))
        .assertEqual('jack:replies:0:0,jack:replies:1:1,jack:replies:2:2');
      expect(model.state.kind).assertEqual(NotificationCentreStateKind.CONTENT);
      expect(model.state.items.length).assertEqual(2);
      expect(model.state.hasMore).assertFalse();
      done();
    });

    it('keeps loaded messages and exposes a retryable pagination failure', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      repository.results.push(
        RepositoryResult.success<Array<NotificationItem>>([activity(1, '已有消息')]),
        RepositoryResult.unknown<Array<NotificationItem>>('网络中断'),
        RepositoryResult.success<Array<NotificationItem>>([activity(2, '恢复后消息')])
      );
      const model: NotificationCentreModel = new NotificationCentreModel(repository);

      await model.load('jack', NotificationBucket.MENTIONS);
      await model.loadMore();
      expect(model.state.items.length).assertEqual(1);
      expect(model.state.message).assertEqual('网络中断');
      expect(model.state.hasMore).assertTrue();

      await model.loadMore();
      expect(model.state.items.length).assertEqual(2);
      expect(model.state.message).assertEqual('');
      done();
    });

    it('foreground refresh replaces the visible bucket without implying background delivery', 0,
      async (done: Function) => {
        const repository: StubNotificationRepository = new StubNotificationRepository();
        repository.results.push(
          RepositoryResult.success<Array<NotificationItem>>([activity(1, '旧消息')]),
          RepositoryResult.success<Array<NotificationItem>>([activity(2, '前台刷新消息')])
        );
        const model: NotificationCentreModel = new NotificationCentreModel(repository);

        await model.load('jack', NotificationBucket.REACTIONS);
        await model.refreshForForeground('jack');

        expect(repository.requests.join(','))
          .assertEqual('jack:reactions:0:0,jack:reactions:0:0');
        expect(model.state.items.length).assertEqual(1);
        expect(model.state.items[0].title).assertEqual('前台刷新消息');
        expect(model.state.refreshing).assertFalse();
        done();
      });

    it('keeps cached messages visible while re-entering the same bucket refreshes', 0,
      async (done: Function) => {
        const repository: CachedRefreshNotificationRepository = new CachedRefreshNotificationRepository();
        const model: NotificationCentreModel = new NotificationCentreModel(repository);

        await model.load('jack', NotificationBucket.REPLIES);
        const refresh: Promise<void> = model.load('jack', NotificationBucket.REPLIES);

        expect(model.state.kind).assertEqual(NotificationCentreStateKind.CONTENT);
        expect(model.state.items.length).assertEqual(1);
        expect(model.state.items[0].title).assertEqual('缓存消息');
        expect(model.state.refreshing).assertTrue();

        repository.refreshResult.complete(
          RepositoryResult.success<Array<NotificationItem>>([activity(2, '刷新消息')])
        );
        await refresh;
        expect(model.state.items[0].title).assertEqual('刷新消息');
        expect(model.state.refreshing).assertFalse();
        done();
      });

    it('does not expose cached messages after the authenticated user changes', 0,
      async (done: Function) => {
        const repository: CachedRefreshNotificationRepository = new CachedRefreshNotificationRepository();
        const model: NotificationCentreModel = new NotificationCentreModel(repository);

        await model.load('jack', NotificationBucket.REPLIES);
        const reload: Promise<void> = model.load('river', NotificationBucket.REPLIES);

        expect(model.state.kind).assertEqual(NotificationCentreStateKind.LOADING);
        expect(model.state.items.length).assertEqual(0);

        repository.refreshResult.complete(
          RepositoryResult.success<Array<NotificationItem>>([activity(2, '新账号消息')])
        );
        await reload;
        expect(model.state.items[0].title).assertEqual('新账号消息');
        done();
      });

    it('publishes empty and failure states and delegates canonical 401 once', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      const lifecycle: StubNotificationAuthenticationLifecycle = new StubNotificationAuthenticationLifecycle();
      repository.results.push(
        RepositoryResult.success<Array<NotificationItem>>([]),
        RepositoryResult.unknown<Array<NotificationItem>>('服务不可用'),
        RepositoryResult.unauthorized<Array<NotificationItem>>()
      );
      const model: NotificationCentreModel = new NotificationCentreModel(repository, lifecycle);

      await model.load('jack', NotificationBucket.PRIVATE_MESSAGES);
      expect(model.state.kind).assertEqual(NotificationCentreStateKind.EMPTY);
      await model.load('jack', NotificationBucket.REPLIES);
      expect(model.state.kind).assertEqual(NotificationCentreStateKind.ERROR);
      expect(model.state.message).assertEqual('服务不可用');
      await model.load('jack', NotificationBucket.MENTIONS);
      expect(lifecycle.callCount).assertEqual(1);
      done();
    });

    it('marks notifications read without clearing the visible activity history', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      repository.results.push(RepositoryResult.success<Array<NotificationItem>>([activity(1, '历史消息')]));
      repository.markAllReadResults.push(RepositoryResult.success<boolean>(true));
      const model: NotificationCentreModel = new NotificationCentreModel(repository);

      await model.load('jack', NotificationBucket.REPLIES);
      const result: RepositoryResult<boolean> = await model.markAllRead();

      expect(result.isSuccess()).assertTrue();
      expect(repository.markAllReadCallCount).assertEqual(1);
      expect(model.state.markingAllRead).assertFalse();
      expect(model.state.items.length).assertEqual(1);
      expect(model.state.items[0].title).assertEqual('历史消息');
      done();
    });

    it('keeps state on mark-read failure and delegates canonical 401 once', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      const lifecycle: StubNotificationAuthenticationLifecycle = new StubNotificationAuthenticationLifecycle();
      repository.results.push(RepositoryResult.success<Array<NotificationItem>>([activity(1, '未读消息')]));
      repository.markAllReadResults.push(RepositoryResult.unauthorized<boolean>());
      const model: NotificationCentreModel = new NotificationCentreModel(repository, lifecycle);

      await model.load('jack', NotificationBucket.MENTIONS);
      const result: RepositoryResult<boolean> = await model.markAllRead();

      expect(result.isUnauthorized()).assertTrue();
      expect(model.state.items.length).assertEqual(1);
      expect(model.state.markingAllRead).assertFalse();
      expect(model.state.message).assertEqual('');
      expect(lifecycle.callCount).assertEqual(1);
      done();
    });
  });
}
