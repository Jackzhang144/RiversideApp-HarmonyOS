import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import {
  ForumSearchResult,
  HomeChannel,
  homeChannelFromIndex,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../models/DiscoveryModels';
import { DiscoverySettings, DiscoverySettingsStore } from '../settings/DiscoverySettingsStore';
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

export interface AuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}

export enum RootDestination {
  HOME = 0,
  CATEGORY = 1,
  ACCOUNT = 2
}

export enum RootTabIndex {
  HOME = 0,
  CATEGORY = 1,
  CHAT = 2,
  NOTIFICATIONS = 3,
  ACCOUNT = 4
}

export enum HomeSortTabIndex {
  LATEST_REPLIES = 0,
  LATEST_CREATED = 1,
  UNREAD = 2,
  HOT = 3,
  FEATURED = 4
}

export function isHomeSortTabAvailable(index: number): boolean {
  return Number.isInteger(index) && index >= HomeSortTabIndex.LATEST_REPLIES &&
    index <= HomeSortTabIndex.FEATURED;
}

export function rootDestinationForTabIndex(index: number): RootDestination | null {
  if (index === RootTabIndex.HOME) {
    return RootDestination.HOME;
  }
  if (index === RootTabIndex.CATEGORY) {
    return RootDestination.CATEGORY;
  }
  if (index === RootTabIndex.ACCOUNT) {
    return RootDestination.ACCOUNT;
  }
  return null;
}

export enum BrowseStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
}

export enum SearchStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
}

export enum SecondaryDestination {
  NONE = 'none',
  CATEGORY_TOPICS = 'category-topics',
  TOPIC = 'topic'
}

export enum TopicReadStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
}

export enum ReplyComposerStateKind {
  CLOSED = 'closed',
  EDITING = 'editing',
  SUBMITTING = 'submitting',
  CHECKING = 'checking',
  ERROR = 'error',
  REAUTHENTICATE = 'reauthenticate',
  SUCCESS = 'success'
}

export class ReplyComposerState {
  public readonly kind: ReplyComposerStateKind;
  public readonly draft: string;
  public readonly replyToPostNumber: number | null;
  public readonly message: string;

  private constructor(
    kind: ReplyComposerStateKind,
    draft: string,
    replyToPostNumber: number | null,
    message: string
  ) {
    this.kind = kind;
    this.draft = draft;
    this.replyToPostNumber = replyToPostNumber;
    this.message = message;
  }

  public static closed(draft: string = '', replyToPostNumber: number | null = null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.CLOSED, draft, replyToPostNumber, '');
  }

  public static editing(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.EDITING, draft, replyToPostNumber, '');
  }

  public static submitting(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.SUBMITTING, draft, replyToPostNumber, '正在提交 Reply');
  }

  public static checking(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.CHECKING,
      draft,
      replyToPostNumber,
      '正在确认 Reply 是否已创建'
    );
  }

  public static error(draft: string, replyToPostNumber: number | null, message: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.ERROR, draft, replyToPostNumber, message);
  }

  public static reauthenticate(
    draft: string,
    replyToPostNumber: number | null,
    message: string = '登录已失效，重新登录后可继续提交'
  ): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.REAUTHENTICATE, draft, replyToPostNumber, message);
  }

  public static success(message: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.SUCCESS, '', null, message);
  }

  public isBusy(): boolean {
    return this.kind === ReplyComposerStateKind.SUBMITTING || this.kind === ReplyComposerStateKind.CHECKING;
  }
}

export class TopicReadState {
  public readonly kind: TopicReadStateKind;
  public readonly topicId: number;
  public readonly title: string;
  public readonly detail: TopicDetail | null;
  public readonly posts: Array<ForumPost>;
  public readonly canReply: boolean;
  public readonly message: string;
  public readonly hasMorePosts: boolean;
  public readonly isLoadingMore: boolean;
  public readonly paginationMessage: string;

  private constructor(
    kind: TopicReadStateKind,
    topicId: number,
    title: string,
    detail: TopicDetail | null,
    posts: Array<ForumPost>,
    canReply: boolean,
    message: string,
    hasMorePosts: boolean,
    isLoadingMore: boolean,
    paginationMessage: string
  ) {
    this.kind = kind;
    this.topicId = topicId;
    this.title = title;
    this.detail = detail;
    this.posts = posts;
    this.canReply = canReply;
    this.message = message;
    this.hasMorePosts = hasMorePosts;
    this.isLoadingMore = isLoadingMore;
    this.paginationMessage = paginationMessage;
  }

