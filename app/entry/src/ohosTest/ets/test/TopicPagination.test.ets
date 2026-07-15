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


export default function topicPaginationTest(): void {
  describe('AppShell Topic pagination', () => {
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
