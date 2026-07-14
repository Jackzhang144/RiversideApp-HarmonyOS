import { describe, expect, it } from '@ohos/hypium';
import {
  AppShellModel,
  AuthenticationLifecycle,
  BrowseStateKind,
  HomeSortTabIndex,
  RootDestination,
  RootTabIndex,
  SearchStateKind,
  SecondaryDestination,
  ComposerMediaTarget
} from '../../../main/ets/app/AppShellModel';
import { CategoryCacheScope } from '../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail, TopicPostBatch } from '../../../main/ets/models/ForumModels';
import {
  ForumSearchResult,
  HomeChannel,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../../../main/ets/models/DiscoveryModels';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitResult
} from '../../../main/ets/models/AuthoringModels';
import {
  CurrentUser,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitResult
} from '../../../main/ets/models/ReplyModels';
import { ForumRepository } from '../../../main/ets/repositories/ForumRepository';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState
} from '../../../main/ets/models/MediaModels';
import { MediaRepository, MediaUploadOperation } from '../../../main/ets/repositories/MediaRepository';
import {
  MediaProgressListener,
  MediaTransportOperation
} from '../../../main/ets/network/ForumMediaTransport';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import {
  DiscoverySettings,
  DiscoverySettingsStore
} from '../../../main/ets/settings/DiscoverySettingsStore';
import { MemoryCategoryCache } from './support/MemoryCategoryCache';

class StubForumRepository implements ForumRepository {
  public latestResults: Array<RepositoryResult<Array<Topic>>> = [];
  public categoryResults: Array<RepositoryResult<Array<Category>>> = [];
  public categoryTopicResults: Array<RepositoryResult<Array<Topic>>> = [];
  public searchResults: Array<RepositoryResult<ForumSearchResult>> = [];
  public currentUserResults: Array<RepositoryResult<CurrentUser>> = [];
  public userProfileResults: Array<RepositoryResult<CurrentUser>> = [];
  public latestCallCount: number = 0;
  public categoryCallCount: number = 0;
  public requestedHomeChannels: Array<HomeChannel> = [];
  public requestedHomePages: Array<number> = [];
  public requestedCategoryPages: Array<number> = [];
  public requestedSearchPages: Array<number> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    this.latestCallCount += 1;
    const result: RepositoryResult<Array<Topic>> | undefined = this.latestResults.shift();
    return result ?? RepositoryResult.failure<Array<Topic>>('missing latest result');
  }

  public async loadHomeTopics(channel: HomeChannel, page: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedHomeChannels.push(channel);
    this.requestedHomePages.push(page);
    return this.loadLatestTopics();
  }

  public async searchForum(_query: string, page: number): Promise<RepositoryResult<ForumSearchResult>> {
    this.requestedSearchPages.push(page);
    const result: RepositoryResult<ForumSearchResult> | undefined = this.searchResults.shift();
    return result ?? RepositoryResult.failure<ForumSearchResult>('missing search result');
  }

  public async searchSuggestions(_term: string): Promise<RepositoryResult<Array<string>>> {
    return RepositoryResult.success<Array<string>>([]);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    this.categoryCallCount += 1;
    const result: RepositoryResult<Array<Category>> | undefined = this.categoryResults.shift();
    return result ?? RepositoryResult.failure<Array<Category>>('missing category result');
  }

  public async loadCategoryTopics(_categoryId: number, page: number = 0): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedCategoryPages.push(page);
    const result: RepositoryResult<Array<Topic>> | undefined = this.categoryTopicResults.shift();
    return result ?? RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadTopicDetail(_topicId: number): Promise<RepositoryResult<TopicDetail>> {
    return RepositoryResult.failure<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, _postIds: Array<number>): Promise<RepositoryResult<TopicPostBatch>> {
    return RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([]));
  }

  public async loadTopicSuggestions(_topicId: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async togglePostReaction(_postId: number, _reaction: string): Promise<RepositoryResult<ForumPost>> {
    return RepositoryResult.failure<ForumPost>('missing Reaction result');
  }

  public async createPostBookmark(_postId: number): Promise<RepositoryResult<number>> {
    return RepositoryResult.failure<number>('missing bookmark result');
  }

  public async deletePostBookmark(_bookmarkId: number): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.failure<boolean>('missing bookmark result');
  }

  public async markTopicRead(
    _topicId: number,
    _postNumbers: Array<number>,
    _milliseconds: number
  ): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.failure<boolean>('missing Topic timing result');
  }

  public async clearTopicNotifications(
    _topicId: number,
    _upToPostNumber: number
  ): Promise<RepositoryResult<number>> {
    return RepositoryResult.success<number>(0);
  }

  public async submitReply(_request: ReplyRequest): Promise<ReplySubmitResult> {
    return ReplySubmitResult.rejected('missing Reply result');
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> | undefined = this.currentUserResults.shift();
    return result ?? RepositoryResult.failure<CurrentUser>('missing current user result');
  }

  public async loadUserProfile(_username: string): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> | undefined = this.userProfileResults.shift();
    return result ?? RepositoryResult.failure<CurrentUser>('missing user profile result');
  }

  public async recoverReply(_request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult> {
    return ReplyRecoveryResult.failed('missing Reply recovery result');
  }

  public async submitTopic(_request: CreateTopicRequest): Promise<TopicSubmitResult> {
    return TopicSubmitResult.rejected('missing Topic result');
  }

  public async editPost(_request: EditPostRequest): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.failure<boolean>('missing Post edit result');
  }

  public async editTopic(_request: EditTopicRequest): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.failure<boolean>('missing Topic edit result');
  }

  public async loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>> {
    return RepositoryResult.success<Array<ServerDraft>>([]);
  }

  public async saveDraft(_request: DraftWriteRequest): Promise<RepositoryResult<number>> {
    return RepositoryResult.failure<number>('missing draft result');
  }

  public async deleteDraft(_draftKey: string, _sequence: number): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.failure<boolean>('missing draft delete result');
  }
}

