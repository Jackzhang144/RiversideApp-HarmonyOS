import { describe, expect, it } from '@ohos/hypium';
import {
  appThemePreferenceOptions,
  AppThemePreferenceOption,
  appSettingsHomeChannelOptions,
  HomeChannelPreferenceOption
} from '../../../main/ets/components/AppSettingsPresentation';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { HomeChannel } from '../../../main/ets/models/DiscoveryModels';
import { AppThemeMode, appThemePlatformColorMode } from '../../../main/ets/settings/AppThemeSettings';

export default function appSettingsPresentationTest(): void {
  describe('App settings presentation contract', () => {
    it('offers only the two product home-channel preferences', 0, () => {
      const options: Array<HomeChannelPreferenceOption> = appSettingsHomeChannelOptions(
        HomeChannel.LATEST_REPLIES
      );

      expect(options.length).assertEqual(2);
      expect(options[0].channel).assertEqual(HomeChannel.LATEST_CREATED);
      expect(options[0].label).assertEqual('最新发表');
      expect(options[0].description).assertEqual('按发帖时间倒序');
      expect(options[0].selected).assertFalse();
      expect(options[1].channel).assertEqual(HomeChannel.LATEST_REPLIES);
      expect(options[1].label).assertEqual('最新回复');
      expect(options[1].description).assertEqual('按最后回复时间倒序');
      expect(options[1].selected).assertTrue();
    });

    it('selects latest-created without exposing authenticated-only state', 0, () => {
      const options: Array<HomeChannelPreferenceOption> = appSettingsHomeChannelOptions(
        HomeChannel.LATEST_CREATED
      );

      expect(options[0].selected).assertTrue();
      expect(options[1].selected).assertFalse();
    });

    it('offers system light and dark theme choices', 0, () => {
      const options: Array<AppThemePreferenceOption> = appThemePreferenceOptions(AppThemeMode.DARK);

      expect(options.length).assertEqual(3);
      expect(options[0].mode).assertEqual(AppThemeMode.SYSTEM);
      expect(options[0].label).assertEqual('跟随系统');
      expect(options[0].selected).assertFalse();
      expect(options[1].mode).assertEqual(AppThemeMode.LIGHT);
      expect(options[1].label).assertEqual('浅色');
      expect(options[1].selected).assertFalse();
      expect(options[2].mode).assertEqual(AppThemeMode.DARK);
      expect(options[2].label).assertEqual('深色');
      expect(options[2].selected).assertTrue();
    });

    it('maps every app theme to the platform color mode', 0, () => {
      expect(appThemePlatformColorMode(AppThemeMode.SYSTEM))
        .assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
      expect(appThemePlatformColorMode(AppThemeMode.LIGHT))
        .assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
      expect(appThemePlatformColorMode(AppThemeMode.DARK))
        .assertEqual(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
    });
  });
}
