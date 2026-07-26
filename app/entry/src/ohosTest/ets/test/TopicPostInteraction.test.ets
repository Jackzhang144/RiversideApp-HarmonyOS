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

export default function topicPostInteractionTest(): void {
  describe('AppShell Topic post interaction', () => {
    it('applies a successful Reaction response to local state immediately', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.reactionResults.push(
        RepositoryResult.unknown<ForumPost>('Reaction 更新失败'),
        RepositoryResult.success<ForumPost>(firstPost())
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

    it('keeps an optimistic Reaction when server reconciliation agrees', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.reactionResults.push(RepositoryResult.success<ForumPost>(firstPost()));
      repository.topicPostResults.push(
        RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([reactedFirstPost()]))
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const mutationVersion: number | null = await model.togglePostReaction(102728, 'heart');
      expect(model.topicState.posts[0].currentUserReaction).assertEqual('heart');
      expect(mutationVersion === null).assertFalse();
      const corrected: boolean = await model.reconcilePostReaction(102728, mutationVersion ?? 0);

      expect(corrected).assertFalse();
      expect(repository.requestedPostIds.length).assertEqual(1);
      expect(model.topicState.posts[0].currentUserReaction).assertEqual('heart');
      done();
    });

    it('retries a failed silent Reaction sync without rolling back local state', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.reactionResults.push(RepositoryResult.success<ForumPost>(firstPost()));
      repository.topicPostResults.push(
        RepositoryResult.network<TopicPostBatch>('临时断网'),
        RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([reactedFirstPost()]))
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const mutationVersion: number | null = await model.togglePostReaction(102728, 'heart');
      const corrected: boolean = await model.reconcilePostReaction(102728, mutationVersion ?? 0);

      expect(corrected).assertFalse();
      expect(repository.requestedPostIds.length).assertEqual(2);
      expect(model.topicState.posts[0].currentUserReaction).assertEqual('heart');
      done();
    });

    it('restores confirmed server Reaction state after two mismatches', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reaction Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.reactionResults.push(RepositoryResult.success<ForumPost>(reactedFirstPost()));
      repository.topicPostResults.push(
        RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([firstPost()])),
        RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([firstPost()]))
      );
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const mutationVersion: number | null = await model.togglePostReaction(102728, 'heart');
      expect(model.topicState.posts[0].currentUserReaction).assertEqual('heart');
      const corrected: boolean = await model.reconcilePostReaction(102728, mutationVersion ?? 0);

      expect(corrected).assertTrue();
      expect(repository.requestedPostIds.length).assertEqual(2);
      expect(model.topicState.posts[0].currentUserReaction).assertNull();
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

    it('loads direct Reply pages only for Posts in the active Topic', 0, async (done: Function) => {
      const repository: TopicReadingRepository = new TopicReadingRepository();
      repository.topicDetailResults.push(RepositoryResult.success<TopicDetail>(new TopicDetail(
        2725, 'Reply thread Topic', 10, 1, 0, false, false, true, [102728], [firstPost()]
      )));
      repository.postReplyResults.push(RepositoryResult.success<Array<ForumPost>>([secondPost()]));
      const model: AppShellModel = new AppShellModel(
        repository, new MemoryCategoryCache(), CategoryCacheScope.anonymous()
      );
      await model.openTopic(topic());

      const result: RepositoryResult<Array<ForumPost>> = await model.loadPostReplies(102728, 1);
      const missing: RepositoryResult<Array<ForumPost>> = await model.loadPostReplies(999999, 1);

      expect(result.isSuccess()).assertTrue();
      expect(result.data?.[0].postNumber).assertEqual(2);
      expect(repository.requestedPostReplies.join(',')).assertEqual('102728:1');
      expect(missing.isSuccess()).assertFalse();
      expect(missing.message).assertEqual('Post 不在当前 Topic 中');
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
  });
}
