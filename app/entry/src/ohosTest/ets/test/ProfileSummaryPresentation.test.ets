import { describe, expect, it } from '@ohos/hypium';
import {
  ProfileSummaryPresentation,
  profileSummaryPresentationFor
} from '../../../main/ets/components/ProfileSummaryPresentation';
import { UserProfileSummary } from '../../../main/ets/models/ProfileModels';

export default function profileSummaryPresentationTest(): void {
  describe('Profile summary presentation', () => {
    it('presents every parsed activity metric and badge', 0, () => {
      const summary: UserProfileSummary = new UserProfileSummary(
        true,
        18,
        27,
        92,
        6,
        41,
        3,
        ['热心成员', '解决达人']
      );

      const presentation: ProfileSummaryPresentation = profileSummaryPresentationFor(summary);

      expect(presentation.available).assertTrue();
      expect(presentation.metrics.length).assertEqual(6);
      expect(presentation.metrics[0].label).assertEqual('Topic');
      expect(presentation.metrics[0].value).assertEqual(6);
      expect(presentation.metrics[1].label).assertEqual('Post');
      expect(presentation.metrics[1].value).assertEqual(41);
      expect(presentation.metrics[2].label).assertEqual('获赞');
      expect(presentation.metrics[2].value).assertEqual(27);
      expect(presentation.metrics[3].label).assertEqual('点赞');
      expect(presentation.metrics[3].value).assertEqual(18);
      expect(presentation.metrics[4].label).assertEqual('访问');
      expect(presentation.metrics[4].value).assertEqual(92);
      expect(presentation.metrics[5].label).assertEqual('解决');
      expect(presentation.metrics[5].value).assertEqual(3);
      expect(presentation.badges.join(',')).assertEqual('热心成员,解决达人');
    });

    it('keeps unavailable summaries empty', 0, () => {
      const presentation: ProfileSummaryPresentation = profileSummaryPresentationFor(
        UserProfileSummary.unavailable()
      );

      expect(presentation.available).assertFalse();
      expect(presentation.metrics.length).assertEqual(0);
      expect(presentation.badges.length).assertEqual(0);
    });
  });
}
