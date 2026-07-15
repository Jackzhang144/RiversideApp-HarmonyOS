import { ForumPost, Topic, TopicDetail } from '../models/ForumModels';

export enum TopicReadStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
}

export enum TopicPostActionKind {
  NONE = 'none',
  REACTION = 'reaction',
  BOOKMARK = 'bookmark',
  DELETE = 'delete',
  FLAG = 'flag',
  SOLUTION = 'solution'
}

export class TopicPostJumpState {
  public readonly targetPostNumber: number;
  public readonly busy: boolean;
  public readonly message: string;

  private constructor(targetPostNumber: number, busy: boolean, message: string) {
    this.targetPostNumber = targetPostNumber;
    this.busy = busy;
    this.message = message;
  }

  public static idle(): TopicPostJumpState {
    return new TopicPostJumpState(0, false, '');
  }

  public static loading(targetPostNumber: number): TopicPostJumpState {
    return new TopicPostJumpState(targetPostNumber, true, '');
  }

  public static ready(targetPostNumber: number): TopicPostJumpState {
    return new TopicPostJumpState(targetPostNumber, false, '');
  }

  public static error(targetPostNumber: number, message: string): TopicPostJumpState {
    return new TopicPostJumpState(targetPostNumber, false, message);
  }
}

export class TopicPostActionState {
  public readonly kind: TopicPostActionKind;
  public readonly postId: number;
  public readonly busy: boolean;
  public readonly message: string;

  private constructor(kind: TopicPostActionKind, postId: number, busy: boolean, message: string) {
    this.kind = kind;
    this.postId = postId;
    this.busy = busy;
    this.message = message;
  }

  public static idle(): TopicPostActionState {
    return new TopicPostActionState(TopicPostActionKind.NONE, 0, false, '');
  }

  public static loading(kind: TopicPostActionKind, postId: number): TopicPostActionState {
    return new TopicPostActionState(kind, postId, true, '');
  }

  public static error(kind: TopicPostActionKind, postId: number, message: string): TopicPostActionState {
    return new TopicPostActionState(kind, postId, false, message);
  }
}

export class TopicReadProgressState {
  public readonly lastReadPostNumber: number;
  public readonly busy: boolean;
  public readonly message: string;

  private constructor(lastReadPostNumber: number, busy: boolean, message: string) {
    this.lastReadPostNumber = Math.max(0, lastReadPostNumber);
    this.busy = busy;
    this.message = message;
  }

  public static idle(lastReadPostNumber: number): TopicReadProgressState {
    return new TopicReadProgressState(lastReadPostNumber, false, '');
  }

  public static loading(lastReadPostNumber: number): TopicReadProgressState {
    return new TopicReadProgressState(lastReadPostNumber, true, '');
  }

