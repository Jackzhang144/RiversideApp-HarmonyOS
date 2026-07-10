import { describe, expect, it } from '@ohos/hypium';
import { JsonObjectReader } from '../../../main/ets/core/JsonObjectReader';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { Category, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
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
  });
}
