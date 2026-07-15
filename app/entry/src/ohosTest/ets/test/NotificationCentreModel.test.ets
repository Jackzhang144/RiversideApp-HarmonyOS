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
  public requests: Array<string> = [];

  public async loadNotificationItems(
    username: string,
    bucket: NotificationBucket,
    page: number,
    offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    this.requests.push(`${username}:${bucket}:${page}:${offset}`);
    return this.results.shift() ?? RepositoryResult.failure<Array<NotificationItem>>('missing notification result');
  }
}

class StubNotificationAuthenticationLifecycle implements NotificationAuthenticationLifecycle {
  public callCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.callCount += 1;
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
        RepositoryResult.failure<Array<NotificationItem>>('网络中断'),
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

    it('publishes empty and failure states and delegates canonical 401 once', 0, async (done: Function) => {
      const repository: StubNotificationRepository = new StubNotificationRepository();
      const lifecycle: StubNotificationAuthenticationLifecycle = new StubNotificationAuthenticationLifecycle();
      repository.results.push(
        RepositoryResult.success<Array<NotificationItem>>([]),
        RepositoryResult.failure<Array<NotificationItem>>('服务不可用'),
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
  });
}
