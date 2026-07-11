import { describe, expect, it } from '@ohos/hypium';
import { JsonObjectReader } from '../../../main/ets/core/JsonObjectReader';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ForumResponseParser } from '../../../main/ets/repositories/ForumResponseParser';

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
      const parser: ForumResponseParser = new ForumResponseParser();
      const result: RepositoryResult<Array<Topic>> = parser.parseLatestTopics(
        '{"users":[],"topic_list":{"topics":[42]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.data).assertNull();
    });

    it('removes duplicate Topic ids at the response boundary', 0, () => {
      const parser: ForumResponseParser = new ForumResponseParser();
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

    it('rejects a non-object Category entry', 0, () => {
      const parser: ForumResponseParser = new ForumResponseParser();
      const result: RepositoryResult<Array<Category>> = parser.parseCategories(
        '{"categories":[]}',
        '{"category_list":{"categories":["invalid"]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(result.data).assertNull();
    });

    it('decodes Topic detail and applies closed Reply restrictions', 0, () => {
      const parser: ForumResponseParser = new ForumResponseParser();
      const result: RepositoryResult<TopicDetail> = parser.parseTopicDetail(
        '{"id":2725,"title":"站务管理区重要主题导航","views":1959,"posts_count":1,"like_count":4,' +
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
      expect(result.data.canReply).assertFalse();
    });

    it('decodes a Post window and removes duplicate Post ids', 0, () => {
      const parser: ForumResponseParser = new ForumResponseParser();
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
      const parser: ForumResponseParser = new ForumResponseParser();
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
      const parser: ForumResponseParser = new ForumResponseParser();
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
  });
}
