import { describe, expect, it } from '@ohos/hypium';
import { JsonObjectReader } from '../../../main/ets/core/JsonObjectReader';
import {
  RepositoryFailureCode,
  RepositoryResult,
  RepositoryResultKind
} from '../../../main/ets/core/RepositoryResult';
import {
  Category,
  ForumPost,
  PostReactionUsers,
  Topic,
  TopicDetail
} from '../../../main/ets/models/ForumModels';
import { ForumListingResponseParser } from '../../../main/ets/repositories/ForumListingResponseParser';
import { TopicResponseParser } from '../../../main/ets/repositories/TopicResponseParser';

export default function jsonBoundaryTest(): void {
  describe('JSON boundary decoding', () => {
    it('reads typed object fields without DTO assertions', 0, () => {
      const reader: JsonObjectReader | null = JsonObjectReader.parse(
        '{"name":"站务管理","position":1,"ids":[60,61]}'
      );

      expect(reader === null).assertFalse();
      if (reader === null) {
        return;
      }
      expect(reader.string('name')).assertEqual('站务管理');
      expect(reader.number('position')).assertEqual(1);
      expect(reader.array('ids')?.length).assertEqual(2);
      expect(JsonObjectReader.parse('[1,2,3]')).assertNull();
    });

    it('rejects a non-object Topic entry', 0, () => {
      const parser: ForumListingResponseParser = new ForumListingResponseParser();
      const result: RepositoryResult<Array<Topic>> = parser.parseLatestTopics(
        '{"users":[],"topic_list":{"topics":[42]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.failureCode).assertEqual(RepositoryFailureCode.INVALID_RESPONSE);
      expect(result.data).assertNull();
    });

    it('removes duplicate Topic ids at the response boundary', 0, () => {
      const parser: ForumListingResponseParser = new ForumListingResponseParser();
      const result: RepositoryResult<Array<Topic>> = parser.parseLatestTopics(
        '{"users":[],"topic_list":{"topics":[' +
        '{"id":2725,"title":"站务管理区重要主题导航"},' +
        '{"id":2725,"title":"重复 Topic"}' +
        ']}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.length).assertEqual(1);
      expect(result.data?.[0].title).assertEqual('站务管理区重要主题导航');
    });

    it('uses the original poster as the Topic author when later repliers are present', 0, () => {
      const parser: ForumListingResponseParser = new ForumListingResponseParser();
      const result: RepositoryResult<Array<Topic>> = parser.parseLatestTopics(
        '{"users":[' +
        '{"id":24,"username":"topic-author"},' +
        '{"id":99,"username":"latest-replier"}' +
        '],"topic_list":{"topics":[{' +
        '"id":2725,"title":"作者映射回归",' +
        '"posters":[{"user_id":24},{"user_id":99}]' +
        '}]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].username).assertEqual('topic-author');
    });

    it('rejects a non-object Category entry', 0, () => {
      const parser: ForumListingResponseParser = new ForumListingResponseParser();
      const result: RepositoryResult<Array<Category>> = parser.parseCategories(
        '{"categories":[]}',
        '{"category_list":{"categories":["invalid"]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.failureCode).assertEqual(RepositoryFailureCode.INVALID_RESPONSE);
      expect(result.data).assertNull();
    });

    it('orders the real Category tree by root position and server child order', 0, () => {
      const parser: ForumListingResponseParser = new ForumListingResponseParser();
      const result: RepositoryResult<Array<Category>> = parser.parseCategories(
        '{"categories":[{' +
        '"id":60,"name":"站务管理","position":2,"subcategory_ids":[62,61]' +
        '}]}',
        '{"category_list":{"categories":[' +
        '{"id":61,"name":"游客公告","position":1,"parent_category_id":60},' +
        '{"id":50,"name":"社区讨论","position":1},' +
        '{"id":62,"name":"测试专用","position":2,"parent_category_id":60}' +
        ']}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.map((category: Category): number => category.id).join(','))
        .assertEqual('50,60,62,61');
      expect(result.data?.[2].parentCategoryId).assertEqual(60);
    });

    it('decodes Topic detail and applies closed Reply restrictions', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<TopicDetail> = parser.parseTopicDetail(
        '{"id":2725,"title":"站务管理区重要主题导航","views":1959,"posts_count":1,' +
        '"highest_post_number":7,"like_count":4,' +
        '"closed":true,"archived":false,"details":{"can_reply":true},' +
        '"post_stream":{"stream":[102728],"posts":[{' +
        '"id":102728,"user_id":24,"username":"Co-admin","cooked":"<h1>站务公告</h1>",' +
        '"raw":"站务公告","post_number":1,"reply_to_post_number":null,' +
        '"created_at":"2026-01-27T14:46:08.722Z"}]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data === null).assertFalse();
      if (result.data === null) {
        return;
      }
      expect(result.data.id).assertEqual(2725);
      expect(result.data.postIds.length).assertEqual(1);
      expect(result.data.posts[0].id).assertEqual(102728);
      expect(result.data.highestPostNumber).assertEqual(7);
      expect(result.data.canReply).assertFalse();
    });

    it('decodes Reply counts and direct Reply arrays', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const topicResult: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[{' +
        '"id":102728,"user_id":24,"username":"Co-admin","raw":"父 Post",' +
        '"post_number":1,"reply_count":2,"created_at":"2026-01-27T14:46:08.722Z"' +
        '}]}}'
      );
      const replyResult: RepositoryResult<Array<ForumPost>> = parser.parsePostReplies(
        '[{"id":102729,"user_id":1,"username":"admin","raw":"第一条直接 Reply",' +
        '"post_number":2,"reply_to_post_number":1,"created_at":"2026-01-28T00:00:00Z"},' +
        '{"id":102730,"user_id":24,"username":"Co-admin","raw":"第二条直接 Reply",' +
        '"post_number":5,"reply_to_post_number":1,"created_at":"2026-01-28T00:01:00Z"}]'
      );

      expect(topicResult.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(topicResult.data?.[0].replyCount).assertEqual(2);
      expect(replyResult.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(replyResult.data?.map((post: ForumPost): number => post.postNumber).join(',')).assertEqual('2,5');
    });

    it('keeps active Post user status and preserves it across local Post updates', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[' +
        '{"id":102728,"user_id":24,"username":"Co-admin","raw":"父 Post",' +
        '"post_number":1,"created_at":"2026-01-27T14:46:08.722Z",' +
        '"user_status":{"description":"正在图书馆","emoji":"books",' +
        '"ends_at":"2099-08-01T08:00:00Z"}},' +
        '{"id":102729,"user_id":25,"username":"expired","raw":"过期状态",' +
        '"post_number":2,"created_at":"2026-01-27T14:47:08.722Z",' +
        '"user_status":{"description":"已离开","emoji":"wave",' +
        '"ends_at":"2000-01-01T00:00:00Z"}}' +
        ']}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].userStatus?.description).assertEqual('正在图书馆');
      expect(result.data?.[0].userStatus?.emoji).assertEqual('books');
      expect(result.data?.[0].withBookmark(true, 88).userStatus?.description)
        .assertEqual('正在图书馆');
      expect(result.data?.[1].userStatus).assertNull();
    });

    it('rejects malformed direct Reply arrays', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();

      const result: RepositoryResult<Array<ForumPost>> = parser.parsePostReplies(
        '[{"id":102729,"username":"admin","raw":"缺少楼层"}]'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.data).assertNull();
    });

    it('decodes a Post window and removes duplicate Post ids', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[' +
        '{"id":102729,"user_id":1,"username":"admin","cooked":"<p>第一条 Reply</p>",' +
        '"raw":"第一条 Reply","post_number":2,"reply_to_post_number":null,"created_at":"2026-01-28T00:00:00Z"},' +
        '{"id":102729,"user_id":1,"username":"admin","cooked":"<p>重复</p>",' +
        '"raw":"重复","post_number":2,"reply_to_post_number":null,"created_at":"2026-01-28T00:00:00Z"}' +
        ']}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.length).assertEqual(1);
      expect(result.data?.[0].postNumber).assertEqual(2);
    });

    it('keeps Reply creation aliases out of ordinary Post windows', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[{' +
        '"post_id":102729,"user_id":1,"username":"admin","raw":"Reply",' +
        '"target_post_number":2,"reply_to_post_number":null' +
        '}]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.data).assertNull();
    });

    it('provides readable Post text when the response only contains cooked HTML', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[{' +
        '"id":102729,"user_id":1,"username":"admin",' +
        '"cooked":"<h1>站务公告</h1><p>第一段<br>第二行 &amp; 更多</p>",' +
        '"raw":"# 原始 Markdown",' +
        '"post_number":2,"reply_to_post_number":null,"created_at":"2026-01-28T00:00:00Z"' +
        '}]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].displayText).assertEqual('站务公告\n第一段\n第二行 & 更多');
    });

    it('keeps Reaction users with canonical usernames and normalized avatars', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();

      const result: RepositoryResult<Array<PostReactionUsers>> = parser.parsePostReactionUsers(
        '{"reaction_users":[' +
        '{"id":"heart","count":2,"users":[' +
        '{"username":"river_user","name":"河畔昵称",' +
        '"avatar_template":"/user_avatar/river-side.cc/river_user/{size}/1.png"},' +
        '{"name":"不能作为用户名"}]},' +
        '{"id":"+1","count":1,"users":[]}]}'
      );

      expect(result.isSuccess()).assertTrue();
      expect(result.data?.length).assertEqual(1);
      expect(result.data?.[0].id).assertEqual('heart');
      expect(result.data?.[0].count).assertEqual(2);
      expect(result.data?.[0].users.length).assertEqual(1);
      expect(result.data?.[0].users[0].username).assertEqual('river_user');
      expect(result.data?.[0].users[0].avatarUrl).assertEqual(
        'https://river-side.cc/user_avatar/river-side.cc/river_user/64/1.png'
      );
    });
  });
}
