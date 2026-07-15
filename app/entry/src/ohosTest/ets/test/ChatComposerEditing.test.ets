import { describe, expect, it } from '@ohos/hypium';
import { ComposerEdit } from '../../../main/ets/models/AuthoringModels';
import { insertChatEmojiText } from '../../../main/ets/models/ChatComposerEditing';

export default function chatComposerEditingTest(): void {
  describe('Chat composer editing', () => {
    it('inserts an Emoji token at the current cursor', 0, () => {
      const edit: ComposerEdit | null = insertChatEmojiText('前缀后缀', 2, 2, 'wave');

      expect(edit?.text).assertEqual('前缀:wave:后缀');
      expect(edit?.selectionStart).assertEqual(8);
      expect(edit?.selectionEnd).assertEqual(8);
    });
  });
}
