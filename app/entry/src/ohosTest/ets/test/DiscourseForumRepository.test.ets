import { describe, expect, it } from '@ohos/hypium';
import { ComposerMentionUser } from '../../../main/ets/models/ComposerMentionModels';
import {
  RepositoryFailureCode,
  RepositoryResult,
  RepositoryResultKind
} from '../../../main/ets/core/RepositoryResult';
import {
  ForumPost,
  PostFlagRequest,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicPostBatch
} from '../../../main/ets/models/ForumModels';
import { ForumSearchResult, HomeChannel, OnlineUsers } from '../../../main/ets/models/DiscoveryModels';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitKind,
  TopicSubmitResult
} from '../../../main/ets/models/AuthoringModels';
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

export class StubForumHttpClient implements ForumHttpClient {
  public results: Array<HttpTextResult> = [];
  public replyResults: Array<HttpTextResult> = [];
  public paths: Array<string> = [];
  public replyRequests: Array<ReplyRequest> = [];
  public putResults: Array<HttpTextResult> = [];
  public formResults: Array<HttpTextResult> = [];
  public deleteResults: Array<HttpTextResult> = [];
  public putPaths: Array<string> = [];
  public formRequests: Array<string> = [];
  public deletePaths: Array<string> = [];
  public jsonPostResults: Array<HttpTextResult> = [];
  public jsonPostRequests: Array<string> = [];
  public formPutResults: Array<HttpTextResult> = [];
  public formPutRequests: Array<string> = [];
  public formDeleteResults: Array<HttpTextResult> = [];
  public formDeleteRequests: Array<string> = [];

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

  public async put(path: string): Promise<HttpTextResult> {
    this.putPaths.push(path);
    return this.putResults.shift() ?? HttpTextResult.failure(0, 'missing PUT result');
  }

  public async postForm(path: string, body: string): Promise<HttpTextResult> {
    this.formRequests.push(`${path}|${body}`);
    return this.formResults.shift() ?? HttpTextResult.failure(0, 'missing form result');
  }

  public async delete(path: string): Promise<HttpTextResult> {
    this.deletePaths.push(path);
    return this.deleteResults.shift() ?? HttpTextResult.failure(0, 'missing DELETE result');
  }

  public async postJson(path: string, body: string): Promise<HttpTextResult> {
    this.jsonPostRequests.push(`${path}|${body}`);
    return this.jsonPostResults.shift() ?? HttpTextResult.failure(0, 'missing JSON POST result');
  }

  public async putForm(path: string, body: string): Promise<HttpTextResult> {
    this.formPutRequests.push(`${path}|${body}`);
    return this.formPutResults.shift() ?? HttpTextResult.failure(0, 'missing form PUT result');
  }

  public async deleteForm(path: string, body: string): Promise<HttpTextResult> {
    this.formDeleteRequests.push(`${path}|${body}`);
    return this.formDeleteResults.shift() ?? HttpTextResult.failure(0, 'missing form DELETE result');
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

    it('loads and parses the Flutter-compatible online user contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"whos_online_state":{"count":3,"last_message_id":91,"users":[' +
        '{"id":7,"username":"river","name":"河畔","avatar_template":"/user_avatar/river-side.cc/river/{size}/1.png"},' +
        '{"id":8,"username":"bank","name":"","avatar_template":""}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<OnlineUsers> = await repository.loadOnlineUsers();

      expect(client.paths[0]).assertEqual('/site.json');
      expect(result.isSuccess()).assertTrue();
      expect(result.data?.count).assertEqual(3);
      expect(result.data?.lastMessageId).assertEqual(91);
      expect(result.data?.users.length).assertEqual(2);
      expect(result.data?.users[0].displayName).assertEqual('河畔');
      expect(result.data?.users[0].avatarUrl).assertEqual(
        'https://river-side.cc/user_avatar/river-side.cc/river/96/1.png'
      );
      expect(result.data?.users[1].displayName).assertEqual('bank');
      done();
    });

