import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { Topic } from '../../../main/ets/models/ForumModels';
import { ForumHttpClient, HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';

class StubForumHttpClient implements ForumHttpClient {
  public results: Array<HttpTextResult> = [];
  public paths: Array<string> = [];

  public async get(path: string): Promise<HttpTextResult> {
    this.paths.push(path);
    const result: HttpTextResult | undefined = this.results.shift();
    return result ?? HttpTextResult.failure(0, 'missing HTTP result');
  }
}

export default function discourseForumRepositoryTest(): void {
  describe('Discourse ForumRepository contract', () => {
    it('loads a Category Topic list through its canonical path', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"users":[{"id":24,"username":"Co-admin"}],"topic_list":{"topics":[{' +
        '"id":2725,"title":"站务管理区重要主题导航","category_id":60,"posts_count":1,' +
        '"views":1959,"like_count":4,"pinned":true,"posters":[{"user_id":24}]}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<Topic>> = await repository.loadCategoryTopics(60);

      expect(client.paths[0]).assertEqual('/c/60.json');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].id).assertEqual(2725);
      done();
    });
  });
}
