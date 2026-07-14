import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
  AuthenticationLifecycle,
  BrowseStateKind,
  ReplyComposerState,
  ReplyComposerStateKind,
  RootDestination,
  SecondaryDestination,
  TopicReadStateKind
} from '../../../main/ets/app/AppShellModel';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../../../main/ets/models/DiscoveryModels';
import {
  CurrentUser,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitResult
} from '../../../main/ets/models/ReplyModels';
import { ForumRepository } from '../../../main/ets/repositories/ForumRepository';
import { MemoryCategoryCache } from './support/MemoryCategoryCache';

class PendingRepositoryResult<T> {
  public readonly promise: Promise<RepositoryResult<T>>;
  private resolver: ((result: RepositoryResult<T>) => void) | null = null;

  public constructor() {
    this.promise = new Promise<RepositoryResult<T>>((resolve: (result: RepositoryResult<T>) => void): void => {
      this.resolver = resolve;
    });
  }

  public complete(result: RepositoryResult<T>): void {
    const resolve: ((result: RepositoryResult<T>) => void) | null = this.resolver;
    if (resolve === null) {
      return;
    }
    this.resolver = null;
    resolve(result);
  }
}

class TopicReadingRepository implements ForumRepository {
  public topicDetailResults: Array<RepositoryResult<TopicDetail>> = [];
  public topicPostResults: Array<RepositoryResult<Array<ForumPost>>> = [];
  public categoryTopicResults: Array<RepositoryResult<Array<Topic>>> = [];
  public topicDetailTasks: Array<Promise<RepositoryResult<TopicDetail>>> = [];
  public categoryTopicTasks: Array<Promise<RepositoryResult<Array<Topic>>>> = [];
  public requestedCategoryIds: Array<number> = [];
  public requestedPostIds: Array<Array<number>> = [];
  public currentUserResults: Array<RepositoryResult<CurrentUser>> = [];
  public replySubmitResults: Array<ReplySubmitResult> = [];
  public replyRecoveryResults: Array<ReplyRecoveryResult> = [];
  public submittedReplies: Array<ReplyRequest> = [];
  public recoveryRequests: Array<ReplyRecoveryRequest> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadHomeTopics(_channel: HomeChannel, _page: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async searchForum(_query: string, _page: number): Promise<RepositoryResult<ForumSearchResult>> {
    return RepositoryResult.failure<ForumSearchResult>('missing search result');
  }

  public async searchSuggestions(_term: string): Promise<RepositoryResult<Array<string>>> {
    return RepositoryResult.success<Array<string>>([]);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    return RepositoryResult.success<Array<Category>>([]);
  }

  public async loadCategoryTopics(categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedCategoryIds.push(categoryId);
    const task: Promise<RepositoryResult<Array<Topic>>> | undefined = this.categoryTopicTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<Array<Topic>> | undefined = this.categoryTopicResults.shift();
    return result ?? RepositoryResult.failure<Array<Topic>>('missing Category Topic result');
  }

  public async loadTopicDetail(_topicId: number): Promise<RepositoryResult<TopicDetail>> {
    const task: Promise<RepositoryResult<TopicDetail>> | undefined = this.topicDetailTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<TopicDetail> | undefined = this.topicDetailResults.shift();
    return result ?? RepositoryResult.failure<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>> {
    this.requestedPostIds.push(postIds);
    const result: RepositoryResult<Array<ForumPost>> | undefined = this.topicPostResults.shift();
    return result ?? RepositoryResult.failure<Array<ForumPost>>('missing Post result');
  }

  public async submitReply(request: ReplyRequest): Promise<ReplySubmitResult> {
    this.submittedReplies.push(request);
    const result: ReplySubmitResult | undefined = this.replySubmitResults.shift();
    return result ?? ReplySubmitResult.rejected('missing Reply result');
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> | undefined = this.currentUserResults.shift();
    return result ?? RepositoryResult.failure<CurrentUser>('missing current user result');
  }

  public async loadUserProfile(_username: string): Promise<RepositoryResult<CurrentUser>> {
    return RepositoryResult.failure<CurrentUser>('missing user profile result');
  }

  public async recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult> {
    this.recoveryRequests.push(request);
    const result: ReplyRecoveryResult | undefined = this.replyRecoveryResults.shift();
    return result ?? ReplyRecoveryResult.failed('missing Reply recovery result');
  }
}

class TopicAuthenticationLifecycle implements AuthenticationLifecycle {
  public unauthorizedCallCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCallCount += 1;
  }
}

function topic(): Topic {
  return new Topic(2725, '站务管理区重要主题导航', 60, 1, 1959, 4, '', '', true, 'Co-admin');
}

function topicWithId(id: number, title: string): Topic {
  return new Topic(id, title, 60, 1, 10, 0, '', '', false, 'Co-admin');
}

function category(): Category {
  return new Category(60, '站务管理', '25AAE2', '站务与公告', 1, null, []);
}

function firstPost(): ForumPost {
  return new ForumPost(102728, 24, 'Co-admin', '<h1>站务公告</h1>', '站务公告', 1, null, '2026-01-27T14:46:08.722Z');
}

function secondPost(): ForumPost {
  return new ForumPost(102729, 1, 'admin', '<p>第一条 Reply</p>', '第一条 Reply', 2, null, '2026-01-28T00:00:00Z');
}

function thirdPost(): ForumPost {
  return new ForumPost(102730, 24, 'Co-admin', '<p>第二条 Reply</p>', '第二条 Reply', 3, 2, '2026-01-28T00:01:00Z');
}

function fourthPost(): ForumPost {
  return new ForumPost(102731, 24, 'Co-admin', '<p>收到</p>', '收到', 4, 3, '2026-01-28T00:02:00Z');
}

function authenticatedUserResult(): RepositoryResult<CurrentUser> {
  const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
  return user === null
    ? RepositoryResult.failure<CurrentUser>('invalid test user')
    : RepositoryResult.success<CurrentUser>(user);
}

export default function topicReadingTest(): void {
  describe('AppShell Topic reading', () => {
    it('composes Category, Topic, targeted Reply, and return navigation through one AppShell', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.categoryTopicResults.push(RepositoryResult.success<Array<Topic>>([topic()]));
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
          [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
        )));
        repository.currentUserResults.push(authenticatedUserResult());
        repository.replySubmitResults.push(ReplySubmitResult.created(fourthPost()));
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );

        model.selectRoot(RootDestination.CATEGORY);
        await model.openCategory(category());
        expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);
        expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
        expect(model.categoryTopicsState.items[0].id).assertEqual(2725);

