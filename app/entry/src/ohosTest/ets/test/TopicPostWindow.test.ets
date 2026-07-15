import { describe, expect, it } from '@ohos/hypium';
import { TopicPostWindow } from '../../../main/ets/app/TopicPostWindow';
import { ForumPost } from '../../../main/ets/models/ForumModels';
import { firstPost, secondPost, thirdPost } from './support/TopicReadingTestFixtures';

export default function topicPostWindowTest(): void {
  describe('Topic post window', () => {
    it('orders visible posts and separates unloaded ids on both sides', 0, () => {
      const window: TopicPostWindow = TopicPostWindow.from(
        [firstPost().id, secondPost().id, thirdPost().id],
        [secondPost()]
      );

      expect(window.posts.map((post: ForumPost): number => post.id).join(','))
        .assertEqual(`${secondPost().id}`);
      expect(window.previousPostIds.join(',')).assertEqual(`${firstPost().id}`);
      expect(window.nextPostIds.join(',')).assertEqual(`${thirdPost().id}`);
      expect(window.hasPreviousPosts()).assertTrue();
      expect(window.hasNextPosts()).assertTrue();
    });

    it('keeps the entire id list pending when no posts are visible', 0, () => {
      const window: TopicPostWindow = TopicPostWindow.from(
        [firstPost().id, secondPost().id],
        []
      );

      expect(window.posts.length).assertEqual(0);
      expect(window.previousPostIds.length).assertEqual(0);
      expect(window.nextPostIds.join(',')).assertEqual(`${firstPost().id},${secondPost().id}`);
    });
  });
}
