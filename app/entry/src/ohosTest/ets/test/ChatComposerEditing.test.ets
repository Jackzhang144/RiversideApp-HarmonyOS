import { describe, expect, it } from '@ohos/hypium';
import { ComposerEdit } from '../../../main/ets/models/AuthoringModels';
import {
  applyChatComposerMention,
  findChatComposerMention,
  insertChatEmojiText
} from '../../../main/ets/models/ChatComposerEditing';
import { ComposerMentionQuery } from '../../../main/ets/models/ComposerMentionModels';

export default function chatComposerEditingTest(): void {
  describe('Chat composer editing', () => {
    it('inserts an Emoji token at the current cursor', 0, () => {
      const edit: ComposerEdit | null = insertChatEmojiText('前缀后缀', 2, 2, 'wave');

      expect(edit?.text).assertEqual('前缀:wave:后缀');
      expect(edit?.selectionStart).assertEqual(8);
      expect(edit?.selectionEnd).assertEqual(8);
    });

    it('replaces only the active Chat mention term and restores its cursor', 0, () => {
      const query: ComposerMentionQuery | null = findChatComposerMention('你好 @mem 后文', 7);
      const edit: ComposerEdit | null = applyChatComposerMention('你好 @mem 后文', 7, 'member');

      expect(query?.term).assertEqual('mem');
      expect(edit?.text).assertEqual('你好 @member 后文');
      expect(edit?.selectionStart).assertEqual(11);
      expect(findChatComposerMention('mail@example.com', 16)).assertNull();
    });
  });
}