class PendingMediaTransportOperation implements MediaTransportOperation {
  public readonly completion: Promise<HttpTextResult> = Promise.resolve(HttpTextResult.failure(0, 'unused'));
  public cancelled: boolean = false;

  public cancel(): void {
    this.cancelled = true;
  }
}

class PendingMediaRepository implements MediaRepository {
  public readonly transportOperation: PendingMediaTransportOperation = new PendingMediaTransportOperation();
  private resolver: ((result: RepositoryResult<MediaUploadResult>) => void) | null = null;

  public upload(_request: MediaUploadRequest, _onProgress: MediaProgressListener): MediaUploadOperation {
    const completion: Promise<RepositoryResult<MediaUploadResult>> =
      new Promise<RepositoryResult<MediaUploadResult>>(
        (resolve: (result: RepositoryResult<MediaUploadResult>) => void): void => {
          this.resolver = resolve;
        }
      );
    return new MediaUploadOperation(this.transportOperation, completion);
  }

  public complete(result: RepositoryResult<MediaUploadResult>): void {
    const resolve: ((result: RepositoryResult<MediaUploadResult>) => void) | null = this.resolver;
    if (resolve !== null) {
      this.resolver = null;
      resolve(result);
    }
  }
}

class StubAuthenticationLifecycle implements AuthenticationLifecycle {
  public unauthorizedCallCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCallCount += 1;
  }
}

class MemoryDiscoverySettingsStore implements DiscoverySettingsStore {
  public stored: DiscoverySettings | null = null;
  public writes: Array<DiscoverySettings> = [];

  public async read(): Promise<DiscoverySettings | null> {
    return this.stored;
  }

  public async write(settings: DiscoverySettings): Promise<void> {
    this.stored = settings;
    this.writes.push(settings);
  }
}

function topic(id: number, title: string): Topic {
  return new Topic(id, title, 60, 1, 10, 0, '', '', false, 'Co-admin');
}

