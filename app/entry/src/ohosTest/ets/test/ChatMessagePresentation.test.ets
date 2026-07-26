import { describe, expect, it } from '@ohos/hypium';
import {
  ChatMessageContextCapabilities,
  ChatMessageFragment,
  ChatMessageFragmentKind,
  chatEmojiGroups,
  filterChatReactionEmojis,
  formatChatMessageTimestamp,
  initialChatMessageIndex,
  isChatMessageGroupStart,
  presentChatMessageBody,
  resolveChatMessageContextCapabilities,
  selectQuickChatEmojis,
  visibleChatMessageId
} from '../../../main/ets/components/ChatMessagePresentation';
import {
  ChatChannel,
  ChatChannelNotificationLevel,
  ChatEmoji,
  ChatMessage
} from '../../../main/ets/models/ChatModels';

function message(body: string): ChatMessage {
  return new ChatMessage(1, 'member', '', body, '', [], [], null, '2026-07-15T00:00:00Z', false);
}

function conversationMessage(id: number, username: string, createdAt: string): ChatMessage {
  return new ChatMessage(id, username, '', `消息 ${id}`, '', [], [], null, createdAt, false);
}

function channel(
  userSilenced: boolean,
  canDeleteSelf: boolean,
  canDeleteOthers: boolean,
  canManagePins: boolean = false
): ChatChannel {
  return new ChatChannel(
    1,
    'general',
    'general',
    '',
    '',
    false,
    0,
    0,
    '',
    'general',
    userSilenced,
    canDeleteSelf,
    canDeleteOthers,
    ChatChannelNotificationLevel.MENTION,
    false,
    0,
    canManagePins
  );
}

