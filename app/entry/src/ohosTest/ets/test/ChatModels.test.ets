import { describe, expect, it } from '@ohos/hypium';
import {
  ChatChannel,
  ChatMessage,
  ChatMessagePage,
  parseChatChannels,
  parseChatMessagePage
} from '../../../main/ets/models/ChatModels';

export default function chatModelsTest(): void {
  describe('Chat server data models', () => {
    it('sorts channels by unread count and the actual last message timestamp', 0, () => {
      const channels: Array<ChatChannel> | null = parseChatChannels(
        '{"channels":[' +
          '{"id":3,"title":"更新时间较新但无消息","updated_at":"2030-01-01T00:00:00Z",' +
            '"current_user_membership":{"unread_count":0}},' +
          '{"id":1,"title":"普通频道","last_message":{"id":10,"created_at":"2026-07-12T09:00:00Z",' +
            '"message":"较早消息"},"current_user_membership":{"unread_count":0}},' +
          '{"id":2,"title":"未读频道","last_message":{"id":11,"created_at":"2026-07-12T08:00:00Z",' +
            '"message":"未读消息"},"current_user_membership":{"unread_count":2}}' +
        ']}'
      );

      expect(channels === null).assertFalse();
      expect(channels?.length).assertEqual(3);
      expect(channels?.[0].id).assertEqual(2);
      expect(channels?.[1].id).assertEqual(1);
      expect(channels?.[2].lastMessageAt).assertEqual('');
    });

    it('parses image-only messages, full Reaction users, replies and server ordering', 0, () => {
      const page: ChatMessagePage | null = parseChatMessagePage(
        '{"messages":[' +
          '{"id":9,"created_at":"2026-07-12T09:00:00Z","user":{"username":"later"},' +
            '"cooked":"<p>后发</p>"},' +
          '{"id":7,"created_at":"2026-07-12T08:00:00Z","user":{"username":"member"},' +
            '"message":"\\u200B","uploads":[{"url":"/uploads/default/original/photo.png"}],' +
            '"in_reply_to":{"user":{"username":"admin"},"excerpt":"<p>原消息</p>"},' +
            '"reactions":[{"emoji":"heart","count":2,"reacted":true,' +
              '"users":[{"username":"admin","avatar_template":"/user_avatar/admin/{size}/1.png"},' +
                '{"username":"member"}]}]},' +
          '{"id":8,"created_at":"2026-07-12T08:00:00Z","user":{"username":"same-time"},' +
            '"cooked":"<p>同时间</p>"}' +
        '],"meta":{"can_load_more_past":true,"can_load_more_future":false}}'
      );

      expect(page === null).assertFalse();
      expect(page?.messages.map((message: ChatMessage): number => message.id).join(',')).assertEqual('7,8,9');
      expect(page?.messages[0].uploadUrls[0]).assertEqual('/uploads/default/original/photo.png');
      expect(page?.messages[0].replyTo?.username).assertEqual('admin');
      expect(page?.messages[0].replyTo?.excerpt).assertEqual('原消息');
      expect(page?.messages[0].reactions[0].users.length).assertEqual(2);
      expect(page?.messages[0].reactions[0].reacted).assertTrue();
      expect(page?.canLoadMorePast).assertTrue();
      expect(page?.canLoadMoreFuture).assertFalse();
    });

    it('keeps deleted messages as recoverable server tombstones', 0, () => {
      const page: ChatMessagePage | null = parseChatMessagePage(
        '{"chat_messages":[{"id":12,"deleted_at":"2026-07-12T09:10:00Z",' +
          '"created_at":"2026-07-12T09:00:00Z","user":{"username":"member"}}]}'
      );

      expect(page?.messages.length).assertEqual(1);
      expect(page?.messages[0].deleted).assertTrue();
      expect(page?.messages[0].displayText()).assertEqual('消息已删除');
    });
  });
}
