import { describe, expect, it } from '@ohos/hypium';
import {
  HomeHeaderActionKind,
  HomeHeaderActionPresentation,
  FeatureSitePresentation,
  featureSitePresentations
} from '../../../main/ets/components/HomePresentation';

export default function homePresentationTest(): void {
  describe('Home presentation contract', () => {
    it('exposes Search and new Topic as real Home actions', 0, () => {
      const search: HomeHeaderActionPresentation = HomeHeaderActionPresentation.search();
      const newTopic: HomeHeaderActionPresentation = HomeHeaderActionPresentation.newTopic();

      expect(search.kind).assertEqual(HomeHeaderActionKind.SEARCH);
      expect(search.label).assertEqual('搜索');
      expect(search.available).assertTrue();
      expect(search.accessibilityText).assertEqual('搜索');
      expect(newTopic.kind).assertEqual(HomeHeaderActionKind.NEW_TOPIC);
      expect(newTopic.label).assertEqual('发布新 Topic');
      expect(newTopic.available).assertTrue();
      expect(newTopic.accessibilityText).assertEqual('发布新 Topic');

      const unavailable: HomeHeaderActionPresentation = HomeHeaderActionPresentation.newTopic(false);
      expect(unavailable.available).assertFalse();
      expect(unavailable.accessibilityText).assertEqual('发布新 Topic，当前账户无可用 Category 创建权限');
    });

    it('exposes only the five non-frozen Flutter feature sites', 0, () => {
      const sites: Array<FeatureSitePresentation> = featureSitePresentations();

      expect(sites.length).assertEqual(5);
      expect(sites.map((site: FeatureSitePresentation): string => site.title).join(','))
        .assertEqual('树洞,选课指南,校友地图,觅电,RS date');
      expect(sites[0].entryUrl)
        .assertEqual('https://whisper.river-side.cc/auth/start?mode=interactive');
      expect(sites[3].entryUrl).assertEqual('https://food.river-side.cc/auth/discourse');
      expect(sites.some((site: FeatureSitePresentation): boolean => site.homeUrl.includes('coin.'))).assertFalse();
    });
  });
}
