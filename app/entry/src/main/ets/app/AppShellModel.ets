import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  Category,
  ForumPost,
  PostFlagRequest,
  PostReaction,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicDetailMetadata,
  TopicNotificationLevel,
  TopicPostBatch
} from '../models/ForumModels';
import { DiscoverySettingsStore } from '../settings/DiscoverySettingsStore';
import {
  DraftWriteRequest,
  EditPostRequest,
  ServerDraft,
  autoReplyQuote
} from '../models/AuthoringModels';
import {
  CurrentUser,
  ReplyRecoveryKind,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitKind,
  ReplySubmitResult
} from '../models/ReplyModels';
import { ForumRepository } from '../repositories/ForumRepository';
import {
  CachedMedia,
  MediaUploadResult,
  MediaUploadState,
  appendUploadedImageMarkdown
} from '../models/MediaModels';
import { MediaRepository } from '../repositories/MediaRepository';
import { AuthenticationLifecycle } from './AuthenticationLifecycle';
import {
  BrowseState
} from './BrowseModels';
import {
  HomeSortTabIndex,
  RootDestination,
  rootDestinationForTabIndex,
  SecondaryDestination
} from './ShellNavigationModels';
import {
  ComposerMediaTarget,
  ReplyComposerState,
  ReplyComposerStateKind,
  TopicComposerStateKind
} from './ComposerModels';
import {
  orderPosts,
  replacePost,
  samePostReactionState,
  TopicPostActionKind,
  TopicPostActionState,
  TopicPostJumpState,
  TopicReadProgressState,
  TopicReadState,
  TopicReadStateKind,
  uniquePosts
} from './TopicReadingModels';
import { TopicPostWindow } from './TopicPostWindow';
import { ComposerMediaCoordinator } from './ComposerMediaCoordinator';
import { MediaUploadStateListener } from './MediaUploadCoordinator';
import { DiscoveryCoordinator } from './DiscoveryCoordinator';
import { CategoryBrowseCoordinator } from './CategoryBrowseCoordinator';
import { TopicAuthoringCoordinator } from './TopicAuthoringCoordinator';
import { ForumPoll, ForumPollVote } from '../models/PollModels';

const REACTION_INITIAL_SYNC_DELAY_MS: number = 750;
const REACTION_CONFIRMATION_DELAY_MS: number = 1250;
const REACTION_MAX_SYNC_ATTEMPTS: number = 3;

class TopicNavigationFrame {
  public readonly topic: Topic;
  public readonly requestedPostNumber: number | null;
  public readonly state: TopicReadState;
  public readonly previousPostIds: Array<number>;
  public readonly nextPostIds: Array<number>;
  public readonly returnDestination: SecondaryDestination;

  public constructor(
    topic: Topic,
    requestedPostNumber: number | null,
    state: TopicReadState,
    previousPostIds: Array<number>,
    nextPostIds: Array<number>,
    returnDestination: SecondaryDestination
  ) {
    this.topic = topic;
    this.requestedPostNumber = requestedPostNumber;
    this.state = state;
    this.previousPostIds = previousPostIds.slice();
    this.nextPostIds = nextPostIds.slice();
    this.returnDestination = returnDestination;
  }
}

export class AppShellModel {
  public selectedRoot: RootDestination = RootDestination.HOME;
  public activeDestination: SecondaryDestination = SecondaryDestination.NONE;
  public requiresAuthentication: boolean = false;
  public readonly discovery: DiscoveryCoordinator;
  public readonly categories: CategoryBrowseCoordinator;
  public readonly topicAuthoring: TopicAuthoringCoordinator;
  public topicState: TopicReadState = TopicReadState.initial();
  public topicReactionUsersState: BrowseState<PostReactionUsers> = BrowseState.initial<PostReactionUsers>();
  public replyState: ReplyComposerState = ReplyComposerState.closed();

  private readonly repository: ForumRepository;
  private readonly authenticationLifecycle: AuthenticationLifecycle | null;
  private readonly mediaCoordinator: ComposerMediaCoordinator;
  private previousPostIds: Array<number> = [];
  private nextPostIds: Array<number> = [];
  private topicNavigationStack: Array<TopicNavigationFrame> = [];
  private topicReturnDestination: SecondaryDestination = SecondaryDestination.NONE;
  private selectedTopic: Topic | null = null;
  private selectedTopicPostNumber: number | null = null;
  private topicRequestVersion: number = 0;
  private topicReactionUsersRequestVersion: number = 0;
  private topicReactionMutationVersion: number = 0;
  private replyRequestVersion: number = 0;
  private replyDraftRequestVersion: number = 0;
  private replyDraftSequence: number = 0;
  private replyDraftKey: string = '';
  private ignoredReplyDraftKey: string = '';
  private ignoredReplyDraftSequence: number = 0;

  public constructor(
    repository: ForumRepository,
    categoryCache: CategoryCache,
    categoryCacheScope: CategoryCacheScope,
    authenticationLifecycle: AuthenticationLifecycle | null = null,
    discoverySettingsStore: DiscoverySettingsStore | null = null,
    mediaRepository: MediaRepository | null = null
  ) {
    this.repository = repository;
    this.authenticationLifecycle = authenticationLifecycle;
    this.discovery = new DiscoveryCoordinator(
      repository,
      discoverySettingsStore,
      (isUnauthorized: boolean): void => {
        this.requiresAuthentication = isUnauthorized;
      },
      async (): Promise<void> => {
        await this.notifyUnauthorized(true);
      }
    );
    this.categories = new CategoryBrowseCoordinator(
      repository,
      categoryCache,
      categoryCacheScope,
      (isUnauthorized: boolean): void => {
        this.requiresAuthentication = isUnauthorized;
      },
      async (): Promise<void> => {
        await this.notifyUnauthorized(true);
      }
    );
    this.mediaCoordinator = new ComposerMediaCoordinator(
      mediaRepository,
      (target: ComposerMediaTarget): boolean => this.hasEditableComposer(target),
      (target: ComposerMediaTarget, result: MediaUploadResult): boolean => this.appendComposerMedia(target, result),
      async (): Promise<void> => {
        this.requiresAuthentication = true;
        await this.notifyUnauthorized(true);
      }
    );
    this.topicAuthoring = new TopicAuthoringCoordinator(
      repository,
      (): TopicReadState => this.topicState,
      (state: TopicReadState): void => {
        this.topicState = state;
      },
      (): void => this.mediaCoordinator.beginSession(ComposerMediaTarget.TOPIC),
      (): void => this.mediaCoordinator.endSession(ComposerMediaTarget.TOPIC),
      (required: boolean): void => {
        this.requiresAuthentication = required;
      },
      async (): Promise<void> => this.notifyUnauthorized(true)
    );
  }

  public selectRoot(destination: RootDestination): void {
    this.selectedRoot = destination;
  }

