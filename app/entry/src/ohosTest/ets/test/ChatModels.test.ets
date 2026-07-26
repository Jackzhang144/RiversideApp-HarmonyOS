import { describe, expect, it } from '@ohos/hypium';
import {
  absoluteChatUrl,
  ChatChannel,
  ChatChannelNotificationLevel,
  chatChannelNotificationLevelLabel,
  ChatMessage,
  ChatMessagePage,
  chatMessagePermalink
} from '../../../main/ets/models/ChatModels';
import {
  parseChatChannels,
  parseChatMessagePage
} from '../../../main/ets/repositories/ChatResponseParser';

export default function chatModelsTest(): void {
  describe('Chat server data models', () => {
    it('resolves Discourse short upload URLs into fetchable HTTPS images', 0, () => {
      expect(absoluteChatUrl('upload://abc123.png')).assertEqual(
        'https://river-side.cc/uploads/short-url/abc123.png'
      );
      expect(absoluteChatUrl('upload://abc 123.png')).assertEqual(
        'https://river-side.cc/uploads/short-url/abc123.png'
      );
    });

    it('builds a Chat message permalink with the server channel slug', 0, () => {
      expect(chatMessagePermalink(71, 'alumni-square', 18)).assertEqual(
        'https://river-side.cc/chat/c/alumni-square/71/18'
      );
    });

    it('falls back to the channel id when the Chat channel has no slug', 0, () => {
      expect(chatMessagePermalink(71, '  ', 18)).assertEqual(
        'https://river-side.cc/chat/c/71/71/18'
      );
    });

    it('rejects Chat message permalinks with invalid identifiers', 0, () => {
      expect(chatMessagePermalink(0, 'alumni-square', 18)).assertEqual('');
      expect(chatMessagePermalink(71, 'alumni-square', -1)).assertEqual('');
      expect(chatMessagePermalink(71.5, 'alumni-square', 18)).assertEqual('');
      expect(chatMessagePermalink(71, 'alumni-square', 9007199254740992)).assertEqual('');
    });

    it('sorts channels by unread count and the actual last message timestamp', 0, () => {
      const channels: Array<ChatChannel> | null = parseChatChannels(
        '{"channels":[' +
          '{"id":3,"title":"更新时间较新但无消息","updated_at":"2030-01-01T00:00:00Z",' +
            '"current_user_membership":{"unread_count":0}},' +
          '{"id":1,"title":"普通频道","last_message":{"id":10,"created_at":"2026-07-12T09:00:00Z",' +
            '"message":"较早消息"},"current_user_membership":{"unread_count":0}},' +
          '{"id":2,"title":"未读频道","last_message":{"id":11,"created_at":"2026-07-12T08:00:00Z",' +
            '"message":"未读消息"},"current_user_membership":{"unread_count":2}}' +
        '],"tracking":{"channel_tracking":{"1":{"unread_count":5},' +
          '"2":{"unread_count":2},"3":{"unread_count":0}}}}'
      );

      expect(channels === null).assertFalse();
      expect(channels?.length).assertEqual(3);
      expect(channels?.[0].id).assertEqual(1);
      expect(channels?.[0].unreadCount).assertEqual(5);
      expect(channels?.[1].id).assertEqual(2);
      expect(channels?.[2].lastMessageAt).assertEqual('');
    });

    it('preserves custom Emoji text and server channel permissions', 0, () => {
      const channels: Array<ChatChannel> | null = parseChatChannels(
        '{"channels":[{"id":5,"title":"只读频道","meta":{"user_silenced":true,' +
          '"can_delete_self":true,"can_delete_others":false},' +
          '"current_user_membership":{"notification_level":"always","muted":true}}]}'
      );
      const page: ChatMessagePage | null = parseChatMessagePage(
        '{"messages":[{"id":4,"created_at":"2026-07-12T07:00:00Z",' +
          '"user":{"username":"member"},"cooked":"<p><img alt=\\\":riverside:\\\" ' +
          'src=\\\"/emoji.png\\\"></p>"}]}'
      );

      expect(channels?.[0].userSilenced).assertTrue();
      expect(channels?.[0].canDeleteSelf).assertTrue();
      expect(channels?.[0].canDeleteOthers).assertFalse();
      expect(channels?.[0].notificationLevel).assertEqual(ChatChannelNotificationLevel.ALWAYS);
      expect(channels?.[0].muted).assertTrue();
      expect(chatChannelNotificationLevelLabel(ChatChannelNotificationLevel.MENTION))
        .assertEqual('仅提及我时');
      expect(page?.messages[0].displayText()).assertEqual(':riverside:');
    });

    it('parses image-only messages, full Reaction users, replies and server ordering', 0, () => {
      const page: ChatMessagePage | null = parseChatMessagePage(
        '{"messages":[' +
          '{"id":9,"created_at":"2026-07-12T09:00:00Z","user":{"username":"later"},' +
            '"cooked":"<p>后发</p>"},' +
          '{"id":7,"created_at":"2026-07-12T08:00:00Z","user":{"username":"member"},' +
            '"message":"scaled_photo.png","uploads":[{"url":"/uploads/default/original/photo.png"}],' +
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
      expect(page?.messages[0].displayText()).assertEqual('');
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
