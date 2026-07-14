import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../../../main/ets/models/DiscoveryModels';
import {
  CurrentUser,
  ReplyRecoveryKind,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitKind,
  ReplySubmitResult
} from '../../../main/ets/models/ReplyModels';
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
    it('loads every Home channel and page through the frozen Flutter paths', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      for (let index: number = 0; index < 5; index += 1) {
        client.results.push(HttpTextResult.success(200, '{"topic_list":{"topics":[]}}'));
      }
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      await repository.loadHomeTopics(HomeChannel.LATEST_REPLIES, 0);
      await repository.loadHomeTopics(HomeChannel.LATEST_CREATED, 2);
      await repository.loadHomeTopics(HomeChannel.UNREAD, 1);
      await repository.loadHomeTopics(HomeChannel.HOT, 3);
      await repository.loadHomeTopics(HomeChannel.FEATURED, 4);

      expect(client.paths[0]).assertEqual('/latest.json');
      expect(client.paths[1]).assertEqual('/latest.json?order=created&page=2');
      expect(client.paths[2]).assertEqual('/new.json?page=1');
      expect(client.paths[3]).assertEqual('/hot.json?page=3');
      expect(client.paths[4]).assertEqual('/tag/2-tag/2.json?page=4');
      done();
    });

    it('loads a Category Topic list through its canonical path', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"users":[{"id":24,"username":"Co-admin"}],"topic_list":{"topics":[{' +
        '"id":2725,"title":"站务管理区重要主题导航","category_id":60,"posts_count":1,' +
        '"views":1959,"like_count":4,"pinned":true,"posters":[{"user_id":24}]}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<Topic>> = await repository.loadCategoryTopics(60, 2);

      expect(client.paths[0]).assertEqual('/c/60.json?page=2');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].id).assertEqual(2725);
      done();
    });

    it('parses Topic, Post, user, Category, tag and group search results with pagination', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"posts":[{"id":103066,"username":"admin","blurb":"<b>河畔</b> 回复",' +
          '"post_number":2,"topic_id":2764,"created_at":"2026-01-28T02:24:17.848Z"}],' +
          '"topics":[{"id":2764,"title":"河畔公告","category_id":54,"posts_count":3}],' +
          '"users":[{"id":38290,"username":"河畔流浪者","name":"河畔流浪者"}],' +
          '"categories":[{"id":111,"name":"测试专用","color":"25AAE2","position":2}],' +
          '"tags":[{"id":"2-tag","name":"2-tag","topic_count":8}],' +
          '"groups":[{"id":50,"name":"rs_developer","full_name":"河畔开发者","user_count":8}],' +
          '"grouped_search_result":{"more_full_page_results":false,"more_users":true}}'
        ));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const result: RepositoryResult<ForumSearchResult> = await repository.searchForum(' 河畔 ', 2);

        expect(client.paths[0]).assertEqual('/search.json?q=%E6%B2%B3%E7%95%94&page=2');
        expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
        expect(result.data?.topics[0].id).assertEqual(2764);
        expect(result.data?.posts[0].displayText).assertEqual('河畔 回复');
        expect(result.data?.users[0].username).assertEqual('河畔流浪者');
        expect(result.data?.categories[0].id).assertEqual(111);
        expect(result.data?.tags[0].name).assertEqual('2-tag');
        expect(result.data?.groups[0].fullName).assertEqual('河畔开发者');
        expect(result.data?.hasMore).assertTrue();
        done();
      });

    it('loads topic search suggestions and rejects blank search without transport', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"topics":[{"title":"河畔公告"},{"title":"测试专用说明"}]}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const suggestions: RepositoryResult<Array<string>> = await repository.searchSuggestions('河畔');
      const blank: RepositoryResult<ForumSearchResult> = await repository.searchForum('  ', 1);

      expect(client.paths[0]).assertEqual('/search/query?term=%E6%B2%B3%E7%95%94&typeahead=true');
      expect(client.paths.length).assertEqual(1);
      expect(suggestions.data?.length).assertEqual(2);
      expect(blank.kind).assertEqual(RepositoryResultKind.FAILURE);
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

    it('accepts the direct Reply response fallback field names', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.replyResults.push(HttpTextResult.success(200,
        '{"post_id":102732,"user_id":24,"username":"Co-admin","cooked":"<p>继续</p>",' +
        '"raw":"继续","target_post_number":5,"reply_to_post_number":null,' +
        '"created_at":"2026-01-28T00:03:00Z"}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: ReplyRequest | null = ReplyRequest.create(2725, '继续', null);
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: ReplySubmitResult = await repository.submitReply(request);

      expect(result.kind).assertEqual(ReplySubmitKind.CREATED);
      expect(result.post?.id).assertEqual(102732);
      expect(result.post?.postNumber).assertEqual(5);
      done();
    });

    it('classifies unauthorized, rejected, and uncertain Reply outcomes', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.replyResults.push(HttpTextResult.unauthorized());
      client.replyResults.push(HttpTextResult.failure(422, '回复内容不符合要求'));
      client.replyResults.push(HttpTextResult.failure(500, '服务器返回 500'));
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
      const serverFailure: ReplySubmitResult = await repository.submitReply(request);
      const interrupted: ReplySubmitResult = await repository.submitReply(request);
      const malformed: ReplySubmitResult = await repository.submitReply(request);

      expect(unauthorized.kind).assertEqual(ReplySubmitKind.UNAUTHORIZED);
      expect(rejected.kind).assertEqual(ReplySubmitKind.REJECTED);
      expect(rejected.message).assertEqual('回复内容不符合要求');
      expect(serverFailure.kind).assertEqual(ReplySubmitKind.UNCERTAIN);
      expect(interrupted.kind).assertEqual(ReplySubmitKind.UNCERTAIN);
      expect(malformed.kind).assertEqual(ReplySubmitKind.UNCERTAIN);
      done();
    });

    it('loads the current authenticated identity required for safe recovery', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"current_user":{"id":24,"username":"Co-admin","name":"协管员",' +
        '"title":"社区维护","admin":false,"moderator":true,"trust_level":3,' +
        '"can_create_post":true,"can_create_topic":true,"can_chat":false,' +
        '"user_option":{"chat_enabled":true},"can_send_private_messages":true,' +
        '"unread_notifications":4,"primary_group_id":45,"flair_group_id":50,' +
        '"groups":[{"id":45,"name":"scuer"},{"id":50,"name":"rs_developer"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<CurrentUser> = await repository.loadCurrentUser();

      expect(client.paths[0]).assertEqual('/session/current.json');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.id).assertEqual(24);
      expect(result.data?.username).assertEqual('Co-admin');
      expect(result.data?.displayName).assertEqual('协管员');
      expect(result.data?.roleLabel).assertEqual('版主');
      expect(result.data?.isVerified).assertTrue();
      expect(result.data?.canReply).assertTrue();
      expect(result.data?.canStartDirectChat).assertTrue();
      expect(result.data?.unreadNotifications).assertEqual(4);
      done();
    });

    it('honors explicit denial, account restrictions, and verification group ids', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"current_user":{"id":25,"username":"restricted","admin":false,"moderator":false,' +
        '"can_create_post":false,"can_create_topic":true,"silenced":true,' +
        '"can_chat":false,"can_send_private_message_to_user":true,' +
        '"groups":[{"id":46,"name":"localized-school-name"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<CurrentUser> = await repository.loadCurrentUser();

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.canReply).assertFalse();
      expect(result.data?.canStartDirectChat).assertTrue();
      expect(result.data?.isVerified).assertTrue();
      done();
    });

    it('confirms an interrupted Reply with an identity and content matched GET', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"id":2725,"title":"站务管理区重要主题导航","posts_count":4,' +
        '"post_stream":{"stream":[102731],"posts":[{' +
        '"id":102731,"user_id":24,"username":"Co-admin","cooked":"<p>收到</p>",' +
        '"raw":"收到","post_number":4,"reply_to_post_number":3,"created_at":"2026-01-28T00:02:00Z"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const reply: ReplyRequest | null = ReplyRequest.create(2725, '收到', 3);
      const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
      const recovery: ReplyRecoveryRequest | null = reply === null || user === null
        ? null
        : ReplyRecoveryRequest.create(reply, 4, user);
      if (recovery === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: ReplyRecoveryResult = await repository.recoverReply(recovery);

      expect(client.paths[0]).assertEqual('/t/2725/4.json?track_visit=true');
      expect(client.replyRequests.length).assertEqual(0);
      expect(result.kind).assertEqual(ReplyRecoveryKind.CONFIRMED);
      expect(result.post?.id).assertEqual(102731);
      done();
    });

    it('does not confirm a recovery candidate from another author or body', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"id":2725,"title":"站务管理区重要主题导航","posts_count":4,' +
        '"post_stream":{"stream":[102731],"posts":[{' +
        '"id":102731,"user_id":99,"username":"other","cooked":"<p>收到</p>",' +
        '"raw":"不同正文","post_number":4,"reply_to_post_number":3,"created_at":"2026-01-28T00:02:00Z"}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const reply: ReplyRequest | null = ReplyRequest.create(2725, '收到', 3);
      const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
      const recovery: ReplyRecoveryRequest | null = reply === null || user === null
        ? null
        : ReplyRecoveryRequest.create(reply, 4, user);
      if (recovery === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: ReplyRecoveryResult = await repository.recoverReply(recovery);

      expect(result.kind).assertEqual(ReplyRecoveryKind.NOT_FOUND);
      expect(client.replyRequests.length).assertEqual(0);
      done();
    });
  });
}