  public static initial(): TopicReadState {
    return new TopicReadState(TopicReadStateKind.INITIAL, 0, '', null, [], false, '', false, false, '');
  }

  public static loading(topic: Topic): TopicReadState {
    return new TopicReadState(TopicReadStateKind.LOADING, topic.id, topic.title, null, [], false, '', false, false, '');
  }

  public static content(
    detail: TopicDetail,
    posts: Array<ForumPost>,
    hasMorePosts: boolean = false,
    isLoadingMore: boolean = false,
    paginationMessage: string = ''
  ): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.CONTENT,
      detail.id,
      detail.title,
      detail,
      posts,
      detail.canReply,
      '',
      hasMorePosts,
      isLoadingMore,
      paginationMessage
    );
  }

  public static empty(
    detail: TopicDetail,
    hasMorePosts: boolean = false,
    isLoadingMore: boolean = false,
    paginationMessage: string = ''
  ): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.EMPTY,
      detail.id,
      detail.title,
      detail,
      [],
      detail.canReply,
      '',
      hasMorePosts,
      isLoadingMore,
      paginationMessage
    );
  }

  public static error(topic: Topic, message: string): TopicReadState {
    return new TopicReadState(TopicReadStateKind.ERROR, topic.id, topic.title, null, [], false, message, false, false, '');
  }

  public static pagination(state: TopicReadState, isLoadingMore: boolean, paginationMessage: string): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasMorePosts,
      isLoadingMore,
      paginationMessage
    );
  }
}

function uniquePosts(posts: Array<ForumPost>): Array<ForumPost> {
  const seenIds: Set<number> = new Set<number>();
  const unique: Array<ForumPost> = [];
  for (const post of posts) {
    if (!seenIds.has(post.id)) {
      seenIds.add(post.id);
      unique.push(post);
    }
  }
  return unique;
}

export class BrowseState<T> {
  public readonly kind: BrowseStateKind;
  public readonly items: Array<T>;
  public readonly message: string;
  public readonly isRefreshing: boolean;
  public readonly hasMore: boolean;
  public readonly isLoadingMore: boolean;
  public readonly paginationMessage: string;

  private constructor(
    kind: BrowseStateKind,
    items: Array<T>,
    message: string,
    isRefreshing: boolean,
    hasMore: boolean,
    isLoadingMore: boolean,
    paginationMessage: string
  ) {
    this.kind = kind;
    this.items = items;
    this.message = message;
    this.isRefreshing = isRefreshing;
    this.hasMore = hasMore;
    this.isLoadingMore = isLoadingMore;
    this.paginationMessage = paginationMessage;
  }

  public static initial<T>(): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.INITIAL, [], '', false, false, false, '');
  }

  public static loading<T>(): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.LOADING, [], '', false, false, false, '');
  }

  public static content<T>(
    items: Array<T>,
    isRefreshing: boolean = false,
    message: string = '',
    hasMore: boolean = false,
    isLoadingMore: boolean = false,
    paginationMessage: string = ''
  ): BrowseState<T> {
    return new BrowseState<T>(
      BrowseStateKind.CONTENT,
      items,
      message,
      isRefreshing,
      hasMore,
      isLoadingMore,
      paginationMessage
    );
  }

  public static empty<T>(isRefreshing: boolean = false, message: string = ''): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.EMPTY, [], message, isRefreshing, false, false, '');
  }

  public static error<T>(message: string): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.ERROR, [], message, false, false, false, '');
  }
}

function emptySearchResult(): ForumSearchResult {
  return new ForumSearchResult([], [], [], [], [], [], false);
}

export class SearchState {
  public readonly kind: SearchStateKind;
  public readonly query: string;
  public readonly result: ForumSearchResult;
  public readonly message: string;
  public readonly isLoadingMore: boolean;
  public readonly paginationMessage: string;

  private constructor(
    kind: SearchStateKind,
    query: string,
    result: ForumSearchResult,
    message: string,
    isLoadingMore: boolean,
    paginationMessage: string
  ) {
    this.kind = kind;
    this.query = query;
    this.result = result;
    this.message = message;
    this.isLoadingMore = isLoadingMore;
    this.paginationMessage = paginationMessage;
  }

