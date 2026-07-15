import { describe, expect, it } from '@ohos/hypium';
import {
  NotificationBucket,
  NotificationItem,
  NotificationItemKind,
  notificationActionText,
  parseReactionReceivedItems,
  parseUserActivityItems
} from '../../../main/ets/models/NotificationModels';

function firstItem(items: Array<NotificationItem> | null): NotificationItem {
  if (items === null || items.length === 0) {
    throw new Error('测试消息响应缺少首项');
  }
  return items[0];
}

export default function notificationModelsTest(): void {
  describe('Notification models', () => {
    it('parses reply and mention activity through the frozen user action shape', 0, () => {
      const items: Array<NotificationItem> | null = parseUserActivityItems(
        '{"user_actions":[{' +
          '"id":91,"topic_id":2725,"title":"站务 <b>更新</b>","post_id":102728,"post_number":5,' +
          '"created_at":"2026-07-15T01:02:03.000Z","acting_username":"river_admin",' +
          '"acting_name":"河畔管理员","acting_avatar_template":"/user_avatar/river-side.cc/river_admin/{size}/1.png",' +
          '"excerpt":"<p>请查看 <strong>第五楼</strong></p>","category_id":60' +
        '}]}'
      );

      expect(items?.length).assertEqual(1);
      expect(items?.[0].kind).assertEqual(NotificationItemKind.ACTIVITY);
      expect(items?.[0].topicId).assertEqual(2725);
      expect(items?.[0].postNumber).assertEqual(5);
      expect(items?.[0].title).assertEqual('站务 更新');
      expect(items?.[0].excerpt).assertEqual('请查看 第五楼');
      expect(items?.[0].actorUsername).assertEqual('river_admin');
      expect(items?.[0].avatarUrl).assertEqual(
        'https://river-side.cc/user_avatar/river-side.cc/river_admin/96/1.png'
      );
      const item: NotificationItem = firstItem(items);
      expect(notificationActionText(NotificationBucket.REPLIES, item))
        .assertEqual('river_admin 回复了');
      expect(notificationActionText(NotificationBucket.MENTIONS, item))
        .assertEqual('river_admin 提及了');
    });

    it('parses custom reactions without dropping the target Post or actor', 0, () => {
      const items: Array<NotificationItem> | null = parseReactionReceivedItems(
        '[{' +
          '"created_at":"2026-07-15T02:03:04.000Z",' +
          '"reaction":{"reaction_value":"heart"},' +
          '"user":{"username":"alice","name":"Alice","avatar_template":"/avatar/alice/{size}.png"},' +
          '"post":{"id":102729,"topic_id":2726,"topic_title":"Reaction Topic",' +
          '"post_number":9,"category_id":111,"excerpt":"<p>感谢分享</p>"}' +
        '}]'
      );

      expect(items?.length).assertEqual(1);
      expect(items?.[0].reaction).assertEqual('heart');
      expect(items?.[0].postId).assertEqual(102729);
      expect(items?.[0].postNumber).assertEqual(9);
      expect(notificationActionText(NotificationBucket.REACTIONS, firstItem(items)))
        .assertEqual('alice 回应了 heart');
    });

    it('rejects malformed activity payloads instead of inventing an empty list', 0, () => {
      expect(parseUserActivityItems('{"user_actions":{}}')).assertNull();
      expect(parseReactionReceivedItems('{"items":[]}')).assertNull();
    });
  });
}
