import { describe, expect, it } from '@ohos/hypium';
import {
  filterComposerEmojis,
  insertComposerEmoji
} from '../../../main/ets/models/ComposerEmojiModels';
import { ComposerEdit } from '../../../main/ets/models/AuthoringModels';
import { ChatEmoji } from '../../../main/ets/models/ChatModels';

export default function composerEmojiModelsTest(): void {
  describe('Forum composer Emoji behavior', () => {
    it('searches the shared Emoji catalog by normalized name and preserves custom images', 0, () => {
      const emojis: Array<ChatEmoji> = [
        new ChatEmoji('smile', '', 'people'),
        new ChatEmoji('RiverSide_Love', '/uploads/default/original/custom-love.png', 'custom'),
        new ChatEmoji('thinking', '', 'people')
      ];

      const matches: Array<ChatEmoji> = filterComposerEmojis(emojis, '  LOVE ');

      expect(matches.length).assertEqual(1);
      expect(matches[0].name).assertEqual('RiverSide_Love');
      expect(matches[0].imageUrl()).assertEqual(
        'https://river-side.cc/uploads/default/original/custom-love.png'
      );
    });

    it('inserts a named Emoji token at the active selection and returns its collapsed caret', 0, () => {
      const edit: ComposerEdit | null = insertComposerEmoji('开头待替换结尾', 2, 5, ':RiverSide_Love:');

      expect(edit?.text).assertEqual('开头:RiverSide_Love:结尾');
      expect(edit?.selectionStart).assertEqual(18);
      expect(edit?.selectionEnd).assertEqual(18);
    });

    it('rejects an empty or punctuation-only Emoji name', 0, () => {
      expect(insertComposerEmoji('正文', 1, 1, ':::')).assertNull();
      expect(insertComposerEmoji('正文', 1, 1, '   ')).assertNull();
    });
  });
}
