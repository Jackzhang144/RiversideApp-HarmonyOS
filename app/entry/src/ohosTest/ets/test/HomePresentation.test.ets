import { describe, expect, it } from '@ohos/hypium';
import {
  HomeHeaderActionKind,
  HomeHeaderActionPresentation
} from '../../../main/ets/components/HomePresentation';

export default function homePresentationTest(): void {
  describe('Home presentation contract', () => {
    it('enables Search while keeping new Topic as an accessible placeholder', 0, () => {
      const search: HomeHeaderActionPresentation = HomeHeaderActionPresentation.search();
      const newTopic: HomeHeaderActionPresentation = HomeHeaderActionPresentation.newTopic();

      expect(search.kind).assertEqual(HomeHeaderActionKind.SEARCH);
      expect(search.label).assertEqual('搜索');
      expect(search.available).assertTrue();
      expect(search.accessibilityText).assertEqual('搜索');
      expect(newTopic.kind).assertEqual(HomeHeaderActionKind.NEW_TOPIC);
      expect(newTopic.label).assertEqual('发布新 Topic');
      expect(newTopic.available).assertFalse();
      expect(newTopic.accessibilityText).assertEqual('发布新 Topic，未实现');
    });
  });
}
