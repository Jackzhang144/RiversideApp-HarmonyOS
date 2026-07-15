import { Category, Topic } from '../models/ForumModels';
import {
  ForumSearchResult,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../models/DiscoveryModels';

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

export function uniqueTopics(existing: Array<Topic>, incoming: Array<Topic>): Array<Topic> {
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

export function mergeSearchResults(existing: ForumSearchResult, incoming: ForumSearchResult): ForumSearchResult {
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
