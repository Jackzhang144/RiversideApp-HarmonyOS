import { RepositoryResult } from '../core/RepositoryResult';
import { NotificationBucket, NotificationItem } from '../models/NotificationModels';
import { NotificationRepository } from '../repositories/NotificationRepository';

export enum NotificationCentreStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  EMPTY = 'empty',
  ERROR = 'error'
}

export interface NotificationAuthenticationLifecycle {
  handleUnauthorized(): Promise<void>;
}

export class NotificationCentreState {
  public readonly kind: NotificationCentreStateKind;
  public readonly bucket: NotificationBucket;
  public readonly items: Array<NotificationItem>;
  public readonly hasMore: boolean;
  public readonly refreshing: boolean;
  public readonly loadingMore: boolean;
  public readonly message: string;
  public readonly markingAllRead: boolean;

  public constructor(
    kind: NotificationCentreStateKind = NotificationCentreStateKind.INITIAL,
    bucket: NotificationBucket = NotificationBucket.REPLIES,
    items: Array<NotificationItem> = [],
    hasMore: boolean = false,
    refreshing: boolean = false,
    loadingMore: boolean = false,
    message: string = '',
    markingAllRead: boolean = false
  ) {
    this.kind = kind;
    this.bucket = bucket;
    this.items = items;
    this.hasMore = hasMore;
    this.refreshing = refreshing;
    this.loadingMore = loadingMore;
    this.message = message;
    this.markingAllRead = markingAllRead;
  }

  public static loading(bucket: NotificationBucket): NotificationCentreState {
    return new NotificationCentreState(NotificationCentreStateKind.LOADING, bucket);
  }

  public static fromItems(
    bucket: NotificationBucket,
    items: Array<NotificationItem>,
    hasMore: boolean
  ): NotificationCentreState {
    return new NotificationCentreState(
      items.length === 0 ? NotificationCentreStateKind.EMPTY : NotificationCentreStateKind.CONTENT,
      bucket,
      items,
      hasMore
    );
  }

  public static failure(
    bucket: NotificationBucket,
    items: Array<NotificationItem>,
    hasMore: boolean,
    message: string
  ): NotificationCentreState {
    return new NotificationCentreState(
      items.length === 0 ? NotificationCentreStateKind.ERROR : NotificationCentreStateKind.CONTENT,
      bucket,
      items,
      hasMore,
      false,
      false,
      message
    );
  }

  public refreshingState(): NotificationCentreState {
    if (this.items.length === 0) return NotificationCentreState.loading(this.bucket);
    return new NotificationCentreState(
      NotificationCentreStateKind.CONTENT,
      this.bucket,
      this.items,
      this.hasMore,
      true,
      false,
      '',
      this.markingAllRead
    );
  }

  public loadingMoreState(): NotificationCentreState {
    return new NotificationCentreState(
      this.kind,
      this.bucket,
      this.items,
      this.hasMore,
      false,
      true,
      '',
      this.markingAllRead
    );
  }

  public markingAllReadState(markingAllRead: boolean): NotificationCentreState {
    return new NotificationCentreState(
      this.kind,
      this.bucket,
      this.items,
      this.hasMore,
      this.refreshing,
      this.loadingMore,
      this.message,
      markingAllRead
    );
  }
}

function uniqueNotificationItems(items: Array<NotificationItem>): Array<NotificationItem> {
  const result: Array<NotificationItem> = [];
  const keys: Set<string> = new Set<string>();
  for (const item of items) {
    const key: string = `${item.kind}:${item.id}:${item.topicId}:${item.postNumber}`;
    if (!keys.has(key)) {
      keys.add(key);
      result.push(item);
    }
  }
  return result;
}

export class NotificationCentreModel {
  public state: NotificationCentreState = new NotificationCentreState();

  private readonly repository: NotificationRepository;
  private readonly authenticationLifecycle: NotificationAuthenticationLifecycle | null;
  private requestVersion: number = 0;
  private username: string = '';
  private page: number = 0;
  private offset: number = 0;

  public constructor(
    repository: NotificationRepository,
    authenticationLifecycle: NotificationAuthenticationLifecycle | null = null
  ) {
    this.repository = repository;
    this.authenticationLifecycle = authenticationLifecycle;
  }