        await model.openTopic(topic());
        expect(model.activeDestination).assertEqual(SecondaryDestination.TOPIC);
        expect(model.topicState.posts.length).assertEqual(3);

        model.openReply(3);
        model.updateReplyDraft('组合路径 Reply');
        await model.submitReply();
        expect(repository.submittedReplies.length).assertEqual(1);
        expect(repository.submittedReplies[0].replyToPostNumber).assertEqual(3);
        expect(model.topicState.posts[3].id).assertEqual(102731);

        model.closeSecondary();
        expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
        model.closeSecondary();
        expect(model.activeDestination).assertEqual(SecondaryDestination.NONE);
        expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);

        model.selectRoot(RootDestination.ACCOUNT);
        expect(model.selectedRoot).assertEqual(RootDestination.ACCOUNT);
        done();
      });

    it('keeps the newest Category and Topic when older requests finish later', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      const firstCategory: PendingRepositoryResult<Array<Topic>> = new PendingRepositoryResult<Array<Topic>>();
      const secondCategory: PendingRepositoryResult<Array<Topic>> = new PendingRepositoryResult<Array<Topic>>();
      repository.categoryTopicTasks.push(firstCategory.promise, secondCategory.promise);
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      const firstCategoryLoad: Promise<void> = model.openCategory(category());
      const otherCategory: Category = new Category(61, '游客公告', '25AAE2', '', 2, null, []);
      const secondCategoryLoad: Promise<void> = model.openCategory(otherCategory);
      secondCategory.complete(RepositoryResult.success<Array<Topic>>([topicWithId(3000, '新 Category Topic')]));
      await secondCategoryLoad;
      firstCategory.complete(RepositoryResult.success<Array<Topic>>([topic()]));
      await firstCategoryLoad;

      expect(model.selectedCategory?.id).assertEqual(61);
      expect(model.categoryTopicsState.items[0].id).assertEqual(3000);

      const firstTopic: PendingRepositoryResult<TopicDetail> = new PendingRepositoryResult<TopicDetail>();
      const secondTopic: PendingRepositoryResult<TopicDetail> = new PendingRepositoryResult<TopicDetail>();
      repository.topicDetailTasks.push(firstTopic.promise, secondTopic.promise);
      const firstTopicLoad: Promise<void> = model.openTopic(topic());
      const otherTopic: Topic = topicWithId(3000, '新 Topic');
      const secondTopicLoad: Promise<void> = model.openTopic(otherTopic);
      secondTopic.complete(RepositoryResult.success<TopicDetail>(new TopicDetail(
        3000, '新 Topic', 10, 0, 0, false, false, true, [], []
      )));
      await secondTopicLoad;
      firstTopic.complete(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '旧 Topic', 10, 0, 0, false, false, true, [], []
      )));
      await firstTopicLoad;

      expect(model.topicState.topicId).assertEqual(3000);
      expect(model.topicState.title).assertEqual('新 Topic');
      done();
    });

    it('opens a Category Topic list as a retryable secondary page', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.categoryTopicResults.push(RepositoryResult.failure<Array<Topic>>('网络连接失败'));
      repository.categoryTopicResults.push(RepositoryResult.success<Array<Topic>>([topic()]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      const loading: Promise<void> = model.openCategory(category());
      expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.ERROR);

      await model.retryCategoryTopics();
      expect(repository.requestedCategoryIds.join(',')).assertEqual('60,60');
      expect(model.categoryTopicsState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryTopicsState.items[0].id).assertEqual(2725);

      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        1,
        4,
        false,
        false,
        true,
        [102728],
        [firstPost()]
      )));
      await model.openTopic(topic());
      model.closeSecondary();
      expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
      done();
    });

    it('opens a Topic as a secondary page and preserves the selected root when closed', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        1,
        4,
        true,
        false,
        false,
        [102728],
        [firstPost()]
      )));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      model.selectRoot(RootDestination.CATEGORY);

      const loading: Promise<void> = model.openTopic(topic());
      expect(model.activeDestination).assertEqual(SecondaryDestination.TOPIC);
      expect(model.topicState.kind).assertEqual(TopicReadStateKind.LOADING);
      await loading;

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.posts[0].id).assertEqual(102728);
      expect(model.topicState.canReply).assertFalse();
      model.openReply(null);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.CLOSED);

      model.closeSecondary();
      expect(model.activeDestination).assertEqual(SecondaryDestination.NONE);
      expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);
      done();
    });

    it('retries a failed Topic first screen without losing its identity', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.failure<TopicDetail>('网络连接失败'));
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        1,
        4,
        false,
        false,
        true,
        [102728],
        [firstPost()]
      )));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.openTopic(topic());
      expect(model.topicState.kind).assertEqual(TopicReadStateKind.ERROR);

      await model.retryTopic();
      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.topicId).assertEqual(2725);
      done();
    });

    it('represents an archived Topic with no Posts as a non-replyable empty state', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '已归档 Topic',
        10,
        0,
        0,
        false,
        true,
        true,
        [],
        []
      )));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.openTopic(topic());

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.EMPTY);
      expect(model.topicState.posts.length).assertEqual(0);
      expect(model.topicState.canReply).assertFalse();
      expect(model.topicState.hasMorePosts).assertFalse();
      model.openReply(null);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.CLOSED);
      done();
    });

    it('preserves visible Posts when pagination fails and retries the same window', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        3,
        4,
        false,
        false,
        true,
        [102728, 102729, 102730],
        [firstPost()]
      )));
      repository.topicPostResults.push(RepositoryResult.failure<Array<ForumPost>>('网络连接失败'));
      repository.topicPostResults.push(RepositoryResult.success<Array<ForumPost>>([
        firstPost(),
        secondPost(),
        thirdPost()
      ]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const failingLoad: Promise<void> = model.loadMorePosts();
      expect(model.topicState.isLoadingMore).assertTrue();
      await failingLoad;

      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.hasMorePosts).assertTrue();
      expect(model.topicState.paginationMessage).assertEqual('网络连接失败');
      expect(repository.requestedPostIds[0].join(',')).assertEqual('102729,102730');

      await model.retryTopicPosts();

      expect(repository.requestedPostIds[1].join(',')).assertEqual('102729,102730');
      expect(model.topicState.posts.length).assertEqual(3);
      expect(model.topicState.hasMorePosts).assertFalse();
      expect(model.topicState.paginationMessage).assertEqual('');
      done();
    });

    it('keeps the server Post order across the first screen and appended window', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        4,
        4,
        false,
        false,
        true,
        [102729, 102728, 102731, 102730],
        [secondPost(), firstPost()]
      )));
      repository.topicPostResults.push(RepositoryResult.success<Array<ForumPost>>([
        fourthPost(),
        thirdPost()
      ]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.openTopic(topic());
      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('2,1');

      await model.loadMorePosts();

      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('2,1,4,3');
      done();
    });

    it('submits a targeted Reply once and appends the created Post', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.currentUserResults.push(authenticatedUserResult());
      repository.replySubmitResults.push(ReplySubmitResult.created(fourthPost()));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      model.openReply(3);
      model.updateReplyDraft('  收到  ');

      const submitting: Promise<void> = model.submitReply();
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUBMITTING);
      await submitting;

      expect(repository.submittedReplies.length).assertEqual(1);
      expect(repository.submittedReplies[0].replyToPostNumber).assertEqual(3);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      expect(model.replyState.draft).assertEqual('');
      expect(model.topicState.posts.length).assertEqual(4);
      expect(model.topicState.posts[3].id).assertEqual(102731);
      done();
    });

    it('submits a Reply longer than 1000 characters without imposing a UI-only limit', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.currentUserResults.push(authenticatedUserResult());
      repository.replySubmitResults.push(ReplySubmitResult.created(fourthPost()));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      const longDraft: string = '长'.repeat(1001);
      await model.openTopic(topic());
      model.openReply(null);
      model.updateReplyDraft(longDraft);

      await model.submitReply();

      expect(repository.submittedReplies.length).assertEqual(1);
      expect(repository.submittedReplies[0].raw.length).assertEqual(1001);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      done();
    });

    it('confirms an uncertain Reply without sending a second POST', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 7
      )));
      repository.currentUserResults.push(authenticatedUserResult());
      repository.replySubmitResults.push(ReplySubmitResult.uncertain('连接中断'));
      repository.replyRecoveryResults.push(ReplyRecoveryResult.confirmed(fourthPost()));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      model.openReply(3);
      model.updateReplyDraft('收到');
      const observedStates: Array<ReplyComposerStateKind> = [];

      await model.submitReply((state: ReplyComposerState): void => {
        observedStates.push(state.kind);
      });

      expect(repository.submittedReplies.length).assertEqual(1);
      expect(repository.recoveryRequests.length).assertEqual(1);
      expect(repository.recoveryRequests[0].expectedPostNumber).assertEqual(8);
      expect(observedStates.join(',')).assertEqual('submitting,checking,success');
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      expect(model.topicState.posts.length).assertEqual(4);
      done();
    });

    it('does not retry an unconfirmed Reply until the user explicitly submits again', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.currentUserResults.push(authenticatedUserResult(), authenticatedUserResult());
      repository.replySubmitResults.push(
        ReplySubmitResult.uncertain('连接中断'),
        ReplySubmitResult.created(fourthPost())
      );
      repository.replyRecoveryResults.push(ReplyRecoveryResult.failed('无法确认 Reply 是否已创建'));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      model.openReply(null);
      model.updateReplyDraft('只发布一次');

      await model.submitReply();

      expect(repository.submittedReplies.length).assertEqual(1);
      expect(repository.recoveryRequests.length).assertEqual(1);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.ERROR);
      expect(model.replyState.draft).assertEqual('只发布一次');

      await model.submitReply();

      expect(repository.submittedReplies.length).assertEqual(2);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      done();
    });

    it('preserves a rejected draft and only retries after another explicit submit', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.currentUserResults.push(authenticatedUserResult(), authenticatedUserResult());
      repository.replySubmitResults.push(
        ReplySubmitResult.rejected('操作过于频繁'),
        ReplySubmitResult.created(fourthPost())
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      model.openReply(null);
      model.updateReplyDraft('收到');

      await model.submitReply();
      expect(repository.submittedReplies.length).assertEqual(1);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.ERROR);
      expect(model.replyState.draft).assertEqual('收到');

      await model.submitReply();
      expect(repository.submittedReplies.length).assertEqual(2);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      done();
    });

    it('keeps the in-memory draft when authentication expires or the composer closes', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.currentUserResults.push(RepositoryResult.unauthorized<CurrentUser>());
      const lifecycle: TopicAuthenticationLifecycle = new TopicAuthenticationLifecycle();
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        lifecycle
      );
      await model.openTopic(topic());
      model.openReply(3);
      model.updateReplyDraft('登录后继续');

      await model.submitReply();

      expect(repository.submittedReplies.length).assertEqual(0);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.REAUTHENTICATE);
      expect(model.replyState.draft).assertEqual('登录后继续');
      expect(lifecycle.unauthorizedCallCount).assertEqual(1);
      model.resumeReplyAfterAuthentication();
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.EDITING);
      expect(model.replyState.draft).assertEqual('登录后继续');
      model.dismissReply();
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.CLOSED);
      model.openReply(3);
      expect(model.replyState.draft).assertEqual('登录后继续');
      done();
    });
  });
}
