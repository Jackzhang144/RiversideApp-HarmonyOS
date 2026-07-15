import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { NotificationBucket, NotificationItem } from '../../../main/ets/models/NotificationModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseNotificationRepository } from '../../../main/ets/repositories/DiscourseNotificationRepository';
import { StubForumHttpClient } from './DiscourseForumRepository.test';

export default function notificationRepositoryTest(): void {
  describe('NotificationRepository contract', () => {
    it('loads private messages through the frozen paged Topic path', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"users":[{"id":8,"username":"alice"}],"topic_list":{"topics":[{' +
          '"id":2725,"title":"私信 Topic","category_id":0,"posts_count":4,"views":3,"like_count":0,' +
          '"excerpt":"私信预览","last_posted_at":"2026-07-15T01:00:00.000Z",' +
          '"posters":[{"user_id":8}]' +
        '}]}}'
      ));
      const repository: DiscourseNotificationRepository = new DiscourseNotificationRepository(client);

      const result: RepositoryResult<Array<NotificationItem>> = await repository.loadNotificationItems(
        'jack', NotificationBucket.PRIVATE_MESSAGES, 2, 40
      );

      expect(client.paths[0]).assertEqual('/topics/private-messages/jack.json?page=2');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].topicId).assertEqual(2725);
      expect(result.data?.[0].actorUsername).assertEqual('alice');
      done();
    });

    it('uses the frozen reply and mention filters with the model offset', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(
        HttpTextResult.success(200, '{"user_actions":[]}'),
        HttpTextResult.success(200, '{"user_actions":[]}')
      );
      const repository: DiscourseNotificationRepository = new DiscourseNotificationRepository(client);

      await repository.loadNotificationItems('jack z', NotificationBucket.REPLIES, 0, 20);
      await repository.loadNotificationItems('jack z', NotificationBucket.MENTIONS, 0, 40);

      expect(client.paths[0]).assertEqual('/user_actions.json?offset=20&username=jack%20z&filter=6,9');
      expect(client.paths[1]).assertEqual('/user_actions.json?offset=40&username=jack%20z&filter=7');
      done();
    });

    it('merges custom Reactions and likes newest first without dropping either source', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(
        HttpTextResult.success(200, '[{' +
          '"created_at":"2026-07-15T01:00:00.000Z","reaction":{"reaction_value":"heart"},' +
          '"user":{"username":"alice"},' +
          '"post":{"id":101,"topic_id":11,"topic_title":"较早 Reaction","post_number":2}' +
        '}]'),
        HttpTextResult.success(200, '{"user_actions":[{' +
          '"id":202,"topic_id":12,"title":"较新赞","post_id":202,"post_number":3,' +
          '"created_at":"2026-07-15T02:00:00.000Z","acting_username":"bob"' +
        '}]}')
      );
      const repository: DiscourseNotificationRepository = new DiscourseNotificationRepository(client);

      const result: RepositoryResult<Array<NotificationItem>> = await repository.loadNotificationItems(
        'jack', NotificationBucket.REACTIONS, 3, 60
      );

      expect(client.paths[0]).assertEqual(
        '/discourse-reactions/posts/reactions-received.json?username=jack&page=3'
      );
      expect(client.paths[1]).assertEqual('/user_actions.json?offset=60&username=jack&filter=2');
      expect(result.data?.length).assertEqual(2);
      expect(result.data?.[0].topicId).assertEqual(12);
      expect(result.data?.[0].reaction).assertEqual('+1');
      expect(result.data?.[1].reaction).assertEqual('heart');
      done();
    });

    it('propagates a canonical unauthorized response from either Reaction source', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(
        HttpTextResult.success(200, '[]'),
        HttpTextResult.unauthorized()
      );
      const repository: DiscourseNotificationRepository = new DiscourseNotificationRepository(client);

      const result: RepositoryResult<Array<NotificationItem>> = await repository.loadNotificationItems(
        'jack', NotificationBucket.REACTIONS, 0, 0
      );

      expect(result.kind).assertEqual(RepositoryResultKind.UNAUTHORIZED);
      done();
    });
  });
}