  public async load(username: string, bucket: NotificationBucket = this.state.bucket): Promise<void> {
    const normalizedUsername: string = username.trim();
    this.requestVersion += 1;
    const requestVersion: number = this.requestVersion;
    this.username = normalizedUsername;
    this.page = 0;
    this.offset = 0;
    this.state = NotificationCentreState.loading(bucket);
    if (normalizedUsername.length === 0) {
      this.state = NotificationCentreState.failure(bucket, [], false, '当前账号不可用');
      return;
    }
    const result: RepositoryResult<Array<NotificationItem>> = await this.repository.loadNotificationItems(
      normalizedUsername,
      bucket,
      0,
      0
    );
    if (requestVersion !== this.requestVersion || bucket !== this.state.bucket) return;
    if (!result.isSuccess() || result.data === null) {
      this.state = NotificationCentreState.failure(bucket, [], false, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.page = 1;
    this.offset = result.data.length;
    this.state = NotificationCentreState.fromItems(bucket, result.data, result.data.length > 0);
  }

  public async selectBucket(bucket: NotificationBucket): Promise<void> {
    if (bucket === this.state.bucket && this.state.kind !== NotificationCentreStateKind.INITIAL) return;
    await this.load(this.username, bucket);
  }

  public async refresh(): Promise<void> {
    await this.refreshForForeground(this.username);
  }

  public async refreshForForeground(username: string): Promise<void> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || this.state.markingAllRead) return;
    const bucket: NotificationBucket = this.state.bucket;
    this.requestVersion += 1;
    const requestVersion: number = this.requestVersion;
    this.username = normalizedUsername;
    this.state = this.state.refreshingState();
    const result: RepositoryResult<Array<NotificationItem>> = await this.repository.loadNotificationItems(
      normalizedUsername,
      bucket,
      0,
      0
    );
    if (requestVersion !== this.requestVersion || bucket !== this.state.bucket) return;
    if (!result.isSuccess() || result.data === null) {
      this.state = NotificationCentreState.failure(
        bucket,
        this.state.items,
        this.state.items.length > 0 && this.state.hasMore,
        result.message
      );
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.page = 1;
    this.offset = result.data.length;
    this.state = NotificationCentreState.fromItems(bucket, result.data, result.data.length > 0);
  }

  public async loadMore(): Promise<void> {
    if (
      this.username.length === 0 ||
      this.state.kind !== NotificationCentreStateKind.CONTENT ||
      !this.state.hasMore ||
      this.state.loadingMore ||
      this.state.refreshing ||
      this.state.markingAllRead
    ) {
      return;
    }
    const bucket: NotificationBucket = this.state.bucket;
    const requestVersion: number = this.requestVersion;
    const requestedPage: number = this.page;
    const requestedOffset: number = this.offset;
    const existing: Array<NotificationItem> = this.state.items;
    this.state = this.state.loadingMoreState();
    const result: RepositoryResult<Array<NotificationItem>> = await this.repository.loadNotificationItems(
      this.username,
      bucket,
      requestedPage,
      requestedOffset
    );
    if (requestVersion !== this.requestVersion || bucket !== this.state.bucket) return;
    if (!result.isSuccess() || result.data === null) {
      this.state = NotificationCentreState.failure(bucket, existing, true, result.message);
      await this.notifyUnauthorized(result.isUnauthorized());
      return;
    }
    this.page += 1;
    this.offset += result.data.length;
    this.state = NotificationCentreState.fromItems(
      bucket,
      uniqueNotificationItems(existing.concat(result.data)),
      result.data.length > 0
    );
  }

  public async markAllRead(): Promise<RepositoryResult<boolean>> {
    if (this.username.length === 0) {
      return RepositoryResult.invalidInput<boolean>('当前账号不可用');
    }
    if (this.state.markingAllRead) {
      return RepositoryResult.unavailable<boolean>('正在将消息标为已读');
    }
    const requestVersion: number = this.requestVersion;
    const username: string = this.username;
    this.state = this.state.markingAllReadState(true);
    const result: RepositoryResult<boolean> = await this.repository.markAllRead();
    if (requestVersion !== this.requestVersion || username !== this.username) {
      return result;
    }
    this.state = this.state.markingAllReadState(false);
    if (!result.isSuccess()) {
      await this.notifyUnauthorized(result.isUnauthorized());
    }
    return result;
  }

  public reset(): void {
    this.requestVersion += 1;
    this.username = '';
    this.page = 0;
    this.offset = 0;
    this.state = new NotificationCentreState();
  }

  private async notifyUnauthorized(unauthorized: boolean): Promise<void> {
    if (unauthorized && this.authenticationLifecycle !== null) {
      await this.authenticationLifecycle.handleUnauthorized();
    }
  }
}
