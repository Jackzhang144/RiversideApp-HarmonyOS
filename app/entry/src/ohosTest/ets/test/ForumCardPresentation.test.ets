import { describe, expect, it } from '@ohos/hypium';
import {
  ForumCardMode,
  ForumCardPresentation,
  ForumCardStatisticKind
} from '../../../main/ets/components/ForumCardPresentation';
import { Category, ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';

export default function forumCardPresentationTest(): void {
  describe('Forum card presentation contract', () => {
    it('maps a Topic preview with truncation, Category, pinned state, statistics, and accessibility', 0, () => {
      const topic: Topic = new Topic(
        2725,
        '图书馆座位预约系统使用体验优化建议',
        10,
        24,
        1200,
        8,
        '完整摘要内容',
        '2026-07-11T14:32:00Z',
        true,
        '李同学'
      );
      const categories: Array<Category> = [
        new Category(10, '校内事务', '00AA88', '', 1, null, [])
      ];

      const presentation: ForumCardPresentation = ForumCardPresentation.topicPreview(topic, categories);

      expect(presentation.mode).assertEqual(ForumCardMode.TOPIC_PREVIEW);
      expect(presentation.author?.name).assertEqual('李同学');
      expect(presentation.author?.username).assertEqual('李同学');
      expect(presentation.author?.initial).assertEqual('李');
      expect(presentation.author?.timestamp).assertEqual('2026-07-11 14:32');
      expect(presentation.title).assertEqual('图书馆座位预约系统使用体验优化建议');
      expect(presentation.body).assertEqual('完整摘要内容');
      expect(presentation.headerBadge?.label).assertEqual('置顶');
      expect(presentation.footerBadge?.label).assertEqual('校内事务');
      expect(presentation.statistics.length).assertEqual(2);
      expect(presentation.statistics[0].kind).assertEqual(ForumCardStatisticKind.REPLIES);
      expect(presentation.statistics[0].value).assertEqual(23);
      expect(presentation.statistics[1].kind).assertEqual(ForumCardStatisticKind.VIEWS);
      expect(presentation.statistics[1].value).assertEqual(1200);
      expect(presentation.replyAction).assertNull();
      expect(presentation.accessibilityText).assertEqual(
        '图书馆座位预约系统使用体验优化建议，作者 李同学，校内事务，置顶，23 条 Reply，1200 浏览'
      );
    });

    it('maps a Topic starter with full text, Topic statistics, and a lightweight Topic Reply target', 0, () => {
      const starter: ForumPost = new ForumPost(
        100,
        7,
        '李同学',
        '<p>完整主楼正文</p>',
        '完整主楼正文',
        1,
        null,
        '2026-07-11T14:32:00Z'
      );
      const detail: TopicDetail = new TopicDetail(
        2725,
        '图书馆座位预约系统使用体验优化建议',
        1200,
        24,
        8,
        false,
        false,
        true,
        [100],
        [starter]
      );

      const presentation: ForumCardPresentation = ForumCardPresentation.topicStarter(
        detail,
        starter,
        '未提交草稿'
      );

      expect(presentation.mode).assertEqual(ForumCardMode.TOPIC_STARTER);
      expect(presentation.title).assertEqual('图书馆座位预约系统使用体验优化建议');
      expect(presentation.body).assertEqual('完整主楼正文');
      expect(presentation.headerBadge?.label).assertEqual('#1');
      expect(presentation.footerBadge).assertNull();
      expect(presentation.statistics.length).assertEqual(3);
      expect(presentation.statistics[0].kind).assertEqual(ForumCardStatisticKind.REPLIES);
      expect(presentation.statistics[0].value).assertEqual(23);
      expect(presentation.statistics[1].kind).assertEqual(ForumCardStatisticKind.VIEWS);
      expect(presentation.statistics[2].kind).assertEqual(ForumCardStatisticKind.LIKES);
      expect(presentation.replyAction?.label).assertEqual('继续 Reply');
      expect(presentation.replyAction?.targetPostNumber).assertNull();
      expect(presentation.replyAction?.accessibilityText).assertEqual('回复当前 Topic');
      expect(presentation.restrictionText).assertEqual('');
      expect(presentation.accessibilityText).assertEqual(
        '图书馆座位预约系统使用体验优化建议，李同学 的第 1 条 Post，23 条 Reply，1200 浏览，8 赞'
      );
    });

    it('removes the Topic starter Reply action and announces the restriction when Reply is unavailable', 0, () => {
      const starter: ForumPost = new ForumPost(
        100, 7, '李同学', '<p>完整主楼正文</p>', '完整主楼正文', 1, null, '2026-07-11T14:32:00Z'
      );
      const archived: TopicDetail = new TopicDetail(
        2725, '已归档 Topic', 10, 1, 0, false, true, true, [100], [starter]
      );

      const presentation: ForumCardPresentation = ForumCardPresentation.topicStarter(archived, starter, '');

      expect(presentation.replyAction).assertNull();
      expect(presentation.restrictionText).assertEqual('此 Topic 已归档，不可 Reply');
      expect(presentation.accessibilityText).assertEqual(
        '已归档 Topic，李同学 的第 1 条 Post，0 条 Reply，10 浏览，0 赞，此 Topic 已归档，不可 Reply'
      );
    });

    it('maps a Reply with full text, floor metadata, and its own Post Reply target', 0, () => {
      const post: ForumPost = new ForumPost(
        102,
        9,
        '图书馆小助手',
        '<p>感谢同学提出的宝贵建议！</p>',
        '感谢同学提出的宝贵建议！',
        3,
        2,
        '2026-07-11T15:02:00Z'
      );

      const presentation: ForumCardPresentation = ForumCardPresentation.reply(post, true);

      expect(presentation.mode).assertEqual(ForumCardMode.REPLY);
      expect(presentation.author?.name).assertEqual('图书馆小助手');
      expect(presentation.author?.username).assertEqual('图书馆小助手');
      expect(presentation.author?.timestamp).assertEqual('2026-07-11 15:02');
      expect(presentation.title).assertEqual('');
      expect(presentation.body).assertEqual('感谢同学提出的宝贵建议！');
      expect(presentation.headerBadge?.label).assertEqual('#3');
      expect(presentation.statistics.length).assertEqual(0);
      expect(presentation.replyAction?.label).assertEqual('Reply');
      expect(presentation.replyAction?.targetPostNumber).assertEqual(3);
      expect(presentation.replyAction?.accessibilityText).assertEqual('回复第 3 条 Post');
      expect(presentation.accessibilityText).assertEqual('图书馆小助手 的第 3 条 Post，回复第 2 条 Post');
    });
  });
}
