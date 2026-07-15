import { CategoryCache, CategoryCacheScope } from '../cache/CategoryCache';
import { RepositoryResult } from '../core/RepositoryResult';
import { Category, Topic } from '../models/ForumModels';
import { ForumRepository } from '../repositories/ForumRepository';
import { BrowseState, BrowseStateKind, uniqueTopics } from './BrowseModels';

export type CategoryAuthenticationStateHandler = (isUnauthorized: boolean) => void;
export type CategoryUnauthorizedHandler = () => Promise<void>;

export class CategoryBrowseCoordinator {
  public state: BrowseState<Category> = BrowseState.initial<Category>();
  public selected: Category | null = null;
  public topicsState: BrowseState<Topic> = BrowseState.initial<Topic>();

  private readonly repository: ForumRepository;
  private readonly cache: CategoryCache;
  private cacheScope: CategoryCacheScope;
  private readonly updateAuthenticationState: CategoryAuthenticationStateHandler;
  private readonly handleUnauthorized: CategoryUnauthorizedHandler;
  private cachedCategories: Array<Category> | null = null;
  private requestVersion: number = 0;
  private topicsPage: number = 0;

  public constructor(
    repository: ForumRepository,
    cache: CategoryCache,
    cacheScope: CategoryCacheScope,
    updateAuthenticationState: CategoryAuthenticationStateHandler,
    handleUnauthorized: CategoryUnauthorizedHandler
  ) {
    this.repository = repository;
    this.cache = cache;
    this.cacheScope = cacheScope;
    this.updateAuthenticationState = updateAuthenticationState;
    this.handleUnauthorized = handleUnauthorized;
  }

  public updateCacheScope(scope: CategoryCacheScope): void {
    if (this.cacheScope.key === scope.key) {
      return;
    }
    this.cacheScope = scope;
    this.cachedCategories = null;
    this.state = BrowseState.initial<Category>();
  }

  public async open(category: Category): Promise<void> {
    this.requestVersion += 1;
    const requestVersion: number = this.requestVersion;
    this.updateAuthenticationState(false);
    this.selected = category;
    this.topicsState = BrowseState.loading<Topic>();
    this.topicsPage = 0;
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadCategoryTopics(category.id, 0);
    if (requestVersion !== this.requestVersion || this.selected?.id !== category.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.topicsState = BrowseState.error<Topic>(result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.topicsState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
  }

  public async loadMoreTopics(): Promise<void> {
    const category: Category | null = this.selected;
    const currentState: BrowseState<Topic> = this.topicsState;
    if (
      category === null ||
      currentState.kind !== BrowseStateKind.CONTENT ||
      !currentState.hasMore ||
      currentState.isLoadingMore
    ) {
      return;
    }
    const requestVersion: number = this.requestVersion;
    const nextPage: number = this.topicsPage + 1;
    this.topicsState = BrowseState.content<Topic>(currentState.items, false, '', true, true);
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadCategoryTopics(category.id, nextPage);
    if (requestVersion !== this.requestVersion || this.selected?.id !== category.id) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.topicsState = BrowseState.content<Topic>(
        currentState.items,
        false,
        '',
        true,
        false,
        result.message
      );
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    const merged: Array<Topic> = uniqueTopics(currentState.items, result.data);
    const addedCount: number = merged.length - currentState.items.length;
    this.topicsPage = nextPage;
    this.topicsState = BrowseState.content<Topic>(merged, false, '', addedCount > 0);
  }

  public async retryTopics(): Promise<void> {
    const category: Category | null = this.selected;
    if (category !== null) {
      await this.open(category);
    }
  }

  public close(): void {
    this.requestVersion += 1;
    this.selected = null;
    this.topicsPage = 0;
    this.topicsState = BrowseState.initial<Topic>();
  }

  public async load(): Promise<void> {
    await this.restore();
    await this.refresh();
  }

  public async restore(): Promise<void> {
    this.cachedCategories = null;
    try {
      this.cachedCategories = await this.cache.read(this.cacheScope);
    } catch (_) {
      this.cachedCategories = null;
    }

    if (this.cachedCategories === null) {
      this.state = BrowseState.loading<Category>();
    } else if (this.cachedCategories.length === 0) {
      this.state = BrowseState.empty<Category>(true);
    } else {
      this.state = BrowseState.content<Category>(this.cachedCategories, true);
    }
  }

  public async refresh(): Promise<void> {
    this.updateAuthenticationState(false);
    if (this.state.kind === BrowseStateKind.CONTENT) {
      this.state = BrowseState.content<Category>(this.state.items, true);
    } else if (this.state.kind === BrowseStateKind.EMPTY) {
      this.state = BrowseState.empty<Category>(true);
    } else {
      this.state = BrowseState.loading<Category>();
    }
    const result: RepositoryResult<Array<Category>> = await this.repository.loadCategories();
    if (!result.isSuccess() || result.data === null) {
      if (this.cachedCategories === null) {
        this.state = BrowseState.error<Category>(result.message);
      } else if (this.cachedCategories.length === 0) {
        this.state = BrowseState.empty<Category>(false, result.message);
      } else {
        this.state = BrowseState.content<Category>(this.cachedCategories, false, result.message);
      }
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }

    this.cachedCategories = result.data;
    this.state = result.data.length === 0
      ? BrowseState.empty<Category>()
      : BrowseState.content<Category>(result.data);
    try {
      await this.cache.write(this.cacheScope, result.data);
    } catch (_) {
      // Fresh browse content remains usable when best-effort cache persistence fails.
    }
  }

  public async retry(): Promise<void> {
    await this.load();
  }

  private async applyAuthenticationFailure(isUnauthorized: boolean): Promise<void> {
    this.updateAuthenticationState(isUnauthorized);
    if (isUnauthorized) {
      await this.handleUnauthorized();
    }
  }
}
