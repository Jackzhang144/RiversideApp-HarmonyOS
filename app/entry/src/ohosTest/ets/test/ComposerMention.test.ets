import { describe, expect, it } from '@ohos/hypium';
import {
  applyComposerMention,
  ComposerMentionQuery,
  ComposerMentionRequestGate,
  findComposerMentionQuery
} from '../../../main/ets/models/ComposerMentionModels';
import { ComposerEdit } from '../../../main/ets/models/AuthoringModels';

export default function composerMentionTest(): void {
  describe('Forum composer mention behavior', () => {
    it('finds only the active mention term at the current cursor', 0, () => {
      const active: ComposerMentionQuery | null = findComposerMentionQuery('前缀 @riv 后缀', 7);
      const email: ComposerMentionQuery | null = findComposerMentionQuery('mail@test', 9);
      const separated: ComposerMentionQuery | null = findComposerMentionQuery('@river hello', 12);

      expect(active?.term).assertEqual('riv');
      expect(active?.start).assertEqual(3);
      expect(active?.end).assertEqual(7);
      expect(email).assertNull();
      expect(separated).assertNull();
    });

    it('replaces the current term and restores the collapsed cursor after the mention', 0, () => {
      const edit: ComposerEdit | null = applyComposerMention('A @riv suffix', 6, 'river');

      expect(edit?.text).assertEqual('A @river suffix');
      expect(edit?.selectionStart).assertEqual(9);
      expect(edit?.selectionEnd).assertEqual(9);
      expect(applyComposerMention('A @riv', 6, 'river')?.text).assertEqual('A @river ');
      expect(applyComposerMention('A @riv suffix', 1, 'river')).assertNull();
    });

    it('rejects results from an older mention request', 0, () => {
      const gate: ComposerMentionRequestGate = new ComposerMentionRequestGate();
      const first: number = gate.issue();
      const second: number = gate.issue();

      expect(gate.isCurrent(first)).assertFalse();
      expect(gate.isCurrent(second)).assertTrue();
      gate.invalidate();
      expect(gate.isCurrent(second)).assertFalse();
    });
  });
}
