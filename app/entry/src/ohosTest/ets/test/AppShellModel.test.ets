import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
  AuthenticationLifecycle,
  BrowseStateKind,
  RootDestination
} from '../../../main/ets/app/AppShellModel';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../../../main/ets/models/ForumModels';
import { ReplyRequest, ReplySubmitResult } from '../../../main/ets/models/ReplyModels';
import { ForumRepository } from '../../../main/ets/repositories/ForumRepository';
import { MemoryCategoryCache } from './support/MemoryCategoryCache';

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

  public async loadCategoryTopics(_categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadTopicDetail(_topicId: number): Promise<RepositoryResult<TopicDetail>> {
    return RepositoryResult.failure<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, _postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>> {
    return RepositoryResult.success<Array<ForumPost>>([]);
  }

  public async submitReply(_request: ReplyRequest): Promise<ReplySubmitResult> {
    return ReplySubmitResult.rejected('missing Reply result');
  }
}

class StubAuthenticationLifecycle implements AuthenticationLifecycle {
  public unauthorizedCallCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCallCount += 1;
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
      model.selectRoot(RootDestination.ACCOUNT);
      expect(model.selectedRoot).assertEqual(RootDestination.ACCOUNT);
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
      const authentication: StubAuthenticationLifecycle = new StubAuthenticationLifecycle();
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        authentication
      );

      await model.loadHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.ERROR);
      expect(model.homeState.message).assertEqual('网络连接失败');

      await model.retryHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.EMPTY);
      expect(repository.latestCallCount).assertEqual(2);
      expect(authentication.unauthorizedCallCount).assertEqual(0);
      done();
    });

    it('exposes an unauthorized Home response to the AppShell', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.latestResults.push(RepositoryResult.unauthorized<Array<Topic>>());
      const authentication: StubAuthenticationLifecycle = new StubAuthenticationLifecycle();
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        authentication
      );

      await model.loadHome();

      expect(model.requiresAuthentication).assertTrue();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.ERROR);
      expect(authentication.unauthorizedCallCount).assertEqual(1);
      done();
    });

    it('distinguishes Category loading, failure, retry and empty states', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.failure<Array<Category>>('网络连接失败'));
      repository.categoryResults.push(RepositoryResult.success([]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      const loading: Promise<void> = model.loadCategories();
      await Promise.resolve();
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.ERROR);

      await model.retryCategories();
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.EMPTY);
      expect(repository.categoryCallCount).assertEqual(2);
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

    it('keeps fresh Category content when a manual refresh fails', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.success([category(60, '站务管理')]));
      repository.categoryResults.push(RepositoryResult.failure<Array<Category>>('刷新失败'));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.loadCategories();

      const refreshing: Promise<void> = model.refreshCategories();
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryState.isRefreshing).assertTrue();
      await refreshing;

      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.categoryState.items[0].id).assertEqual(60);
      expect(model.categoryState.message).assertEqual('刷新失败');
      done();
    });

    it('writes fresh Category data into the active identity partition', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.success([category(60, '站务管理')]));
      const cache: MemoryCategoryCache = new MemoryCategoryCache();
      const scope: CategoryCacheScope | null = CategoryCacheScope.authenticated('client-123');
      expect(scope === null).assertFalse();
      if (scope === null) {
        done();
        return;
      }
      const model: AppShellModel = new AppShellModel(repository, cache, scope);

      await model.loadCategories();

      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(cache.writeScope?.key).assertEqual('authenticated:client-123');
      expect(cache.stored?.length).assertEqual(1);
      done();
    });

    it('rejects an empty authenticated cache identity', 0, () => {
      expect(CategoryCacheScope.authenticated('')).assertNull();
    });

    it('resets Category presentation when the authentication cache partition changes', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryResults.push(RepositoryResult.success([category(60, '站务管理')]));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.loadCategories();
      expect(model.categoryState.kind).assertEqual(BrowseStateKind.CONTENT);
      const authenticated: CategoryCacheScope | null = CategoryCacheScope.authenticated('client-123');
      expect(authenticated === null).assertFalse();
      if (authenticated === null) {
        done();
        return;
      }

      model.updateCategoryCacheScope(authenticated);

      expect(model.categoryState.kind).assertEqual(BrowseStateKind.INITIAL);
      done();
    });
  });
}
