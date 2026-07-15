import { describe, expect, it } from '@ohos/hypium';
import {
  ChatMessageFragment,
  ChatMessageFragmentKind,
  formatChatMessageTimestamp,
  isChatMessageGroupStart,
  presentChatMessageBody
} from '../../../main/ets/components/ChatMessagePresentation';
import { ChatEmoji, ChatMessage } from '../../../main/ets/models/ChatModels';

function message(body: string): ChatMessage {
  return new ChatMessage(1, 'member', '', body, '', [], [], null, '2026-07-15T00:00:00Z', false);
}

function conversationMessage(id: number, username: string, createdAt: string): ChatMessage {
  return new ChatMessage(id, username, '', `消息 ${id}`, '', [], [], null, createdAt, false);
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
  });
}
