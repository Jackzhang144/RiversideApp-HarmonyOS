import { describe, expect, it } from '@ohos/hypium';
import {
  ForumLiveUpdateController,
  ForumLiveUpdateTimer
} from '../../../main/ets/app/ForumLiveUpdateController';
import {
  DiscourseMessageBusClient,
  MessageBusEvent,
  MessageBusPollResult,
  MessageBusResponseParser,
  MessageBusSubscription
} from '../../../main/ets/network/DiscourseMessageBus';
import {
  HttpTextResult,
  MessageBusHttpClient
} from '../../../main/ets/network/DiscourseHttpClient';
import { AppShellModel } from '../../../main/ets/app/AppShellModel';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  ForumPost,
  TopicDetail,
  TopicDetailMetadata,
  TopicNotificationLevel,
  TopicPostBatch
} from '../../../main/ets/models/ForumModels';
import { MemoryCategoryCache } from './support/MemoryCategoryCache';
import {
  TopicReadingRepository,
  firstPost,
  fourthPost,
  secondPost,
  thirdPost,
  topic
} from './support/TopicReadingTestFixtures';

class StubMessageBusHttpClient implements MessageBusHttpClient {
  public readonly requests: Array<string> = [];
  public readonly results: Array<HttpTextResult> = [];

  public async postMessageBus(path: string, body: string): Promise<HttpTextResult> {
    this.requests.push(`${path}|${body}`);
    return this.results.shift() ?? HttpTextResult.failure(0, 'missing MessageBus result');
  }
}

class FakeForumLiveUpdateTimer implements ForumLiveUpdateTimer {
  public readonly delays: Array<number> = [];
  public readonly clearedHandles: Array<number> = [];
  private readonly callbacks: Array<(() => Promise<void>) | null> = [null];
  private nextHandle: number = 1;

  public setTimeout(callback: () => Promise<void>, delayMilliseconds: number): number {
    const handle: number = this.nextHandle;
    this.nextHandle += 1;
    this.delays.push(delayMilliseconds);
    this.callbacks.push(callback);
    return handle;
  }

  public clearTimeout(handle: number): void {
    this.clearedHandles.push(handle);
  }

  public async fire(handle: number = this.nextHandle - 1): Promise<void> {
    const callback: (() => Promise<void>) | null = this.callbacks[handle] ?? null;
    if (callback !== null) {
      await callback();
    }
  }
}

export default function forumLiveUpdateTest(): void {
  describe('Discourse MessageBus live updates', () => {
    it('parses typed events and rejects incomplete payloads', 0, () => {
      const parser: MessageBusResponseParser = new MessageBusResponseParser();
      const success: MessageBusPollResult = parser.parse(
        '[{"channel":"/latest","message_id":12,"global_id":44,"data":{"topic_id":9}}]'
      );
      const invalid: MessageBusPollResult = parser.parse(
        '[{"channel":"/latest","message_id":12,"data":{"topic_id":9}}]'
      );

      expect(success.isSuccess()).assertTrue();
      expect(success.events.length).assertEqual(1);
      expect(success.events[0].data.number('topic_id')).assertEqual(9);
      expect(invalid.isSuccess()).assertFalse();
    });

    it('encodes channel cursors and sequence in the poll request', 0, async (done: Function) => {
      const transport: StubMessageBusHttpClient = new StubMessageBusHttpClient();
      transport.results.push(HttpTextResult.success(200, '[]'));
      const client: DiscourseMessageBusClient = new DiscourseMessageBusClient(transport);

      const result: MessageBusPollResult = await client.poll('client-id', 3, [
        new MessageBusSubscription('/latest', 8),
        new MessageBusSubscription('/topic/42', 19)
      ]);

      expect(result.isSuccess()).assertTrue();
      expect(transport.requests[0]).assertEqual(
        '/message-bus/client-id/poll|%2Flatest=8&%2Ftopic%2F42=19&__seq=3'
      );
      done();
    });

    it('runs only in foreground and resumes each channel from its last cursor', 0, async (done: Function) => {
      const transport: StubMessageBusHttpClient = new StubMessageBusHttpClient();
      transport.results.push(HttpTextResult.success(200,
        '[{"channel":"/latest","message_id":7,"global_id":20,"data":{"topic_id":5}}]'));
      transport.results.push(HttpTextResult.success(200, '[]'));
      const timer: FakeForumLiveUpdateTimer = new FakeForumLiveUpdateTimer();
      const delivered: Array<MessageBusEvent> = [];
      const controller: ForumLiveUpdateController = new ForumLiveUpdateController(
        new DiscourseMessageBusClient(transport),
        timer,
        (): string => 'client',
        (): Array<MessageBusSubscription> => [new MessageBusSubscription('/latest', -1)],
        async (events: Array<MessageBusEvent>): Promise<void> => {
          delivered.push(...events);
        }
      );

      controller.setForeground(true);
      await timer.fire(1);
      await timer.fire(2);
      controller.setForeground(false);

      expect(delivered.length).assertEqual(1);
      expect(transport.requests[0]).assertEqual('/message-bus/client/poll|%2Flatest=-1&__seq=0');
      expect(transport.requests[1]).assertEqual('/message-bus/client/poll|%2Flatest=7&__seq=1');
      expect(timer.clearedHandles.length).assertEqual(1);
      done();
    });

    it('appends a fetched live Reply without replacing the active Topic window', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        3,
        4,
        false,
        false,
        true,
        [102728, 102729, 102730],
        [firstPost(), secondPost(), thirdPost()],
        3,
        new TopicDetailMetadata(111, false, '', [], [], 0, TopicNotificationLevel.REGULAR, null, 91)
      )));
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(
        new TopicPostBatch([fourthPost()])
      ));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const addedPostNumbers: Array<number> = await model.applyLiveTopicPosts([fourthPost().id]);

      expect(addedPostNumbers.join(',')).assertEqual('4');
      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('1,2,3,4');
      expect(model.topicState.detail?.messageBusLastId).assertEqual(91);
      done();
    });
  });
}
