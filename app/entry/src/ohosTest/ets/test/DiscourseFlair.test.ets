import { describe, expect, it } from '@ohos/hypium';
import {
  absoluteDiscourseFlairUrl,
  isDiscourseFlairImage,
  normalizedDiscourseFlairColor
} from '../../../main/ets/core/DiscourseFlair';

export default function discourseFlairTest(): void {
  describe('Discourse avatar flair contract', () => {
    it('keeps icon names distinct from image paths', 0, () => {
      expect(isDiscourseFlairImage('graduation-cap')).assertFalse();
      expect(absoluteDiscourseFlairUrl('graduation-cap')).assertEqual('graduation-cap');
      expect(isDiscourseFlairImage('/uploads/default/flair.svg')).assertTrue();
      expect(absoluteDiscourseFlairUrl('/uploads/default/flair.svg'))
        .assertEqual('https://river-side.cc/uploads/default/flair.svg');
    });

    it('accepts only six-digit Discourse flair colors', 0, () => {
      expect(normalizedDiscourseFlairColor('25aae2')).assertEqual('#25AAE2');
      expect(normalizedDiscourseFlairColor('#FFFFFF')).assertEqual('#FFFFFF');
      expect(normalizedDiscourseFlairColor('transparent')).assertEqual('');
      expect(normalizedDiscourseFlairColor('123')).assertEqual('');
    });
  });
}
