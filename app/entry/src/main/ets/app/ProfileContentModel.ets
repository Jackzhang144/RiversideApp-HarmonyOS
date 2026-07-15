import { RepositoryResult } from '../core/RepositoryResult';
import { ServerDraft } from '../models/AuthoringModels';
import { Topic } from '../models/ForumModels';
import { UserBookmarkItem, UserReplyItem } from '../models/ProfileModels';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { ProfileSessionLifecycle } from './ProfileManagementModel';

export enum ProfileContentKind {
  TOPICS = 'topics',
  REPLIES = 'replies',
  DRAFTS = 'drafts',
  BOOKMARKS = 'bookmarks'
}

export function profileContentKindsForProfile(ownProfile: boolean): Array<ProfileContentKind> {
  if (ownProfile) {
    return [
      ProfileContentKind.TOPICS,
      ProfileContentKind.REPLIES,
      ProfileContentKind.DRAFTS,
      ProfileContentKind.BOOKMARKS
    ];
  }
  return [ProfileContentKind.TOPICS, ProfileContentKind.REPLIES];
}

export function profileContentDestinationTitle(
  kind: ProfileContentKind,
  ownProfile: boolean,
  username: string
): string {
  const owner: string = ownProfile ? '我的' : `${username} 的`;
  if (kind === ProfileContentKind.TOPICS) {
    return `${owner} Topic`;
  }
  if (kind === ProfileContentKind.REPLIES) {
    return `${owner} Reply`;
  }
  if (kind === ProfileContentKind.DRAFTS) {
    return '我的草稿';
  }
  return '我的书签';
}

export class ProfileContentState {
  public readonly kind: ProfileContentKind;
  public readonly loading: boolean;
  public readonly loadingMore: boolean;
  public readonly message: string;
  public readonly topics: Array<Topic>;
  public readonly replies: Array<UserReplyItem>;
  public readonly drafts: Array<ServerDraft>;
  public readonly bookmarks: Array<UserBookmarkItem>;
  public readonly hasMore: boolean;

  public constructor(
    kind: ProfileContentKind = ProfileContentKind.TOPICS,
    loading: boolean = false,
    loadingMore: boolean = false,
    message: string = '',
    topics: Array<Topic> = [],
    replies: Array<UserReplyItem> = [],
    drafts: Array<ServerDraft> = [],
    bookmarks: Array<UserBookmarkItem> = [],
    hasMore: boolean = false
  ) {
    this.kind = kind;
    this.loading = loading;
    this.loadingMore = loadingMore;
    this.message = message;
    this.topics = topics.slice();
    this.replies = replies.slice();
    this.drafts = drafts.slice();
    this.bookmarks = bookmarks.slice();
    this.hasMore = hasMore;
  }
}

export class ProfileContentModel {
  public state: ProfileContentState = new ProfileContentState();
  private readonly repository: ProfileRepository;
  private readonly sessionLifecycle: ProfileSessionLifecycle;
  private username: string = '';
  private page: number = 0;
  private replyOffset: number = 0;
  private generation: number = 0;

  public constructor(repository: ProfileRepository, sessionLifecycle: ProfileSessionLifecycle) {
    this.repository = repository;
    this.sessionLifecycle = sessionLifecycle;
  }

  public reset(): void {
    this.generation += 1;
    this.username = '';
    this.page = 0;
    this.replyOffset = 0;
    this.state = new ProfileContentState();
  }

  public async load(username: string, kind: ProfileContentKind): Promise<void> {
    const normalized: string = username.trim();
    this.generation += 1;
    const generation: number = this.generation;
    this.username = normalized;
    this.page = 0;
    this.replyOffset = 0;
    this.state = new ProfileContentState(kind, true);
    if (normalized.length === 0) {
      this.state = new ProfileContentState(kind, false, false, '用户名无效');
      return;
    }
    await this.loadPage(generation, false);
  }

  public async loadMore(): Promise<void> {
    if (this.state.loading || this.state.loadingMore || !this.state.hasMore ||
      this.state.kind === ProfileContentKind.DRAFTS) {
      return;
    }
    const generation: number = this.generation;
    this.state = new ProfileContentState(
      this.state.kind,
      false,
      true,
      '',
      this.state.topics,
      this.state.replies,
      this.state.drafts,
      this.state.bookmarks,
      true
    );
    await this.loadPage(generation, true);
  }

