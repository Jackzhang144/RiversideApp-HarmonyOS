import { RepositoryResult } from '../core/RepositoryResult';
import { ChatSearchResult } from '../models/ChatModels';
import { ChatRepository } from '../repositories/ChatRepository';
import { ChatSearchState, ChatStateKind } from './ChatStateModels';

export type ChatSearchUnauthorizedHandler = () => Promise<void>;

export class ChatSearchCoordinator {
  public state: ChatSearchState = new ChatSearchState();

  private readonly repository: ChatRepository;
  private readonly handleUnauthorized: ChatSearchUnauthorizedHandler;
  private requestVersion: number = 0;

  public constructor(
    repository: ChatRepository,
    handleUnauthorized: ChatSearchUnauthorizedHandler
  ) {
    this.repository = repository;
    this.handleUnauthorized = handleUnauthorized;
  }

  public reset(): void {
    this.requestVersion += 1;
    this.state = new ChatSearchState();
  }

  public async query(query: string): Promise<void> {
    const normalized: string = query.trim();
    this.requestVersion += 1;
    const requestVersion: number = this.requestVersion;
    if (normalized.length === 0) {
      this.state = new ChatSearchState();
      return;
    }
    this.state = new ChatSearchState(ChatStateKind.LOADING, normalized);
    const result: RepositoryResult<Array<ChatSearchResult>> = await this.repository.searchChat(normalized, 0, 20);
    if (requestVersion !== this.requestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.state = new ChatSearchState(ChatStateKind.ERROR, normalized, [], false, false, result.message);
      if (result.isUnauthorized()) {
        await this.handleUnauthorized();
      }
      return;
    }
    this.state = new ChatSearchState(
      result.data.length === 0 ? ChatStateKind.EMPTY : ChatStateKind.CONTENT,
      normalized,
      result.data,
      result.data.length === 20
    );
  }

  public async loadMore(): Promise<void> {
    if (!this.state.hasMore || this.state.loadingMore || this.state.query.length === 0) {
      return;
    }
    const requestVersion: number = this.requestVersion;
    const previous: ChatSearchState = this.state;
    this.state = new ChatSearchState(
      previous.kind,
      previous.query,
      previous.results,
      previous.hasMore,
      true
    );
    const result: RepositoryResult<Array<ChatSearchResult>> = await this.repository.searchChat(
      previous.query,
      previous.results.length,
      20
    );
    if (requestVersion !== this.requestVersion) {
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.state = new ChatSearchState(
        previous.kind,
        previous.query,
        previous.results,
        previous.hasMore,
        false,
        result.message
      );
      if (result.isUnauthorized()) {
        await this.handleUnauthorized();
      }
      return;
    }
    this.state = new ChatSearchState(
      ChatStateKind.CONTENT,
      previous.query,
      mergeChatSearchResults(previous.results, result.data),
      result.data.length === 20
    );
  }
}

function mergeChatSearchResults(
  existing: Array<ChatSearchResult>,
  incoming: Array<ChatSearchResult>
): Array<ChatSearchResult> {
  const merged: Array<ChatSearchResult> = existing.slice();
  for (const candidate of incoming) {
    if (!merged.some((result: ChatSearchResult): boolean => result.message.id === candidate.message.id)) {
      merged.push(candidate);
    }
  }
  return merged;
}
