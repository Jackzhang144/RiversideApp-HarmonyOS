import { RepositoryResult } from '../core/RepositoryResult';
import { ForumSearchResult, HomeChannel, homeChannelFromIndex } from '../models/DiscoveryModels';
import { Topic } from '../models/ForumModels';
import { ForumRepository } from '../repositories/ForumRepository';
import { DiscoverySettings, DiscoverySettingsStore } from '../settings/DiscoverySettingsStore';
import {
  BrowseState,
  BrowseStateKind,
  mergeSearchResults,
  SearchState,
  SearchStateKind,
  SearchSuggestionState,
  uniqueTopics
} from './BrowseModels';
import { isHomeSortTabAvailable } from './ShellNavigationModels';

export type DiscoveryAuthenticationStateHandler = (isUnauthorized: boolean) => void;
export type DiscoveryUnauthorizedHandler = () => Promise<void>;

export class DiscoveryCoordinator {
  public homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  public selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  public worldCupEntryEnabled: boolean = true;
  public searchState: SearchState = SearchState.initial();
  public searchSuggestionState: SearchSuggestionState = SearchSuggestionState.initial();

  private readonly repository: ForumRepository;
  private readonly settingsStore: DiscoverySettingsStore | null;
  private readonly updateAuthenticationState: DiscoveryAuthenticationStateHandler;
  private readonly handleUnauthorized: DiscoveryUnauthorizedHandler;
  private homeRequestVersion: number = 0;
  private searchRequestVersion: number = 0;
  private searchSuggestionRequestVersion: number = 0;
  private homePage: number = 0;
  private searchNextPage: number = 1;

