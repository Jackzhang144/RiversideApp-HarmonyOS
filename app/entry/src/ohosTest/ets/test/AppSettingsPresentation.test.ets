import { describe, expect, it } from '@ohos/hypium';
import {
  appSettingsHomeChannelOptions,
  HomeChannelPreferenceOption
} from '../../../main/ets/components/AppSettingsPresentation';
import { HomeChannel } from '../../../main/ets/models/DiscoveryModels';

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
  });
}
