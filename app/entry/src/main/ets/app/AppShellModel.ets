import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import { ForumRepository } from '../repositories/ForumRepository';

export interface AuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}

export enum RootDestination {
  HOME = 0,
  CATEGORY = 1
}

export enum BrowseStateKind {
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

  private constructor(kind: BrowseStateKind, items: Array<T>, message: string, isRefreshing: boolean) {
    this.kind = kind;
    this.items = items;
    this.message = message;
    this.isRefreshing = isRefreshing;
  }

  public static initial<T>(): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.INITIAL, [], '', false);
  }

  public static loading<T>(): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.LOADING, [], '', false);
  }

  public static content<T>(items: Array<T>, isRefreshing: boolean = false, message: string = ''): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.CONTENT, items, message, isRefreshing);
  }

  public static empty<T>(isRefreshing: boolean = false, message: string = ''): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.EMPTY, [], message, isRefreshing);
  }

  public static error<T>(message: string): BrowseState<T> {
    return new BrowseState<T>(BrowseStateKind.ERROR, [], message, false);
  }
}

export class AppShellModel {
  public selectedRoot: RootDestination = RootDestination.HOME;
  public activeDestination: SecondaryDestination = SecondaryDestination.NONE;
  public requiresAuthentication: boolean = false;
  public homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  public selectedCategory: Category | null = null;
  public categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public topicState: TopicReadState = TopicReadState.initial();

  private readonly repository: ForumRepository;
  private readonly categoryCache: CategoryCache;
  private readonly categoryCacheScope: CategoryCacheScope;
  private readonly authenticationLifecycle: AuthenticationLifecycle | null;
  private cachedCategories: Array<Category> | null = null;
  private remainingPostIds: Array<number> = [];
  private topicReturnDestination: SecondaryDestination = SecondaryDestination.NONE;
  private selectedTopic: Topic | null = null;
  private categoryRequestVersion: number = 0;
  private topicRequestVersion: number = 0;

  public constructor(
    repository: ForumRepository,
    categoryCache: CategoryCache,
    categoryCacheScope: CategoryCacheScope,
    authenticationLifecycle: AuthenticationLifecycle | null = null
  ) {
    this.repository = repository;
    this.categoryCache = categoryCache;
    this.categoryCacheScope = categoryCacheScope;
    this.authenticationLifecycle = authenticationLifecycle;
  }

  public selectRoot(destination: RootDestination): void {
    this.selectedRoot = destination;
  }

  public async openCategory(category: Category): Promise<void> {
    this.categoryRequestVersion += 1;
    const requestVersion: number = this.categoryRequestVersion;
    this.requiresAuthentication = false;
    this.activeDestination = SecondaryDestination.CATEGORY_TOPICS;
    this.selectedCategory = category;
    this.categoryTopicsState = BrowseState.loading<Topic>();
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadCategoryTopics(category.id);
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
      : BrowseState.content<Topic>(result.data);
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

  public closeSecondary(): void {
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicRequestVersion += 1;
      this.activeDestination = this.topicReturnDestination;
      this.topicReturnDestination = SecondaryDestination.NONE;
    } else {
      this.categoryRequestVersion += 1;
      this.activeDestination = SecondaryDestination.NONE;
    }
    this.remainingPostIds = [];
  }

  public async loadHome(): Promise<void> {
    this.requiresAuthentication = false;
    this.homeState = BrowseState.loading<Topic>();
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadLatestTopics();
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.homeState = BrowseState.error<Topic>(result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.homeState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data);
  }

  public async retryHome(): Promise<void> {
    await this.loadHome();
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