  public constructor(
    repository: ForumRepository,
    settingsStore: DiscoverySettingsStore | null,
    updateAuthenticationState: DiscoveryAuthenticationStateHandler,
    handleUnauthorized: DiscoveryUnauthorizedHandler
  ) {
    this.repository = repository;
    this.settingsStore = settingsStore;
    this.updateAuthenticationState = updateAuthenticationState;
    this.handleUnauthorized = handleUnauthorized;
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

  public async restoreSettings(): Promise<void> {
    if (this.settingsStore === null) {
      return;
    }
    try {
      const settings: DiscoverySettings | null = await this.settingsStore.read();
      if (settings !== null) {
        this.selectedHomeChannel = settings.homeChannel;
        this.worldCupEntryEnabled = settings.worldCupEntryEnabled;
      }
    } catch (_) {
      // Discovery settings are best effort and fall back to product defaults.
    }
  }

  public async selectHomeChannel(index: number): Promise<boolean> {
    const channel: HomeChannel | null = homeChannelFromIndex(index);
    return channel === null ? false : this.applyHomeChannelPreference(channel);
  }

  public async applyHomeChannelPreference(channel: HomeChannel): Promise<boolean> {
    if (!this.selectHomeSortTab(channel)) {
      return false;
    }
    await this.persistSettings();
    return true;
  }

  public async setWorldCupEntryEnabled(enabled: boolean): Promise<void> {
    if (this.worldCupEntryEnabled === enabled) {
      return;
    }
    this.worldCupEntryEnabled = enabled;
    await this.persistSettings();
  }

  public async loadHome(): Promise<void> {
    this.homeRequestVersion += 1;
    const requestVersion: number = this.homeRequestVersion;
    const channel: HomeChannel = this.selectedHomeChannel;
    this.updateAuthenticationState(false);
    this.homeState = BrowseState.loading<Topic>();
    this.homePage = 0;
    const result: RepositoryResult<Array<Topic>> = await this.repository.loadHomeTopics(channel, 0);
    if (requestVersion !== this.homeRequestVersion || channel !== this.selectedHomeChannel) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.homeState = BrowseState.error<Topic>(result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.homeState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
  }

  public async refreshHome(): Promise<void> {
    this.updateAuthenticationState(false);
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
      this.homeState = previousState.kind === BrowseStateKind.CONTENT
        ? BrowseState.content<Topic>(previousState.items, false, result.message, previousState.hasMore)
        : BrowseState.empty<Topic>(false, result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.homeState = result.data.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(result.data, false, '', true);
    this.homePage = 0;
  }

  public async mergeLiveHomeTopics(topicIds: Array<number>): Promise<boolean> {
    const state: BrowseState<Topic> = this.homeState;
    if (state.kind !== BrowseStateKind.CONTENT && state.kind !== BrowseStateKind.EMPTY) {
      return false;
    }
    const requestVersion: number = this.homeRequestVersion;
    const channel: HomeChannel = this.selectedHomeChannel;
    const result: RepositoryResult<Array<Topic>> =
      await this.repository.loadHomeTopicsByIds(channel, topicIds);
    if (requestVersion !== this.homeRequestVersion || channel !== this.selectedHomeChannel) {
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return false;
    }
    const updatedIds: Set<number> = new Set<number>();
    for (const topic of result.data) {
      updatedIds.add(topic.id);
    }
    const remaining: Array<Topic> = state.items.filter((topic: Topic): boolean => {
      return !updatedIds.has(topic.id);
    });
    const merged: Array<Topic> = result.data.concat(remaining);
    this.homeState = merged.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(merged, false, '', state.hasMore);
    return true;
  }

  public removeLiveHomeTopic(topicId: number): void {
    const state: BrowseState<Topic> = this.homeState;
    if (state.kind !== BrowseStateKind.CONTENT) {
      return;
    }
    const remaining: Array<Topic> = state.items.filter((topic: Topic): boolean => {
      return topic.id !== topicId;
    });
    this.homeState = remaining.length === 0
      ? BrowseState.empty<Topic>()
      : BrowseState.content<Topic>(remaining, false, '', state.hasMore);
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
      this.homeState = BrowseState.content<Topic>(state.items, false, '', true, false, result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
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
      this.resetSearch();
      return;
    }
    this.updateAuthenticationState(false);
    this.searchState = SearchState.loading(normalizedQuery);
    this.searchNextPage = 1;
    const result: RepositoryResult<ForumSearchResult> = await this.repository.searchForum(normalizedQuery, 1);
    if (requestVersion !== this.searchRequestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.searchState = SearchState.error(normalizedQuery, result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.searchNextPage = 2;
    this.searchState = result.data.isEmpty()
      ? SearchState.empty(normalizedQuery)
      : SearchState.content(normalizedQuery, result.data);
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
      this.searchState = SearchState.content(state.query, state.result, false, result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.searchNextPage = page + 1;
    this.searchState = SearchState.content(state.query, mergeSearchResults(state.result, result.data));
  }

  public async retrySearch(): Promise<void> {
    await this.searchForum(this.searchState.query);
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
    if (!result.isSuccess() || result.data === null) {
      this.searchSuggestionState = SearchSuggestionState.error(normalizedTerm, result.message);
      await this.applyAuthenticationFailure(result.isUnauthorized());
      return;
    }
    this.searchSuggestionState = result.data.length === 0
      ? SearchSuggestionState.empty(normalizedTerm)
      : SearchSuggestionState.content(normalizedTerm, result.data);
  }

  public resetSearch(): void {
    this.searchRequestVersion += 1;
    this.searchSuggestionRequestVersion += 1;
    this.searchState = SearchState.initial();
    this.searchSuggestionState = SearchSuggestionState.initial();
    this.searchNextPage = 1;
  }

  private async persistSettings(): Promise<void> {
    if (this.settingsStore === null) {
      return;
    }
    try {
      await this.settingsStore.write(new DiscoverySettings(
        this.selectedHomeChannel,
        this.worldCupEntryEnabled
      ));
    } catch (_) {
      // A failed preference write does not invalidate current browse content.
    }
  }

  private async applyAuthenticationFailure(isUnauthorized: boolean): Promise<void> {
    this.updateAuthenticationState(isUnauthorized);
    if (isUnauthorized) {
      await this.handleUnauthorized();
    }
  }
}