  public static initial(): SearchState {
    return new SearchState(SearchStateKind.INITIAL, '', emptySearchResult(), '', false, '');
  }

  public static loading(query: string): SearchState {
    return new SearchState(SearchStateKind.LOADING, query, emptySearchResult(), '', false, '');
  }

  public static content(
    query: string,
    result: ForumSearchResult,
    isLoadingMore: boolean = false,
    paginationMessage: string = ''
  ): SearchState {
    return new SearchState(SearchStateKind.CONTENT, query, result, '', isLoadingMore, paginationMessage);
  }

  public static empty(query: string): SearchState {
    return new SearchState(SearchStateKind.EMPTY, query, emptySearchResult(), '', false, '');
  }

  public static error(query: string, message: string): SearchState {
    return new SearchState(SearchStateKind.ERROR, query, emptySearchResult(), message, false, '');
  }

  public get hasMore(): boolean {
    return this.result.hasMore;
  }
}

function uniqueTopics(existing: Array<Topic>, incoming: Array<Topic>): Array<Topic> {
  const ids: Set<number> = new Set<number>();
  const merged: Array<Topic> = [];
  for (const topic of existing.concat(incoming)) {
    if (!ids.has(topic.id)) {
      ids.add(topic.id);
      merged.push(topic);
    }
  }
  return merged;
}

function mergeSearchResults(existing: ForumSearchResult, incoming: ForumSearchResult): ForumSearchResult {
  const topics: Array<Topic> = uniqueTopics(existing.topics, incoming.topics);
  const postIds: Set<number> = new Set<number>();
  const posts: Array<SearchPost> = [];
  for (const post of existing.posts.concat(incoming.posts)) {
    if (!postIds.has(post.id)) {
      postIds.add(post.id);
      posts.push(post);
    }
  }
  const userIds: Set<number> = new Set<number>();
  const users: Array<SearchUser> = [];
  for (const user of existing.users.concat(incoming.users)) {
    if (!userIds.has(user.id)) {
      userIds.add(user.id);
      users.push(user);
    }
  }
  const categoryIds: Set<number> = new Set<number>();
  const categories: Array<Category> = [];
  for (const category of existing.categories.concat(incoming.categories)) {
    if (!categoryIds.has(category.id)) {
      categoryIds.add(category.id);
      categories.push(category);
    }
  }
  const tagIds: Set<string> = new Set<string>();
  const tags: Array<SearchTag> = [];
  for (const tag of existing.tags.concat(incoming.tags)) {
    if (!tagIds.has(tag.id)) {
      tagIds.add(tag.id);
      tags.push(tag);
    }
  }
  const groupIds: Set<number> = new Set<number>();
  const groups: Array<SearchGroup> = [];
  for (const group of existing.groups.concat(incoming.groups)) {
    if (!groupIds.has(group.id)) {
      groupIds.add(group.id);
      groups.push(group);
    }
  }
  return new ForumSearchResult(topics, posts, users, categories, tags, groups, incoming.hasMore);
}

export class AppShellModel {
  public selectedRoot: RootDestination = RootDestination.HOME;
  public activeDestination: SecondaryDestination = SecondaryDestination.NONE;
  public requiresAuthentication: boolean = false;
  public homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  public worldCupEntryEnabled: boolean = true;
  public categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  public selectedCategory: Category | null = null;
  public categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public topicState: TopicReadState = TopicReadState.initial();
  public replyState: ReplyComposerState = ReplyComposerState.closed();
  public searchState: SearchState = SearchState.initial();

  private readonly repository: ForumRepository;
  private readonly categoryCache: CategoryCache;
  private categoryCacheScope: CategoryCacheScope;
  private readonly authenticationLifecycle: AuthenticationLifecycle | null;
  private readonly discoverySettingsStore: DiscoverySettingsStore | null;
  private cachedCategories: Array<Category> | null = null;
  private remainingPostIds: Array<number> = [];
  private topicReturnDestination: SecondaryDestination = SecondaryDestination.NONE;
  private selectedTopic: Topic | null = null;
  private categoryRequestVersion: number = 0;
  private homeRequestVersion: number = 0;
  private searchRequestVersion: number = 0;
  private homePage: number = 0;
  private categoryTopicsPage: number = 0;
  private searchNextPage: number = 1;
  private topicRequestVersion: number = 0;
  private replyRequestVersion: number = 0;

