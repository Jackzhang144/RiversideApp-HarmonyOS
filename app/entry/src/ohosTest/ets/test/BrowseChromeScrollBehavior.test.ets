import { describe, expect, it } from '@ohos/hypium';
import {
  BrowseChromeScrollBehavior,
  BrowseChromeScrollIntent
} from '../../../main/ets/app/BrowseChromeScrollBehavior';

export default function browseChromeScrollBehaviorTest(): void {
  describe('Browse chrome scroll behavior', () => {
    it('hides while browsing down and shows after reversing direction', 0, () => {
      const behavior: BrowseChromeScrollBehavior = new BrowseChromeScrollBehavior();

      expect(behavior.observe(4, true)).assertEqual(BrowseChromeScrollIntent.KEEP);
      expect(behavior.observe(5, true)).assertEqual(BrowseChromeScrollIntent.HIDE);
      expect(behavior.observe(-3, true)).assertEqual(BrowseChromeScrollIntent.KEEP);
      expect(behavior.observe(-5, true)).assertEqual(BrowseChromeScrollIntent.SHOW);
    });

    it('discards partial movement when scrolling becomes idle or resets', 0, () => {
      const behavior: BrowseChromeScrollBehavior = new BrowseChromeScrollBehavior();

      expect(behavior.observe(6, true)).assertEqual(BrowseChromeScrollIntent.KEEP);
      expect(behavior.observe(0, false)).assertEqual(BrowseChromeScrollIntent.KEEP);
      expect(behavior.observe(3, true)).assertEqual(BrowseChromeScrollIntent.KEEP);
      behavior.reset();
      expect(behavior.observe(5, true)).assertEqual(BrowseChromeScrollIntent.KEEP);
    });
  });
}
