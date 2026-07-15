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

        model.topicAuthoring.openNew();
        await model.topicAuthoring.restoreDraft();
        expect(model.topicAuthoring.state.title).assertEqual('课程笔记');
        expect(model.topicAuthoring.state.raw).assertEqual('草稿正文');
        expect(model.topicAuthoring.state.categoryId).assertEqual(54);
        expect(model.topicAuthoring.state.draftSequence).assertEqual(2);

        await model.topicAuthoring.submit();
        expect(model.topicAuthoring.state.kind).assertEqual(TopicComposerStateKind.ERROR);
        expect(model.topicAuthoring.state.title).assertEqual('课程笔记');
        expect(model.topicAuthoring.state.raw).assertEqual('草稿正文');
        expect(repository.submittedTopics[0].categoryId).assertEqual(54);

        await model.topicAuthoring.submit();
        expect(model.topicAuthoring.state.kind).assertEqual(TopicComposerStateKind.SUCCESS);
        expect(model.topicAuthoring.state.createdTopicId).assertEqual(19139);
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

      model.topicAuthoring.openNew();
      await model.topicAuthoring.restoreDraft();

      expect(model.topicAuthoring.state.title).assertEqual('第一份草稿');
      expect(model.topicAuthoring.state.raw).assertEqual('尚未同步过的正文');
      expect(model.topicAuthoring.state.categoryId).assertEqual(54);
      expect(model.topicAuthoring.state.draftSequence).assertEqual(0);
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

        model.topicAuthoring.openNew();
        await model.topicAuthoring.restoreDraft();
        await model.topicAuthoring.submit();
        expect(model.topicAuthoring.state.kind).assertEqual(TopicComposerStateKind.SUCCESS);
        expect(model.topicAuthoring.state.message.includes('草稿清理失败')).assertTrue();

        model.topicAuthoring.dismiss();
        model.topicAuthoring.openNew();
        await model.topicAuthoring.restoreDraft();
        expect(model.topicAuthoring.state.title).assertEqual('');
        expect(model.topicAuthoring.state.raw).assertEqual('');
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
