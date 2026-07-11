import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ReplyRequest, ReplySubmitKind, ReplySubmitResult } from '../../../main/ets/models/ReplyModels';
import { ForumHttpClient, HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../../../main/ets/repositories/DiscourseForumRepository';

class StubForumHttpClient implements ForumHttpClient {
  public results: Array<HttpTextResult> = [];
  public replyResults: Array<HttpTextResult> = [];
  public paths: Array<string> = [];
  public replyRequests: Array<ReplyRequest> = [];

  public async get(path: string): Promise<HttpTextResult> {
    this.paths.push(path);
    const result: HttpTextResult | undefined = this.results.shift();
    return result ?? HttpTextResult.failure(0, 'missing HTTP result');
  }

  public async postReply(request: ReplyRequest): Promise<HttpTextResult> {
    this.replyRequests.push(request);
    const result: HttpTextResult | undefined = this.replyResults.shift();
    return result ?? HttpTextResult.failure(0, 'missing Reply result');
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

    it('loads Topic detail with visit tracking enabled', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"id":2725,"title":"站务管理区重要主题导航","views":1959,"posts_count":1,"like_count":4,' +
        '"closed":false,"archived":false,"details":{"can_reply":true},' +
        '"post_stream":{"stream":[102728],"posts":[{' +
        '"id":102728,"user_id":24,"username":"Co-admin","cooked":"<h1>站务公告</h1>",' +
        '"raw":"站务公告","post_number":1,"reply_to_post_number":null,' +
        '"created_at":"2026-01-27T14:46:08.722Z"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<TopicDetail> = await repository.loadTopicDetail(2725);

      expect(client.paths[0]).assertEqual('/t/2725.json?track_visit=true');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.id).assertEqual(2725);
      done();
    });

    it('loads a Post window in the requested id order', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"post_stream":{"posts":[' +
        '{"id":102729,"user_id":1,"username":"admin","cooked":"<p>第一条 Reply</p>",' +
        '"raw":"第一条 Reply","post_number":2,"reply_to_post_number":null,"created_at":"2026-01-28T00:00:00Z"},' +
        '{"id":102730,"user_id":24,"username":"Co-admin","cooked":"<p>第二条 Reply</p>",' +
        '"raw":"第二条 Reply","post_number":3,"reply_to_post_number":2,"created_at":"2026-01-28T00:01:00Z"}' +
        ']}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<ForumPost>> =
        await repository.loadTopicPosts(2725, [102729, 102730]);

      expect(client.paths[0]).assertEqual(
        '/t/2725/posts.json?post_ids[]=102729&post_ids[]=102730&include_suggested=true'
      );
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.length).assertEqual(2);
      expect(result.data?.[1].postNumber).assertEqual(3);
      done();
    });

    it('returns the created Post from a nested Reply response', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.replyResults.push(HttpTextResult.success(200,
        '{"post":{"id":102731,"user_id":24,"username":"Co-admin","cooked":"<p>收到</p>",' +
        '"raw":"收到","post_number":4,"reply_to_post_number":3,"created_at":"2026-01-28T00:02:00Z"}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: ReplyRequest | null = ReplyRequest.create(2725, '收到', 3);
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: ReplySubmitResult = await repository.submitReply(request);

      expect(client.replyRequests.length).assertEqual(1);
      expect(client.replyRequests[0].raw).assertEqual('收到');
      expect(result.kind).assertEqual(ReplySubmitKind.CREATED);
      expect(result.post?.postNumber).assertEqual(4);
      done();
    });

    it('classifies unauthorized, rejected, and uncertain Reply outcomes', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.replyResults.push(HttpTextResult.unauthorized());
      client.replyResults.push(HttpTextResult.failure(422, '回复内容不符合要求'));
      client.replyResults.push(HttpTextResult.failure(0, '连接中断'));
      client.replyResults.push(HttpTextResult.success(200, '{"post":{"id":102731}}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: ReplyRequest | null = ReplyRequest.create(2725, '收到', null);
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const unauthorized: ReplySubmitResult = await repository.submitReply(request);
      const rejected: ReplySubmitResult = await repository.submitReply(request);
      const interrupted: ReplySubmitResult = await repository.submitReply(request);
      const malformed: ReplySubmitResult = await repository.submitReply(request);

      expect(unauthorized.kind).assertEqual(ReplySubmitKind.UNAUTHORIZED);
      expect(rejected.kind).assertEqual(ReplySubmitKind.REJECTED);
      expect(rejected.message).assertEqual('回复内容不符合要求');
      expect(interrupted.kind).assertEqual(ReplySubmitKind.UNCERTAIN);
      expect(malformed.kind).assertEqual(ReplySubmitKind.UNCERTAIN);
      done();
    });
  });
}
