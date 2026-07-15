import { describe, expect, it } from '@ohos/hypium';
import { AppShellModel } from '../../../main/ets/app/AppShellModel';
import {
  ReplyComposerState,
  ReplyComposerStateKind,
  TopicComposerStateKind
} from '../../../main/ets/app/ComposerModels';
import { TopicReadStateKind } from '../../../main/ets/app/TopicReadingModels';
import { BrowseStateKind } from '../../../main/ets/app/BrowseModels';
import { AuthenticationLifecycle } from '../../../main/ets/app/AuthenticationLifecycle';
import {
  RootDestination,
  SecondaryDestination
} from '../../../main/ets/app/ShellNavigationModels';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  Category,
  ForumPost,
  ForumPostMetadata,
  PostFlagRequest,
  PostReaction,
  PostReactionUser,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicDetailMetadata,
  TopicPostBatch
} from '../../../main/ets/models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../../../main/ets/models/DiscoveryModels';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitResult
} from '../../../main/ets/models/AuthoringModels';
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
  public topicPostResults: Array<RepositoryResult<TopicPostBatch>> = [];
  public topicPostTasks: Array<Promise<RepositoryResult<TopicPostBatch>>> = [];
  public topicSuggestionResults: Array<RepositoryResult<Array<Topic>>> = [];
  public reactionResults: Array<RepositoryResult<ForumPost>> = [];
  public reactionUsersResults: Array<RepositoryResult<Array<PostReactionUsers>>> = [];
  public createBookmarkResults: Array<RepositoryResult<number>> = [];
  public deleteBookmarkResults: Array<RepositoryResult<boolean>> = [];
  public deletePostResults: Array<RepositoryResult<boolean>> = [];
  public flagPostResults: Array<RepositoryResult<boolean>> = [];
  public deletePostTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public acceptedAnswerResults: Array<RepositoryResult<boolean>> = [];
  public acceptedAnswerTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public markTopicReadResults: Array<RepositoryResult<boolean>> = [];
  public markTopicReadTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public clearNotificationResults: Array<RepositoryResult<number>> = [];
  public clearNotificationTasks: Array<Promise<RepositoryResult<number>>> = [];
  public categoryTopicResults: Array<RepositoryResult<Array<Topic>>> = [];
  public topicDetailTasks: Array<Promise<RepositoryResult<TopicDetail>>> = [];
  public categoryTopicTasks: Array<Promise<RepositoryResult<Array<Topic>>>> = [];
  public requestedCategoryIds: Array<number> = [];
  public requestedPostIds: Array<Array<number>> = [];
  public requestedTopicPostNumbers: Array<number | null> = [];
  public requestedSuggestionTopicIds: Array<number> = [];
  public requestedReactions: Array<string> = [];
  public requestedReactionUserPostIds: Array<number> = [];
  public requestedBookmarkPostIds: Array<number> = [];
  public requestedDeleteBookmarkIds: Array<number> = [];
  public requestedDeletePostIds: Array<number> = [];
  public requestedFlags: Array<string> = [];
  public requestedAcceptedAnswers: Array<string> = [];
  public requestedReadTimings: Array<string> = [];
  public requestedNotificationProgress: Array<string> = [];
  public currentUserResults: Array<RepositoryResult<CurrentUser>> = [];
  public replySubmitResults: Array<ReplySubmitResult> = [];
  public replyRecoveryResults: Array<ReplyRecoveryResult> = [];
  public submittedReplies: Array<ReplyRequest> = [];
  public recoveryRequests: Array<ReplyRecoveryRequest> = [];
  public topicSubmitResults: Array<TopicSubmitResult> = [];
  public submittedTopics: Array<CreateTopicRequest> = [];
  public editPostResults: Array<RepositoryResult<boolean>> = [];
  public editedPosts: Array<EditPostRequest> = [];
  public draftResults: Array<RepositoryResult<Array<ServerDraft>>> = [];
  public savedDrafts: Array<DraftWriteRequest> = [];
  public savedDraftResults: Array<RepositoryResult<number>> = [];
  public deletedDrafts: Array<string> = [];
  public deletedDraftResults: Array<RepositoryResult<boolean>> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadHomeTopics(_channel: HomeChannel, _page: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async searchForum(_query: string, _page: number): Promise<RepositoryResult<ForumSearchResult>> {
    return RepositoryResult.unknown<ForumSearchResult>('missing search result');
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
    return result ?? RepositoryResult.unknown<Array<Topic>>('missing Category Topic result');
  }

  public async loadTopicDetail(
    _topicId: number,
    postNumber: number | null = null
  ): Promise<RepositoryResult<TopicDetail>> {
    this.requestedTopicPostNumbers.push(postNumber);
    const task: Promise<RepositoryResult<TopicDetail>> | undefined = this.topicDetailTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<TopicDetail> | undefined = this.topicDetailResults.shift();
    return result ?? RepositoryResult.unknown<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, postIds: Array<number>): Promise<RepositoryResult<TopicPostBatch>> {
    this.requestedPostIds.push(postIds);
    const task: Promise<RepositoryResult<TopicPostBatch>> | undefined = this.topicPostTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<TopicPostBatch> | undefined = this.topicPostResults.shift();
    return result ?? RepositoryResult.unknown<TopicPostBatch>('missing Post result');
  }

  public async loadTopicSuggestions(topicId: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedSuggestionTopicIds.push(topicId);
    const result: RepositoryResult<Array<Topic>> | undefined = this.topicSuggestionResults.shift();
    return result ?? RepositoryResult.success<Array<Topic>>([]);
  }

  public async togglePostReaction(postId: number, reaction: string): Promise<RepositoryResult<ForumPost>> {
    this.requestedReactions.push(`${postId}:${reaction}`);
    return this.reactionResults.shift() ?? RepositoryResult.unknown<ForumPost>('missing Reaction result');
  }

  public async loadPostReactionUsers(postId: number): Promise<RepositoryResult<Array<PostReactionUsers>>> {
    this.requestedReactionUserPostIds.push(postId);
    return this.reactionUsersResults.shift() ??
      RepositoryResult.unknown<Array<PostReactionUsers>>('missing Reaction users result');
  }

  public async createPostBookmark(postId: number): Promise<RepositoryResult<number>> {
    this.requestedBookmarkPostIds.push(postId);
    return this.createBookmarkResults.shift() ?? RepositoryResult.unknown<number>('missing bookmark result');
  }

  public async deletePostBookmark(bookmarkId: number): Promise<RepositoryResult<boolean>> {
    this.requestedDeleteBookmarkIds.push(bookmarkId);
    return this.deleteBookmarkResults.shift() ?? RepositoryResult.unknown<boolean>('missing bookmark result');
  }

  public async deletePost(postId: number): Promise<RepositoryResult<boolean>> {
    this.requestedDeletePostIds.push(postId);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.deletePostTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.deletePostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post delete result');
  }

  public async flagPost(request: PostFlagRequest): Promise<RepositoryResult<boolean>> {
    this.requestedFlags.push(`${request.postId}:${request.typeId}:${request.message ?? ''}`);
    return this.flagPostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post flag result');
  }

  public async setPostAcceptedAnswer(postId: number, accepted: boolean): Promise<RepositoryResult<boolean>> {
    this.requestedAcceptedAnswers.push(`${postId}:${accepted}`);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.acceptedAnswerTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.acceptedAnswerResults.shift() ?? RepositoryResult.unknown<boolean>('missing solution result');
  }

  public async markTopicRead(
    topicId: number,
    postNumbers: Array<number>,
    milliseconds: number
  ): Promise<RepositoryResult<boolean>> {
    this.requestedReadTimings.push(`${topicId}:${postNumbers.join(',')}:${milliseconds}`);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.markTopicReadTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.markTopicReadResults.shift() ?? RepositoryResult.unknown<boolean>('missing Topic timing result');
  }

  public async clearTopicNotifications(
    topicId: number,
    upToPostNumber: number
  ): Promise<RepositoryResult<number>> {
    this.requestedNotificationProgress.push(`${topicId}:${upToPostNumber}`);
    const task: Promise<RepositoryResult<number>> | undefined = this.clearNotificationTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.clearNotificationResults.shift() ?? RepositoryResult.success<number>(0);
  }

  public async submitReply(request: ReplyRequest): Promise<ReplySubmitResult> {
    this.submittedReplies.push(request);
    const result: ReplySubmitResult | undefined = this.replySubmitResults.shift();
    return result ?? ReplySubmitResult.rejected('missing Reply result');
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> | undefined = this.currentUserResults.shift();
    return result ?? RepositoryResult.unknown<CurrentUser>('missing current user result');
  }

  public async loadUserProfile(_username: string): Promise<RepositoryResult<CurrentUser>> {
    return RepositoryResult.unknown<CurrentUser>('missing user profile result');
  }

  public async recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult> {
    this.recoveryRequests.push(request);
    const result: ReplyRecoveryResult | undefined = this.replyRecoveryResults.shift();
    return result ?? ReplyRecoveryResult.failed('missing Reply recovery result');
  }

  public async submitTopic(request: CreateTopicRequest): Promise<TopicSubmitResult> {
    this.submittedTopics.push(request);
    return this.topicSubmitResults.shift() ?? TopicSubmitResult.rejected('missing Topic result');
  }

  public async editPost(request: EditPostRequest): Promise<RepositoryResult<boolean>> {
    this.editedPosts.push(request);
    return this.editPostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post edit result');
  }

  public async editTopic(_request: EditTopicRequest): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.unknown<boolean>('missing Topic edit result');
  }

  public async loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>> {
    return this.draftResults.shift() ?? RepositoryResult.success<Array<ServerDraft>>([]);
  }

  public async saveDraft(request: DraftWriteRequest): Promise<RepositoryResult<number>> {
    this.savedDrafts.push(request);
    return this.savedDraftResults.shift() ?? RepositoryResult.unknown<number>('missing draft result');
  }

  public async deleteDraft(draftKey: string, sequence: number): Promise<RepositoryResult<boolean>> {
    this.deletedDrafts.push(`${draftKey}:${sequence}`);
    return this.deletedDraftResults.shift() ?? RepositoryResult.success<boolean>(true);
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

function deletableSecondPost(): ForumPost {
  return new ForumPost(
    102729,
    24,
    'Co-admin',
    '<p>我自己的 Reply</p>',
    '我自己的 Reply',
    2,
    null,
    '2026-01-28T00:00:00Z',
    new ForumPostMetadata('', '', '', null, null, 0, [], null, false, true)
  );
}

function thirdPost(): ForumPost {
  return new ForumPost(102730, 24, 'Co-admin', '<p>第二条 Reply</p>', '第二条 Reply', 3, 2, '2026-01-28T00:01:00Z');
}

function fourthPost(): ForumPost {
  return new ForumPost(102731, 24, 'Co-admin', '<p>收到</p>', '收到', 4, 3, '2026-01-28T00:02:00Z');
}

function reactedFirstPost(): ForumPost {
  return new ForumPost(
    102728,
    24,
    'Co-admin',
    '<h1>站务公告</h1>',
    '站务公告',
    1,
    null,
    '2026-01-27T14:46:08.722Z',
    new ForumPostMetadata('', '', '', null, null, 1, [new PostReaction('heart', 1)], 'heart')
  );
}

function solutionReply(
  acceptedAnswer: boolean,
  canAcceptAnswer: boolean,
  canUnacceptAnswer: boolean
): ForumPost {
  return new ForumPost(
    102729,
    1,
    'admin',
    '<p>可采纳的回答</p>',
    '可采纳的回答',
    2,
    null,
    '2026-01-28T00:00:00Z',
    new ForumPostMetadata(
      '', '', '', null, null, 0, [], null, false, false,
      acceptedAnswer, canAcceptAnswer, canUnacceptAnswer
    )
  );
}

function authenticatedUserResult(): RepositoryResult<CurrentUser> {
  const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
  return user === null
    ? RepositoryResult.unknown<CurrentUser>('invalid test user')
    : RepositoryResult.success<CurrentUser>(user);
}

export default function topicReadingTest(): void {
  describe('AppShell Topic reading', () => {
    it('opens only the current loaded Topic in place', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
      )));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );

      expect(model.shouldOpenTopicInPlace(2725)).assertFalse();
      await model.openTopic(topic());
      expect(model.shouldOpenTopicInPlace(2725)).assertTrue();
      expect(model.shouldOpenTopicInPlace(3000)).assertFalse();
      expect(model.shouldOpenTopicInPlace(0)).assertFalse();
      done();
    });

    it('composes Category, Topic, targeted Reply, and return navigation through one AppShell', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.categoryTopicResults.push(RepositoryResult.success<Array<Topic>>([topic()]));
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
          [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
          new TopicDetailMetadata(111)
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
      repository.categoryTopicResults.push(RepositoryResult.unknown<Array<Topic>>('网络连接失败'));
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

    it('restores the previous Topic read window and requested floor after a nested Topic closes', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        const primaryDetail: TopicDetail = new TopicDetail(
          2725,
          '定点阅读 Topic',
          100,
          4,
          0,
          false,
          false,
          true,
          [102728, 102729, 102730, 102731],
          [secondPost(), thirdPost()],
          4,
          new TopicDetailMetadata(60, false, 'Co-admin', [], [], 2)
        );
        const nestedPost: ForumPost = new ForumPost(
          203007,
          1,
          'admin',
          '<p>嵌套 Topic 内容</p>',
          '嵌套 Topic 内容',
          7,
          null,
          '2026-01-28T01:00:00Z'
        );
        const nestedDetail: TopicDetail = new TopicDetail(
          3000,
          '嵌套 Topic',
          10,
          7,
          0,
          false,
          false,
          true,
          [203007],
          [nestedPost],
          7,
          new TopicDetailMetadata(60, false, 'admin', [], [], 7)
        );
        repository.topicDetailResults.push(
          RepositoryResult.success<TopicDetail>(primaryDetail),
          RepositoryResult.success<TopicDetail>(nestedDetail),
          RepositoryResult.success<TopicDetail>(primaryDetail)
        );
        repository.topicPostResults.push(
          RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([firstPost()])),
          RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([fourthPost()]))
        );
        const model: AppShellModel = new AppShellModel(
          repository,
          new MemoryCategoryCache(),
          CategoryCacheScope.anonymous()
        );

        await model.openTopic(topic(), 2);
        await model.openTopic(topicWithId(3000, '嵌套 Topic'), 7);
        model.closeSecondary();

        expect(model.activeDestination).assertEqual(SecondaryDestination.TOPIC);
        expect(model.topicState.topicId).assertEqual(2725);
        expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
          .assertEqual('2,3');
        expect(model.topicState.readProgressState.lastReadPostNumber).assertEqual(2);
        expect(model.topicState.hasPreviousPosts).assertTrue();
        expect(model.topicState.hasNextPosts).assertTrue();

        await model.loadPreviousPosts();
        await model.loadMorePosts();
        expect(repository.requestedPostIds[0].join(',')).assertEqual('102728');
        expect(repository.requestedPostIds[1].join(',')).assertEqual('102731');
        expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
          .assertEqual('1,2,3,4');

        await model.retryTopic();
        expect(repository.requestedTopicPostNumbers.map((postNumber: number | null): string => {
          return postNumber === null ? 'null' : postNumber.toString();
        }).join(',')).assertEqual('2,7,2');

        model.closeSecondary();
        expect(model.activeDestination).assertEqual(SecondaryDestination.NONE);
        done();
      });

    it('retries a failed Topic first screen without losing its identity', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.unknown<TopicDetail>('网络连接失败'));
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

    it('refreshes a loaded Topic without hiding its current Posts', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '刷新前 Topic',
        10,
        1,
        4,
        false,
        false,
        true,
        [102728],
        [firstPost()]
      )));
      const refreshedTopic: PendingRepositoryResult<TopicDetail> = new PendingRepositoryResult<TopicDetail>();
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      repository.topicDetailTasks.push(refreshedTopic.promise);

      const refreshTask: Promise<void> = model.refreshTopic();

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.posts[0].postNumber).assertEqual(1);
      expect(model.topicState.isRefreshing).assertTrue();

      refreshedTopic.complete(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '刷新后 Topic',
        11,
        2,
        4,
        false,
        false,
        true,
        [102728, 102729],
        [firstPost(), secondPost()]
      )));
      await refreshTask;

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.title).assertEqual('刷新后 Topic');
      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('1,2');
      expect(model.topicState.isRefreshing).assertFalse();
      expect(repository.requestedTopicPostNumbers.map((postNumber: number | null): string => {
        return postNumber === null ? 'null' : postNumber.toString();
      }).join(',')).assertEqual('null,null');
      done();
    });

    it('keeps refreshed Topic metadata when an older read report finishes later', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '旧标题', 10, 1, 4, false, false, true, [102728], [firstPost()]
      )));
      const refreshedTopic: PendingRepositoryResult<TopicDetail> = new PendingRepositoryResult<TopicDetail>();
      const readReport: PendingRepositoryResult<boolean> = new PendingRepositoryResult<boolean>();
      repository.markTopicReadTasks.push(readReport.promise);
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      repository.topicDetailTasks.push(refreshedTopic.promise);

      const refreshTask: Promise<void> = model.refreshTopic();
      const progressTask: Promise<void> = model.reportTopicReadProgress(1);
      refreshedTopic.complete(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '服务端新标题', 11, 1, 4, false, false, true, [102728], [firstPost()]
      )));
      await refreshTask;
      readReport.complete(RepositoryResult.success<boolean>(true));
      await progressTask;

      expect(model.topicState.title).assertEqual('服务端新标题');
      expect(model.topicState.detail?.lastReadPostNumber).assertEqual(1);
      done();
    });

    it('keeps the loaded Topic visible when pull-to-refresh fails', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '保留中的 Topic',
        10,
        1,
        4,
        false,
        false,
        true,
        [102728],
        [firstPost()]
      )));
      repository.topicDetailResults.push(RepositoryResult.unknown<TopicDetail>('刷新失败'));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.refreshTopic();

      expect(model.topicState.kind).assertEqual(TopicReadStateKind.CONTENT);
      expect(model.topicState.title).assertEqual('保留中的 Topic');
      expect(model.topicState.posts[0].postNumber).assertEqual(1);
      expect(model.topicState.isRefreshing).assertFalse();
      expect(model.topicState.refreshMessage).assertEqual('刷新失败');
      done();
    });

    it('opens and retries a searched Post from its requested floor', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.unknown<TopicDetail>('网络连接失败'));
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '站务管理区重要主题导航',
        1959,
        12,
        4,
        false,
        false,
        true,
        [102739],
        [new ForumPost(
          102739,
          24,
          'Co-admin',
          '<p>命中的 Post</p>',
          '命中的 Post',
          12,
          null,
          '2026-01-28T00:00:00Z'
        )]
      )));
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

      await model.openTopic(topic(), 12);
      await model.retryTopic();
      await model.refreshTopic();

      expect(repository.requestedTopicPostNumbers.map((postNumber: number | null): string => {
        return postNumber === null ? 'null' : postNumber.toString();
      }).join(',')).assertEqual('12,12,null');
      expect(model.topicState.posts[0].postNumber).assertEqual(1);
      expect(model.topicState.postJumpState.targetPostNumber).assertEqual(1);
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
      repository.topicPostResults.push(RepositoryResult.unknown<TopicPostBatch>('网络连接失败'));
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
        firstPost(),
        secondPost(),
        thirdPost()
      ])));
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
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
        fourthPost(),
        thirdPost()
      ])));
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

    it('loads both sides of a targeted Post window without breaking stream order', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725,
        '定点阅读',
        100,
        5,
        0,
        false,
        false,
        true,
        [102728, 102729, 102730, 102731, 102732],
        [thirdPost(), fourthPost()]
      )));
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
        firstPost(), secondPost()
      ])));
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
        new ForumPost(102732, 1, 'admin', '<p>末楼</p>', '末楼', 5, null, '2026-01-28T00:03:00Z')
      ])));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.openTopic(topic(), 3);
      expect(model.topicState.hasPreviousPosts).assertTrue();
      expect(model.topicState.hasNextPosts).assertTrue();

      await model.loadPreviousPosts();
      expect(repository.requestedPostIds[0].join(',')).assertEqual('102728,102729');
      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('1,2,3,4');

      await model.loadMorePosts();
      expect(repository.requestedPostIds[1].join(',')).assertEqual('102732');
      expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
        .assertEqual('1,2,3,4,5');
      expect(model.topicState.hasPreviousPosts).assertFalse();
      expect(model.topicState.hasNextPosts).assertFalse();
      expect(model.topicState.postJumpState.targetPostNumber).assertEqual(3);
      done();
    });

    it('keeps the current Post window when a floor jump fails and retries that target', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(
          RepositoryResult.success<TopicDetail>(new TopicDetail(
            2725, '定点阅读', 100, 80, 0, false, false, true,
            [102728, 102729, 102730], [firstPost(), secondPost()], 80
          )),
          RepositoryResult.unknown<TopicDetail>('楼层加载失败'),
          RepositoryResult.success<TopicDetail>(new TopicDetail(
            2725, '定点阅读', 100, 80, 0, false, false, true,
            [103735, 103736, 103737, 103738, 103739], [
              new ForumPost(103736, 24, 'Co-admin', '<p>前一楼</p>', '前一楼', 36, null, '2026-01-28T00:00:00Z'),
              new ForumPost(103737, 24, 'Co-admin', '<p>目标楼层</p>', '目标楼层', 37, null, '2026-01-28T00:01:00Z'),
              new ForumPost(103738, 1, 'admin', '<p>后一楼</p>', '后一楼', 38, null, '2026-01-28T00:02:00Z')
            ], 80
          ))
        );
        const model: AppShellModel = new AppShellModel(
          repository,
          new MemoryCategoryCache(),
          CategoryCacheScope.anonymous()
        );

        await model.openTopic(topic());
        const visiblePostIds: string = model.topicState.posts.map((post: ForumPost): number => post.id).join(',');

        const failedJump: Promise<void> = model.jumpToTopicPost(37);
        expect(model.topicState.postJumpState.busy).assertTrue();
        await failedJump;

        expect(model.topicState.posts.map((post: ForumPost): number => post.id).join(','))
          .assertEqual(visiblePostIds);
        expect(model.topicState.hasNextPosts).assertTrue();
        expect(model.topicState.postJumpState.targetPostNumber).assertEqual(37);
        expect(model.topicState.postJumpState.message).assertEqual('楼层加载失败');

        await model.retryTopicPostJump();

        expect(repository.requestedTopicPostNumbers.map((postNumber: number | null): string => {
          return postNumber === null ? 'null' : postNumber.toString();
        }).join(',')).assertEqual('null,37,37');
        expect(model.topicState.posts.map((post: ForumPost): number => post.postNumber).join(','))
          .assertEqual('36,37,38');
        expect(model.topicState.hasPreviousPosts).assertTrue();
        expect(model.topicState.hasNextPosts).assertTrue();
        expect(model.topicState.postJumpState.targetPostNumber).assertEqual(37);
        expect(model.topicState.postJumpState.message).assertEqual('');
        done();
      });

    it('does not start pagination while a floor jump is in flight', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '定点阅读', 100, 3, 0, false, false, true,
        [102728, 102729, 102730], [firstPost()], 3
      )));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());
      const jumpResult: PendingRepositoryResult<TopicDetail> = new PendingRepositoryResult<TopicDetail>();
      repository.topicDetailTasks.push(jumpResult.promise);

      const jumpTask: Promise<void> = model.jumpToTopicPost(2);
      expect(model.topicState.postJumpState.busy).assertTrue();
      await model.loadMorePosts();

      expect(repository.requestedPostIds.length).assertEqual(0);
      expect(model.topicState.isLoadingMore).assertFalse();
      jumpResult.complete(RepositoryResult.unknown<TopicDetail>('楼层加载失败'));
      await jumpTask;
      done();
    });

    it('does not invalidate an in-flight pagination request with a floor jump', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(
        RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '定点阅读', 100, 3, 0, false, false, true,
          [102728, 102729, 102730], [firstPost()], 3
        )),
        RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '定点阅读', 100, 3, 0, false, false, true,
          [102728, 102729, 102730], [secondPost()], 3
        ))
      );
      repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
        secondPost(), thirdPost()
      ])));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const paginationTask: Promise<void> = model.loadMorePosts();
      expect(model.topicState.isLoadingMore).assertTrue();
      await model.jumpToTopicPost(2);

      expect(repository.requestedTopicPostNumbers.length).assertEqual(1);
      await paginationTask;
      expect(model.topicState.isLoadingMore).assertFalse();
      expect(model.topicState.posts.length).assertEqual(3);
      done();
    });

    it('falls back to the full Topic response when the final Post batch has no suggestions', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '长 Topic', 100, 3, 0, false, false, true,
          [102728, 102729, 102730], [firstPost()]
        )));
        repository.topicPostResults.push(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([
          secondPost(), thirdPost()
        ])));
        repository.topicSuggestionResults.push(RepositoryResult.success<Array<Topic>>([
          topicWithId(2800, '推荐 Topic')
        ]));
        const model: AppShellModel = new AppShellModel(
          repository,
          new MemoryCategoryCache(),
          CategoryCacheScope.anonymous()
        );

        await model.openTopic(topic());
        await model.loadMorePosts();

        expect(repository.requestedSuggestionTopicIds.join(',')).assertEqual('2725');
        expect(model.topicState.detail?.suggestedTopics[0].id).assertEqual(2800);
        done();
      });

    it('submits a targeted Reply once and appends the created Post', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
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

    it('allows Reply authoring in any Category permitted by the server', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '非创作分区', 10, 1, 0, false, false, true,
        [102728], [firstPost()], 1, new TopicDetailMetadata(54)
      )));
      repository.currentUserResults.push(authenticatedUserResult());
      repository.replySubmitResults.push(ReplySubmitResult.created(fourthPost()));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      model.openReply(null);
      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.EDITING);
      model.updateReplyDraft('允许发布');
      await model.submitReply();

      expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
      expect(repository.submittedReplies.length).assertEqual(1);
      done();
    });

    it('updates a Reaction only after the server returns the authoritative Post', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.reactionResults.push(
        RepositoryResult.unknown<ForumPost>('Reaction 更新失败'),
        RepositoryResult.success<ForumPost>(reactedFirstPost())
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.togglePostReaction(102728, 'heart');
      expect(model.topicState.posts[0].currentUserReaction).assertNull();
      expect(model.topicState.postActionState.message).assertEqual('Reaction 更新失败');

      await model.togglePostReaction(102728, 'heart');
      expect(repository.requestedReactions.join(',')).assertEqual('102728:heart,102728:heart');
      expect(model.topicState.posts[0].currentUserReaction).assertEqual('heart');
      expect(model.topicState.posts[0].likeCount).assertEqual(1);
      expect(model.topicState.postActionState.message).assertEqual('');
      done();
    });

    it('loads Reaction participants for a visible Post and exposes failures', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true,
        [102728], [reactedFirstPost()]
      )));
      repository.reactionUsersResults.push(
        RepositoryResult.success<Array<PostReactionUsers>>([
          new PostReactionUsers('heart', 1, [new PostReactionUser('river_user', '/avatar/{size}.png')])
        ]),
        RepositoryResult.unknown<Array<PostReactionUsers>>('回应用户加载失败')
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.loadPostReactionUsers(102728);
      expect(repository.requestedReactionUserPostIds.join(',')).assertEqual('102728');
      expect(model.topicReactionUsersState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.topicReactionUsersState.items[0].users[0].username).assertEqual('river_user');

      await model.loadPostReactionUsers(102728);
      expect(model.topicReactionUsersState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.topicReactionUsersState.message).assertEqual('回应用户加载失败');
      expect(model.topicReactionUsersState.items[0].id).assertEqual('heart');

      await model.loadPostReactionUsers(999999);
      expect(repository.requestedReactionUserPostIds.length).assertEqual(2);
      done();
    });

    it('keeps bookmark state unchanged on failure and mutates only after success', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Bookmark Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.createBookmarkResults.push(RepositoryResult.success<number>(901));
      repository.deleteBookmarkResults.push(
        RepositoryResult.unknown<boolean>('书签删除失败'),
        RepositoryResult.success<boolean>(true)
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.togglePostBookmark(102728);
      expect(model.topicState.posts[0].bookmarked).assertTrue();
      expect(model.topicState.posts[0].bookmarkId).assertEqual(901);

      await model.togglePostBookmark(102728);
      expect(model.topicState.posts[0].bookmarked).assertTrue();
      expect(model.topicState.postActionState.message).assertEqual('书签删除失败');

      await model.togglePostBookmark(102728);
      expect(repository.requestedDeleteBookmarkIds.join(',')).assertEqual('901,901');
      expect(model.topicState.posts[0].bookmarked).assertFalse();
      expect(model.topicState.posts[0].bookmarkId).assertNull();
      done();
    });

    it('removes a server-deleted Post from the current Topic', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), deletableSecondPost()]
      )));
      repository.deletePostResults.push(RepositoryResult.success<boolean>(true));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.deletePost(102729);

      expect(repository.requestedDeletePostIds[0]).assertEqual(102729);
      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.posts[0].id).assertEqual(102728);
      expect(model.topicState.detail?.postCount).assertEqual(1);
      expect(model.topicState.detail?.postIds.join(',')).assertEqual('102728');
      expect(model.topicState.detail?.posts.length).assertEqual(1);
      expect(model.topicState.postActionState.message).assertEqual('');
      done();
    });

    it('submits a valid Post flag without mutating the visible Post', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Flag Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.flagPostResults.push(RepositoryResult.success<boolean>(true));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const submitted: boolean = await model.flagPost(102728, 7, '需要管理人员查看');

      expect(submitted).assertTrue();
      expect(repository.requestedFlags[0]).assertEqual('102728:7:需要管理人员查看');
      expect(model.topicState.posts.length).assertEqual(1);
      expect(model.topicState.postActionState.message).assertEqual('');
      done();
    });

    it('does not request deletion when the server does not grant canDelete', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), secondPost()]
      )));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.deletePost(102729);

      expect(repository.requestedDeletePostIds.length).assertEqual(0);
      expect(model.topicState.posts.length).assertEqual(2);
      done();
    });

    it('retains a Post and exposes the server message when deletion fails', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), deletableSecondPost()]
      )));
      repository.deletePostResults.push(RepositoryResult.unknown<boolean>('删除失败，请稍后重试'));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.deletePost(102729);

      expect(model.topicState.posts.length).assertEqual(2);
      expect(model.topicState.postActionState.message).assertEqual('删除失败，请稍后重试');
      done();
    });

    it('retains a Post and invalidates the session when deletion returns 401', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), deletableSecondPost()]
      )));
      repository.deletePostResults.push(RepositoryResult.unauthorized<boolean>());
      const lifecycle: TopicAuthenticationLifecycle = new TopicAuthenticationLifecycle();
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous(), lifecycle
      );
      await model.openTopic(topic());

      await model.deletePost(102729);

      expect(model.topicState.posts.length).assertEqual(2);
      expect(model.requiresAuthentication).assertTrue();
      expect(lifecycle.unauthorizedCallCount).assertEqual(1);
      done();
    });

    it('keeps read progress that completes while Post deletion is pending', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), deletableSecondPost()], 2
      )));
      const pendingDelete: PendingRepositoryResult<boolean> = new PendingRepositoryResult<boolean>();
      repository.deletePostTasks.push(pendingDelete.promise);
      repository.markTopicReadResults.push(RepositoryResult.success<boolean>(true));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const deleteTask: Promise<void> = model.deletePost(102729);
      await model.reportTopicReadProgress(1);
      pendingDelete.complete(RepositoryResult.success<boolean>(true));
      await deleteTask;

      expect(model.topicState.detail?.lastReadPostNumber).assertEqual(1);
      expect(model.topicState.detail?.postIds.join(',')).assertEqual('102728');
      done();
    });

    it('keeps a deleted Post removed when read progress completes later', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Delete Topic', 10, 2, 0, false, false, true,
        [102728, 102729], [firstPost(), deletableSecondPost()], 2
      )));
      const pendingRead: PendingRepositoryResult<boolean> = new PendingRepositoryResult<boolean>();
      repository.markTopicReadTasks.push(pendingRead.promise);
      repository.deletePostResults.push(RepositoryResult.success<boolean>(true));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const readTask: Promise<void> = model.reportTopicReadProgress(1);
      await model.deletePost(102729);
      pendingRead.complete(RepositoryResult.success<boolean>(true));
      await readTask;

      expect(model.topicState.detail?.lastReadPostNumber).assertEqual(1);
      expect(model.topicState.detail?.postCount).assertEqual(1);
      expect(model.topicState.detail?.postIds.join(',')).assertEqual('102728');
      done();
    });

    it('changes solution state only after the server confirms accept or unaccept', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '求助 Topic', 10, 2, 0, false, false, true,
          [102728, 102729], [firstPost(), solutionReply(false, true, false)]
        )));
        repository.acceptedAnswerResults.push(
          RepositoryResult.unknown<boolean>('采纳失败'),
          RepositoryResult.success<boolean>(true),
          RepositoryResult.success<boolean>(true)
        );
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );
        await model.openTopic(topic());

        await model.togglePostAcceptedAnswer(102729);
        expect(model.topicState.posts[1].acceptedAnswer).assertFalse();
        expect(model.topicState.posts[1].canAcceptAnswer).assertTrue();
        expect(model.topicState.postActionState.message).assertEqual('采纳失败');

        await model.togglePostAcceptedAnswer(102729);
        expect(model.topicState.posts[1].acceptedAnswer).assertTrue();
        expect(model.topicState.posts[1].canAcceptAnswer).assertFalse();
        expect(model.topicState.posts[1].canUnacceptAnswer).assertTrue();

        await model.togglePostAcceptedAnswer(102729);
        expect(repository.requestedAcceptedAnswers.join(',')).assertEqual(
          '102729:true,102729:true,102729:false'
        );
        expect(model.topicState.posts[1].acceptedAnswer).assertFalse();
        expect(model.topicState.posts[1].canAcceptAnswer).assertTrue();
        expect(model.topicState.posts[1].canUnacceptAnswer).assertFalse();
        done();
      });

    it('honors solution capabilities and routes unauthorized writes through the session lifecycle', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '求助 Topic', 10, 3, 0, false, false, true,
          [102728, 102729, 102730], [
            firstPost(),
            solutionReply(false, false, false),
            new ForumPost(
              102730,
              2,
              'helper',
              '<p>等待采纳</p>',
              '等待采纳',
              3,
              null,
              '2026-01-28T00:01:00Z',
              new ForumPostMetadata('', '', '', null, null, 0, [], null, false, false, false, true, false)
            )
          ]
        )));
        repository.acceptedAnswerResults.push(RepositoryResult.unauthorized<boolean>());
        const lifecycle: TopicAuthenticationLifecycle = new TopicAuthenticationLifecycle();
        const model: AppShellModel = new AppShellModel(
          repository,
          new MemoryCategoryCache(),
          CategoryCacheScope.anonymous(),
          lifecycle
        );
        await model.openTopic(topic());

        await model.togglePostAcceptedAnswer(102729);
        expect(repository.requestedAcceptedAnswers.length).assertEqual(0);

        await model.togglePostAcceptedAnswer(102730);
        expect(repository.requestedAcceptedAnswers.join(',')).assertEqual('102730:true');
        expect(model.topicState.posts[2].acceptedAnswer).assertFalse();
        expect(model.topicState.posts[2].canAcceptAnswer).assertTrue();
        expect(model.requiresAuthentication).assertTrue();
        expect(lifecycle.unauthorizedCallCount).assertEqual(1);
        done();
      });

    it('keeps one trusted solution and does not overlap solution writes with Post pagination', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '求助 Topic', 10, 4, 0, false, false, true,
          [102728, 102729, 102730, 102731], [
            firstPost(),
            solutionReply(true, false, true),
            new ForumPost(
              102730,
              2,
              'helper',
              '<p>更合适的回答</p>',
              '更合适的回答',
              3,
              null,
              '2026-01-28T00:01:00Z',
              new ForumPostMetadata('', '', '', null, null, 0, [], null, false, false, false, true, false)
            )
          ]
        )));
        const pendingSolution: PendingRepositoryResult<boolean> = new PendingRepositoryResult<boolean>();
        repository.acceptedAnswerTasks.push(pendingSolution.promise);
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );
        await model.openTopic(topic());

        const solutionTask: Promise<void> = model.togglePostAcceptedAnswer(102730);
        await model.loadMorePosts();
        expect(repository.requestedPostIds.length).assertEqual(0);
        pendingSolution.complete(RepositoryResult.success<boolean>(true));
        await solutionTask;
        expect(model.topicState.posts[1].acceptedAnswer).assertFalse();
        expect(model.topicState.posts[2].acceptedAnswer).assertTrue();

        const pendingPosts: PendingRepositoryResult<TopicPostBatch> =
          new PendingRepositoryResult<TopicPostBatch>();
        repository.topicPostTasks.push(pendingPosts.promise);
        const paginationTask: Promise<void> = model.loadMorePosts();
        await model.togglePostAcceptedAnswer(102730);
        expect(repository.requestedAcceptedAnswers.join(',')).assertEqual('102730:true');
        pendingPosts.complete(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([fourthPost()])));
        await paginationTask;
        expect(model.topicState.posts[2].acceptedAnswer).assertTrue();
        done();
      });

    it('serializes previous and next Post pagination around solution actions', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      const postIds: Array<number> = [];
      for (let postId: number = 102701; postId <= 102723; postId += 1) {
        postIds.push(postId);
      }
      const candidate: ForumPost = new ForumPost(
        102722,
        2,
        'helper',
        '<p>分页中的回答</p>',
        '分页中的回答',
        22,
        null,
        '2026-01-28T00:01:00Z',
        new ForumPostMetadata('', '', '', null, null, 0, [], null, false, false, false, true, false)
      );
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '求助 Topic', 10, 23, 0, false, false, true, postIds, [candidate]
      )));
      const pendingPrevious: PendingRepositoryResult<TopicPostBatch> =
        new PendingRepositoryResult<TopicPostBatch>();
      repository.topicPostTasks.push(pendingPrevious.promise);
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic(), 22);

      const previousTask: Promise<void> = model.loadPreviousPosts();
      await model.loadMorePosts();
      expect(repository.requestedPostIds.length).assertEqual(1);
      pendingPrevious.complete(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([])));
      await previousTask;

      const pendingNext: PendingRepositoryResult<TopicPostBatch> = new PendingRepositoryResult<TopicPostBatch>();
      repository.topicPostTasks.push(pendingNext.promise);
      const nextTask: Promise<void> = model.loadMorePosts();
      await model.loadPreviousPosts();
      await model.togglePostAcceptedAnswer(102722);
      expect(repository.requestedPostIds.length).assertEqual(2);
      expect(repository.requestedAcceptedAnswers.length).assertEqual(0);
      pendingNext.complete(RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([])));
      await nextTask;
      done();
    });

    it('reports only loaded forward progress and retries without faking a failed read', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '阅读进度', 10, 5, 0, false, false, true,
        [102728, 102729, 102730, 102731, 102732], [firstPost(), secondPost(), thirdPost()]
      )));
      repository.markTopicReadResults.push(
        RepositoryResult.unknown<boolean>('阅读进度同步失败'),
        RepositoryResult.success<boolean>(true)
      );
      repository.clearNotificationResults.push(RepositoryResult.success<number>(2));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      await model.reportTopicReadProgress(5);
      expect(model.topicState.readProgressState.lastReadPostNumber).assertEqual(0);
      expect(model.topicState.readProgressState.message).assertEqual('阅读进度同步失败');

      await model.reportTopicReadProgress(5);
      expect(repository.requestedReadTimings.join('|')).assertEqual(
        '2725:1,2,3:1000|2725:1,2,3:1000'
      );
      expect(model.topicState.readProgressState.lastReadPostNumber).assertEqual(3);
      expect(model.topicState.detail?.lastReadPostNumber).assertEqual(3);
      expect(repository.requestedNotificationProgress.join(',')).assertEqual('2725:3');

      await model.reportTopicReadProgress(2);
      expect(repository.requestedReadTimings.length).assertEqual(2);
      done();
    });

    it('submits the final visible Posts while an earlier read report is still in flight', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '离页阅读进度', 10, 3, 0, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()]
      )));
      const earlierReport: PendingRepositoryResult<boolean> = new PendingRepositoryResult<boolean>();
      repository.markTopicReadTasks.push(earlierReport.promise);
      repository.markTopicReadResults.push(RepositoryResult.success<boolean>(true));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const earlierTask: Promise<void> = model.reportTopicReadProgress(2);
      await model.submitFinalTopicReadProgress(2725, [1, 2, 3]);

      expect(repository.requestedReadTimings.join('|')).assertEqual(
        '2725:1,2:1000|2725:1,2,3:1000'
      );
      earlierReport.complete(RepositoryResult.success<boolean>(true));
      await earlierTask;
      done();
    });

    it('publishes read progress before notification cleanup finishes', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '阅读进度', 10, 5, 0, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
      )));
      repository.markTopicReadResults.push(RepositoryResult.success<boolean>(true));
      const pendingCleanup: PendingRepositoryResult<number> = new PendingRepositoryResult<number>();
      repository.clearNotificationTasks.push(pendingCleanup.promise);
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      let completed: boolean = false;
      const progressTask: Promise<void> = model.reportTopicReadProgress(3);
      progressTask.then((): void => {
        completed = true;
      });
      await Promise.resolve();
      await Promise.resolve();
      await Promise.resolve();

      expect(model.topicState.readProgressState.lastReadPostNumber).assertEqual(3);
      expect(repository.requestedNotificationProgress.join(',')).assertEqual('2725:3');
      expect(completed).assertTrue();

      pendingCleanup.complete(RepositoryResult.success<number>(0));
      await progressTask;
      done();
    });

    it('submits a Reply longer than 1000 characters without imposing a UI-only limit', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '站务管理区重要主题导航', 1959, 3, 4, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
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
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 7,
        new TopicDetailMetadata(111)
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
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
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
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
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
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 0,
        new TopicDetailMetadata(111)
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

    it('prepares an identity-safe quote only when replying across a floor gap', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, '引用语义', 10, 7, 0, false, false, true,
        [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 7,
        new TopicDetailMetadata(111)
      )));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      model.openReply(3);

      expect(model.replyState.replyToPostNumber).assertEqual(3);
      expect(model.replyState.draft).assertEqual(
        '[quote="Co-admin, post:3, topic:2725"]\n第二条 Reply\n[/quote]\n\n'
      );
      done();
    });

    it('restores, saves, and discards the server Reply draft for the active Topic', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '草稿语义', 10, 7, 0, false, false, true,
          [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 7,
          new TopicDetailMetadata(111)
        )));
        repository.draftResults.push(RepositoryResult.success<Array<ServerDraft>>([
          new ServerDraft('topic_2725', 4, 'reply', '', '服务端 Reply 草稿', null, 2725, 3)
        ]));
        repository.savedDraftResults.push(RepositoryResult.success<number>(5));
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );
        await model.openTopic(topic());

        model.openReply(null);
        await model.restoreReplyDraft();
        expect(model.replyState.draft).assertEqual('服务端 Reply 草稿');
        expect(model.replyState.replyToPostNumber).assertEqual(3);

        model.updateReplyDraft('更新后的服务端草稿');
        expect(await model.saveReplyDraft()).assertTrue();
        expect(repository.savedDrafts[0].draftKey).assertEqual('topic_2725');
        expect(repository.savedDrafts[0].sequence).assertEqual(4);

        expect(await model.discardReplyDraft()).assertTrue();
        expect(repository.deletedDrafts[0]).assertEqual('topic_2725:5');
        expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.CLOSED);
        expect(model.replyState.draft).assertEqual('');
        done();
      });

    it('publishes a Reply once and suppresses its stale server draft when cleanup fails', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '草稿清理', 10, 3, 0, false, false, true,
          [102728, 102729, 102730], [firstPost(), secondPost(), thirdPost()], 3,
          new TopicDetailMetadata(111)
        )));
        const staleDraft: ServerDraft = new ServerDraft(
          'topic_2725', 4, 'reply', '', '已发布的 Reply 草稿', null, 2725, null
        );
        repository.draftResults.push(
          RepositoryResult.success<Array<ServerDraft>>([staleDraft]),
          RepositoryResult.success<Array<ServerDraft>>([staleDraft])
        );
        repository.currentUserResults.push(authenticatedUserResult());
        repository.replySubmitResults.push(ReplySubmitResult.created(fourthPost()));
        repository.deletedDraftResults.push(RepositoryResult.unknown<boolean>('网络中断'));
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );
        await model.openTopic(topic());

        model.openReply(null);
        await model.restoreReplyDraft();
        await model.submitReply();
        expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
        expect(model.replyState.message.includes('草稿清理失败')).assertTrue();
        expect(repository.submittedReplies.length).assertEqual(1);

        model.openReply(null);
        await model.restoreReplyDraft();
        expect(model.replyState.draft).assertEqual('');
        done();
      });

    it('restores and retries a rejected new Topic draft in its selected Category', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        repository.draftResults.push(RepositoryResult.success<Array<ServerDraft>>([
          new ServerDraft('new_topic_1720000000', 2, 'createTopic', '课程笔记', '草稿正文', 54, null, null)
        ]));
        repository.topicSubmitResults.push(
          TopicSubmitResult.rejected('标题不符合要求'),
          TopicSubmitResult.created(19139)
        );
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );

        model.openNewTopic();
        await model.restoreTopicDraft();
        expect(model.topicComposerState.title).assertEqual('课程笔记');
        expect(model.topicComposerState.raw).assertEqual('草稿正文');
        expect(model.topicComposerState.categoryId).assertEqual(54);
        expect(model.topicComposerState.draftSequence).assertEqual(2);

        await model.submitTopicComposer();
        expect(model.topicComposerState.kind).assertEqual(TopicComposerStateKind.ERROR);
        expect(model.topicComposerState.title).assertEqual('课程笔记');
        expect(model.topicComposerState.raw).assertEqual('草稿正文');
        expect(repository.submittedTopics[0].categoryId).assertEqual(54);

        await model.submitTopicComposer();
        expect(model.topicComposerState.kind).assertEqual(TopicComposerStateKind.SUCCESS);
        expect(model.topicComposerState.createdTopicId).assertEqual(19139);
        expect(repository.submittedTopics.length).assertEqual(2);
        expect(repository.deletedDrafts[0]).assertEqual('new_topic_1720000000:2');
        done();
      });

    it('restores the first server Topic draft when its sequence is zero', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.draftResults.push(RepositoryResult.success<Array<ServerDraft>>([
        new ServerDraft('new_topic', 0, 'createTopic', '第一份草稿', '尚未同步过的正文', 54, null, null)
      ]));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );

      model.openNewTopic();
      await model.restoreTopicDraft();

      expect(model.topicComposerState.title).assertEqual('第一份草稿');
      expect(model.topicComposerState.raw).assertEqual('尚未同步过的正文');
      expect(model.topicComposerState.categoryId).assertEqual(54);
      expect(model.topicComposerState.draftSequence).assertEqual(0);
      done();
    });

    it('reports new Topic draft cleanup failure without restoring the published draft again', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        const staleDraft: ServerDraft = new ServerDraft(
          'new_topic', 2, 'createTopic', '已发布标题', '已发布正文', 111, null, null
        );
        repository.draftResults.push(
          RepositoryResult.success<Array<ServerDraft>>([staleDraft]),
          RepositoryResult.success<Array<ServerDraft>>([staleDraft])
        );
        repository.topicSubmitResults.push(TopicSubmitResult.created(19139));
        repository.deletedDraftResults.push(RepositoryResult.unknown<boolean>('网络中断'));
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );

        model.openNewTopic();
        await model.restoreTopicDraft();
        await model.submitTopicComposer();
        expect(model.topicComposerState.kind).assertEqual(TopicComposerStateKind.SUCCESS);
        expect(model.topicComposerState.message.includes('草稿清理失败')).assertTrue();

        model.dismissTopicComposer();
        model.openNewTopic();
        await model.restoreTopicDraft();
        expect(model.topicComposerState.title).assertEqual('');
        expect(model.topicComposerState.raw).assertEqual('');
        done();
      });

    it('edits only a Post allowed by the server and keeps rejected edits recoverable', 0,
      async (done: Function) => {
        const repository: TopicReadingRepository = new TopicReadingRepository();
        const editablePost = new ForumPost(
          102729, 1, 'admin', '<p>第一条 Reply</p>', '第一条 Reply', 2, null,
          '2026-01-28T00:00:00Z', new ForumPostMetadata('', '', '', null, null, 0, [], null, true)
        );
        repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
          2725, '编辑许可', 10, 3, 0, false, false, true,
          [102728, 102729, 102730], [firstPost(), editablePost, thirdPost()], 3,
          new TopicDetailMetadata(111)
        )));
        repository.editPostResults.push(
          RepositoryResult.unknown<boolean>('服务器拒绝编辑'),
          RepositoryResult.success<boolean>(true)
        );
        const model: AppShellModel = new AppShellModel(
          repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
        );
        await model.openTopic(topic());

        expect(model.openPostEditor(102730)).assertFalse();
        expect(model.openPostEditor(102729)).assertTrue();
        model.updateReplyDraft('更新后的 Reply');
        await model.submitReply();

        expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.ERROR);
        expect(model.replyState.draft).assertEqual('更新后的 Reply');
        expect(repository.editedPosts.length).assertEqual(1);

        await model.submitReply();
        expect(model.replyState.kind).assertEqual(ReplyComposerStateKind.SUCCESS);
        expect(repository.editedPosts.length).assertEqual(2);
        expect(model.topicState.posts[1].raw).assertEqual('更新后的 Reply');
        done();
      });
  });
}