    it('loads a Category Topic list through its canonical path', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"users":[{"id":24,"username":"Co-admin",' +
        '"avatar_template":"/user_avatar/river-side.cc/co-admin/{size}/1.png"}],' +
        '"topic_list":{"topics":[{' +
        '"id":2725,"title":"站务管理区重要主题导航","category_id":60,"posts_count":1,' +
        '"views":1959,"like_count":4,"pinned":true,"posters":[{"user_id":24}]}]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<Topic>> = await repository.loadCategoryTopics(60, 2);

      expect(client.paths[0]).assertEqual('/c/60.json?page=2');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].id).assertEqual(2725);
      expect(result.data?.[0].avatarUrl).assertEqual(
        'https://river-side.cc/user_avatar/river-side.cc/co-admin/64/1.png'
      );
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

    it('accepts nullable Topic results and string tags returned by Discourse', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"posts":[],"topics":null,"users":[{"id":38290,"username":"river"}],' +
        '"categories":[],"tags":["2-tag"],"groups":[],' +
        '"grouped_search_result":{"more_full_page_results":false,"more_tags":true}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<ForumSearchResult> = await repository.searchForum('river', 1);

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.topics.length).assertEqual(0);
      expect(result.data?.users[0].username).assertEqual('river');
      expect(result.data?.tags[0].name).assertEqual('2-tag');
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
      expect(blank.failureCode).assertEqual(RepositoryFailureCode.INVALID_INPUT);
      done();
    });

    it('loads at most six composer mention users through the Discourse user search endpoint', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"users":[{"username":"river","name":"River User",' +
          '"avatar_template":"/user_avatar/river/{size}/1.png"}]}'
        ));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const result: RepositoryResult<Array<ComposerMentionUser>> = await repository.searchMentionUsers(' river ');

        expect(client.paths[0]).assertEqual('/u/search/users.json?term=river&limit=6');
        expect(result.data?.length).assertEqual(1);
        expect(result.data?.[0].username).assertEqual('river');
        expect(result.data?.[0].name).assertEqual('River User');
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

    it('preserves Topic permissions, system actions, reactions, bookmarks and suggestions', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"id":2725,"title":"完整阅读","category_id":111,"views":20,"posts_count":2,"like_count":3,' +
          '"closed":false,"archived":false,"can_edit":true,"last_read_post_number":1,' +
          '"highest_post_number":2,"valid_reactions":["heart","+1"],' +
          '"details":{"can_create_post":false,"created_by":{"username":"admin"}},' +
          '"suggested_topics":[{"id":2800,"title":"推荐 Topic","category_id":111,"posts_count":4}],' +
          '"post_stream":{"stream":[102728,102729],"posts":[' +
          '{"id":102728,"user_id":24,"username":"Co-admin","user_title":"管理员",' +
          '"avatar_template":"/user_avatar/river-side.cc/co-admin/{size}/1_2.png",' +
          '"cooked":"<p>正文</p>","raw":"正文","post_number":1,"created_at":"2026-01-27T14:46:08Z",' +
          '"reactions":[{"id":"heart","count":2}],"current_user_reaction":{"id":"heart"},' +
          '"can_edit":true,"can_delete":true,"bookmarked":true,"bookmark_id":901},' +
          '{"id":102729,"user_id":-1,"username":"system","cooked":"","raw":"",' +
          '"post_number":2,"post_type":3,"action_code":"closed.enabled","created_at":"2026-01-27T14:47:08Z"}' +
          ']}}'
        ));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const result: RepositoryResult<TopicDetail> = await repository.loadTopicDetail(2725);

        expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
        expect(result.data?.categoryId).assertEqual(111);
        expect(result.data?.canEdit).assertTrue();
        expect(result.data?.canReply).assertFalse();
        expect(result.data?.authorUsername).assertEqual('admin');
        expect(result.data?.validReactions.join(',')).assertEqual('heart,+1');
        expect(result.data?.lastReadPostNumber).assertEqual(1);
        expect(result.data?.suggestedTopics[0].id).assertEqual(2800);
        expect(result.data?.posts[0].likeCount).assertEqual(2);
        expect(result.data?.posts[0].currentUserReaction).assertEqual('heart');
        expect(result.data?.posts[0].bookmarked).assertTrue();
        expect(result.data?.posts[0].bookmarkId).assertEqual(901);
        expect(result.data?.posts[0].canEdit).assertTrue();
        expect(result.data?.posts[0].canDelete).assertTrue();
        expect(result.data?.posts[0].avatarUrl).assertEqual(
          'https://river-side.cc/user_avatar/river-side.cc/co-admin/64/1_2.png'
        );
        expect(result.data?.posts[1].isSystemAction()).assertTrue();
        done();
      });

    it('loads Topic detail around a searched Post number', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"id":2725,"title":"站务管理区重要主题导航","post_stream":{"stream":[],"posts":[]}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      await repository.loadTopicDetail(2725, 12);

      expect(client.paths[0]).assertEqual('/t/2725/12.json?track_visit=true');
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
        ']},"suggested_topics":[{"id":2800,"title":"推荐 Topic","category_id":111,"posts_count":4}]}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<TopicPostBatch> =
        await repository.loadTopicPosts(2725, [102729, 102730]);

      expect(client.paths[0]).assertEqual(
        '/t/2725/posts.json?post_ids[]=102729&post_ids[]=102730&include_suggested=true'
      );
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.posts.length).assertEqual(2);
      expect(result.data?.posts[1].postNumber).assertEqual(3);
      expect(result.data?.suggestedTopics[0].id).assertEqual(2800);
      done();
    });

    it('loads suggested Topics from the untracked full Topic fallback', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"suggested_topics":[{"id":2800,"title":"推荐 Topic","category_id":111,"posts_count":4}]}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<Topic>> = await repository.loadTopicSuggestions(2725);

      expect(client.paths[0]).assertEqual('/t/2725.json');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].id).assertEqual(2800);
      done();
    });

  });
}
