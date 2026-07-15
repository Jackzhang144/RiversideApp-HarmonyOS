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

    it('toggles a Reaction and returns only the server-updated Post', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.putResults.push(HttpTextResult.success(200,
        '{"id":102728,"user_id":24,"username":"Co-admin","cooked":"<p>正文</p>",' +
        '"raw":"正文","post_number":1,"reactions":[{"id":"heart","count":2}],' +
        '"current_user_reaction":{"id":"heart"},"created_at":"2026-01-27T14:46:08Z"}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<ForumPost> = await repository.togglePostReaction(102728, 'heart');

      expect(client.putPaths[0]).assertEqual(
        '/discourse-reactions/posts/102728/custom-reactions/heart/toggle.json'
      );
      expect(result.data?.currentUserReaction).assertEqual('heart');
      expect(result.data?.likeCount).assertEqual(2);
      done();
    });

    it('loads Reaction participants without changing the Reaction write contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"reaction_users":[{"id":"heart","count":2,"users":[' +
        '{"username":"river_user","avatar_template":"/letter_avatar_proxy/v4/letter/r/{size}.png"}]}]}'
      ));
      client.results.push(HttpTextResult.unauthorized());
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<Array<PostReactionUsers>> = await repository.loadPostReactionUsers(102728);
      const invalid: RepositoryResult<Array<PostReactionUsers>> = await repository.loadPostReactionUsers(0);
      const unauthorized: RepositoryResult<Array<PostReactionUsers>> = await repository.loadPostReactionUsers(102729);

      expect(client.paths[0]).assertEqual('/discourse-reactions/posts/102728/reactions-users.json');
      expect(client.paths[1]).assertEqual('/discourse-reactions/posts/102729/reactions-users.json');
      expect(result.data?.[0].users[0].username).assertEqual('river_user');
      expect(invalid.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(unauthorized.kind).assertEqual(RepositoryResultKind.UNAUTHORIZED);
      done();
    });

    it('creates and deletes a Post bookmark through the frozen Discourse contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.formResults.push(HttpTextResult.success(200, '{"id":901}'));
      client.deleteResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const created: RepositoryResult<number> = await repository.createPostBookmark(102728);
      const deleted: RepositoryResult<boolean> = await repository.deletePostBookmark(901);

      expect(client.formRequests[0]).assertEqual(
        '/bookmarks.json|reminder_at=&auto_delete_preference=3&bookmarkable_id=102728&bookmarkable_type=Post'
      );
      expect(created.data).assertEqual(901);
      expect(client.deletePaths[0]).assertEqual('/bookmarks/901.json');
      expect(deleted.data).assertTrue();
      done();
    });

    it('deletes a Post through the Flutter-compatible Discourse contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.deleteResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const deleted: RepositoryResult<boolean> = await repository.deletePost(102729);

      expect(client.deletePaths[0]).assertEqual('/posts/102729');
      expect(deleted.data).assertTrue();
      done();
    });

    it('flags a Post through the frozen Flutter form contract', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.formResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: PostFlagRequest | null = PostFlagRequest.create(102729, 7, '需要管理人员查看');
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const flagged: RepositoryResult<boolean> = await repository.flagPost(request);

      expect(client.formRequests[0]).assertEqual(
        '/post_actions|id=102729&post_action_type_id=7&flag_topic=false&' +
        'message=%E9%9C%80%E8%A6%81%E7%AE%A1%E7%90%86%E4%BA%BA%E5%91%98%E6%9F%A5%E7%9C%8B'
      );
      expect(flagged.data).assertTrue();
      expect(PostFlagRequest.create(102729, 7, null)).assertNull();
      expect(PostFlagRequest.create(102729, 3, null)?.formBody())
        .assertEqual('id=102729&post_action_type_id=3&flag_topic=false');
      done();
    });

    it('maps an unauthorized Post deletion to an expired authenticated session', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.deleteResults.push(HttpTextResult.unauthorized());
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const deleted: RepositoryResult<boolean> = await repository.deletePost(102729);

      expect(client.deletePaths[0]).assertEqual('/posts/102729');
      expect(deleted.isUnauthorized()).assertTrue();
      done();
    });

    it('accepts and unaccepts a solution through the Flutter-compatible form contracts', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.formResults.push(
          HttpTextResult.success(200, '{}'),
          HttpTextResult.success(200, '{}')
        );
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const accepted: RepositoryResult<boolean> = await repository.setPostAcceptedAnswer(102729, true);
        const unaccepted: RepositoryResult<boolean> = await repository.setPostAcceptedAnswer(102729, false);

        expect(client.formRequests[0]).assertEqual('/solution/accept|id=102729');
        expect(client.formRequests[1]).assertEqual('/solution/unaccept|id=102729');
        expect(accepted.data).assertTrue();
        expect(unaccepted.data).assertTrue();
         done();
       });

    it('reports sorted unique Topic timings without encoding bracket keys', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.formResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<boolean> = await repository.markTopicRead(2725, [3, 2, 2], 1000);

      expect(client.formRequests[0]).assertEqual(
        '/topics/timings|topic_id=2725&topic_time=1000&timings[2]=1000&timings[3]=1000'
      );
      expect(result.data).assertTrue();
      done();
    });

    it('clears only unread notifications reached by Topic progress', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"notifications":[' +
        '{"id":11,"read":false,"topic_id":7,"post_number":2},' +
        '{"id":12,"read":false,"topic_id":7,"post_number":5},' +
        '{"id":13,"read":false,"topic_id":7,"post_number":9},' +
        '{"id":14,"read":false,"topic_id":8,"post_number":4},' +
        '{"id":15,"read":true,"topic_id":7,"post_number":4},' +
        '{"id":16,"read":false,"data":{"topic_id":7}}' +
        ']}'
      ));
      client.putResults.push(HttpTextResult.success(200, '{}'));
      client.putResults.push(HttpTextResult.success(200, '{}'));
      client.putResults.push(HttpTextResult.success(200, '{}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<number> = await repository.clearTopicNotifications(7, 5);

      expect(client.paths[0]).assertEqual('/notifications.json?filter=unread');
      expect(client.putPaths.join(',')).assertEqual(
        '/notifications/mark-read.json?id=11,/notifications/mark-read.json?id=12,' +
        '/notifications/mark-read.json?id=16'
      );
      expect(result.data).assertEqual(3);
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

    it('creates Topics only in Category 111 and returns the created Topic id', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.jsonPostResults.push(HttpTextResult.success(200, '{"topic_id":19139}'));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
      const request: CreateTopicRequest | null = CreateTopicRequest.create('课程笔记', '**正文**', 111);
      if (request === null) {
        expect(false).assertTrue();
        done();
        return;
      }

      const result: TopicSubmitResult = await repository.submitTopic(request);

      expect(client.jsonPostRequests[0]).assertEqual(
        '/posts.json|{"title":"课程笔记","raw":"**正文**","category":111}'
      );
      expect(result.kind).assertEqual(TopicSubmitKind.CREATED);
      expect(result.topicId).assertEqual(19139);
      done();
    });

    it('edits a permitted Topic title Category and first Post body through frozen paths', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        client.formPutResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);
        const topicRequest: EditTopicRequest | null = EditTopicRequest.create(19139, '新标题', '旧标题', 111);
        const postRequest: EditPostRequest | null = EditPostRequest.create(103066, '更新后的正文');
        if (topicRequest === null || postRequest === null) {
          expect(false).assertTrue();
          done();
          return;
        }

        await repository.editTopic(topicRequest);
        await repository.editPost(postRequest);

        expect(client.formPutRequests[0]).assertEqual(
          '/t/-/19139.json|title=%E6%96%B0%E6%A0%87%E9%A2%98&category_id=111&original_title=%E6%97%A7%E6%A0%87%E9%A2%98'
        );
        expect(client.formPutRequests[1]).assertEqual(
          '/posts/103066|post%5Braw%5D=%E6%9B%B4%E6%96%B0%E5%90%8E%E7%9A%84%E6%AD%A3%E6%96%87&post%5Bedit_reason%5D='
        );
        done();
      });

    it('loads saves and deletes server drafts with their sequence and authoring context', 0,
      async (done: Function) => {
        const client: StubForumHttpClient = new StubForumHttpClient();
        client.results.push(HttpTextResult.success(200,
          '{"drafts":[{"draft_key":"new_topic","sequence":2,"data":{' +
            '"action":"createTopic","title":"课程笔记","reply":"正文","category_id":111}}]}'
        ));
        client.jsonPostResults.push(HttpTextResult.success(200, '{"draft_sequence":3}'));
        client.formDeleteResults.push(HttpTextResult.success(200, '{}'));
        const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

        const drafts: RepositoryResult<Array<ServerDraft>> = await repository.loadDrafts();
        const write: DraftWriteRequest | null = DraftWriteRequest.newTopic('课程笔记', '正文', 111, 2);
        if (write === null) {
          expect(false).assertTrue();
          done();
          return;
        }
        const saved: RepositoryResult<number> = await repository.saveDraft(write);
        const deleted: RepositoryResult<boolean> = await repository.deleteDraft('new_topic', 3);

        expect(drafts.data?.[0].categoryId).assertEqual(111);
        expect(drafts.data?.[0].sequence).assertEqual(2);
        expect(client.jsonPostRequests[0]).assertEqual(
          '/drafts.json|{"draft_key":"new_topic","data":"{\\"action\\":\\"createTopic\\",' +
            '\\"title\\":\\"课程笔记\\",\\"reply\\":\\"正文\\",\\"category_id\\":111}","sequence":2}'
        );
        expect(saved.data).assertEqual(3);
        expect(client.formDeleteRequests[0]).assertEqual('/drafts/new_topic.json|draft_key=new_topic&sequence=3');
        expect(deleted.data).assertTrue();
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
        '"user_option":{"chat_enabled":true,"homepage_id":5},"can_send_private_messages":true,' +
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
      expect(result.data?.defaultHomeChannel).assertEqual(HomeChannel.HOT);
      expect(result.data?.unreadNotifications).assertEqual(4);
      done();
    });

    it('loads the user Profile used as the Home preference fallback', 0, async (done: Function) => {
      const client: StubForumHttpClient = new StubForumHttpClient();
      client.results.push(HttpTextResult.success(200,
        '{"user":{"id":24,"username":"member","user_option":{"homepage_id":4}}}'
      ));
      const repository: DiscourseForumRepository = new DiscourseForumRepository(client);

      const result: RepositoryResult<CurrentUser> = await repository.loadUserProfile(' member ');

      expect(client.paths[0]).assertEqual('/u/member.json');
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.defaultHomeChannel).assertEqual(HomeChannel.LATEST_CREATED);
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
