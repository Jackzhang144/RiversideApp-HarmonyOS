import { describe, expect, it } from '@ohos/hypium';
import {
  AppBehaviorSettings,
  AppMaterialPreference,
  appMaterialPreferenceFromStoredValue
} from '../../../main/ets/settings/AppBehaviorSettings';
import { appMaterialEffect } from '../../../main/ets/settings/AppMaterialPolicy';
import { hdsMaterial } from '@kit.UIDesignKit';

export default function appBehaviorSettingsTest(): void {
  describe('App behavior settings', () => {
    it('preserves the existing safe browsing defaults', 0, () => {
      const settings: AppBehaviorSettings = new AppBehaviorSettings();

      expect(settings.immersiveBrowsingEnabled).assertTrue();
      expect(settings.confirmExternalLinks).assertTrue();
      expect(settings.materialPreference).assertEqual(AppMaterialPreference.SYSTEM);
    });

    it('updates one preference without changing the other', 0, () => {
      const defaults: AppBehaviorSettings = new AppBehaviorSettings();
      const reducedChrome: AppBehaviorSettings = defaults.withImmersiveBrowsing(false);
      const directLinks: AppBehaviorSettings = reducedChrome.withExternalLinkConfirmation(false);

      expect(reducedChrome.immersiveBrowsingEnabled).assertFalse();
      expect(reducedChrome.confirmExternalLinks).assertTrue();
      expect(directLinks.immersiveBrowsingEnabled).assertFalse();
      expect(directLinks.confirmExternalLinks).assertFalse();
      expect(directLinks.materialPreference).assertEqual(AppMaterialPreference.SYSTEM);
    });

    it('maps stored material values and keeps unknown values adaptive', 0, () => {
      expect(appMaterialPreferenceFromStoredValue('gentle')).assertEqual(AppMaterialPreference.GENTLE);
      expect(appMaterialPreferenceFromStoredValue('unsupported')).assertEqual(AppMaterialPreference.SYSTEM);
    });

    it('follows the official material fallback policy', 0, () => {
      expect(appMaterialEffect(AppMaterialPreference.SYSTEM, false).materialLevel)
        .assertEqual(hdsMaterial.MaterialLevel.ADAPTIVE);
      expect(appMaterialEffect(AppMaterialPreference.EXQUISITE, true).materialLevel)
        .assertEqual(hdsMaterial.MaterialLevel.EXQUISITE);
      expect(appMaterialEffect(AppMaterialPreference.EXQUISITE, false).materialLevel)
        .assertEqual(hdsMaterial.MaterialLevel.SMOOTH);
      expect(appMaterialEffect(AppMaterialPreference.OFF, true).materialType)
        .assertEqual(hdsMaterial.MaterialType.NONE);
    });
  });
}