  public selectRootTab(index: number): boolean {
    const destination: RootDestination | null = rootDestinationForTabIndex(index);
    if (destination === null) {
      return false;
    }
    this.selectRoot(destination);
    return true;
  }

  public async navigateToCategory(category: Category): Promise<void> {
    this.activeDestination = SecondaryDestination.CATEGORY_TOPICS;
    await this.categories.open(category);
  }

  public shouldOpenTopicInPlace(topicId: number): boolean {
    return Number.isSafeInteger(topicId) &&
      topicId > 0 &&
      this.activeDestination === SecondaryDestination.TOPIC &&
      this.selectedTopic?.id === topicId &&
      this.topicState.detail !== null &&
      (this.topicState.kind === TopicReadStateKind.CONTENT || this.topicState.kind === TopicReadStateKind.EMPTY);
  }

  public async openTopic(topic: Topic, initialPostNumber: number | null = null): Promise<void> {
    const opensNestedTopic: boolean = this.activeDestination === SecondaryDestination.TOPIC &&
      this.selectedTopic !== null && this.selectedTopic.id !== topic.id;
    if (opensNestedTopic && this.selectedTopic !== null) {
      this.topicNavigationStack.push(new TopicNavigationFrame(
        this.selectedTopic,
        this.selectedTopicPostNumber,
        this.topicState,
        this.previousPostIds,
        this.nextPostIds,
        this.topicReturnDestination
      ));
    }
    const returnDestination: SecondaryDestination = opensNestedTopic
      ? SecondaryDestination.TOPIC
      : this.activeDestination === SecondaryDestination.TOPIC
        ? this.topicReturnDestination
        : this.activeDestination === SecondaryDestination.CATEGORY_TOPICS
          ? SecondaryDestination.CATEGORY_TOPICS
          : SecondaryDestination.NONE;
    this.topicRequestVersion += 1;
    this.topicReactionUsersRequestVersion += 1;
    this.topicReactionUsersState = BrowseState.initial<PostReactionUsers>();
    const requestVersion: number = this.topicRequestVersion;
    this.requiresAuthentication = false;
    this.replyRequestVersion += 1;
    this.replyDraftRequestVersion += 1;
    this.replyDraftSequence = 0;
    this.replyDraftKey = '';
    this.replyState = ReplyComposerState.closed();
    this.selectedTopic = topic;
    this.selectedTopicPostNumber = initialPostNumber;
    this.topicReturnDestination = returnDestination;
    this.activeDestination = SecondaryDestination.TOPIC;
    this.topicState = TopicReadState.loading(topic);
    const result: RepositoryResult<TopicDetail> =
      await this.repository.loadTopicDetail(topic.id, initialPostNumber);
    if (requestVersion !== this.topicRequestVersion || this.selectedTopic?.id !== topic.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.previousPostIds = [];
      this.nextPostIds = [];
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.error(topic, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const window: TopicPostWindow = TopicPostWindow.from(result.data.postIds, result.data.posts);
    this.previousPostIds = window.previousPostIds;
    this.nextPostIds = window.nextPostIds;
    this.topicState = window.posts.length === 0
      ? TopicReadState.empty(result.data, window.hasNextPosts(), false, '', window.hasPreviousPosts())
      : TopicReadState.content(result.data, window.posts, window.hasNextPosts(), false, '', window.hasPreviousPosts());
    const focusedPostNumber: number = initialPostNumber ?? window.posts[0]?.postNumber ?? 1;
    this.topicState = TopicReadState.withPostJump(
      this.topicState,
      TopicPostJumpState.ready(focusedPostNumber)
    );
    if (!window.hasNextPosts() && result.data.suggestedTopics.length === 0) {
      await this.refreshTopicSuggestions(requestVersion);
    }
  }

  public async retryTopic(): Promise<void> {
    const topic: Topic | null = this.selectedTopic;
    if (topic === null) {
      return;
    }
    const returnDestination: SecondaryDestination = this.topicReturnDestination;
    await this.openTopic(topic, this.selectedTopicPostNumber);
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicReturnDestination = returnDestination;
    }
  }

  public async jumpToTopicPost(postNumber: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const topic: Topic | null = this.selectedTopic;
    if (
      detail === null ||
      topic === null ||
      !Number.isSafeInteger(postNumber) ||
      postNumber <= 0 ||
      postNumber > detail.highestPostNumber ||
      this.topicState.isLoadingMore ||
      this.topicState.isLoadingPrevious ||
      this.topicState.isRefreshing ||
      this.topicState.postJumpState.busy ||
      this.topicState.postActionState.busy ||
      (this.topicState.kind !== TopicReadStateKind.CONTENT && this.topicState.kind !== TopicReadStateKind.EMPTY)
    ) {
      return;
    }

    this.topicRequestVersion += 1;
    const requestVersion: number = this.topicRequestVersion;
    this.requiresAuthentication = false;
    this.topicState = TopicReadState.withPostJump(
      this.topicState,
      TopicPostJumpState.loading(postNumber)
    );
    const result: RepositoryResult<TopicDetail> = await this.repository.loadTopicDetail(detail.id, postNumber);
    if (requestVersion !== this.topicRequestVersion || this.selectedTopic?.id !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostJump(
        this.topicState,
        TopicPostJumpState.error(postNumber, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }

    const window: TopicPostWindow = TopicPostWindow.from(result.data.postIds, result.data.posts);
    const targetVisible: boolean = window.posts.some(
      (post: ForumPost): boolean => post.postNumber === postNumber
    );
    if (!targetVisible) {
      this.topicState = TopicReadState.withPostJump(
        this.topicState,
        TopicPostJumpState.error(postNumber, '服务器未返回目标楼层')
      );
      return;
    }

    this.previousPostIds = window.previousPostIds;
    this.nextPostIds = window.nextPostIds;
    this.selectedTopicPostNumber = postNumber;
    const nextState: TopicReadState = TopicReadState.content(
      result.data,
      window.posts,
      window.hasNextPosts(),
      false,
      '',
      window.hasPreviousPosts(),
      false,
      '',
      this.topicState.readProgressState
    );
    this.topicState = TopicReadState.withPostJump(nextState, TopicPostJumpState.ready(postNumber));
    if (!window.hasNextPosts() && result.data.suggestedTopics.length === 0) {
      await this.refreshTopicSuggestions(requestVersion);
    }
  }

  public async retryTopicPostJump(): Promise<void> {
    const targetPostNumber: number = this.topicState.postJumpState.targetPostNumber;
    if (targetPostNumber <= 0 || this.topicState.postJumpState.busy) {
      return;
    }
    await this.jumpToTopicPost(targetPostNumber);
  }

  public async refreshTopic(): Promise<void> {
    const topic: Topic | null = this.selectedTopic;
    const currentState: TopicReadState = this.topicState;
    if (
      topic === null ||
      currentState.detail === null ||
      (currentState.kind !== TopicReadStateKind.CONTENT && currentState.kind !== TopicReadStateKind.EMPTY) ||
      currentState.isRefreshing ||
      currentState.isLoadingMore ||
      currentState.isLoadingPrevious ||
      currentState.postActionState.busy ||
      currentState.readProgressState.busy ||
      currentState.postJumpState.busy
    ) {
      return;
    }

    this.topicRequestVersion += 1;
    const requestVersion: number = this.topicRequestVersion;
    this.requiresAuthentication = false;
    this.topicState = TopicReadState.refreshing(currentState, true);
    const result: RepositoryResult<TopicDetail> = await this.repository.loadTopicDetail(topic.id);
    if (requestVersion !== this.topicRequestVersion || this.selectedTopic?.id !== topic.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.refreshing(this.topicState, false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }

    const window: TopicPostWindow = TopicPostWindow.from(result.data.postIds, result.data.posts);
    this.previousPostIds = window.previousPostIds;
    this.nextPostIds = window.nextPostIds;
    const readProgressState: TopicReadProgressState = TopicReadProgressState.idle(Math.max(
      this.topicState.readProgressState.lastReadPostNumber,
      result.data.lastReadPostNumber
    ));
    const refreshedState: TopicReadState = window.posts.length === 0
      ? TopicReadState.empty(
        result.data, window.hasNextPosts(), false, '', window.hasPreviousPosts(), false, '', readProgressState
      )
      : TopicReadState.content(
        result.data, window.posts, window.hasNextPosts(), false, '', window.hasPreviousPosts(), false, '', readProgressState
      );
    const focusedPostNumber: number = window.posts[0]?.postNumber ?? 1;
    this.selectedTopicPostNumber = null;
    this.topicState = TopicReadState.withPostJump(
      refreshedState,
      TopicPostJumpState.ready(focusedPostNumber)
    );
    if (!window.hasNextPosts() && result.data.suggestedTopics.length === 0) {
      await this.refreshTopicSuggestions(requestVersion);
    }
  }

  public async loadMorePosts(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.topicState.isLoadingMore ||
      this.topicState.isLoadingPrevious ||
      this.topicState.isRefreshing ||
      this.topicState.postJumpState.busy ||
      this.topicState.postActionState.busy ||
      this.nextPostIds.length === 0 ||
      (this.topicState.kind !== TopicReadStateKind.CONTENT && this.topicState.kind !== TopicReadStateKind.EMPTY)
    ) {
      return;
    }

    this.requiresAuthentication = false;
    const requestedPostIds: Array<number> = this.nextPostIds.slice(0, 20);
    const requestVersion: number = this.topicRequestVersion;
    const visiblePosts: Array<ForumPost> = this.topicState.posts;
    this.topicState = TopicReadState.pagination(this.topicState, true, '');
    const result: RepositoryResult<TopicPostBatch> =
      await this.repository.loadTopicPosts(detail.id, requestedPostIds);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.pagination(this.topicState, false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }

    const requestedIds: Set<number> = new Set<number>(requestedPostIds);
    this.nextPostIds = this.nextPostIds.filter((postId: number) => !requestedIds.has(postId));
    const posts: Array<ForumPost> = orderPosts(detail.postIds, visiblePosts.concat(result.data.posts));
    const hasNextPosts: boolean = this.nextPostIds.length > 0;
    const hasPreviousPosts: boolean = this.previousPostIds.length > 0;
    const postJumpState: TopicPostJumpState = this.topicState.postJumpState;
    const updatedDetail: TopicDetail = result.data.suggestedTopics.length > 0
      ? detail.withSuggestedTopics(result.data.suggestedTopics)
      : detail;
    this.topicState = posts.length === 0
      ? TopicReadState.empty(
        updatedDetail, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      )
      : TopicReadState.content(
        updatedDetail, posts, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      );
    this.topicState = TopicReadState.withPostJump(this.topicState, postJumpState);
    if (!hasNextPosts && updatedDetail.suggestedTopics.length === 0) {
      await this.refreshTopicSuggestions(requestVersion);
    }
  }

  public async loadPreviousPosts(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.topicState.isLoadingPrevious ||
      this.topicState.isLoadingMore ||
      this.topicState.isRefreshing ||
      this.topicState.postJumpState.busy ||
      this.topicState.postActionState.busy ||
      this.previousPostIds.length === 0 ||
      (this.topicState.kind !== TopicReadStateKind.CONTENT && this.topicState.kind !== TopicReadStateKind.EMPTY)
    ) {
      return;
    }

    this.requiresAuthentication = false;
    const startIndex: number = Math.max(0, this.previousPostIds.length - 20);
    const requestedPostIds: Array<number> = this.previousPostIds.slice(startIndex);
    const requestVersion: number = this.topicRequestVersion;
    const visiblePosts: Array<ForumPost> = this.topicState.posts;
    this.topicState = TopicReadState.previousPagination(this.topicState, true, '');
    const result: RepositoryResult<TopicPostBatch> =
      await this.repository.loadTopicPosts(detail.id, requestedPostIds);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.previousPagination(this.topicState, false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }

    const requestedIds: Set<number> = new Set<number>(requestedPostIds);
    this.previousPostIds = this.previousPostIds.filter((postId: number) => !requestedIds.has(postId));
    const posts: Array<ForumPost> = orderPosts(detail.postIds, result.data.posts.concat(visiblePosts));
    const hasPreviousPosts: boolean = this.previousPostIds.length > 0;
    const hasNextPosts: boolean = this.nextPostIds.length > 0;
    const postJumpState: TopicPostJumpState = this.topicState.postJumpState;
    this.topicState = posts.length === 0
      ? TopicReadState.empty(
        detail, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      )
      : TopicReadState.content(
        detail, posts, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      );
    this.topicState = TopicReadState.withPostJump(this.topicState, postJumpState);
  }

  public async retryPreviousTopicPosts(): Promise<void> {
    await this.loadPreviousPosts();
  }

  private async refreshTopicSuggestions(requestVersion: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null || detail.suggestedTopics.length > 0) {
      return;
    }
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadTopicSuggestions(detail.id);
    if (
      requestVersion !== this.topicRequestVersion ||
      this.topicState.topicId !== detail.id ||
      !result.isSuccess() ||
      result.data === null ||
      result.data.length === 0
    ) {
      return;
    }
    this.topicState = TopicReadState.withDetail(this.topicState, detail.withSuggestedTopics(result.data));
  }

  public async setTopicNotificationLevel(
    notificationLevel: TopicNotificationLevel
  ): Promise<RepositoryResult<boolean>> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null) {
      return RepositoryResult.invalidInput<boolean>('Topic 尚未加载');
    }
    if (detail.notificationLevel === notificationLevel) {
      return RepositoryResult.success<boolean>(true);
    }
    const requestVersion: number = this.topicRequestVersion;
    const result: RepositoryResult<boolean> =
      await this.repository.setTopicNotificationLevel(detail.id, notificationLevel);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return RepositoryResult.cancelled<boolean>('Topic 已切换');
    }
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
      return result;
    }
    if (result.isSuccess() && result.data === true) {
      const currentDetail: TopicDetail | null = this.topicState.detail;
      if (currentDetail !== null && currentDetail.id === detail.id) {
        this.topicState = TopicReadState.withDetail(
          this.topicState,
          currentDetail.withNotificationLevel(notificationLevel)
        );
      }
    }
    return result;
  }

  public async togglePostReaction(postId: number, reaction: string): Promise<number | null> {
    const detail: TopicDetail | null = this.topicState.detail;
    const normalizedReaction: string = reaction.trim();
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (
      detail === null ||
      post === undefined ||
      normalizedReaction.length === 0 ||
      this.topicState.postActionState.busy ||
      (detail.validReactions.length > 0 && !detail.validReactions.includes(normalizedReaction))
    ) {
      return null;
    }

    this.topicReactionMutationVersion += 1;
    const mutationVersion: number = this.topicReactionMutationVersion;
    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.REACTION, postId)
    );
    const result: RepositoryResult<ForumPost> =
      await this.repository.togglePostReaction(postId, normalizedReaction);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return null;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.REACTION, postId, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return null;
    }
    const optimisticPost: ForumPost = post.withToggledReaction(normalizedReaction);
    this.topicState = TopicReadState.withPosts(this.topicState, replacePost(this.topicState.posts, optimisticPost));
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
    return mutationVersion;
  }

  private waitForReactionSync(delayMilliseconds: number): Promise<void> {
    return new Promise<void>((resolve: () => void): void => {
      setTimeout(resolve, delayMilliseconds);
    });
  }

  private isCurrentReactionMutation(topicId: number, mutationVersion: number): boolean {
    return this.topicState.topicId === topicId &&
      this.topicRequestVersion > 0 &&
      this.topicReactionMutationVersion === mutationVersion;
  }

  private async loadServerPostReactionState(topicId: number, postId: number): Promise<ForumPost | null> {
    const result: RepositoryResult<TopicPostBatch> = await this.repository.loadTopicPosts(topicId, [postId]);
    if (!result.isSuccess() || result.data === null) {
      return null;
    }
    return result.data.posts.find((post: ForumPost): boolean => post.id === postId) ?? null;
  }

  public async reconcilePostReaction(postId: number, mutationVersion: number): Promise<boolean> {
    const topicId: number = this.topicState.topicId;
    if (!this.isCurrentReactionMutation(topicId, mutationVersion)) {
      return false;
    }
    let mismatchCount: number = 0;
    for (let attemptIndex: number = 0; attemptIndex < REACTION_MAX_SYNC_ATTEMPTS; attemptIndex += 1) {
      await this.waitForReactionSync(
        attemptIndex === 0 ? REACTION_INITIAL_SYNC_DELAY_MS : REACTION_CONFIRMATION_DELAY_MS
      );
      if (!this.isCurrentReactionMutation(topicId, mutationVersion)) {
        return false;
      }
      const serverPost: ForumPost | null = await this.loadServerPostReactionState(topicId, postId);
      const currentPost: ForumPost | undefined = this.topicState.posts.find(
        (post: ForumPost): boolean => post.id === postId
      );
      if (currentPost === undefined || !this.isCurrentReactionMutation(topicId, mutationVersion)) {
        return false;
      }
      if (serverPost === null) {
        continue;
      }
      if (samePostReactionState(currentPost, serverPost)) {
        return false;
      }
      mismatchCount += 1;
      if (mismatchCount < 2) {
        continue;
      }
      this.topicState = TopicReadState.withPosts(
        this.topicState,
        replacePost(this.topicState.posts, serverPost)
      );
      return true;
    }
    return false;
  }

  public async loadPostReactionUsers(postId: number): Promise<void> {
    const topicId: number = this.topicState.topicId;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (topicId <= 0 || post === undefined) {
      this.topicReactionUsersState = BrowseState.error<PostReactionUsers>('Post 不在当前 Topic 中');
      return;
    }

    this.topicReactionUsersRequestVersion += 1;
    const requestVersion: number = this.topicReactionUsersRequestVersion;
    this.requiresAuthentication = false;
    this.topicReactionUsersState = BrowseState.loading<PostReactionUsers>();
    const result: RepositoryResult<Array<PostReactionUsers>> = await this.repository.loadPostReactionUsers(postId);
    if (requestVersion !== this.topicReactionUsersRequestVersion || this.topicState.topicId !== topicId) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      if (result.isUnauthorized()) {
        this.topicReactionUsersState = BrowseState.error<PostReactionUsers>(result.message);
        await this.notifyUnauthorized(true);
        return;
      }
      const fallback: Array<PostReactionUsers> = post.reactions.map(
        (reaction: PostReaction): PostReactionUsers => {
          return new PostReactionUsers(reaction.id, reaction.count, []);
        }
      );
      this.topicReactionUsersState = fallback.length === 0
        ? BrowseState.empty<PostReactionUsers>(false, result.message)
        : BrowseState.content<PostReactionUsers>(fallback, false, result.message);
      return;
    }
    this.topicReactionUsersState = result.data.length === 0
      ? BrowseState.empty<PostReactionUsers>()
      : BrowseState.content<PostReactionUsers>(result.data);
  }

  public async votePoll(
    postId: number,
    pollName: string,
    vote: ForumPollVote
  ): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    const poll: ForumPoll | undefined = post?.polls.find(
      (candidate: ForumPoll): boolean => candidate.name === pollName
    );
    if (
      detail === null ||
      post === undefined ||
      poll === undefined ||
      this.topicState.postActionState.busy ||
      !poll.canSubmit(vote)
    ) {
      return;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.POLL, post.id)
    );
    const result: RepositoryResult<ForumPoll> =
      await this.repository.votePoll(post.id, poll.name, vote);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.POLL, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.topicState = TopicReadState.withPosts(
      this.topicState,
      replacePost(this.topicState.posts, post.withPoll(result.data))
    );
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  public async removePollVote(postId: number, pollName: string): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    const poll: ForumPoll | undefined = post?.polls.find(
      (candidate: ForumPoll): boolean => candidate.name === pollName
    );
    if (
      detail === null ||
      post === undefined ||
      poll === undefined ||
      !poll.hasSavedVote() ||
      poll.isClosed() ||
      this.topicState.postActionState.busy
    ) {
      return;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.POLL, post.id)
    );
    const result: RepositoryResult<ForumPoll> =
      await this.repository.removePollVote(post.id, poll.name);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.POLL, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.topicState = TopicReadState.withPosts(
      this.topicState,
      replacePost(this.topicState.posts, post.withPoll(result.data))
    );
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  public async loadPostReplies(
    postId: number,
    afterPostNumber: number
  ): Promise<RepositoryResult<Array<ForumPost>>> {
    const topicId: number = this.topicState.topicId;
    const postVisible: boolean = this.topicState.posts.some(
      (post: ForumPost): boolean => post.id === postId
    );
    if (topicId <= 0 || !postVisible) {
      return RepositoryResult.unavailable<Array<ForumPost>>('Post 不在当前 Topic 中');
    }
    const requestVersion: number = this.topicRequestVersion;
    const result: RepositoryResult<Array<ForumPost>> =
      await this.repository.loadPostReplies(postId, afterPostNumber);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== topicId) {
      return RepositoryResult.cancelled<Array<ForumPost>>('Topic 已切换');
    }
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
    return result;
  }

  public async togglePostAcceptedAnswer(postId: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (
      detail === null ||
      post === undefined ||
      this.topicState.postActionState.busy ||
      this.topicState.isLoadingMore ||
      this.topicState.isLoadingPrevious ||
      this.topicState.isRefreshing ||
      this.topicState.postJumpState.busy
    ) {
      return;
    }
    let accepted: boolean = false;
    if (post.canUnacceptAnswer) {
      accepted = false;
    } else if (post.canAcceptAnswer) {
      accepted = true;
    } else {
      return;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.SOLUTION, post.id)
    );
    const result: RepositoryResult<boolean> = await this.repository.setPostAcceptedAnswer(post.id, accepted);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.SOLUTION, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const updatedPosts: Array<ForumPost> = this.topicState.posts.map((candidate: ForumPost): ForumPost => {
      if (candidate.id === post.id) {
        return candidate.withAcceptedAnswer(accepted);
      }
      if (accepted && candidate.acceptedAnswer) {
        return candidate.withAcceptedAnswer(false);
      }
      return candidate;
    });
    this.topicState = TopicReadState.withPosts(this.topicState, updatedPosts);
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  public async togglePostBookmark(postId: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (detail === null || post === undefined || this.topicState.postActionState.busy) {
      return;
    }
    if (post.bookmarked) {
      await this.deleteBookmark(detail, post);
    } else {
      await this.createBookmark(detail, post);
    }
  }

  public async deletePost(postId: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (detail === null || post === undefined || !post.canDelete || this.topicState.postActionState.busy) {
      return;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.DELETE, post.id)
    );
    const result: RepositoryResult<boolean> = await this.repository.deletePost(post.id);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.DELETE, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const remainingPosts: Array<ForumPost> = this.topicState.posts.filter(
      (candidate: ForumPost): boolean => candidate.id !== post.id
    );
    const currentDetail: TopicDetail = this.topicState.detail ?? detail;
    this.topicState = TopicReadState.withDetailAndPosts(
      this.topicState,
      currentDetail.withoutPost(post.id),
      remainingPosts
    );
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  public async flagPost(postId: number, typeId: number, message: string | null): Promise<boolean> {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (detail === null || post === undefined || this.topicState.postActionState.busy) {
      return false;
    }
    const request: PostFlagRequest | null = PostFlagRequest.create(postId, typeId, message);
    if (request === null) {
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.FLAG, postId, '举报原因无效或缺少具体说明')
      );
      return false;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.FLAG, postId)
    );
    const result: RepositoryResult<boolean> = await this.repository.flagPost(request);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return false;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.FLAG, postId, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return false;
    }
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
    return true;
  }

  private async createBookmark(detail: TopicDetail, post: ForumPost): Promise<void> {
    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.BOOKMARK, post.id)
    );
    const result: RepositoryResult<number> = await this.repository.createPostBookmark(post.id);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.BOOKMARK, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const updatedPost: ForumPost = post.withBookmark(true, result.data);
    this.topicState = TopicReadState.withPosts(this.topicState, replacePost(this.topicState.posts, updatedPost));
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  private async deleteBookmark(detail: TopicDetail, post: ForumPost): Promise<void> {
    if (post.bookmarkId === null) {
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.BOOKMARK, post.id, '书签状态缺少服务端标识，请刷新后重试')
      );
      return;
    }
    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.BOOKMARK, post.id)
    );
    const result: RepositoryResult<boolean> = await this.repository.deletePostBookmark(post.bookmarkId);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.BOOKMARK, post.id, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const updatedPost: ForumPost = post.withBookmark(false, null);
    this.topicState = TopicReadState.withPosts(this.topicState, replacePost(this.topicState.posts, updatedPost));
    this.topicState = TopicReadState.withPostAction(this.topicState, TopicPostActionState.idle());
  }

  public async reportTopicReadProgress(visiblePostNumber: number): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    const currentProgress: TopicReadProgressState = this.topicState.readProgressState;
    if (
      detail === null ||
      currentProgress.busy ||
      !Number.isInteger(visiblePostNumber) ||
      visiblePostNumber <= currentProgress.lastReadPostNumber
    ) {
      return;
    }
    const highestPostNumber: number = detail.highestPostNumber > 0
      ? detail.highestPostNumber
      : visiblePostNumber;
    const safeTarget: number = Math.min(visiblePostNumber, highestPostNumber);
    const postNumbers: Array<number> = this.topicState.posts
      .map((post: ForumPost): number => post.postNumber)
      .filter((postNumber: number): boolean => {
        return postNumber > currentProgress.lastReadPostNumber && postNumber <= safeTarget;
      });
    const uniquePostNumbers: Array<number> = Array.from(new Set<number>(postNumbers).values());
    uniquePostNumbers.sort((left: number, right: number): number => left - right);
    if (uniquePostNumbers.length === 0) {
      return;
    }
    const reportedPostNumber: number = uniquePostNumbers[uniquePostNumbers.length - 1];
    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withReadProgress(
      this.topicState,
      TopicReadProgressState.loading(currentProgress.lastReadPostNumber)
    );
    const result: RepositoryResult<boolean> = await this.repository.markTopicRead(
      detail.id,
      uniquePostNumbers,
      1000
    );
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withReadProgress(
        this.topicState,
        TopicReadProgressState.error(currentProgress.lastReadPostNumber, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const activeDetail: TopicDetail | null = this.topicState.detail;
    if (activeDetail === null || activeDetail.id !== detail.id) {
      return;
    }
    const updatedDetail: TopicDetail = activeDetail.withLastReadPostNumber(reportedPostNumber);
    this.topicState = TopicReadState.withDetail(this.topicState, updatedDetail);
    this.topicState = TopicReadState.withReadProgress(
      this.topicState,
      TopicReadProgressState.idle(reportedPostNumber)
    );
    this.clearTopicNotificationsInBackground(detail.id, reportedPostNumber);
  }

  public async submitFinalTopicReadProgress(topicId: number, postNumbers: Array<number>): Promise<void> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return;
    }
    const normalizedPostNumbers: Array<number> = Array.from(new Set<number>(postNumbers.filter(
      (postNumber: number): boolean => Number.isInteger(postNumber) && postNumber > 0
    )).values());
    normalizedPostNumbers.sort((left: number, right: number): number => left - right);
    if (normalizedPostNumbers.length === 0) {
      return;
    }
    const result: RepositoryResult<boolean> = await this.repository.markTopicRead(
      topicId,
      normalizedPostNumbers,
      1000
    );
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
  }

  private async clearTopicNotificationsInBackground(topicId: number, upToPostNumber: number): Promise<void> {
    const notificationResult: RepositoryResult<number> = await this.repository.clearTopicNotifications(
      topicId,
      upToPostNumber
    );
    if (notificationResult.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
  }

  public async retryTopicPosts(): Promise<void> {
    await this.loadMorePosts();
  }

  public openReply(replyToPostNumber: number | null): void {
    if (
      !this.topicState.canReply ||
      this.topicState.detail === null ||
      this.replyState.isBusy()
    ) {
      return;
    }
    this.mediaCoordinator.beginSession(ComposerMediaTarget.REPLY);
    let draft: string = this.replyState.isEditingPost() ? '' : this.replyState.draft;
    if (replyToPostNumber !== null) {
      const post: ForumPost | undefined = this.topicState.posts.find(
        (candidate: ForumPost): boolean => candidate.postNumber === replyToPostNumber
      );
      if (post !== undefined) {
        draft = autoReplyQuote(post, this.topicState.detail.id, this.topicState.detail.highestPostNumber, draft);
      }
    }
    this.replyDraftRequestVersion += 1;
    this.replyDraftKey = `topic_${this.topicState.detail.id}`;
    this.replyState = ReplyComposerState.editing(draft, replyToPostNumber);
  }

  public openReplyDraft(draft: ServerDraft): boolean {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null || draft.topicId !== detail.id || draft.raw.trim().length === 0) {
      return false;
    }
    this.openReply(draft.replyToPostNumber);
    if (this.replyState.kind !== ReplyComposerStateKind.EDITING) {
      return false;
    }
    this.replyDraftKey = draft.draftKey;
    this.replyDraftSequence = draft.sequence;
    this.replyState = ReplyComposerState.editing(draft.raw, draft.replyToPostNumber);
    return true;
  }

  public openPostEditor(postId: number): boolean {
    const detail: TopicDetail | null = this.topicState.detail;
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (
      detail === null ||
      post === undefined ||
      !post.canEdit ||
      this.replyState.isBusy()
    ) {
      return false;
    }
    if (post.postNumber === 1) {
      if (!detail.canEdit) {
        return false;
      }
      this.topicAuthoring.openEditor(detail, post);
      return true;
    }
    this.mediaCoordinator.beginSession(ComposerMediaTarget.REPLY);
    this.replyState = ReplyComposerState.editingPost(post.id, post.raw);
    return true;
  }

  public updateReplyDraft(draft: string): void {
    if (
      this.replyState.kind !== ReplyComposerStateKind.EDITING &&
      this.replyState.kind !== ReplyComposerStateKind.ERROR
    ) {
      return;
    }
    this.replyState = this.replyState.editingPostId === null
      ? ReplyComposerState.editing(draft, this.replyState.replyToPostNumber)
      : ReplyComposerState.editingPost(this.replyState.editingPostId, draft);
  }

  public async uploadComposerMedia(
    media: CachedMedia,
    target: ComposerMediaTarget,
    onStateChange: MediaUploadStateListener
  ): Promise<MediaUploadState> {
    return this.mediaCoordinator.upload(media, target, onStateChange);
  }

  public cancelComposerMediaUpload(): void {
    this.mediaCoordinator.cancelUpload();
  }

  private hasEditableComposer(target: ComposerMediaTarget): boolean {
    if (target === ComposerMediaTarget.REPLY) {
      return this.replyState.kind === ReplyComposerStateKind.EDITING ||
        this.replyState.kind === ReplyComposerStateKind.ERROR;
    }
    return this.topicAuthoring.state.kind === TopicComposerStateKind.EDITING ||
      this.topicAuthoring.state.kind === TopicComposerStateKind.ERROR;
  }

  private appendComposerMedia(target: ComposerMediaTarget, result: MediaUploadResult): boolean {
    if (target === ComposerMediaTarget.REPLY && (
      this.replyState.kind === ReplyComposerStateKind.EDITING ||
      this.replyState.kind === ReplyComposerStateKind.ERROR
    )) {
      this.updateReplyDraft(appendUploadedImageMarkdown(this.replyState.draft, result));
      return true;
    }
    if (target === ComposerMediaTarget.TOPIC) {
      return this.topicAuthoring.appendMedia(result);
    }
    return false;
  }

  public dismissReply(): void {
    if (this.replyState.isBusy()) {
      return;
    }
    this.mediaCoordinator.endSession(ComposerMediaTarget.REPLY);
    this.replyState = ReplyComposerState.closed(
      this.replyState.draft,
      this.replyState.replyToPostNumber
    );
  }

  public async restoreReplyDraft(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.replyState.kind !== ReplyComposerStateKind.EDITING ||
      this.replyState.isEditingPost()
    ) {
      return;
    }
    const requestVersion: number = this.replyDraftRequestVersion;
    const draft: string = this.replyState.draft;
    const replyToPostNumber: number | null = this.replyState.replyToPostNumber;
    const result: RepositoryResult<Array<ServerDraft>> = await this.repository.loadDrafts();
    if (
      requestVersion !== this.replyDraftRequestVersion ||
      this.topicState.topicId !== detail.id ||
      this.replyState.draft !== draft ||
      this.replyState.replyToPostNumber !== replyToPostNumber
    ) {
      return;
    }
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.replyState = ReplyComposerState.reauthenticate(draft, replyToPostNumber);
      await this.notifyUnauthorized(true);
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.replyState = ReplyComposerState.error(draft, replyToPostNumber, result.message);
      return;
    }
    const serverDraft: ServerDraft | undefined = result.data.find(
      (candidate: ServerDraft): boolean => candidate.draftKey === `topic_${detail.id}` &&
        (candidate.topicId === null || candidate.topicId === detail.id) &&
        (candidate.draftKey !== this.ignoredReplyDraftKey ||
          candidate.sequence !== this.ignoredReplyDraftSequence)
    );
    if (serverDraft !== undefined) {
      this.replyDraftKey = serverDraft.draftKey;
      this.replyDraftSequence = serverDraft.sequence;
      this.replyState = ReplyComposerState.editing(serverDraft.raw, serverDraft.replyToPostNumber);
    }
  }

  public async saveReplyDraft(): Promise<boolean> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null || this.replyState.isBusy() || this.replyState.isEditingPost()) {
      return false;
    }
    const request: DraftWriteRequest | null = DraftWriteRequest.reply(
      detail.id,
      this.replyState.draft,
      this.replyState.replyToPostNumber,
      this.replyDraftSequence,
      this.replyDraftKey.length > 0 ? this.replyDraftKey : `topic_${detail.id}`
    );
    if (request === null) {
      this.replyState = ReplyComposerState.error(
        this.replyState.draft,
        this.replyState.replyToPostNumber,
        '草稿内容为空'
      );
      return false;
    }
    const result: RepositoryResult<number> = await this.repository.saveDraft(request);
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.replyState = ReplyComposerState.reauthenticate(request.raw, request.replyToPostNumber);
      await this.notifyUnauthorized(true);
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.replyState = ReplyComposerState.error(request.raw, request.replyToPostNumber, result.message);
      return false;
    }
    this.replyDraftSequence = result.data;
    this.ignoredReplyDraftKey = '';
    this.ignoredReplyDraftSequence = 0;
    this.replyState = ReplyComposerState.editing(request.raw, request.replyToPostNumber);
    return true;
  }

  public async discardReplyDraft(): Promise<boolean> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail !== null && this.replyDraftSequence > 0) {
      const result: RepositoryResult<boolean> = await this.repository.deleteDraft(
        this.replyDraftKey.length > 0 ? this.replyDraftKey : `topic_${detail.id}`,
        this.replyDraftSequence
      );
      if (result.isUnauthorized()) {
        this.requiresAuthentication = true;
        this.replyState = ReplyComposerState.reauthenticate(
          this.replyState.draft,
          this.replyState.replyToPostNumber
        );
        await this.notifyUnauthorized(true);
        return false;
      }
      if (!result.isSuccess() || result.data !== true) {
        this.replyState = ReplyComposerState.error(
          this.replyState.draft,
          this.replyState.replyToPostNumber,
          result.message
        );
        return false;
      }
    }
    this.replyDraftRequestVersion += 1;
    this.replyDraftSequence = 0;
    this.ignoredReplyDraftKey = '';
    this.ignoredReplyDraftSequence = 0;
    this.mediaCoordinator.endSession(ComposerMediaTarget.REPLY);
    this.replyState = ReplyComposerState.closed();
    return true;
  }

  public resumeReplyAfterAuthentication(): void {
    if (this.replyState.kind !== ReplyComposerStateKind.REAUTHENTICATE) {
      return;
    }
    this.requiresAuthentication = false;
    this.replyState = this.replyState.editingPostId === null
      ? ReplyComposerState.editing(this.replyState.draft, this.replyState.replyToPostNumber)
      : ReplyComposerState.editingPost(this.replyState.editingPostId, this.replyState.draft);
  }

  public async submitReply(
    onStateChange: (state: ReplyComposerState) => void = (_state: ReplyComposerState): void => {}
  ): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.replyState.isBusy() ||
      (this.replyState.editingPostId === null && !this.topicState.canReply)
    ) {
      return;
    }
    if (this.replyState.editingPostId !== null) {
      await this.submitPostEdit(onStateChange);
      return;
    }
    const request: ReplyRequest | null = ReplyRequest.create(
      detail.id,
      this.replyState.draft,
      this.replyState.replyToPostNumber
    );
    if (request === null) {
      this.transitionReplyState(ReplyComposerState.error(
        this.replyState.draft,
        this.replyState.replyToPostNumber,
        '请输入 Reply 内容'
      ), onStateChange);
      return;
    }

    this.replyRequestVersion += 1;
    const requestVersion: number = this.replyRequestVersion;
    const replyToPostNumber: number | null = request.replyToPostNumber;
    const expectedPostNumber: number = this.nextExpectedPostNumber(detail);
    this.requiresAuthentication = false;
    this.transitionReplyState(ReplyComposerState.submitting(request.raw, replyToPostNumber), onStateChange);

    const userResult: RepositoryResult<CurrentUser> = await this.repository.loadCurrentUser();
    if (!this.isCurrentReplyRequest(requestVersion, detail.id)) {
      return;
    }
    if (!userResult.isSuccess() || userResult.data === null) {
      if (userResult.isUnauthorized()) {
        await this.handleReplyUnauthorized(request.raw, replyToPostNumber, onStateChange);
      } else {
        this.transitionReplyState(
          ReplyComposerState.error(request.raw, replyToPostNumber, userResult.message),
          onStateChange
        );
      }
      return;
    }

    const submitResult: ReplySubmitResult = await this.repository.submitReply(request);
    if (!this.isCurrentReplyRequest(requestVersion, detail.id)) {
      return;
    }
    if (submitResult.kind === ReplySubmitKind.CREATED && submitResult.post !== null) {
      await this.completeReply(submitResult.post, onStateChange);
      return;
    }
    if (submitResult.kind === ReplySubmitKind.UNAUTHORIZED) {
      await this.handleReplyUnauthorized(request.raw, replyToPostNumber, onStateChange);
      return;
    }
    if (submitResult.kind === ReplySubmitKind.REJECTED) {
      this.transitionReplyState(
        ReplyComposerState.error(request.raw, replyToPostNumber, submitResult.message),
        onStateChange
      );
      return;
    }

    const recoveryRequest: ReplyRecoveryRequest | null = ReplyRecoveryRequest.create(
      request,
      expectedPostNumber,
      userResult.data
    );
    if (recoveryRequest === null) {
      this.transitionReplyState(ReplyComposerState.error(
        request.raw,
        replyToPostNumber,
        '无法确认 Reply 是否已创建，请检查 Topic 后再显式重试'
      ), onStateChange);
      return;
    }
    this.transitionReplyState(ReplyComposerState.checking(request.raw, replyToPostNumber), onStateChange);
    const recoveryResult: ReplyRecoveryResult = await this.repository.recoverReply(recoveryRequest);
    if (!this.isCurrentReplyRequest(requestVersion, detail.id)) {
      return;
    }
    if (recoveryResult.kind === ReplyRecoveryKind.CONFIRMED && recoveryResult.post !== null) {
      await this.completeReply(recoveryResult.post, onStateChange);
    } else if (recoveryResult.kind === ReplyRecoveryKind.UNAUTHORIZED) {
      await this.handleReplyUnauthorized(request.raw, replyToPostNumber, onStateChange);
    } else {
      this.transitionReplyState(
        ReplyComposerState.error(request.raw, replyToPostNumber, recoveryResult.message),
        onStateChange
      );
    }
  }

  private async submitPostEdit(onStateChange: (state: ReplyComposerState) => void): Promise<void> {
    const postId: number | null = this.replyState.editingPostId;
    const request: EditPostRequest | null = postId === null
      ? null
      : EditPostRequest.create(postId, this.replyState.draft);
    if (request === null) {
      this.transitionReplyState(
        ReplyComposerState.error(this.replyState.draft, null, '请输入 Post 内容', postId),
        onStateChange
      );
      return;
    }
    this.transitionReplyState(ReplyComposerState.submitting(request.raw, null, postId), onStateChange);
    const result: RepositoryResult<boolean> = await this.repository.editPost(request);
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.transitionReplyState(ReplyComposerState.reauthenticate(request.raw, null, undefined, postId), onStateChange);
      await this.notifyUnauthorized(true);
      return;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.transitionReplyState(ReplyComposerState.error(request.raw, null, result.message, postId), onStateChange);
      return;
    }
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (post !== undefined) {
      this.topicState = TopicReadState.withPosts(this.topicState, replacePost(
        this.topicState.posts,
        post.withRawContent(request.raw)
      ));
    }
    this.transitionReplyState(ReplyComposerState.success('Post 已保存'), onStateChange);
  }

  public closeSecondary(): void {
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicRequestVersion += 1;
      this.topicReactionUsersRequestVersion += 1;
      this.topicReactionUsersState = BrowseState.initial<PostReactionUsers>();
      this.replyRequestVersion += 1;
      const previousTopic: TopicNavigationFrame | undefined = this.topicNavigationStack.pop();
      if (previousTopic !== undefined) {
        this.activeDestination = SecondaryDestination.TOPIC;
        this.topicReturnDestination = previousTopic.returnDestination;
        this.selectedTopic = previousTopic.topic;
        this.selectedTopicPostNumber = previousTopic.requestedPostNumber;
        this.topicState = previousTopic.state;
        this.previousPostIds = previousTopic.previousPostIds.slice();
        this.nextPostIds = previousTopic.nextPostIds.slice();
        return;
      }
      this.activeDestination = this.topicReturnDestination;
      this.topicReturnDestination = SecondaryDestination.NONE;
    } else {
      this.categories.close();
      this.activeDestination = SecondaryDestination.NONE;
    }
    this.previousPostIds = [];
    this.nextPostIds = [];
    this.selectedTopicPostNumber = null;
  }

  private nextExpectedPostNumber(detail: TopicDetail): number {
    let highestPostNumber: number = detail.highestPostNumber;
    for (const post of this.topicState.posts) {
      highestPostNumber = Math.max(highestPostNumber, post.postNumber);
    }
    return highestPostNumber + 1;
  }

  private isCurrentReplyRequest(requestVersion: number, topicId: number): boolean {
    return requestVersion === this.replyRequestVersion && this.topicState.topicId === topicId;
  }

  private transitionReplyState(
    state: ReplyComposerState,
    onStateChange: (state: ReplyComposerState) => void
  ): void {
    this.replyState = state;
    onStateChange(state);
  }

  private async handleReplyUnauthorized(
    draft: string,
    replyToPostNumber: number | null,
    onStateChange: (state: ReplyComposerState) => void
  ): Promise<void> {
    this.requiresAuthentication = true;
    this.transitionReplyState(ReplyComposerState.reauthenticate(draft, replyToPostNumber), onStateChange);
    await this.notifyUnauthorized(true);
  }

  private async completeReply(
    post: ForumPost,
    onStateChange: (state: ReplyComposerState) => void
  ): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null) {
      return;
    }
    const postIds: Array<number> = detail.postIds.includes(post.id)
      ? detail.postIds
      : detail.postIds.concat([post.id]);
    const detailPosts: Array<ForumPost> = uniquePosts(detail.posts.concat([post]));
    const updatedDetail: TopicDetail = new TopicDetail(
      detail.id,
      detail.title,
      detail.viewCount,
      Math.max(detail.postCount, post.postNumber),
      detail.likeCount,
      detail.closed,
      detail.archived,
      detail.canReply,
      postIds,
      detailPosts,
      Math.max(detail.highestPostNumber, post.postNumber),
      new TopicDetailMetadata(
        detail.categoryId,
        detail.canEdit,
        detail.authorUsername,
        detail.validReactions,
        detail.suggestedTopics,
        detail.lastReadPostNumber,
        detail.notificationLevel,
        detail.notificationReasonId
      )
    );
    const visiblePosts: Array<ForumPost> = uniquePosts(this.topicState.posts.concat([post]));
    this.topicState = TopicReadState.content(
      updatedDetail,
      visiblePosts,
      this.topicState.hasNextPosts,
      false,
      this.topicState.paginationMessage,
      this.topicState.hasPreviousPosts,
      false,
      this.topicState.previousPaginationMessage,
      this.topicState.readProgressState
    );
    const sequence: number = this.replyDraftSequence;
    if (sequence > 0) {
      const draftKey: string = this.replyDraftKey.length > 0 ? this.replyDraftKey : `topic_${detail.id}`;
      const result: RepositoryResult<boolean> = await this.repository.deleteDraft(draftKey, sequence);
      if (!result.isSuccess() || result.data !== true) {
        this.ignoredReplyDraftKey = draftKey;
        this.ignoredReplyDraftSequence = sequence;
        this.replyDraftSequence = 0;
        this.transitionReplyState(
          ReplyComposerState.success(`Reply 已发布；服务器草稿清理失败：${result.message}`),
          onStateChange
        );
        return;
      }
    }
    this.replyDraftSequence = 0;
    this.replyDraftKey = '';
    this.ignoredReplyDraftKey = '';
    this.ignoredReplyDraftSequence = 0;
    this.transitionReplyState(ReplyComposerState.success('Reply 已发布'), onStateChange);
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> = await this.repository.loadCurrentUser();
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
      return result;
    }
    if (!result.isSuccess() || result.data === null || result.data.defaultHomeChannel !== null) {
      return result;
    }
    const profileResult: RepositoryResult<CurrentUser> =
      await this.repository.loadUserProfile(result.data.username);
    if (profileResult.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
      return profileResult;
    }
    if (profileResult.isSuccess() && profileResult.data?.defaultHomeChannel !== null &&
      profileResult.data?.defaultHomeChannel !== undefined) {
      return RepositoryResult.success<CurrentUser>(
        result.data.withDefaultHomeChannel(profileResult.data.defaultHomeChannel)
      );
    }
    return result;
  }

  public async loadUserProfile(username: string): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> = await this.repository.loadUserProfile(username);
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
    return result;
  }

  private async notifyUnauthorized(isUnauthorized: boolean): Promise<void> {
    if (!isUnauthorized || this.authenticationLifecycle === null) {
      return;
    }
    await this.authenticationLifecycle.handleUnauthorized();
  }
}
