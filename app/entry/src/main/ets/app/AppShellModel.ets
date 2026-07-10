import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import { Category, Topic } from '../models/ForumModels';
import { ForumRepository } from '../repositories/ForumRepository';

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
  public homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public categoryState: BrowseState<Category> = BrowseState.initial<Category>();

  private readonly repository: ForumRepository;
  private readonly categoryCache: CategoryCache;
  private readonly categoryCacheScope: CategoryCacheScope;

  public constructor(
    repository: ForumRepository,
    categoryCache: CategoryCache,
    categoryCacheScope: CategoryCacheScope
  ) {
    this.repository = repository;
    this.categoryCache = categoryCache;
    this.categoryCacheScope = categoryCacheScope;
  }

  public selectRoot(destination: RootDestination): void {
    this.selectedRoot = destination;
  }

  public async loadHome(): Promise<void> {
    this.homeState = BrowseState.loading<Topic>();
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadLatestTopics();
    if (!result.isSuccess() || result.data === null) {
      this.homeState = BrowseState.error<Topic>(result.message);
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
    let cachedCategories: Array<Category> | null = null;
    try {
      cachedCategories = await this.categoryCache.read(this.categoryCacheScope);
    } catch (_) {
      cachedCategories = null;
    }

    if (cachedCategories === null) {
      this.categoryState = BrowseState.loading<Category>();
    } else if (cachedCategories.length === 0) {
      this.categoryState = BrowseState.empty<Category>(true);
    } else {
      this.categoryState = BrowseState.content<Category>(cachedCategories, true);
    }

    const result: RepositoryResult<Array<Category>> = await this.repository.loadCategories();
    if (!result.isSuccess() || result.data === null) {
      if (cachedCategories === null) {
        this.categoryState = BrowseState.error<Category>(result.message);
      } else if (cachedCategories.length === 0) {
        this.categoryState = BrowseState.empty<Category>(false, result.message);
      } else {
        this.categoryState = BrowseState.content<Category>(cachedCategories, false, result.message);
      }
      return;
    }

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
}