export default function chatMessagePresentationTest(): void {
  describe('Chat message presentation', () => {
    it('renders only known Emoji tokens as inline image segments', 0, () => {
      const fragments: Array<ChatMessageFragment> = presentChatMessageBody(
        message('你好:wave:世界:missing:'),
        [new ChatEmoji('wave', '/images/emoji/wave.png', 'people')]
      );

      expect(fragments.length).assertEqual(3);
      expect(fragments[0].kind).assertEqual(ChatMessageFragmentKind.TEXT);
      expect(fragments[0].text).assertEqual('你好');
      expect(fragments[1].kind).assertEqual(ChatMessageFragmentKind.EMOJI);
      expect(fragments[1].text).assertEqual(':wave:');
      expect(fragments[1].imageUrl).assertEqual('https://river-side.cc/images/emoji/wave.png');
      expect(fragments[2].text).assertEqual('世界:missing:');
    });

    it('formats message timestamps to minutes without exposing seconds', 0, () => {
      expect(formatChatMessageTimestamp('2026-06-30T04:57:16Z')).assertEqual('2026-06-30 04:57');
      expect(formatChatMessageTimestamp('')).assertEqual('');
    });

    it('groups only consecutive messages from the same author within five minutes', 0, () => {
      const messages: Array<ChatMessage> = [
        conversationMessage(1, 'admin', '2026-06-30T04:57:16Z'),
        conversationMessage(2, 'admin', '2026-06-30T05:01:16Z'),
        conversationMessage(3, 'member', '2026-06-30T05:02:16Z'),
        conversationMessage(4, 'member', '2026-06-30T05:08:17Z')
      ];

      expect(isChatMessageGroupStart(messages, 0)).assertTrue();
      expect(isChatMessageGroupStart(messages, 1)).assertFalse();
      expect(isChatMessageGroupStart(messages, 2)).assertTrue();
      expect(isChatMessageGroupStart(messages, 3)).assertTrue();
    });

    it('exposes writable message actions from one permission policy', 0, () => {
      const capabilities: ChatMessageContextCapabilities = resolveChatMessageContextCapabilities(
        conversationMessage(1, 'member', '2026-07-15T00:00:00Z'),
        channel(false, true, false),
        'member',
        true
      );

      expect(capabilities.canReply).assertTrue();
      expect(capabilities.canCopyLink).assertTrue();
      expect(capabilities.canMention).assertTrue();
      expect(capabilities.canReact).assertTrue();
      expect(capabilities.canDelete).assertTrue();
      expect(capabilities.canRestore).assertFalse();
      expect(capabilities.canPin).assertFalse();
    });

    it('exposes pinning only when the server grants channel pin management', 0, () => {
      const capabilities: ChatMessageContextCapabilities = resolveChatMessageContextCapabilities(
        conversationMessage(1, 'member', '2026-07-15T00:00:00Z'),
        channel(false, false, false, true),
        'member',
        true
      );

      expect(capabilities.canPin).assertTrue();
    });

    it('keeps deleted messages read-only while exposing permitted restore', 0, () => {
      const deletedMessage: ChatMessage = new ChatMessage(
        2,
        'other',
        '',
        '已删除',
        '',
        [],
        [],
        null,
        '2026-07-15T00:00:00Z',
        true
      );
      const capabilities: ChatMessageContextCapabilities = resolveChatMessageContextCapabilities(
        deletedMessage,
        channel(true, false, true),
        'member',
        true
      );

      expect(capabilities.canReply).assertFalse();
      expect(capabilities.canMention).assertFalse();
      expect(capabilities.canReact).assertFalse();
      expect(capabilities.canDelete).assertFalse();
      expect(capabilities.canRestore).assertTrue();
    });

    it('prioritizes diverse quick reactions and fills missing slots in source order', 0, () => {
      const emojis: Array<ChatEmoji> = [
        new ChatEmoji('smile', '', 'people'),
        new ChatEmoji('heart', '', 'symbols'),
        new ChatEmoji('+1', '', 'people'),
        new ChatEmoji('laughing', '', 'people'),
        new ChatEmoji('wave', '', 'people')
      ];
      const selected: Array<ChatEmoji> = selectQuickChatEmojis(
        emojis,
        ['heart', '+1', '-1', 'laughing'],
        4
      );

      expect(selected.map((emoji: ChatEmoji): string => emoji.name).join(','))
        .assertEqual('heart,+1,laughing,smile');
    });

    it('builds stable Reaction groups and filters the full catalog by group and search', 0, () => {
      const emojis: Array<ChatEmoji> = [
        new ChatEmoji('smile', '', 'people'),
        new ChatEmoji('heart', '', 'symbols'),
        new ChatEmoji('wave', '', 'people'),
        new ChatEmoji('RiverSide_Love', '', 'custom'),
        new ChatEmoji('orphan', '', '')
      ];

      expect(chatEmojiGroups(emojis).join(',')).assertEqual('people,symbols,custom');
      expect(filterChatReactionEmojis(emojis, 'people', ' WA ')[0].name).assertEqual('wave');
      expect(filterChatReactionEmojis(emojis, '', 'love')[0].name).assertEqual('RiverSide_Love');
      expect(filterChatReactionEmojis(emojis, 'symbols', 'wave').length).assertEqual(0);
    });

    it('selects the latest or focused initial Chat message and validates visible indices', 0, () => {
      const messages: Array<ChatMessage> = [
        conversationMessage(7, 'member', '2026-07-12T07:00:00Z'),
        conversationMessage(8, 'member', '2026-07-12T08:00:00Z'),
        conversationMessage(9, 'member', '2026-07-12T09:00:00Z')
      ];

      expect(initialChatMessageIndex(messages, null)).assertEqual(2);
      expect(initialChatMessageIndex(messages, 8)).assertEqual(1);
      expect(initialChatMessageIndex(messages, 99)).assertEqual(2);
      expect(visibleChatMessageId(messages, 1)).assertEqual(8);
      expect(visibleChatMessageId(messages, -1)).assertNull();
      expect(visibleChatMessageId(messages, 3)).assertNull();
    });
  });
}