  public static error(lastReadPostNumber: number, message: string): TopicReadProgressState {
    return new TopicReadProgressState(lastReadPostNumber, false, message);
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
  public readonly hasPreviousPosts: boolean;
  public readonly hasNextPosts: boolean;
  public readonly isLoadingMore: boolean;
  public readonly paginationMessage: string;
  public readonly isLoadingPrevious: boolean;
  public readonly previousPaginationMessage: string;
  public readonly postActionState: TopicPostActionState;
  public readonly readProgressState: TopicReadProgressState;
  public readonly postJumpState: TopicPostJumpState;
  public readonly isRefreshing: boolean;
  public readonly refreshMessage: string;

  private constructor(
    kind: TopicReadStateKind,
    topicId: number,
    title: string,
    detail: TopicDetail | null,
    posts: Array<ForumPost>,
    canReply: boolean,
    message: string,
    hasPreviousPosts: boolean,
    hasNextPosts: boolean,
    isLoadingMore: boolean,
    paginationMessage: string,
    isLoadingPrevious: boolean,
    previousPaginationMessage: string,
    postActionState: TopicPostActionState = TopicPostActionState.idle(),
    readProgressState: TopicReadProgressState = TopicReadProgressState.idle(0),
    postJumpState: TopicPostJumpState = TopicPostJumpState.idle(),
    isRefreshing: boolean = false,
    refreshMessage: string = ''
  ) {
    this.kind = kind;
    this.topicId = topicId;
    this.title = title;
    this.detail = detail;
    this.posts = posts;
    this.canReply = canReply;
    this.message = message;
    this.hasPreviousPosts = hasPreviousPosts;
    this.hasNextPosts = hasNextPosts;
    this.hasMorePosts = hasPreviousPosts || hasNextPosts;
    this.isLoadingMore = isLoadingMore;
    this.paginationMessage = paginationMessage;
    this.isLoadingPrevious = isLoadingPrevious;
    this.previousPaginationMessage = previousPaginationMessage;
    this.postActionState = postActionState;
    this.readProgressState = readProgressState;
    this.postJumpState = postJumpState;
    this.isRefreshing = isRefreshing;
    this.refreshMessage = refreshMessage;
  }

  public static initial(): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.INITIAL, 0, '', null, [], false, '', false, false, false, '', false, ''
    );
  }

  public static loading(topic: Topic): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.LOADING, topic.id, topic.title, null, [], false, '', false, false, false, '', false, ''
    );
  }

  public static content(
    detail: TopicDetail,
    posts: Array<ForumPost>,
    hasMorePosts: boolean = false,
    isLoadingMore: boolean = false,
    paginationMessage: string = '',
    hasPreviousPosts: boolean = false,
    isLoadingPrevious: boolean = false,
    previousPaginationMessage: string = '',
    readProgressState: TopicReadProgressState | null = null
  ): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.CONTENT,
      detail.id,
      detail.title,
      detail,
      posts,
      detail.canReply,
      '',
      hasPreviousPosts,
      hasMorePosts,
      isLoadingMore,
      paginationMessage,
      isLoadingPrevious,
      previousPaginationMessage,
      TopicPostActionState.idle(),
      readProgressState ?? TopicReadProgressState.idle(detail.lastReadPostNumber)
    );
  }

  public static empty(
    detail: TopicDetail,
    hasMorePosts: boolean = false,
    isLoadingMore: boolean = false,
    paginationMessage: string = '',
    hasPreviousPosts: boolean = false,
    isLoadingPrevious: boolean = false,
    previousPaginationMessage: string = '',
    readProgressState: TopicReadProgressState | null = null
  ): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.EMPTY,
      detail.id,
      detail.title,
      detail,
      [],
      detail.canReply,
      '',
      hasPreviousPosts,
      hasMorePosts,
      isLoadingMore,
      paginationMessage,
      isLoadingPrevious,
      previousPaginationMessage,
      TopicPostActionState.idle(),
      readProgressState ?? TopicReadProgressState.idle(detail.lastReadPostNumber)
    );
  }

  public static error(topic: Topic, message: string): TopicReadState {
    return new TopicReadState(
      TopicReadStateKind.ERROR, topic.id, topic.title, null, [], false, message, false, false, false, '', false, ''
    );
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
      state.hasPreviousPosts,
      state.hasNextPosts,
      isLoadingMore,
      paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static previousPagination(
    state: TopicReadState,
    isLoadingPrevious: boolean,
    previousPaginationMessage: string
  ): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      isLoadingPrevious,
      previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withDetail(state: TopicReadState, detail: TopicDetail): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      detail,
      state.posts,
      detail.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withPosts(state: TopicReadState, posts: Array<ForumPost>): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withDetailAndPosts(
    state: TopicReadState,
    detail: TopicDetail,
    posts: Array<ForumPost>
  ): TopicReadState {
    return new TopicReadState(
      state.kind,
      detail.id,
      detail.title,
      detail,
      posts,
      detail.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withPostAction(state: TopicReadState, postActionState: TopicPostActionState): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      postActionState,
      state.readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withReadProgress(
    state: TopicReadState,
    readProgressState: TopicReadProgressState
  ): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      readProgressState,
      state.postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static withPostJump(state: TopicReadState, postJumpState: TopicPostJumpState): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      postJumpState,
      state.isRefreshing,
      state.refreshMessage
    );
  }

  public static refreshing(state: TopicReadState, isRefreshing: boolean, refreshMessage: string = ''): TopicReadState {
    return new TopicReadState(
      state.kind,
      state.topicId,
      state.title,
      state.detail,
      state.posts,
      state.canReply,
      state.message,
      state.hasPreviousPosts,
      state.hasNextPosts,
      state.isLoadingMore,
      state.paginationMessage,
      state.isLoadingPrevious,
      state.previousPaginationMessage,
      state.postActionState,
      state.readProgressState,
      state.postJumpState,
      isRefreshing,
      refreshMessage
    );
  }
}

export function uniquePosts(posts: Array<ForumPost>): Array<ForumPost> {
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

export function orderPosts(postIds: Array<number>, posts: Array<ForumPost>): Array<ForumPost> {
  const byId: Map<number, ForumPost> = new Map<number, ForumPost>();
  for (const post of uniquePosts(posts)) {
    byId.set(post.id, post);
  }
  const ordered: Array<ForumPost> = [];
  for (const postId of postIds) {
    const post: ForumPost | undefined = byId.get(postId);
    if (post !== undefined) {
      ordered.push(post);
      byId.delete(postId);
    }
  }
  return ordered.concat(Array.from(byId.values()));
}

export function replacePost(posts: Array<ForumPost>, replacement: ForumPost): Array<ForumPost> {
  return posts.map((post: ForumPost): ForumPost => post.id === replacement.id ? replacement : post);
}

