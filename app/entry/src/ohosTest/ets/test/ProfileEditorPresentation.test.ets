import { describe, expect, it } from '@ohos/hypium';
import { canClearProfileBackground } from '../../../main/ets/components/ProfileEditorPresentation';
import { UserProfile } from '../../../main/ets/models/ProfileModels';

function profileWithBackgroundCapability(
  canUploadProfileBackground: boolean,
  profileBackgroundUrl: string
): UserProfile | null {
  return UserProfile.create(24, 'member', {
    canUploadProfileBackground: canUploadProfileBackground,
    profileBackgroundUrl: profileBackgroundUrl
  });
}

export default function profileEditorPresentationTest(): void {
  describe('Profile editor presentation', () => {
    it('shows clear background only when the server permits it and a background exists', 0, () => {
      const allowed: UserProfile | null = profileWithBackgroundCapability(
        true,
        '/uploads/default/original/background.png'
      );
      const forbidden: UserProfile | null = profileWithBackgroundCapability(
        false,
        '/uploads/default/original/background.png'
      );
      const empty: UserProfile | null = profileWithBackgroundCapability(true, '');

      expect(canClearProfileBackground(allowed)).assertTrue();
      expect(canClearProfileBackground(forbidden)).assertFalse();
      expect(canClearProfileBackground(empty)).assertFalse();
      expect(canClearProfileBackground(null)).assertFalse();
    });
  });
}
