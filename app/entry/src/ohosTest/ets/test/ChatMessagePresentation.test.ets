import { describe, expect, it } from '@ohos/hypium';
import {
  ChatMessageFragment,
  ChatMessageFragmentKind,
  presentChatMessageBody
} from '../../../main/ets/components/ChatMessagePresentation';
import { ChatEmoji, ChatMessage } from '../../../main/ets/models/ChatModels';

function message(body: string): ChatMessage {
  return new ChatMessage(1, 'member', '', body, '', [], [], null, '2026-07-15T00:00:00Z', false);
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
  });
}
