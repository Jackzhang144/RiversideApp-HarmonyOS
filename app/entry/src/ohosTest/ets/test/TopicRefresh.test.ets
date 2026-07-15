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


export default function topicRefreshTest(): void {
  describe('AppShell Topic refresh and floor targeting', () => {
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

  });
}
