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
import {
  PendingRepositoryResult,
  TopicAuthenticationLifecycle,
  TopicReadingRepository,
  authenticatedUserResult,
  category,
  deletableSecondPost,
  firstPost,
  fourthPost,
  reactedFirstPost,
  secondPost,
  solutionReply,
  thirdPost,
  topic,
  topicWithId
} from './support/TopicReadingTestFixtures';

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

  });
}