  private async loadPage(generation: number, append: boolean): Promise<void> {
    const kind: ProfileContentKind = this.state.kind;
    if (kind === ProfileContentKind.TOPICS) {
      await this.finishTopics(await this.repository.loadUserTopics(this.username, this.page), generation, append);
    } else if (kind === ProfileContentKind.REPLIES) {
      await this.finishReplies(
        await this.repository.loadUserReplies(this.username, this.replyOffset),
        generation,
        append
      );
    } else if (kind === ProfileContentKind.DRAFTS) {
      await this.finishDrafts(await this.repository.loadDrafts(), generation);
    } else {
      await this.finishBookmarks(
        await this.repository.loadUserBookmarks(this.username, this.page),
        generation,
        append
      );
    }
  }

  private async rejected<T>(result: RepositoryResult<T>, generation: number): Promise<boolean> {
    if (generation !== this.generation) {
      return true;
    }
    if (result.isUnauthorized()) {
      this.generation += 1;
      await this.sessionLifecycle.handleUnauthorized();
      this.state = new ProfileContentState(this.state.kind, false, false, result.message);
      return true;
    }
    if (!result.isSuccess() || result.data === null) {
      this.state = new ProfileContentState(
        this.state.kind, false, false, result.message,
        this.state.topics, this.state.replies, this.state.drafts, this.state.bookmarks, this.state.hasMore
      );
      return true;
    }
    return false;
  }

  private async finishTopics(
    result: RepositoryResult<Array<Topic>>,
    generation: number,
    append: boolean
  ): Promise<void> {
    if (await this.rejected(result, generation) || result.data === null) {
      return;
    }
    const incoming: Array<Topic> = result.data;
    const items: Array<Topic> = append ? this.state.topics.slice() : [];
    for (const item of incoming) {
      if (!items.some((candidate: Topic): boolean => candidate.id === item.id)) {
        items.push(item);
      }
    }
    if (incoming.length > 0) {
      this.page += 1;
    }
    this.state = new ProfileContentState(this.state.kind, false, false, '', items, [], [], [], incoming.length > 0);
  }

  private async finishReplies(
    result: RepositoryResult<Array<UserReplyItem>>,
    generation: number,
    append: boolean
  ): Promise<void> {
    if (await this.rejected(result, generation) || result.data === null) {
      return;
    }
    const incoming: Array<UserReplyItem> = result.data;
    const items: Array<UserReplyItem> = append ? this.state.replies.slice() : [];
    for (const item of incoming) {
      if (!items.some((candidate: UserReplyItem): boolean => candidate.actionId === item.actionId)) {
        items.push(item);
      }
    }
    if (incoming.length > 0) {
      this.replyOffset += incoming.length;
    }
    this.state = new ProfileContentState(this.state.kind, false, false, '', [], items, [], [], incoming.length > 0);
  }

  private async finishDrafts(result: RepositoryResult<Array<ServerDraft>>, generation: number): Promise<void> {
    if (await this.rejected(result, generation) || result.data === null) {
      return;
    }
    this.state = new ProfileContentState(this.state.kind, false, false, '', [], [], result.data, [], false);
  }

  private async finishBookmarks(
    result: RepositoryResult<Array<UserBookmarkItem>>,
    generation: number,
    append: boolean
  ): Promise<void> {
    if (await this.rejected(result, generation) || result.data === null) {
      return;
    }
    const incoming: Array<UserBookmarkItem> = result.data;
    const items: Array<UserBookmarkItem> = append ? this.state.bookmarks.slice() : [];
    for (const item of incoming) {
      if (!items.some((candidate: UserBookmarkItem): boolean => candidate.bookmarkId === item.bookmarkId)) {
        items.push(item);
      }
    }
    if (incoming.length > 0) {
      this.page += 1;
    }
    this.state = new ProfileContentState(this.state.kind, false, false, '', [], [], [], items, incoming.length > 0);
  }
}
