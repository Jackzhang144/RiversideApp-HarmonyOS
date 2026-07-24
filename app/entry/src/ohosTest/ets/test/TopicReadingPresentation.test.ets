import { describe, expect, it } from '@ohos/hypium';
import {
  Category,
  ForumPost,
  ForumPostMetadata,
  PostReaction
} from '../../../main/ets/models/ForumModels';
import {
  categoryLabel,
  normalizeTopicFloor,
  displayedReactions,
  reactionAccessibilityLabel,
  reactionCount,
  reactionEmojiKey,
  reactionEmojiUrl,
  PostFlagOption,
  postFlagOptions,
  selectedBookmarkPostIds,
  shouldShowSuggestedTopics,
  systemActionLabel,
  topicPostRenderKey,
  topicPostListIndex,
  topicPostUrl
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
        new PostReaction('+1', 4),
        new PostReaction('heart', 2),
        new PostReaction('thinking', 0)
      ];

      expect(displayedReactions([]).length).assertEqual(0);
      expect(displayedReactions(reactions).length).assertEqual(1);
      expect(displayedReactions(reactions)[0].id).assertEqual('heart');
      expect(displayedReactions(reactions)[0].count).assertEqual(2);
      expect(reactionCount('+1', reactions)).assertEqual(4);
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

    it('builds canonical Flutter Post links from Topic and Post numbers', 0, () => {
      expect(topicPostUrl(2725, 1)).assertEqual('https://river-side.cc/t/2725/1');
      expect(topicPostUrl(2725, 37)).assertEqual('https://river-side.cc/t/2725/37');
      expect(topicPostUrl(0, 1)).assertEqual('');
      expect(topicPostUrl(2725, 0)).assertEqual('');
      expect(topicPostUrl(1.5, 2)).assertEqual('');
    });

    it('shows Suggested Topics only after the final Post window', 0, () => {
      expect(shouldShowSuggestedTopics(false, 2)).assertTrue();
      expect(shouldShowSuggestedTopics(true, 2)).assertFalse();
      expect(shouldShowSuggestedTopics(false, 0)).assertFalse();
    });

    it('normalizes typed and Slider floor targets against the Topic range', 0, () => {
      expect(normalizeTopicFloor('37', 120)).assertEqual(37);
      expect(normalizeTopicFloor('37.8', 120)).assertEqual(37);
      expect(normalizeTopicFloor('0', 120)).assertEqual(1);
      expect(normalizeTopicFloor('999', 120)).assertEqual(120);
      expect(normalizeTopicFloor('not-a-floor', 120)).assertEqual(null);
      expect(normalizeTopicFloor('37th', 120)).assertEqual(null);
      expect(normalizeTopicFloor('2', 0)).assertEqual(null);
    });

    it('maps a loaded Post number to its Topic List position', 0, () => {
      const completeWindow: Array<ForumPost> = [
        new ForumPost(101, 1, 'admin', '', '', 1, null, ''),
        new ForumPost(102, 1, 'admin', '', '', 2, null, ''),
        new ForumPost(103, 1, 'admin', '', '', 3, null, '')
      ];
      const pinpointWindow: Array<ForumPost> = [
        new ForumPost(103, 1, 'admin', '', '', 3, null, ''),
        new ForumPost(104, 1, 'admin', '', '', 4, null, '')
      ];

      expect(topicPostListIndex(completeWindow, 1)).assertEqual(0);
      expect(topicPostListIndex(completeWindow, 2)).assertEqual(6);
      expect(topicPostListIndex(completeWindow, 3)).assertEqual(7);
      expect(topicPostListIndex(pinpointWindow, 3)).assertEqual(6);
      expect(topicPostListIndex(pinpointWindow, 2)).assertEqual(-1);
      expect(topicPostListIndex(completeWindow, 0)).assertEqual(-1);
    });

    it('changes the card render key when a visible Post interaction changes', 0, () => {
      const original: ForumPost = new ForumPost(
        102, 1, 'admin', '', '原始正文', 2, null, '',
        new ForumPostMetadata('', '', '', null, null, 1, [new PostReaction('heart', 1)])
      );
      const reacted: ForumPost = new ForumPost(
        102, 1, 'admin', '', '原始正文', 2, null, '',
        new ForumPostMetadata('', '', '', null, null, 2, [new PostReaction('heart', 2)], 'heart')
      );

      expect(topicPostRenderKey(original) !== topicPostRenderKey(reacted)).assertTrue();
    });

    it('offers the six frozen Flutter flag reasons with explicit message requirements', 0, () => {
      const options: Array<PostFlagOption> = postFlagOptions('river_user');

      expect(options.length).assertEqual(6);
      expect(options.map((option: PostFlagOption): number => option.typeId).join(','))
        .assertEqual('6,3,4,8,10,7');
      expect(options[0].label).assertEqual('向 @river_user 发送消息');
      expect(options[0].needsMessage).assertTrue();
      expect(options[1].needsMessage).assertFalse();
      expect(options[4].needsMessage).assertTrue();
      expect(options[5].needsMessage).assertTrue();
    });
  });
}
