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
        await model.navigateToCategory(category());
        expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);
        expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
        expect(model.categories.topicsState.items[0].id).assertEqual(2725);

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
      const firstCategoryLoad: Promise<void> = model.navigateToCategory(category());
      const otherCategory: Category = new Category(61, '游客公告', '25AAE2', '', 2, null, []);
      const secondCategoryLoad: Promise<void> = model.navigateToCategory(otherCategory);
      secondCategory.complete(RepositoryResult.success<Array<Topic>>([topicWithId(3000, '新 Category Topic')]));
      await secondCategoryLoad;
      firstCategory.complete(RepositoryResult.success<Array<Topic>>([topic()]));
      await firstCategoryLoad;

      expect(model.categories.selected?.id).assertEqual(61);
      expect(model.categories.topicsState.items[0].id).assertEqual(3000);

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

      const loading: Promise<void> = model.navigateToCategory(category());
      expect(model.activeDestination).assertEqual(SecondaryDestination.CATEGORY_TOPICS);
      expect(model.categories.topicsState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;
      expect(model.categories.topicsState.kind).assertEqual(BrowseStateKind.ERROR);

      await model.categories.retryTopics();
      expect(repository.requestedCategoryIds.join(',')).assertEqual('60,60');
      expect(model.categories.topicsState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categories.topicsState.items[0].id).assertEqual(2725);

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

  });
}
