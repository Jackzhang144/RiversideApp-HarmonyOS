import { describe, expect, it } from '@ohos/hypium';
import {
  Category,
  ForumPost,
  ForumPostMetadata,
  PostReaction,
  TopicNotificationLevel
} from '../../../main/ets/models/ForumModels';
import {
  categoryLabel,
  displayedReactions,
  reactionAccessibilityLabel,
  reactionCount,
  reactionEmojiKey,
  reactionEmojiUrl,
  shouldShowPositiveReactionCountInTrigger,
  PostFlagOption,
  postFlagOptions,
  selectedBookmarkPostIds,
  shouldShowSuggestedTopics,
  systemActionLabel,
  topicProgressPreview,
  TopicProgressPreview,
  TopicProgressRailSide,
  topicProgressRailSideForHoldingStatus,
  topicProgressRatio,
  topicProgressTargetPostNumber,
  topicPostRenderKey,
  topicPostListIndex,
  topicPostUrl,
  TopicNotificationOption,
  topicNotificationLabel,
  topicNotificationOptions
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

    it('moves every Reaction to the left when a non-positive Reaction exists', 0, () => {
      const mixedReactions: Array<PostReaction> = [
        new PostReaction('+1', 4),
        new PostReaction('heart', 2),
        new PostReaction('thinking', 0)
      ];
      const positiveOnly: Array<PostReaction> = [new PostReaction('+1', 4)];

      expect(displayedReactions([]).length).assertEqual(0);
      expect(displayedReactions(positiveOnly).length).assertEqual(0);
      expect(displayedReactions(mixedReactions).length).assertEqual(2);
      expect(displayedReactions(mixedReactions)[0].id).assertEqual('+1');
      expect(displayedReactions(mixedReactions)[1].id).assertEqual('heart');
      expect(shouldShowPositiveReactionCountInTrigger(positiveOnly)).assertTrue();
      expect(shouldShowPositiveReactionCountInTrigger(mixedReactions)).assertFalse();
      expect(reactionCount('+1', mixedReactions)).assertEqual(4);
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

    it('maps the vertical reading rail onto exact Topic Post positions', 0, () => {
      expect(topicProgressRatio(1, 101)).assertEqual(0);
      expect(topicProgressRatio(51, 101)).assertEqual(0.5);
      expect(topicProgressRatio(101, 101)).assertEqual(1);
      expect(topicProgressRatio(999, 101)).assertEqual(1);
      expect(topicProgressTargetPostNumber(0, 200, 101)).assertEqual(1);
      expect(topicProgressTargetPostNumber(100, 200, 101)).assertEqual(51);
      expect(topicProgressTargetPostNumber(200, 200, 101)).assertEqual(101);
      expect(topicProgressTargetPostNumber(-20, 200, 101)).assertEqual(1);
    });

    it('moves the reading rail only for an unambiguous holding hand', 0, () => {
      expect(topicProgressRailSideForHoldingStatus(1, TopicProgressRailSide.RIGHT))
        .assertEqual(TopicProgressRailSide.LEFT);
      expect(topicProgressRailSideForHoldingStatus(2, TopicProgressRailSide.LEFT))
        .assertEqual(TopicProgressRailSide.RIGHT);
      expect(topicProgressRailSideForHoldingStatus(0, TopicProgressRailSide.LEFT))
        .assertEqual(TopicProgressRailSide.LEFT);
      expect(topicProgressRailSideForHoldingStatus(3, TopicProgressRailSide.RIGHT))
        .assertEqual(TopicProgressRailSide.RIGHT);
      expect(topicProgressRailSideForHoldingStatus(16, TopicProgressRailSide.LEFT))
        .assertEqual(TopicProgressRailSide.LEFT);
    });

    it('shows an exact loaded Post summary and an honest unloaded fallback', 0, () => {
      const posts: Array<ForumPost> = [
        new ForumPost(101, 2725, 'river_user', '<p>正文</p>', '  第一段\n第二段  ', 37, null, '')
      ];

      const loaded: TopicProgressPreview = topicProgressPreview(posts, 37);
      const unloaded: TopicProgressPreview = topicProgressPreview(posts, 80);

      expect(loaded.postNumber).assertEqual(37);
      expect(loaded.authorLabel).assertEqual('@river_user');
      expect(loaded.excerpt).assertEqual('第一段 第二段');
      expect(loaded.loaded).assertTrue();
      expect(unloaded.postNumber).assertEqual(80);
      expect(unloaded.authorLabel).assertEqual('尚未加载');
      expect(unloaded.loaded).assertFalse();
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
      expect(topicPostListIndex(completeWindow, 2)).assertEqual(5);
      expect(topicPostListIndex(completeWindow, 3)).assertEqual(6);
      expect(topicPostListIndex(pinpointWindow, 3)).assertEqual(5);
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

    it('changes the card render key when the direct Reply count changes', 0, () => {
      const original: ForumPost = new ForumPost(
        102, 1, 'admin', '', '原始正文', 2, null, '',
        new ForumPostMetadata()
      );
      const replied: ForumPost = new ForumPost(
        102, 1, 'admin', '', '原始正文', 2, null, '',
        new ForumPostMetadata(
          '', '', '', null, null, 0, [], null, false, false, false, false,
          false, false, null, 1, '', 2
        )
      );

      expect(topicPostRenderKey(original) !== topicPostRenderKey(replied)).assertTrue();
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

    it('presents every Discourse Topic notification level in a mobile-friendly order', 0, () => {
      const options: Array<TopicNotificationOption> = topicNotificationOptions();

      expect(options.map((option: TopicNotificationOption): number => option.level).join(','))
        .assertEqual('3,2,1,0');
      expect(options.map((option: TopicNotificationOption): string => option.label).join(','))
        .assertEqual('关注,跟踪,常规,免打扰');
      expect(topicNotificationLabel(TopicNotificationLevel.TRACKING)).assertEqual('跟踪');
      expect(options[0].description.includes('每条')).assertTrue();
      expect(options[3].description.includes('任何通知')).assertTrue();
    });
  });
}
