import { describe, expect, it } from '@ohos/hypium';
import {
  BrowseStateKind,
  SearchStateKind,
  SearchSuggestionStateKind
} from '../../../main/ets/app/BrowseModels';
import { DiscoveryCoordinator } from '../../../main/ets/app/DiscoveryCoordinator';
import { HomeSortTabIndex } from '../../../main/ets/app/ShellNavigationModels';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  ForumSearchResult,
  HomeChannel,
  SearchGroup,
  SearchPost,
  SearchTag,
  SearchUser
} from '../../../main/ets/models/DiscoveryModels';
import { Category, Topic } from '../../../main/ets/models/ForumModels';
import {
  DiscoverySettings,
  DiscoverySettingsStore
} from '../../../main/ets/settings/DiscoverySettingsStore';
import { TopicReadingRepository } from './support/TopicReadingTestFixtures';

class DiscoveryRepository extends TopicReadingRepository {
  public latestResults: Array<RepositoryResult<Array<Topic>>> = [];
  public searchResults: Array<RepositoryResult<ForumSearchResult>> = [];
  public suggestionResults: Array<RepositoryResult<Array<string>>> = [];
  public latestCallCount: number = 0;
  public requestedHomeChannels: Array<HomeChannel> = [];
  public requestedHomePages: Array<number> = [];
  public requestedSearchPages: Array<number> = [];
  public requestedSuggestionTerms: Array<string> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    this.latestCallCount += 1;
    return this.latestResults.shift() ?? RepositoryResult.unknown<Array<Topic>>('missing latest result');
  }

  public async loadHomeTopics(channel: HomeChannel, page: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedHomeChannels.push(channel);
    this.requestedHomePages.push(page);
    return await this.loadLatestTopics();
  }

  public async searchForum(_query: string, page: number): Promise<RepositoryResult<ForumSearchResult>> {
    this.requestedSearchPages.push(page);
    return this.searchResults.shift() ?? RepositoryResult.unknown<ForumSearchResult>('missing search result');
  }

  public async searchSuggestions(term: string): Promise<RepositoryResult<Array<string>>> {
    this.requestedSuggestionTerms.push(term);
    return this.suggestionResults.shift() ?? RepositoryResult.success<Array<string>>([]);
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

class DiscoveryAuthenticationProbe {
  public required: boolean = false;
  public unauthorizedCallCount: number = 0;

  public coordinator(
    repository: DiscoveryRepository,
    settingsStore: DiscoverySettingsStore | null = null
  ): DiscoveryCoordinator {
    return new DiscoveryCoordinator(
      repository,
      settingsStore,
      (required: boolean): void => {
        this.required = required;
      },
      async (): Promise<void> => {
        this.unauthorizedCallCount += 1;
      }
    );
  }
}

function topic(id: number, title: string): Topic {
  return new Topic(id, title, 60, 1, 10, 0, '', '', false, 'Co-admin');
}

function category(id: number, name: string): Category {
  return new Category(id, name, '25AAE2', '', 1, null, []);
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

export default function discoveryCoordinatorTest(): void {
  describe('DiscoveryCoordinator public behavior', () => {
    it('shows Home loading then content from the repository', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.latestResults.push(RepositoryResult.success([topic(2725, '站务管理区重要主题导航')]));
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);

      const loading: Promise<void> = coordinator.loadHome();
      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.LOADING);
      await loading;

      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(coordinator.homeState.items.length).assertEqual(1);
      expect(coordinator.homeState.items[0].id).assertEqual(2725);
      done();
    });

    it('selects every Home channel without starting hidden network work', 0, () => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);

      expect(coordinator.selectHomeSortTab(HomeSortTabIndex.LATEST_REPLIES)).assertTrue();
      expect(coordinator.selectHomeSortTab(HomeSortTabIndex.LATEST_CREATED)).assertTrue();
      expect(coordinator.selectHomeSortTab(HomeSortTabIndex.UNREAD)).assertTrue();
      expect(coordinator.selectHomeSortTab(HomeSortTabIndex.HOT)).assertTrue();
      expect(coordinator.selectHomeSortTab(HomeSortTabIndex.FEATURED)).assertTrue();
      expect(coordinator.selectedHomeChannel).assertEqual(HomeChannel.FEATURED);
      expect(coordinator.selectHomeSortTab(99)).assertFalse();
      expect(repository.latestCallCount).assertEqual(0);
    });

    it('loads and deduplicates paged Home topics for the selected channel', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.latestResults.push(
        RepositoryResult.success([topic(1, '第一页')]),
        RepositoryResult.success([topic(1, '重复'), topic(2, '第二页')]),
        RepositoryResult.success([])
      );
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);
      coordinator.selectHomeSortTab(HomeSortTabIndex.HOT);

      await coordinator.loadHome();
      await coordinator.loadMoreHome();

      expect(repository.requestedHomeChannels[0]).assertEqual(HomeChannel.HOT);
      expect(repository.requestedHomePages[0]).assertEqual(0);
      expect(repository.requestedHomePages[1]).assertEqual(1);
      expect(coordinator.homeState.items.length).assertEqual(2);
      expect(coordinator.homeState.items[1].id).assertEqual(2);
      expect(coordinator.homeState.hasMore).assertTrue();

      await coordinator.loadMoreHome();
      expect(coordinator.homeState.hasMore).assertFalse();
      done();
    });

    it('searches all result kinds and deduplicates the next page', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      const firstTopic: Topic = topic(1, '第一页');
      const secondTopic: Topic = topic(2, '第二页');
      const firstPost: SearchPost = new SearchPost(10, firstTopic, 1, 'admin', '第一条', '');
      const secondPost: SearchPost = new SearchPost(11, secondTopic, 2, 'user', '第二条', '');
      repository.searchResults.push(
        RepositoryResult.success(searchResult([firstTopic], [firstPost], true)),
        RepositoryResult.success(searchResult([firstTopic, secondTopic], [firstPost, secondPost], false, '2'))
      );
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);

      await coordinator.searchForum('河畔');
      expect(coordinator.searchState.kind).assertEqual(SearchStateKind.CONTENT);
      expect(coordinator.searchState.result.topics.length).assertEqual(1);
      expect(coordinator.searchState.result.users.length).assertEqual(1);

      await coordinator.loadMoreSearch();
      expect(repository.requestedSearchPages[0]).assertEqual(1);
      expect(repository.requestedSearchPages[1]).assertEqual(2);
      expect(coordinator.searchState.result.topics.length).assertEqual(2);
      expect(coordinator.searchState.result.posts.length).assertEqual(2);
      expect(coordinator.searchState.result.users.length).assertEqual(2);
      expect(coordinator.searchState.hasMore).assertFalse();
      done();
    });

    it('distinguishes blank, failed and empty forum search states', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.searchResults.push(
        RepositoryResult.unknown<ForumSearchResult>('搜索失败'),
        RepositoryResult.success(new ForumSearchResult([], [], [], [], [], [], false))
      );
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);

      await coordinator.searchForum('  ');
      expect(coordinator.searchState.kind).assertEqual(SearchStateKind.INITIAL);
      expect(repository.requestedSearchPages.length).assertEqual(0);

      await coordinator.searchForum('河畔');
      expect(coordinator.searchState.kind).assertEqual(SearchStateKind.ERROR);
      expect(coordinator.searchState.message).assertEqual('搜索失败');

      await coordinator.retrySearch();
      expect(coordinator.searchState.kind).assertEqual(SearchStateKind.EMPTY);
      done();
    });

    it('models search suggestion loading, content, error and blank reset', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.suggestionResults.push(
        RepositoryResult.success<Array<string>>(['河畔开发日志', '河畔使用指南']),
        RepositoryResult.unknown<Array<string>>('建议加载失败')
      );
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);

      await coordinator.loadSearchSuggestions(' 河畔 ');
      expect(coordinator.searchSuggestionState.kind).assertEqual(SearchSuggestionStateKind.CONTENT);
      expect(coordinator.searchSuggestionState.items.length).assertEqual(2);
      expect(repository.requestedSuggestionTerms[0]).assertEqual('河畔');

      await coordinator.loadSearchSuggestions('失败');
      expect(coordinator.searchSuggestionState.kind).assertEqual(SearchSuggestionStateKind.ERROR);
      expect(coordinator.searchSuggestionState.message).assertEqual('建议加载失败');

      await coordinator.loadSearchSuggestions('   ');
      expect(coordinator.searchSuggestionState.kind).assertEqual(SearchSuggestionStateKind.INITIAL);
      expect(repository.requestedSuggestionTerms.length).assertEqual(2);
      done();
    });

    it('restores and persists Home discovery settings', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      const settings: MemoryDiscoverySettingsStore = new MemoryDiscoverySettingsStore();
      settings.stored = new DiscoverySettings(HomeChannel.HOT, false);
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository, settings);

      await coordinator.restoreSettings();
      expect(coordinator.selectedHomeChannel).assertEqual(HomeChannel.HOT);
      expect(coordinator.worldCupEntryEnabled).assertFalse();

      expect(await coordinator.selectHomeChannel(HomeSortTabIndex.FEATURED)).assertTrue();
      await coordinator.setWorldCupEntryEnabled(true);
      expect(settings.writes.length).assertEqual(2);
      expect(settings.stored?.homeChannel).assertEqual(HomeChannel.FEATURED);
      expect(settings.stored?.worldCupEntryEnabled).assertTrue();
      done();
    });

    it('applies and persists a supported server Home preference', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      const settings: MemoryDiscoverySettingsStore = new MemoryDiscoverySettingsStore();
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository, settings);

      expect(await coordinator.applyHomeChannelPreference(HomeChannel.LATEST_CREATED)).assertTrue();
      expect(coordinator.selectedHomeChannel).assertEqual(HomeChannel.LATEST_CREATED);
      expect(settings.stored?.homeChannel).assertEqual(HomeChannel.LATEST_CREATED);
      done();
    });

    it('distinguishes Home empty and retryable failure states', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.latestResults.push(RepositoryResult.unknown<Array<Topic>>('网络连接失败'));
      repository.latestResults.push(RepositoryResult.success([]));
      const authentication: DiscoveryAuthenticationProbe = new DiscoveryAuthenticationProbe();
      const coordinator: DiscoveryCoordinator = authentication.coordinator(repository);

      await coordinator.loadHome();
      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.ERROR);
      expect(coordinator.homeState.message).assertEqual('网络连接失败');

      await coordinator.retryHome();
      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.EMPTY);
      expect(repository.latestCallCount).assertEqual(2);
      expect(authentication.unauthorizedCallCount).assertEqual(0);
      done();
    });

    it('keeps visible Home content when refresh fails and replaces it on success', 0, async (done: Function) => {
      const repository: DiscoveryRepository = new DiscoveryRepository();
      repository.latestResults.push(
        RepositoryResult.success([topic(2725, '已有 Topic')]),
        RepositoryResult.unknown<Array<Topic>>('刷新失败'),
        RepositoryResult.success([topic(3000, '新 Topic')])
      );
      const coordinator: DiscoveryCoordinator = new DiscoveryAuthenticationProbe().coordinator(repository);
      await coordinator.loadHome();

      const failingRefresh: Promise<void> = coordinator.refreshHome();
      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(coordinator.homeState.isRefreshing).assertTrue();
      expect(coordinator.homeState.items[0].id).assertEqual(2725);
      await failingRefresh;

      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(coordinator.homeState.isRefreshing).assertFalse();
      expect(coordinator.homeState.items[0].id).assertEqual(2725);
      expect(coordinator.homeState.message).assertEqual('刷新失败');

      await coordinator.refreshHome();
      expect(coordinator.homeState.kind).assertEqual(BrowseStateKind.CONTENT);
      expect(coordinator.homeState.items[0].id).assertEqual(3000);
      expect(coordinator.homeState.message).assertEqual('');
      done();
    });
  });
}
