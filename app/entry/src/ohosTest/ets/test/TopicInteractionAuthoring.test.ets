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

export default function topicInteractionAuthoringTest(): void {
  describe('AppShell Topic interaction and authoring', () => {
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
