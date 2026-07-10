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
  private cachedCategories: Array<Category> | null = null;

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
    if (this.categoryState.kind === BrowseStateKind.CONTENT) {
      this.categoryState = BrowseState.content<Category>(this.categoryState.items, true);
    } else if (this.categoryState.kind === BrowseStateKind.EMPTY) {
      this.categoryState = BrowseState.empty<Category>(true);
    } else {
      this.categoryState = BrowseState.loading<Category>();
    }
    const result: RepositoryResult<Array<Category>> = await this.repository.loadCategories();
    if (!result.isSuccess() || result.data === null) {
      if (this.cachedCategories === null) {
        this.categoryState = BrowseState.error<Category>(result.message);
      } else if (this.cachedCategories.length === 0) {
        this.categoryState = BrowseState.empty<Category>(false, result.message);
      } else {
        this.categoryState = BrowseState.content<Category>(this.cachedCategories, false, result.message);
      }
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
}
