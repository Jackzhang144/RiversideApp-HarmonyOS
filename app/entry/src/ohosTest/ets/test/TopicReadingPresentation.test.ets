import { describe, expect, it } from '@ohos/hypium';
import {
  Category,
  ForumPost,
  PostReaction
} from '../../../main/ets/models/ForumModels';
import {
  categoryLabel,
  displayedReactions,
  reactionAccessibilityLabel,
  reactionCount,
  reactionEmojiKey,
  reactionEmojiUrl,
  selectedBookmarkPostIds,
  systemActionLabel
} from '../../../main/ets/components/TopicReadingPresentation';

export default function topicReadingPresentationTest(): void {
  describe('Topic reading presentation', () => {
    it('maps known and unknown system action codes into readable Chinese', 0, () => {
      expect(systemActionLabel('closed.enabled')).assertEqual('关闭了 Topic');
      expect(systemActionLabel('archived.disabled')).assertEqual('取消了 Topic 归档');
      expect(systemActionLabel('future.action')).assertEqual('更新了 Topic 状态');
    });

    it('resolves Category names and Reaction counts without guessing state', 0, () => {
      const categories: Array<Category> = [
        new Category(111, '测试专用', '25AAE2', '', 1, null, [])
      ];
      const reactions: Array<PostReaction> = [
        new PostReaction('heart', 2),
        new PostReaction('+1', 1)
      ];

      expect(categoryLabel(111, categories)).assertEqual('测试专用');
      expect(categoryLabel(60, categories)).assertEqual('Category #60');
      expect(reactionCount('heart', reactions)).assertEqual(2);
      expect(reactionCount('laughing', reactions)).assertEqual(0);
    });

    it('presents Reaction identifiers as emoji assets instead of visible internal labels', 0, () => {
      expect(reactionEmojiKey('reaction.open_mouth')).assertEqual('open_mouth');
      expect(reactionEmojiKey(':anxious_face_with_sweat:')).assertEqual('anxious_face_with_sweat');
      expect(reactionEmojiUrl('distorted_face'))
        .assertEqual('https://river-side.cc/images/emoji/twitter/distorted_face.png?v=15');
      expect(reactionAccessibilityLabel('+1')).assertEqual('赞同');
      expect(reactionAccessibilityLabel('open_mouth')).assertEqual('惊讶');
      expect(reactionAccessibilityLabel('future_reaction')).assertEqual('回应');
    });

    it('shows only Reactions that already have server-proven counts', 0, () => {
      const reactions: Array<PostReaction> = [
        new PostReaction('+1', 0),
        new PostReaction('heart', 2),
        new PostReaction('thinking', 0)
      ];

      expect(displayedReactions([]).length).assertEqual(0);
      expect(displayedReactions(reactions).length).assertEqual(1);
      expect(displayedReactions(reactions)[0].id).assertEqual('heart');
      expect(displayedReactions(reactions)[0].count).assertEqual(2);
    });

    it('projects only server-bookmarked Posts into observable selection state', 0, () => {
      const posts: Array<ForumPost> = [
        new ForumPost(101, 1, 'admin', '', '', 1, null, ''),
        new ForumPost(102, 1, 'admin', '', '', 2, null, '').withBookmark(true, 4763)
      ];

      const selectedPostIds: Array<number> = selectedBookmarkPostIds(posts);

      expect(selectedPostIds.length).assertEqual(1);
      expect(selectedPostIds[0]).assertEqual(102);
    });
  });
}
