import { describe, expect, it } from '@ohos/hypium';
import {
  avatarCornerRadius,
  avatarInitial,
  normalizedAvatarSize
} from '../../../main/ets/components/UserAvatarPresentation';

export default function userAvatarPresentationTest(): void {
  describe('User avatar presentation contract', () => {
    it('uses rounded rectangle corners instead of circular clipping', 0, () => {
      expect(avatarCornerRadius(28)).assertEqual(6);
      expect(avatarCornerRadius(32)).assertEqual(7);
      expect(avatarCornerRadius(36)).assertEqual(8);
      expect(avatarCornerRadius(38)).assertEqual(8);
      expect(avatarCornerRadius(64)).assertEqual(14);
      expect(avatarCornerRadius(76)).assertEqual(17);
      expect(avatarCornerRadius(76) < 38).assertTrue();
    });

    it('normalizes invalid sizes and creates a stable fallback initial', 0, () => {
      expect(normalizedAvatarSize(Number.NaN)).assertEqual(36);
      expect(normalizedAvatarSize(8)).assertEqual(24);
      expect(normalizedAvatarSize(160)).assertEqual(96);
      expect(avatarInitial(' 河畔 ')).assertEqual('河');
      expect(avatarInitial(' river ')).assertEqual('R');
      expect(avatarInitial('')).assertEqual('人');
    });
  });
}
