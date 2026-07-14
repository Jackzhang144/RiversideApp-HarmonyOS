import { describe, expect, it } from '@ohos/hypium';
import {
  HomeHeaderActionKind,
  HomeHeaderActionPresentation
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
      expect(unavailable.accessibilityText).assertEqual('发布新 Topic，当前账户无 Category #111 创建权限');
    });
  });
}
