import { describe, expect, it } from '@ohos/hypium';
import { JsonObjectReader } from '../../../main/ets/core/JsonObjectReader';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { Category, Topic } from '../../../main/ets/models/ForumModels';
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
  });
}
