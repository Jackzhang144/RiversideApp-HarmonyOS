import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  Category,
  ForumPost,
  Topic,
  TopicDetail,
  TopicDetailMetadata,
  TopicPostBatch
} from '../models/ForumModels';
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
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitKind,
  TopicSubmitResult,
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
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind,
  appendUploadedImageMarkdown
} from '../models/MediaModels';
import { MediaRepository, MediaUploadOperation } from '../repositories/MediaRepository';

export type MediaUploadStateListener = (state: MediaUploadState) => void;

export enum ComposerMediaTarget {
  REPLY = 'reply',
  TOPIC = 'topic'
}

export interface AuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}

export enum RootDestination {
  HOME = 0,
  CATEGORY = 1,
  CHAT = 2,
  NOTIFICATIONS = 3,
  ACCOUNT = 4
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
  if (index === RootTabIndex.CHAT) {
    return RootDestination.CHAT;
  }
  if (index === RootTabIndex.NOTIFICATIONS) {
    return RootDestination.NOTIFICATIONS;
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

export enum SearchSuggestionStateKind {
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

export enum TopicPostActionKind {
  NONE = 'none',
  REACTION = 'reaction',
  BOOKMARK = 'bookmark'
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
  public readonly editingPostId: number | null;

  private constructor(
    kind: ReplyComposerStateKind,
    draft: string,
    replyToPostNumber: number | null,
    message: string,
    editingPostId: number | null = null
  ) {
    this.kind = kind;
    this.draft = draft;
    this.replyToPostNumber = replyToPostNumber;
    this.message = message;
    this.editingPostId = editingPostId;
  }

  public static closed(draft: string = '', replyToPostNumber: number | null = null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.CLOSED, draft, replyToPostNumber, '');
  }

  public static editing(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.EDITING, draft, replyToPostNumber, '');
  }

  public static editingPost(postId: number, draft: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.EDITING, draft, null, '', postId);
  }

  public static submitting(
    draft: string,
    replyToPostNumber: number | null,
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.SUBMITTING,
      draft,
      replyToPostNumber,
      editingPostId === null ? '正在提交 Reply' : '正在保存 Post',
      editingPostId
    );
  }

  public static checking(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.CHECKING,
      draft,
      replyToPostNumber,
      '正在确认 Reply 是否已创建'
    );
  }

  public static error(
    draft: string,
    replyToPostNumber: number | null,
    message: string,
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.ERROR, draft, replyToPostNumber, message, editingPostId);
  }

  public static reauthenticate(
    draft: string,
    replyToPostNumber: number | null,
    message: string = '登录已失效，重新登录后可继续提交',
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.REAUTHENTICATE,
      draft,
      replyToPostNumber,
      message,
      editingPostId
    );
  }

  public static success(message: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.SUCCESS, '', null, message);
  }

  public isBusy(): boolean {
    return this.kind === ReplyComposerStateKind.SUBMITTING || this.kind === ReplyComposerStateKind.CHECKING;
  }

  public isEditingPost(): boolean {
    return this.editingPostId !== null;
  }
}

export enum TopicComposerStateKind {
  CLOSED = 'closed',
  EDITING = 'editing',
  SUBMITTING = 'submitting',
  SAVING_DRAFT = 'saving-draft',
  ERROR = 'error',
  REAUTHENTICATE = 'reauthenticate',
  SUCCESS = 'success'
}

export class TopicComposerState {
  public readonly kind: TopicComposerStateKind;
  public readonly title: string;
  public readonly raw: string;
  public readonly categoryId: number | null;
  public readonly draftSequence: number;
  public readonly createdTopicId: number | null;
  public readonly message: string;