function category(id: number, name: string): Category {
  return new Category(id, name, '25AAE2', '', 1, null, []);
}

function cachedComposerImage(): CachedMedia {
  const media: CachedMedia | null = CachedMedia.create(
    'composer-race',
    '/data/storage/el2/base/cache/media/composer-race.png',
    'internal://cache/media/composer-race.png',
    'composer-race.png',
    'image/png',
    1024
  );
  if (media === null) {
    throw new Error('测试媒体模型创建失败');
  }
  return media;
}

function searchResult(
  topics: Array<Topic>,
  posts: Array<SearchPost>,
  hasMore: boolean,
  suffix: string = ''
): ForumSearchResult {
  return new ForumSearchResult(
    topics,
    posts,
    [new SearchUser(30 + suffix.length, `user${suffix}`, `用户${suffix}`, '')],
    [category(60 + suffix.length, `分类${suffix}`)],
    [new SearchTag(`tag${suffix}`, `标签${suffix}`, 1)],
    [new SearchGroup(50 + suffix.length, `group${suffix}`, `群组${suffix}`, 2)],
    hasMore
  );
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

    it('never inserts an old upload into a newly opened Topic composer', 0, async (done: Function) => {
      const mediaRepository: PendingMediaRepository = new PendingMediaRepository();
      const model: AppShellModel = new AppShellModel(
        new StubForumRepository(),
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        null,
        null,
        mediaRepository
      );
      model.openNewTopic();
      model.updateTopicComposerTitle('草稿 A');
      model.updateTopicComposerRaw('仅属于 A');
      const upload: Promise<MediaUploadState> = model.uploadComposerMedia(
        cachedComposerImage(),
        ComposerMediaTarget.TOPIC,
        (_state: MediaUploadState): void => {}
      );

      model.openNewTopic();
      model.updateTopicComposerTitle('草稿 B');
      model.updateTopicComposerRaw('仅属于 B');
      const result: MediaUploadResult | null = MediaUploadResult.create(
        812,
        '/uploads/original/composer-race.png',
        'upload://composer-race',
        'composer-race.png',
        '![composer-race.png](upload://composer-race)'
      );
      expect(result === null).assertFalse();
      if (result === null) {
        done();
        return;
      }
      mediaRepository.complete(RepositoryResult.success<MediaUploadResult>(result));
      await upload;

      expect(mediaRepository.transportOperation.cancelled).assertTrue();
      expect(model.topicComposerState.title).assertEqual('草稿 B');
      expect(model.topicComposerState.raw).assertEqual('仅属于 B');
      done();
    });

    it('selects only available destinations from the five visible root tabs', 0, () => {
      const model: AppShellModel = new AppShellModel(
        new StubForumRepository(),
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      expect(model.selectRootTab(RootTabIndex.CATEGORY)).assertTrue();
      expect(model.selectedRoot).assertEqual(RootDestination.CATEGORY);

      expect(model.selectRootTab(RootTabIndex.CHAT)).assertTrue();
      expect(model.selectedRoot).assertEqual(RootDestination.CHAT);
      expect(model.selectRootTab(RootTabIndex.NOTIFICATIONS)).assertFalse();
      expect(model.selectedRoot).assertEqual(RootDestination.CHAT);

      expect(model.selectRootTab(RootTabIndex.ACCOUNT)).assertTrue();
      expect(model.selectedRoot).assertEqual(RootDestination.ACCOUNT);
      expect(model.selectRootTab(RootTabIndex.HOME)).assertTrue();
      expect(model.selectedRoot).assertEqual(RootDestination.HOME);
      expect(model.selectRootTab(-1)).assertFalse();
      expect(model.selectedRoot).assertEqual(RootDestination.HOME);
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

    it('selects every frozen Home channel without starting hidden network work', 0, () => {
      const repository: StubForumRepository = new StubForumRepository();
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      expect(model.selectHomeSortTab(HomeSortTabIndex.LATEST_REPLIES)).assertTrue();
      expect(model.selectHomeSortTab(HomeSortTabIndex.LATEST_CREATED)).assertTrue();
      expect(model.selectHomeSortTab(HomeSortTabIndex.UNREAD)).assertTrue();
      expect(model.selectHomeSortTab(HomeSortTabIndex.HOT)).assertTrue();
      expect(model.selectHomeSortTab(HomeSortTabIndex.FEATURED)).assertTrue();
      expect(model.selectedHomeChannel).assertEqual(HomeChannel.FEATURED);
      expect(model.selectHomeSortTab(99)).assertFalse();
      expect(repository.latestCallCount).assertEqual(0);
      expect(model.activeDestination).assertEqual(SecondaryDestination.NONE);
    });

    it('loads and deduplicates paged Home topics for the selected channel', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.latestResults.push(
        RepositoryResult.success([topic(1, '第一页')]),
        RepositoryResult.success([topic(1, '重复'), topic(2, '第二页')]),
        RepositoryResult.success([])
      );
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      model.selectHomeSortTab(HomeSortTabIndex.HOT);

      await model.loadHome();
      await model.loadMoreHome();

      expect(repository.requestedHomeChannels[0]).assertEqual(HomeChannel.HOT);
      expect(repository.requestedHomePages[0]).assertEqual(0);
      expect(repository.requestedHomePages[1]).assertEqual(1);
      expect(model.homeState.items.length).assertEqual(2);
      expect(model.homeState.items[1].id).assertEqual(2);
      expect(model.homeState.hasMore).assertTrue();

      await model.loadMoreHome();
      expect(model.homeState.hasMore).assertFalse();
      done();
    });

    it('loads and deduplicates Category Topic pages', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.categoryTopicResults.push(
        RepositoryResult.success([topic(1, '第一页')]),
        RepositoryResult.success([topic(1, '重复'), topic(2, '第二页')])
      );
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.openCategory(category(60, '站务管理'));
      await model.loadMoreCategoryTopics();

      expect(repository.requestedCategoryPages[0]).assertEqual(0);
      expect(repository.requestedCategoryPages[1]).assertEqual(1);
      expect(model.categoryTopicsState.items.length).assertEqual(2);
      expect(model.categoryTopicsState.hasMore).assertTrue();
      done();
    });

    it('searches all result kinds and deduplicates the next page', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      const firstTopic: Topic = topic(1, '第一页');
      const secondTopic: Topic = topic(2, '第二页');
      const firstPost: SearchPost = new SearchPost(10, firstTopic, 1, 'admin', '第一条', '');
      const secondPost: SearchPost = new SearchPost(11, secondTopic, 2, 'user', '第二条', '');
      repository.searchResults.push(
        RepositoryResult.success(searchResult([firstTopic], [firstPost], true)),
        RepositoryResult.success(searchResult([firstTopic, secondTopic], [firstPost, secondPost], false, '2'))
      );
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.searchForum('河畔');
      expect(model.searchState.kind).assertEqual(SearchStateKind.CONTENT);
      expect(model.searchState.result.topics.length).assertEqual(1);
      expect(model.searchState.result.users.length).assertEqual(1);

      await model.loadMoreSearch();
      expect(repository.requestedSearchPages[0]).assertEqual(1);
      expect(repository.requestedSearchPages[1]).assertEqual(2);
      expect(model.searchState.result.topics.length).assertEqual(2);
      expect(model.searchState.result.posts.length).assertEqual(2);
      expect(model.searchState.result.users.length).assertEqual(2);
      expect(model.searchState.hasMore).assertFalse();
      done();
    });

    it('distinguishes blank, failed and empty forum search states', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.searchResults.push(
        RepositoryResult.failure<ForumSearchResult>('搜索失败'),
        RepositoryResult.success(new ForumSearchResult([], [], [], [], [], [], false))
      );
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      await model.searchForum('  ');
      expect(model.searchState.kind).assertEqual(SearchStateKind.INITIAL);
      expect(repository.requestedSearchPages.length).assertEqual(0);

      await model.searchForum('河畔');
      expect(model.searchState.kind).assertEqual(SearchStateKind.ERROR);
      expect(model.searchState.message).assertEqual('搜索失败');

      await model.retrySearch();
      expect(model.searchState.kind).assertEqual(SearchStateKind.EMPTY);
      done();
    });

    it('restores and persists the Home channel and World Cup entry setting', 0, async (done: Function) => {
      const settings: MemoryDiscoverySettingsStore = new MemoryDiscoverySettingsStore();
      settings.stored = new DiscoverySettings(HomeChannel.HOT, false);
      const model: AppShellModel = new AppShellModel(
        new StubForumRepository(),
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        null,
        settings
      );

      await model.restoreDiscoverySettings();
      expect(model.selectedHomeChannel).assertEqual(HomeChannel.HOT);
      expect(model.worldCupEntryEnabled).assertFalse();

      expect(await model.selectHomeChannel(HomeSortTabIndex.FEATURED)).assertTrue();
      await model.setWorldCupEntryEnabled(true);
      expect(settings.writes.length).assertEqual(2);
      expect(settings.stored?.homeChannel).assertEqual(HomeChannel.FEATURED);
      expect(settings.stored?.worldCupEntryEnabled).assertTrue();
      done();
    });

    it('applies a supported server Home preference and persists it', 0, async (done: Function) => {
      const settings: MemoryDiscoverySettingsStore = new MemoryDiscoverySettingsStore();
      const model: AppShellModel = new AppShellModel(
        new StubForumRepository(),
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous(),
        null,
        settings
      );

      expect(await model.applyServerHomeChannel(HomeChannel.LATEST_CREATED)).assertTrue();
      expect(model.selectedHomeChannel).assertEqual(HomeChannel.LATEST_CREATED);
      expect(settings.stored?.homeChannel).assertEqual(HomeChannel.LATEST_CREATED);
      done();
    });

    it('falls back to the user Profile for a missing session Home preference', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      const sessionUser: CurrentUser | null = CurrentUser.create(24, 'member', {
        name: '会话身份',
        canCreatePost: false
      });
      const profileUser: CurrentUser | null = CurrentUser.create(24, 'member', {
        defaultHomeChannel: HomeChannel.HOT
      });
      if (sessionUser === null || profileUser === null) {
        expect(false).assertTrue();
        done();
        return;
      }
      repository.currentUserResults.push(RepositoryResult.success(sessionUser));
      repository.userProfileResults.push(RepositoryResult.success(profileUser));
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );

      const result: RepositoryResult<CurrentUser> = await model.loadCurrentUser();

      expect(result.data?.displayName).assertEqual('会话身份');
      expect(result.data?.canReply).assertFalse();
      expect(result.data?.defaultHomeChannel).assertEqual(HomeChannel.HOT);
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

    it('keeps visible Home content when a refresh fails and replaces it on success', 0, async (done: Function) => {
      const repository: StubForumRepository = new StubForumRepository();
      repository.latestResults.push(
        RepositoryResult.success([topic(2725, '已有 Topic')]),
        RepositoryResult.failure<Array<Topic>>('刷新失败'),
        RepositoryResult.success([topic(3000, '新 Topic')])
      );
      const model: AppShellModel = new AppShellModel(
        repository,
        new MemoryCategoryCache(),
        CategoryCacheScope.anonymous()
      );
      await model.loadHome();

      const failingRefresh: Promise<void> = model.refreshHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.homeState.isRefreshing).assertTrue();
      expect(model.homeState.items[0].id).assertEqual(2725);
      await failingRefresh;

      expect(model.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.homeState.isRefreshing).assertFalse();
      expect(model.homeState.items[0].id).assertEqual(2725);
      expect(model.homeState.message).assertEqual('刷新失败');

      await model.refreshHome();
      expect(model.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(model.homeState.items[0].id).assertEqual(3000);
      expect(model.homeState.message).assertEqual('');
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
