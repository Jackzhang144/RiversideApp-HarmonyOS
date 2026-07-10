import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
  BrowseStateKind,
  RootDestination
} from '../../../main/ets/app/AppShellModel';
import { CategoryCache, CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { Category, Topic } from '../../../main/ets/models/ForumModels';
import { ForumRepository } from '../../../main/ets/repositories/ForumRepository';

class StubForumRepository implements ForumRepository {
  public latestResults: Array<RepositoryResult<Array<Topic>>> = [];
  public categoryResults: Array<RepositoryResult<Array<Category>>> = [];
  public latestCallCount: number = 0;
  public categoryCallCount: number = 0;

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    this.latestCallCount += 1;
    const result: RepositoryResult<Array<Topic>> | undefined = this.latestResults.shift();
    return result ?? RepositoryResult.failure<Array<Topic>>('missing latest result');
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    this.categoryCallCount += 1;
    const result: RepositoryResult<Array<Category>> | undefined = this.categoryResults.shift();
    return result ?? RepositoryResult.failure<Array<Category>>('missing category result');
  }
}

class MemoryCategoryCache implements CategoryCache {
  public stored: Array<Category> | null = null;
  public readScope: CategoryCacheScope | null = null;
  public writeScope: CategoryCacheScope | null = null;

  public async read(scope: CategoryCacheScope): Promise<Array<Category> | null> {
    this.readScope = scope;
    return this.stored;
  }

  public async write(scope: CategoryCacheScope, categories: Array<Category>): Promise<void> {
    this.writeScope = scope;
    this.stored = categories;
  }
}

function topic(id: number, title: string): Topic {
  return new Topic(id, title, 60, 1, 10, 0, '', '', false, 'Co-admin');
}

function category(id: number, name: string): Category {
  return new Category(id, name, '25AAE2', '', 1, null, []);
}

export default function appShellModelTest(): void {
  describe('AppShell browse composition', () => {
    it('owns the Home and Category root selection', 0, () => {
      const repository: StubForumRepository = new StubForumRepository();
      const cache: MemoryCategoryCache = new MemoryCategoryCache();
      const model: AppShellModel = new AppShellModel(repository, cache, CategoryCacheScope.anonymous());

      expect(model.selectedRoot).assertEqual(RootDestination.HOME);
      model.selectRoot(RootDestination.CATEGORY);
      expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);
    });

    it('shows Home loading then content from the repository', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.latestResults.push(RepositoryResult.success([topic(2725, '站务管理区重要主题导航')]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      const loading: Promise<void> = model.loadHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;

      expect(model.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.homeState.items.length).assertEqual(1);
      expect(model.homeState.items[0].id).assertEqual(2725);
      done();
    });

    it('distinguishes Home empty and retryable failure states', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.latestResults.push(RepositoryResult.failure<Array<Topic>>('网络连接失败'));
      repository.latestResults.push(RepositoryResult.success([]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.loadHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.ERROR);
      expect(model.homeState.message).assertEqual('网络连接失败');

      await model.retryHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.EMPTY);
      expect(repository.latestCallCount).assertEqual(2);
      done();
    });

    it('keeps cached Category content when background refresh fails', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.failure<Array<Category>>('刷新失败'));
      const cache: MemoryCategoryCache = new MemoryCategoryCache();
      cache.stored = [category(60, '站务管理')];
      const scope: CategoryCacheScope = CategoryCacheScope.anonymous();
      const model: AppShellModel = new AppShellModel(repository, cache, scope);

      const refreshing: Promise<void> = model.loadCategories();
      await Promise.resolve();
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryState.isRefreshing).assertTrue();
      await refreshing;

      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryState.items[0].id).assertEqual(60);
      expect(model.categoryState.isRefreshing).assertFalse();
      expect(model.categoryState.message).assertEqual('刷新失败');
      done();
    });

    it('writes fresh Category data into the active identity partition', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.success([category(60, '站务管理')]));
      const cache: MemoryCategoryCache = new MemoryCategoryCache();
      const scope: CategoryCacheScope = CategoryCacheScope.authenticated('client-123');
      const model: AppShellModel = new AppShellModel(repository, cache, scope);

      await model.loadCategories();

      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(cache.writeScope?.key).assertEqual('authenticated:client-123');
      expect(cache.stored?.length).assertEqual(1);
      done();
    });
  });
}