  private constructor(
    kind: TopicComposerStateKind,
    title: string,
    raw: string,
    categoryId: number | null,
    draftSequence: number,
    createdTopicId: number | null,
    message: string
  ) {
    this.kind = kind;
    this.title = title;
    this.raw = raw;
    this.categoryId = categoryId !== null && Number.isInteger(categoryId) && categoryId > 0 ? categoryId : null;
    this.draftSequence = Math.max(0, draftSequence);
    this.createdTopicId = createdTopicId;
    this.message = message;
  }

  public static closed(): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.CLOSED, '', '', null, 0, null, '');
  }

  public static editing(
    title: string = '',
    raw: string = '',
    categoryId: number | null = null,
    draftSequence: number = 0
  ): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.EDITING, title, raw, categoryId, draftSequence, null, '');
  }

  public static submitting(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.SUBMITTING,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '正在发布 Topic'
    );
  }

  public static savingDraft(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.SAVING_DRAFT,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '正在保存草稿'
    );
  }

  public static error(state: TopicComposerState, message: string): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.ERROR,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      message
    );
  }

  public static reauthenticate(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.REAUTHENTICATE,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '登录已失效，重新登录后可继续发布'
    );
  }

  public static success(topicId: number, message: string = 'Topic 已发布'): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.SUCCESS, '', '', null, 0, topicId, message);
  }

  public withTitle(title: string): TopicComposerState {
    return TopicComposerState.editing(title, this.raw, this.categoryId, this.draftSequence);
  }

  public withRaw(raw: string): TopicComposerState {
    return TopicComposerState.editing(this.title, raw, this.categoryId, this.draftSequence);
  }

  public withCategoryId(categoryId: number | null): TopicComposerState {
    return TopicComposerState.editing(this.title, this.raw, categoryId, this.draftSequence);
  }

  public isBusy(): boolean {
    return this.kind === TopicComposerStateKind.SUBMITTING || this.kind === TopicComposerStateKind.SAVING_DRAFT;
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
    readProgressState: TopicReadProgressState = TopicReadProgressState.idle(0)
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
      state.readProgressState
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
      state.readProgressState
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
      state.readProgressState
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
      state.readProgressState
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
      state.readProgressState
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
      state.readProgressState
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
      readProgressState
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

function orderPosts(postIds: Array<number>, posts: Array<ForumPost>): Array<ForumPost> {
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

function replacePost(posts: Array<ForumPost>, replacement: ForumPost): Array<ForumPost> {
  return posts.map((post: ForumPost): ForumPost => post.id === replacement.id ? replacement : post);
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

export class SearchSuggestionState {
  public readonly kind: SearchSuggestionStateKind;
  public readonly term: string;
  public readonly items: Array<string>;
  public readonly message: string;

  private constructor(
    kind: SearchSuggestionStateKind,
    term: string,
    items: Array<string>,
    message: string = ''
  ) {
    this.kind = kind;
    this.term = term;
    this.items = items;
    this.message = message;
  }

  public static initial(): SearchSuggestionState {
    return new SearchSuggestionState(SearchSuggestionStateKind.INITIAL, '', []);
  }

  public static loading(term: string): SearchSuggestionState {
    return new SearchSuggestionState(SearchSuggestionStateKind.LOADING, term, []);
  }

  public static content(term: string, items: Array<string>): SearchSuggestionState {
    return new SearchSuggestionState(SearchSuggestionStateKind.CONTENT, term, items.slice());
  }

  public static empty(term: string): SearchSuggestionState {
    return new SearchSuggestionState(SearchSuggestionStateKind.EMPTY, term, []);
  }

  public static error(term: string, message: string): SearchSuggestionState {
    return new SearchSuggestionState(SearchSuggestionStateKind.ERROR, term, [], message);
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
  public homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  public worldCupEntryEnabled: boolean = true;
  public categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  public selectedCategory: Category | null = null;
  public categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public topicState: TopicReadState = TopicReadState.initial();
  public replyState: ReplyComposerState = ReplyComposerState.closed();
  public topicComposerState: TopicComposerState = TopicComposerState.closed();
  public topicEditingTopicId: number | null = null;
  public topicEditingPostId: number | null = null;
  public searchState: SearchState = SearchState.initial();
  public searchSuggestionState: SearchSuggestionState = SearchSuggestionState.initial();

  private readonly repository: ForumRepository;
  private readonly categoryCache: CategoryCache;
  private categoryCacheScope: CategoryCacheScope;
  private readonly authenticationLifecycle: AuthenticationLifecycle | null;
  private readonly discoverySettingsStore: DiscoverySettingsStore | null;
  private readonly mediaRepository: MediaRepository | null;
  private activeMediaUpload: MediaUploadOperation | null = null;
  private activeMediaState: MediaUploadState | null = null;
  private activeMediaStateListener: MediaUploadStateListener | null = null;
  private activeMediaTarget: ComposerMediaTarget | null = null;
  private replyComposerSession: number = 0;
  private topicComposerSession: number = 0;
  private cachedCategories: Array<Category> | null = null;
  private previousPostIds: Array<number> = [];
  private nextPostIds: Array<number> = [];
  private topicNavigationStack: Array<TopicNavigationFrame> = [];
  private topicReturnDestination: SecondaryDestination = SecondaryDestination.NONE;
  private selectedTopic: Topic | null = null;
  private selectedTopicPostNumber: number | null = null;
  private categoryRequestVersion: number = 0;
  private homeRequestVersion: number = 0;
  private searchRequestVersion: number = 0;
  private searchSuggestionRequestVersion: number = 0;
  private homePage: number = 0;
  private categoryTopicsPage: number = 0;
  private searchNextPage: number = 1;
  private topicRequestVersion: number = 0;
  private replyRequestVersion: number = 0;
  private replyDraftRequestVersion: number = 0;
  private replyDraftSequence: number = 0;
  private replyDraftKey: string = '';
  private ignoredReplyDraftKey: string = '';
  private ignoredReplyDraftSequence: number = 0;
  private topicComposerRequestVersion: number = 0;
  private ignoredTopicDraftSequence: number | null = null;
  private topicDraftKey: string = 'new_topic';
  private topicEditingOriginalTitle: string = '';

  public constructor(
    repository: ForumRepository,
    categoryCache: CategoryCache,
    categoryCacheScope: CategoryCacheScope,
    authenticationLifecycle: AuthenticationLifecycle | null = null,
    discoverySettingsStore: DiscoverySettingsStore | null = null,
    mediaRepository: MediaRepository | null = null
  ) {
    this.repository = repository;
    this.categoryCache = categoryCache;
    this.categoryCacheScope = categoryCacheScope;
    this.authenticationLifecycle = authenticationLifecycle;
    this.discoverySettingsStore = discoverySettingsStore;
    this.mediaRepository = mediaRepository;
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
    const posts: Array<ForumPost> = orderPosts(result.data.postIds, result.data.posts);
    let firstVisibleIndex: number = result.data.postIds.length;
    let lastVisibleIndex: number = -1;
    for (const post of posts) {
      const index: number = result.data.postIds.indexOf(post.id);
      if (index >= 0) {
        firstVisibleIndex = Math.min(firstVisibleIndex, index);
        lastVisibleIndex = Math.max(lastVisibleIndex, index);
      }
    }
    this.previousPostIds = lastVisibleIndex < 0 ? [] : result.data.postIds.slice(0, firstVisibleIndex);
    this.nextPostIds = lastVisibleIndex < 0
      ? result.data.postIds.slice()
      : result.data.postIds.slice(lastVisibleIndex + 1);
    const hasPreviousPosts: boolean = this.previousPostIds.length > 0;
    const hasNextPosts: boolean = this.nextPostIds.length > 0;
    this.topicState = posts.length === 0
      ? TopicReadState.empty(result.data, hasNextPosts, false, '', hasPreviousPosts)
      : TopicReadState.content(result.data, posts, hasNextPosts, false, '', hasPreviousPosts);
    if (!hasNextPosts && result.data.suggestedTopics.length === 0) {
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

  public async loadMorePosts(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.topicState.isLoadingMore ||
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
    if (!hasNextPosts && updatedDetail.suggestedTopics.length === 0) {
      await this.refreshTopicSuggestions(requestVersion);
    }
  }

  public async loadPreviousPosts(): Promise<void> {
    const detail: TopicDetail | null = this.topicState.detail;
    if (
      detail === null ||
      this.topicState.isLoadingPrevious ||
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
    this.topicState = posts.length === 0
      ? TopicReadState.empty(
        detail, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      )
      : TopicReadState.content(
        detail, posts, hasNextPosts, false, '', hasPreviousPosts, false, '', this.topicState.readProgressState
      );
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

  public async togglePostReaction(postId: number, reaction: string): Promise<void> {
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
      return;
    }

    const requestVersion: number = this.topicRequestVersion;
    this.topicState = TopicReadState.withPostAction(
      this.topicState,
      TopicPostActionState.loading(TopicPostActionKind.REACTION, postId)
    );
    const result: RepositoryResult<ForumPost> =
      await this.repository.togglePostReaction(postId, normalizedReaction);
    if (requestVersion !== this.topicRequestVersion || this.topicState.topicId !== detail.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.requiresAuthentication = result.isUnauthorized();
      this.topicState = TopicReadState.withPostAction(
        this.topicState,
        TopicPostActionState.error(TopicPostActionKind.REACTION, postId, result.message)
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.topicState = TopicReadState.withPosts(this.topicState, replacePost(this.topicState.posts, result.data));
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
    const updatedDetail: TopicDetail = detail.withLastReadPostNumber(reportedPostNumber);
    this.topicState = TopicReadState.withDetail(this.topicState, updatedDetail);
    this.topicState = TopicReadState.withReadProgress(
      this.topicState,
      TopicReadProgressState.idle(reportedPostNumber)
    );
    this.clearTopicNotificationsInBackground(detail.id, reportedPostNumber);
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
    this.beginComposerSession(ComposerMediaTarget.REPLY);
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
      this.beginComposerSession(ComposerMediaTarget.TOPIC);
      this.topicEditingTopicId = detail.id;
      this.topicEditingPostId = post.id;
      this.topicEditingOriginalTitle = detail.title;
      this.topicComposerState = TopicComposerState.editing(detail.title, post.raw, detail.categoryId);
      return true;
    }
    this.beginComposerSession(ComposerMediaTarget.REPLY);
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
    let state: MediaUploadState = MediaUploadState.selected(media);
    onStateChange(state);
    if (!this.hasEditableComposer(target)) {
      state = state.failed('编辑器已关闭，未开始图片上传');
      onStateChange(state);
      return state;
    }
    if (this.mediaRepository === null) {
      state = state.failed('图片上传服务不可用');
      onStateChange(state);
      return state;
    }
    if (this.activeMediaUpload !== null) {
      state = state.failed('已有图片正在上传');
      onStateChange(state);
      return state;
    }
    const targetSession: number = this.composerSession(target);

    state = state.uploading(0, media.sizeBytes);
    onStateChange(state);
    const operation: MediaUploadOperation = this.mediaRepository.upload(
      MediaUploadRequest.composer(media),
      (uploadedBytes: number, totalBytes: number): void => {
        if (this.activeMediaState?.kind !== MediaUploadStateKind.CANCELLED) {
          state = state.uploading(uploadedBytes, totalBytes);
          this.activeMediaState = state;
          onStateChange(state);
        }
      }
    );
    this.activeMediaUpload = operation;
    this.activeMediaState = state;
    this.activeMediaStateListener = onStateChange;
    this.activeMediaTarget = target;
    const result: RepositoryResult<MediaUploadResult> = await operation.completion;
    if (this.activeMediaState?.kind === MediaUploadStateKind.CANCELLED) {
      const cancelled: MediaUploadState = this.activeMediaState;
      this.clearActiveMediaUpload(operation);
      return cancelled;
    }
    this.clearActiveMediaUpload(operation);
    if (!result.isSuccess() || result.data === null) {
      if (result.isUnauthorized()) {
        this.requiresAuthentication = true;
        await this.notifyUnauthorized(true);
      }
      state = state.failed(result.message);
      onStateChange(state);
      return state;
    }
    if (this.composerSession(target) !== targetSession || !this.appendComposerMedia(target, result.data)) {
      state = state.failed('编辑器已关闭或切换，上传结果未插入草稿');
      onStateChange(state);
      return state;
    }
    state = state.succeeded(result.data);
    onStateChange(state);
    return state;
  }

  public cancelComposerMediaUpload(): void {
    const operation: MediaUploadOperation | null = this.activeMediaUpload;
    const state: MediaUploadState | null = this.activeMediaState;
    const listener: MediaUploadStateListener | null = this.activeMediaStateListener;
    if (operation === null || state === null || listener === null || !state.canCancel()) {
      return;
    }
    const cancelled: MediaUploadState = state.cancelled();
    this.activeMediaState = cancelled;
    listener(cancelled);
    operation.cancel();
  }

  private hasEditableComposer(target: ComposerMediaTarget): boolean {
    if (target === ComposerMediaTarget.REPLY) {
      return this.replyState.kind === ReplyComposerStateKind.EDITING ||
        this.replyState.kind === ReplyComposerStateKind.ERROR;
    }
    return this.topicComposerState.kind === TopicComposerStateKind.EDITING ||
      this.topicComposerState.kind === TopicComposerStateKind.ERROR;
  }

  private appendComposerMedia(target: ComposerMediaTarget, result: MediaUploadResult): boolean {
    if (target === ComposerMediaTarget.REPLY && (
      this.replyState.kind === ReplyComposerStateKind.EDITING ||
      this.replyState.kind === ReplyComposerStateKind.ERROR
    )) {
      this.updateReplyDraft(appendUploadedImageMarkdown(this.replyState.draft, result));
      return true;
    }
    if (target === ComposerMediaTarget.TOPIC && (
      this.topicComposerState.kind === TopicComposerStateKind.EDITING ||
      this.topicComposerState.kind === TopicComposerStateKind.ERROR
    )) {
      this.updateTopicComposerRaw(appendUploadedImageMarkdown(this.topicComposerState.raw, result));
      return true;
    }
    return false;
  }

  private clearActiveMediaUpload(operation: MediaUploadOperation): void {
    if (this.activeMediaUpload !== operation) {
      return;
    }
    this.activeMediaUpload = null;
    this.activeMediaState = null;
    this.activeMediaStateListener = null;
    this.activeMediaTarget = null;
  }

  private beginComposerSession(target: ComposerMediaTarget): void {
    if (this.activeMediaUpload !== null) {
      this.cancelComposerMediaUpload();
    }
    if (target === ComposerMediaTarget.REPLY) {
      this.replyComposerSession += 1;
    } else {
      this.topicComposerSession += 1;
    }
  }

  private endComposerSession(target: ComposerMediaTarget): void {
    if (this.activeMediaTarget === target) {
      this.cancelComposerMediaUpload();
    }
    if (target === ComposerMediaTarget.REPLY) {
      this.replyComposerSession += 1;
    } else {
      this.topicComposerSession += 1;
    }
  }

  private composerSession(target: ComposerMediaTarget): number {
    return target === ComposerMediaTarget.REPLY
      ? this.replyComposerSession
      : this.topicComposerSession;
  }

  public dismissReply(): void {
    if (this.replyState.isBusy()) {
      return;
    }
    this.endComposerSession(ComposerMediaTarget.REPLY);
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
    this.endComposerSession(ComposerMediaTarget.REPLY);
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

  public openNewTopic(initialCategoryId: number | null = null): void {
    this.beginComposerSession(ComposerMediaTarget.TOPIC);
    this.topicComposerRequestVersion += 1;
    this.topicEditingTopicId = null;
    this.topicEditingPostId = null;
    this.topicEditingOriginalTitle = '';
    this.topicDraftKey = 'new_topic';
    this.topicComposerState = TopicComposerState.editing('', '', initialCategoryId);
  }

  public openTopicDraft(draft: ServerDraft): boolean {
    if (!draft.draftKey.startsWith('new_topic')) {
      return false;
    }
    this.openNewTopic(draft.categoryId);
    this.topicDraftKey = draft.draftKey;
    this.topicComposerState = TopicComposerState.editing(
      draft.title,
      draft.raw,
      draft.categoryId,
      draft.sequence
    );
    return true;
  }

  public updateTopicComposerTitle(title: string): void {
    if (
      this.topicComposerState.kind === TopicComposerStateKind.EDITING ||
      this.topicComposerState.kind === TopicComposerStateKind.ERROR
    ) {
      this.topicComposerState = this.topicComposerState.withTitle(title);
    }
  }

  public updateTopicComposerRaw(raw: string): void {
    if (
      this.topicComposerState.kind === TopicComposerStateKind.EDITING ||
      this.topicComposerState.kind === TopicComposerStateKind.ERROR
    ) {
      this.topicComposerState = this.topicComposerState.withRaw(raw);
    }
  }

  public updateTopicComposerCategory(categoryId: number): void {
    if (
      (this.topicComposerState.kind === TopicComposerStateKind.EDITING ||
        this.topicComposerState.kind === TopicComposerStateKind.ERROR) &&
      Number.isInteger(categoryId) && categoryId > 0
    ) {
      this.topicComposerState = this.topicComposerState.withCategoryId(categoryId);
    }
  }

  public async restoreTopicDraft(): Promise<void> {
    if (this.topicEditingTopicId !== null || this.topicComposerState.kind !== TopicComposerStateKind.EDITING) {
      return;
    }
    const requestVersion: number = this.topicComposerRequestVersion;
    const title: string = this.topicComposerState.title;
    const raw: string = this.topicComposerState.raw;
    const categoryId: number | null = this.topicComposerState.categoryId;
    const result: RepositoryResult<Array<ServerDraft>> = await this.repository.loadDrafts();
    if (
      requestVersion !== this.topicComposerRequestVersion ||
      this.topicComposerState.title !== title ||
      this.topicComposerState.raw !== raw ||
      this.topicComposerState.categoryId !== categoryId
    ) {
      return;
    }
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.topicComposerState = TopicComposerState.reauthenticate(this.topicComposerState);
      await this.notifyUnauthorized(true);
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.topicComposerState = TopicComposerState.error(this.topicComposerState, result.message);
      return;
    }
    const draft: ServerDraft | undefined = result.data.find(
      (candidate: ServerDraft): boolean => candidate.draftKey.startsWith('new_topic') &&
        (this.ignoredTopicDraftSequence === null || candidate.sequence !== this.ignoredTopicDraftSequence)
    );
    if (draft !== undefined) {
      this.topicDraftKey = draft.draftKey;
      this.topicComposerState = TopicComposerState.editing(
        draft.title,
        draft.raw,
        draft.categoryId,
        draft.sequence
      );
    }
  }

  public async saveTopicDraft(): Promise<boolean> {
    if (this.topicEditingTopicId !== null || this.topicComposerState.isBusy()) {
      return false;
    }
    const request: DraftWriteRequest | null = DraftWriteRequest.newTopic(
      this.topicComposerState.title,
      this.topicComposerState.raw,
      this.topicComposerState.categoryId ?? 0,
      this.topicComposerState.draftSequence,
      this.topicDraftKey
    );
    if (request === null) {
      this.topicComposerState = TopicComposerState.error(this.topicComposerState, '草稿内容为空');
      return false;
    }
    const editing: TopicComposerState = this.topicComposerState;
    this.topicComposerState = TopicComposerState.savingDraft(editing);
    const result: RepositoryResult<number> = await this.repository.saveDraft(request);
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.topicComposerState = TopicComposerState.reauthenticate(editing);
      await this.notifyUnauthorized(true);
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.topicComposerState = TopicComposerState.error(editing, result.message);
      return false;
    }
    this.topicComposerState = TopicComposerState.editing(
      editing.title,
      editing.raw,
      editing.categoryId,
      result.data
    );
    this.ignoredTopicDraftSequence = null;
    return true;
  }

  public dismissTopicComposer(): void {
    if (!this.topicComposerState.isBusy()) {
      this.endComposerSession(ComposerMediaTarget.TOPIC);
      this.topicComposerRequestVersion += 1;
      this.topicComposerState = TopicComposerState.closed();
      this.topicEditingTopicId = null;
      this.topicEditingPostId = null;
      this.topicEditingOriginalTitle = '';
    }
  }

  public async discardTopicDraft(): Promise<boolean> {
    if (this.topicComposerState.isBusy()) {
      return false;
    }
    if (this.topicEditingTopicId !== null || this.topicComposerState.draftSequence === 0) {
      this.dismissTopicComposer();
      return true;
    }
    const editing: TopicComposerState = this.topicComposerState;
    const result: RepositoryResult<boolean> = await this.repository.deleteDraft(
      this.topicDraftKey,
      editing.draftSequence
    );
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.topicComposerState = TopicComposerState.reauthenticate(editing);
      await this.notifyUnauthorized(true);
      return false;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.topicComposerState = TopicComposerState.error(editing, result.message);
      return false;
    }
    this.ignoredTopicDraftSequence = null;
    this.dismissTopicComposer();
    return true;
  }

  public resumeTopicAfterAuthentication(): void {
    if (this.topicComposerState.kind === TopicComposerStateKind.REAUTHENTICATE) {
      this.requiresAuthentication = false;
      this.topicComposerState = TopicComposerState.editing(
        this.topicComposerState.title,
        this.topicComposerState.raw,
        this.topicComposerState.categoryId,
        this.topicComposerState.draftSequence
      );
    }
  }

  public async submitTopicComposer(): Promise<void> {
    if (this.topicComposerState.isBusy()) {
      return;
    }
    if (this.topicEditingTopicId !== null && this.topicEditingPostId !== null) {
      await this.submitTopicEdit();
      return;
    }
    const request: CreateTopicRequest | null = CreateTopicRequest.create(
      this.topicComposerState.title,
      this.topicComposerState.raw,
      this.topicComposerState.categoryId ?? 0
    );
    if (request === null) {
      this.topicComposerState = TopicComposerState.error(this.topicComposerState, '请填写标题、Category 和内容');
      return;
    }
    const editing: TopicComposerState = this.topicComposerState;
    this.topicComposerState = TopicComposerState.submitting(editing);
    const result: TopicSubmitResult = await this.repository.submitTopic(request);
    if (result.kind === TopicSubmitKind.UNAUTHORIZED) {
      this.requiresAuthentication = true;
      this.topicComposerState = TopicComposerState.reauthenticate(editing);
      await this.notifyUnauthorized(true);
      return;
    }
    if (result.kind !== TopicSubmitKind.CREATED || result.topicId === null) {
      this.topicComposerState = TopicComposerState.error(editing, result.message);
      return;
    }
    if (editing.draftSequence > 0) {
      const cleanupResult: RepositoryResult<boolean> = await this.repository.deleteDraft(
        this.topicDraftKey,
        editing.draftSequence
      );
      if (!cleanupResult.isSuccess() || cleanupResult.data !== true) {
        this.ignoredTopicDraftSequence = editing.draftSequence;
        this.topicComposerState = TopicComposerState.success(
          result.topicId,
          `Topic 已发布；服务器草稿清理失败：${cleanupResult.message}`
        );
        return;
      }
    }
    this.ignoredTopicDraftSequence = null;
    this.topicComposerState = TopicComposerState.success(result.topicId);
  }

  private async submitTopicEdit(): Promise<void> {
    const topicId: number | null = this.topicEditingTopicId;
    const postId: number | null = this.topicEditingPostId;
    const topicRequest: EditTopicRequest | null = topicId === null
      ? null
      : EditTopicRequest.create(
        topicId,
        this.topicComposerState.title,
        this.topicEditingOriginalTitle,
        this.topicComposerState.categoryId ?? 0
      );
    const postRequest: EditPostRequest | null = postId === null
      ? null
      : EditPostRequest.create(postId, this.topicComposerState.raw);
    if (topicRequest === null || postRequest === null) {
      this.topicComposerState = TopicComposerState.error(this.topicComposerState, '请填写标题、Category 和内容');
      return;
    }
    const editing: TopicComposerState = this.topicComposerState;
    this.topicComposerState = TopicComposerState.submitting(editing);
    const topicResult: RepositoryResult<boolean> = await this.repository.editTopic(topicRequest);
    if (!topicResult.isSuccess() || topicResult.data !== true) {
      await this.handleTopicEditFailure(editing, topicResult);
      return;
    }
    const postResult: RepositoryResult<boolean> = await this.repository.editPost(postRequest);
    if (!postResult.isSuccess() || postResult.data !== true) {
      await this.handleTopicEditFailure(editing, postResult);
      return;
    }
    const post: ForumPost | undefined = this.topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (post !== undefined) {
      const posts: Array<ForumPost> = replacePost(
        this.topicState.posts,
        post.withRawContent(postRequest.raw)
      );
      const detail: TopicDetail | null = this.topicState.detail;
      this.topicState = detail === null
        ? TopicReadState.withPosts(this.topicState, posts)
        : TopicReadState.withDetailAndPosts(
          this.topicState,
          detail.withTitleAndPosts(topicRequest.title, posts, topicRequest.categoryId),
          posts
        );
    }
    this.topicComposerState = TopicComposerState.success(topicRequest.topicId);
  }

  private async handleTopicEditFailure(
    editing: TopicComposerState,
    result: RepositoryResult<boolean>
  ): Promise<void> {
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      this.topicComposerState = TopicComposerState.reauthenticate(editing);
      await this.notifyUnauthorized(true);
      return;
    }
    this.topicComposerState = TopicComposerState.error(editing, result.message);
  }

  public closeSecondary(): void {
    if (this.activeDestination === SecondaryDestination.TOPIC) {
      this.topicRequestVersion += 1;
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
      this.categoryRequestVersion += 1;
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
        detail.lastReadPostNumber
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

  public async loadSearchSuggestions(term: string): Promise<void> {
    const normalizedTerm: string = term.trim();
    this.searchSuggestionRequestVersion += 1;
    const requestVersion: number = this.searchSuggestionRequestVersion;
    if (normalizedTerm.length === 0) {
      this.searchSuggestionState = SearchSuggestionState.initial();
      return;
    }
    this.searchSuggestionState = SearchSuggestionState.loading(normalizedTerm);
    const result: RepositoryResult<Array<string>> = await this.repository.searchSuggestions(normalizedTerm);
    if (requestVersion !== this.searchSuggestionRequestVersion) {
      return;
    }
    if (result.isUnauthorized()) {
      this.requiresAuthentication = true;
      await this.notifyUnauthorized(true);
    }
    if (!result.isSuccess() || result.data === null) {
      this.searchSuggestionState = SearchSuggestionState.error(normalizedTerm, result.message);
      return;
    }
    this.searchSuggestionState = result.data.length === 0
      ? SearchSuggestionState.empty(normalizedTerm)
      : SearchSuggestionState.content(normalizedTerm, result.data);
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