  public constructor(
    repository: ForumRepository,
    categoryCache: CategoryCache,
    categoryCacheScope: CategoryCacheScope,
    authenticationLifecycle: AuthenticationLifecycle | null = null,
    discoverySettingsStore: DiscoverySettingsStore | null = null
  ) {
    this.repository = repository;
    this.categoryCache = categoryCache;
    this.categoryCacheScope = categoryCacheScope;
    this.authenticationLifecycle = authenticationLifecycle;
    this.discoverySettingsStore = discoverySettingsStore;
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

  public selectHomeSortTab(index: number): boolean {
    if (!isHomeSortTabAvailable(index)) {
      return false;
    }
    const channel: HomeChannel | null = homeChannelFromIndex(index);
    if (channel === null) {
      return false;
    }
    if (this.selectedHomeChannel !== channel) {
      this.selectedHomeChannel = channel;
      this.homeRequestVersion += 1;
      this.homePage = 0;
      this.homeState = BrowseState.initial<Topic>();
    }
    return true;
  }

  public async restoreDiscoverySettings(): Promise<void> {
    const store: DiscoverySettingsStore | null = this.discoverySettingsStore;
    if (store === null) {
      return;
    }
    try {
      const settings: DiscoverySettings | null = await store.read();
      if (settings === null) {
        return;
      }
      this.selectedHomeChannel = settings.homeChannel;
      this.worldCupEntryEnabled = settings.worldCupEntryEnabled;
    } catch (_) {
      // Settings restoration is best effort and falls back to the product defaults.
    }
  }

  public async selectHomeChannel(index: number): Promise<boolean> {
    if (!this.selectHomeSortTab(index)) {
      return false;
    }
    await this.persistDiscoverySettings();
    return true;
  }

  public async applyServerHomeChannel(channel: HomeChannel): Promise<boolean> {
    if (!this.selectHomeSortTab(channel)) {
      return false;
    }
    await this.persistDiscoverySettings();
    return true;
  }

  public async setWorldCupEntryEnabled(enabled: boolean): Promise<void> {
    if (this.worldCupEntryEnabled === enabled) {
      return;
    }
    this.worldCupEntryEnabled = enabled;
    await this.persistDiscoverySettings();
  }

  private async persistDiscoverySettings(): Promise<void> {
    const store: DiscoverySettingsStore | null = this.discoverySettingsStore;
    if (store === null) {
      return;
    }
    try {
      await store.write(new DiscoverySettings(this.selectedHomeChannel, this.worldCupEntryEnabled));
    } catch (_) {
      // A failed preference write does not invalidate current browse content.
    }
  }

  public updateCategoryCacheScope(scope: CategoryCacheScope): void {
    if (this.categoryCacheScope.key === scope.key) {
      return;
    }
    this.categoryCacheScope = scope;
    this.cachedCategories = null;
    this.categoryState = BrowseState.initial<Category>();
  }

  public async openCategory(category: Category): Promise<void> {
    this.categoryRequestVersion += 1;
    const requestVersion: number = this.categoryRequestVersion;
    this.requiresAuthentication = false;
    this.activeDestination = SecondaryDestination.CATEGORY_TOPICS;
    this.selectedCategory = category;
    this.categoryTopicsState = BrowseState.loading<Topic>();
    this.categoryTopicsPage = 0;
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadCategoryTopics(category.id, 0);
    if (requestVersion !== this.categoryRequestVersion || this.selectedCategory?.id !== category.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.categoryTopicsState = BrowseState.error<Topic>(result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.categoryTopicsState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
  }

  public async loadMoreCategoryTopics(): Promise<void> {
    const category: Category | null = this.selectedCategory;
    const state: BrowseState<Topic> = this.categoryTopicsState;
    if (category === null || state.kind !== BrowseStateKind.CONTENT || !state.hasMore || state.isLoadingMore) {
      return;
    }
    const requestVersion: number = this.categoryRequestVersion;
    const nextPage: number = this.categoryTopicsPage + 1;
    this.categoryTopicsState = BrowseState.content<Topic>(state.items, false, '', true, true);
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadCategoryTopics(category.id, nextPage);
    if (requestVersion !== this.categoryRequestVersion || this.selectedCategory?.id !== category.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.categoryTopicsState = BrowseState.content<Topic>(
        state.items,
        false,
        '',
        true,
        false,
        result.message
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const merged: Array<Topic> = uniqueTopics(state.items, result.data);
    const addedCount: number = merged.length - state.items.length;
    this.categoryTopicsPage = nextPage;
    this.categoryTopicsState = BrowseState.content<Topic>(merged, false, '', addedCount > 0);
  }

  public async retryCategoryTopics(): Promise<void> {
    const category: Category | null = this.selectedCategory;
    if (category === null) {
      return;
    }
    await this.openCategory(category);
  }

  public async openTopic(topic: Topic): Promise<void> {
    this.topicRequestVersion += 1;
    const requestVersion: number = this.topicRequestVersion;
    this.requiresAuthentication = false;
    this.replyRequestVersion += 1;
    this.replyState = ReplyComposerState.closed();
    this.selectedTopic = topic;
    this.topicReturnDestination = this.activeDestination === SecondaryDestination.CATEGORY_TOPICS
      ? SecondaryDestination.CATEGORY_TOPICS
      : SecondaryDestination.NONE;
    this.activeDestination = SecondaryDestination.TOPIC;
    this.topicState = TopicReadState.loading(topic);
    const result: RepositoryResult<TopicDetail> = await this.repository.loadTopicDetail(topic.id);
    if (requestVersion !== this.topicRequestVersion || this.selectedTopic?.id !== topic.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.remainingPostIds = [];
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.error(topic, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const posts: Array<ForumPost> = uniquePosts(result.data.posts);
    const visiblePostIds: Set<number> = new Set<number>();
    for (const post of posts) {
      visiblePostIds.add(post.id);
    }
    this.remainingPostIds = result.data.postIds.filter((postId: number) => !visiblePostIds.has(postId));
    const hasMorePosts: boolean = this.remainingPostIds.length > 0;
    this.topicState = posts.length === 0
      ? TopicReadState.empty(result.data, hasMorePosts)
      : TopicReadState.content(result.data, posts, hasMorePosts);
  }

  public async retryTopic(): Promise<void> {
    const topic: Topic | null = this.selectedTopic;
    if (topic === null) {
      return;
    }
    const returnDestination: SecondaryDestination = this.topicReturnDestination;
    await this.openTopic(topic);
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicReturnDestination = returnDestination;
    }
  }

  public async loadMorePosts(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.topicState.isLoadingMore ||
      this.remainingPostIds.length === 0 ||
      (this.topicState.kind !== TopicReadStateKind.CONTENT && this.topicState.kind !== TopicReadStateKind.EMPTY)
    ) {
      return;
    }

    this.requiresAuthentication = false;
    const requestedPostIds: Array<number> = this.remainingPostIds.slice(0, 20);
    const requestVersion: number = this.topicRequestVersion;
    const visiblePosts: Array<ForumPost> = this.topicState.posts;
    this.topicState = TopicReadState.pagination(this.topicState, true, '');
    const result: RepositoryResult<Array<ForumPost>> =
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
    this.remainingPostIds = this.remainingPostIds.filter((postId: number) => !requestedIds.has(postId));
    const posts: Array<ForumPost> = uniquePosts(visiblePosts.concat(result.data));
    const hasMorePosts: boolean = this.remainingPostIds.length > 0;
    this.topicState = posts.length === 0
      ? TopicReadState.empty(detail, hasMorePosts)
      : TopicReadState.content(detail, posts, hasMorePosts);
  }

  public async retryTopicPosts(): Promise<void> {
    await this.loadMorePosts();
  }

  public openReply(replyToPostNumber: number | null): void {
    if (!this.topicState.canReply || this.topicState.detail === null || this.replyState.isBusy()) {
      return;
    }
    this.replyState = ReplyComposerState.editing(this.replyState.draft, replyToPostNumber);
  }

  public updateReplyDraft(draft: string): void {
    if (this.replyState.isBusy()) {
      return;
    }
    this.replyState = ReplyComposerState.editing(draft, this.replyState.replyToPostNumber);
  }

  public dismissReply(): void {
    if (this.replyState.isBusy()) {
      return;
    }
    this.replyState = ReplyComposerState.closed(
      this.replyState.draft,
      this.replyState.replyToPostNumber
    );
  }

  public resumeReplyAfterAuthentication(): void {
    if (this.replyState.kind !== ReplyComposerStateKind.REAUTHENTICATE) {
      return;
    }
    this.requiresAuthentication = false;
    this.replyState = ReplyComposerState.editing(
      this.replyState.draft,
      this.replyState.replyToPostNumber
    );
  }

  public async submitReply(
    onStateChange: (state: ReplyComposerState) => void = (_state: ReplyComposerState): void => {}
  ): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (detail === null || !this.topicState.canReply || this.replyState.isBusy()) {
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
      this.completeReply(submitResult.post, onStateChange);
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
      this.completeReply(recoveryResult.post, onStateChange);
    } else if (recoveryResult.kind === ReplyRecoveryKind.UNAUTHORIZED) {
      await this.handleReplyUnauthorized(request.raw, replyToPostNumber, onStateChange);
    } else {
      this.transitionReplyState(
        ReplyComposerState.error(request.raw, replyToPostNumber, recoveryResult.message),
        onStateChange
      );
    }
  }

  public closeSecondary(): void {
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicRequestVersion += 1;
      this.replyRequestVersion += 1;
      this.activeDestination = this.topicReturnDestination;
      this.topicReturnDestination = SecondaryDestination.NONE;
    } else {
      this.categoryRequestVersion += 1;
      this.activeDestination = SecondaryDestination.NONE;
    }
    this.remainingPostIds = [];
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

  private completeReply(
    post: ForumPost,
    onStateChange: (state: ReplyComposerState) => void
  ): void {
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
      Math.max(detail.highestPostNumber, post.postNumber)
    );
    const visiblePosts: Array<ForumPost> = uniquePosts(this.topicState.posts.concat([post]));
    this.topicState = TopicReadState.content(
      updatedDetail,
      visiblePosts,
      this.topicState.hasMorePosts,
      false,
      this.topicState.paginationMessage
    );
    this.transitionReplyState(ReplyComposerState.success('Reply 已发布'), onStateChange);
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> = await this.repository.loadCurrentUser();
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
    return result;
  }

  public async loadHome(): Promise<void> {
    this.homeRequestVersion += 1;
    const requestVersion: number = this.homeRequestVersion;
    const channel: HomeChannel = this.selectedHomeChannel;
    this.requiresAuthentication = false;
    this.homeState = BrowseState.loading<Topic>();
    this.homePage = 0;
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadHomeTopics(channel, 0);
    if (requestVersion !== this.homeRequestVersion || channel !== this.selectedHomeChannel) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.homeState = BrowseState.error<Topic>(result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.homeState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
  }

  public async refreshHome(): Promise<void> {
    this.requiresAuthentication = false;
    const previousState: BrowseState<Topic> = this.homeState;
    if (previousState.kind === BrowseStateKind.CONTENT) {
      this.homeState = BrowseState.content<Topic>(previousState.items, true);
    } else if (previousState.kind === BrowseStateKind.EMPTY) {
      this.homeState = BrowseState.empty<Topic>(true);
    } else {
      await this.loadHome();
      return;
    }

    this.homeRequestVersion += 1;
    const requestVersion: number = this.homeRequestVersion;
    const channel: HomeChannel = this.selectedHomeChannel;
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadHomeTopics(channel, 0);
    if (requestVersion !== this.homeRequestVersion || channel !== this.selectedHomeChannel) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.homeState = previousState.kind === BrowseStateKind.CONTENT
        ? BrowseState.content<Topic>(previousState.items, false, result.message, previousState.hasMore)
        : BrowseState.empty<Topic>(false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.homeState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
    this.homePage = 0;
  }

  public async loadMoreHome(): Promise<void> {
    const state: BrowseState<Topic> = this.homeState;
    if (state.kind !== BrowseStateKind.CONTENT || !state.hasMore || state.isLoadingMore) {
      return;
    }
    const requestVersion: number = this.homeRequestVersion;
    const channel: HomeChannel = this.selectedHomeChannel;
    const nextPage: number = this.homePage + 1;
    this.homeState = BrowseState.content<Topic>(state.items, false, '', true, true);
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadHomeTopics(channel, nextPage);
    if (requestVersion !== this.homeRequestVersion || channel !== this.selectedHomeChannel) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.homeState = BrowseState.content<Topic>(state.items, false, '', true, false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    const merged: Array<Topic> = uniqueTopics(state.items, result.data);
    const addedCount: number = merged.length - state.items.length;
    this.homePage = nextPage;
    this.homeState = BrowseState.content<Topic>(merged, false, '', addedCount > 0);
  }

  public async retryHome(): Promise<void> {
    await this.loadHome();
  }

  public async searchForum(query: string): Promise<void> {
    const normalizedQuery: string = query.trim();
    this.searchRequestVersion += 1;
    const requestVersion: number = this.searchRequestVersion;
    if (normalizedQuery.length === 0) {
      this.searchState = SearchState.initial();
      this.searchNextPage = 1;
      return;
    }
    this.requiresAuthentication = false;
    this.searchState = SearchState.loading(normalizedQuery);
    this.searchNextPage = 1;
    const result: RepositoryResult<ForumSearchResult> = await this.repository.searchForum(normalizedQuery, 1);
    if (requestVersion !== this.searchRequestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.searchState = SearchState.error(normalizedQuery, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.searchNextPage = 2;
    this.searchState = result.data.isEmpty()
      ? SearchState.empty(normalizedQuery)
      : SearchState.content(normalizedQuery, result.data);
  }

  public async retrySearch(): Promise<void> {
    await this.searchForum(this.searchState.query);
  }

  public async loadMoreSearch(): Promise<void> {
    const state: SearchState = this.searchState;
    if (state.kind !== SearchStateKind.CONTENT || !state.hasMore || state.isLoadingMore) {
      return;
    }
    const requestVersion: number = this.searchRequestVersion;
    const page: number = this.searchNextPage;
    this.searchState = SearchState.content(state.query, state.result, true);
    const result: RepositoryResult<ForumSearchResult> = await this.repository.searchForum(state.query, page);
    if (requestVersion !== this.searchRequestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.searchState = SearchState.content(state.query, state.result, false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.searchNextPage = page + 1;
    this.searchState = SearchState.content(state.query, mergeSearchResults(state.result, result.data));
  }

  public async loadSearchSuggestions(term: string): Promise<RepositoryResult<Array<string>>> {
    const result: RepositoryResult<Array<string>> = await this.repository.searchSuggestions(term);
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
    return result;
  }

  public async loadCategories(): Promise<void> {
    await this.restoreCategories();
    await this.refreshCategories();
  }

  public async restoreCategories(): Promise<void> {
    this.cachedCategories = null;
    try {
      this.cachedCategories = await this.categoryCache.read(this.categoryCacheScope);
    } catch (_) {
      this.cachedCategories = null;
    }

    if (this.cachedCategories === null) {
      this.categoryState = BrowseState.loading<Category>();
    } else if (this.cachedCategories.length === 0) {
      this.categoryState = BrowseState.empty<Category>(true);
    } else {
      this.categoryState = BrowseState.content<Category>(this.cachedCategories, true);
    }
  }

  public async refreshCategories(): Promise<void> {
    this.requiresAuthentication = false;
    if (this.categoryState.kind === BrowseStateKind.CONTENT) {
      this.categoryState = BrowseState.content<Category>(this.categoryState.items, true);
    } else if (this.categoryState.kind === BrowseStateKind.EMPTY) {
      this.categoryState = BrowseState.empty<Category>(true);
    } else {
      this.categoryState = BrowseState.loading<Category>();
    }
    const result: RepositoryResult<Array<Category>> = await this.repository.loadCategories();
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      if (this.cachedCategories === null) {
        this.categoryState = BrowseState.error<Category>(result.message);
      } else if (this.cachedCategories.length === 0) {
        this.categoryState = BrowseState.empty<Category>(false, result.message);
      } else {
        this.categoryState = BrowseState.content<Category>(this.cachedCategories, false, result.message);
      }
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }

    this.cachedCategories = result.data;
    this.categoryState = result.data.length === 0
      ? BrowseState.empty<Category>()
      : BrowseState.content<Category>(result.data);
    try {
      await this.categoryCache.write(this.categoryCacheScope, result.data);
    } catch (_) {
      // Cache persistence never converts fresh browse content into a page failure.
    }
  }

  public async retryCategories(): Promise<void> {
    await this.loadCategories();
  }

  private async notifyUnauthorized(isUnauthorized: boolean): Promise<void> {
    if (!isUnauthorized || this.authenticationLifecycle === null) {
      return;
    }
    await this.authenticationLifecycle.handleUnauthorized();
  }
}
