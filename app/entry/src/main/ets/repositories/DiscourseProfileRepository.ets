import { RepositoryResult } from '../core/RepositoryResult';
import { ServerDraft } from '../models/AuthoringModels';
import { Topic } from '../models/ForumModels';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserBookmarkItem,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary,
  UserReplyItem
} from '../models/ProfileModels';
import { ForumHttpClient, HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import { ProfileRepository } from './ProfileRepository';
import { ForumResponseParser } from './ForumResponseParser';
import { ProfileResponseParser } from './ProfileResponseParser';

export class DiscourseProfileRepository implements ProfileRepository {
  private readonly client: ForumHttpClient;
  private readonly parser: ProfileResponseParser;
  private readonly forumParser: ForumResponseParser;

  public constructor(
    client: ForumHttpClient,
    parser: ProfileResponseParser = new ProfileResponseParser(),
    forumParser: ForumResponseParser = new ForumResponseParser()
  ) {
    this.client = client;
    this.parser = parser;
    this.forumParser = forumParser;
  }

  public async loadFullUserProfile(username: string): Promise<RepositoryResult<UserProfile>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserProfile>('用户名无效');
    }
    const response: HttpTextResult = await this.client.get(`/u/${encodeURIComponent(normalizedUsername)}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserProfile>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserProfile>(response.message);
    }
    return this.parser.parseFullUserProfile(response.body);
  }

  public async loadUserSummary(username: string): Promise<RepositoryResult<UserProfileSummary>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserProfileSummary>('用户名无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/u/${encodeURIComponent(normalizedUsername)}/summary.json`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserProfileSummary>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserProfileSummary>(response.message);
    }
    return this.parser.parseUserProfileSummary(response.body);
  }

  public async loadUserEmails(username: string): Promise<RepositoryResult<UserEmailInfo>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserEmailInfo>('用户名无效');
    }
    const encodedUsername: string = encodeURIComponent(normalizedUsername);
    const context: string = encodeURIComponent(`/u/${normalizedUsername}/preferences/account`);
    const response: HttpTextResult = await this.client.get(
      `/u/${encodedUsername}/emails.json?context=${context}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserEmailInfo>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserEmailInfo>(response.message);
    }
    return this.parser.parseUserEmails(response.body);
  }

  public async loadUserTopics(username: string, page: number): Promise<RepositoryResult<Array<Topic>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<Topic>>('用户主题查询参数无效');
    }
    const pageSuffix: string = page > 0 ? `?page=${page}` : '';
    const response: HttpTextResult = await this.client.get(
      `/topics/created-by/${encodeURIComponent(normalizedUsername)}.json${pageSuffix}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.forumParser.parseLatestTopics(response.body);
  }

  public async loadUserReplies(username: string, offset: number): Promise<RepositoryResult<Array<UserReplyItem>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(offset) || offset < 0) {
      return RepositoryResult.failure<Array<UserReplyItem>>('用户回复查询参数无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/user_actions.json?offset=${offset}&username=${encodeURIComponent(normalizedUsername)}&filter=5`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<UserReplyItem>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<UserReplyItem>>(response.message);
    }
    return this.parser.parseUserReplies(response.body);
  }

  public async loadUserBookmarks(
    username: string,
    page: number
  ): Promise<RepositoryResult<Array<UserBookmarkItem>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<UserBookmarkItem>>('用户收藏查询参数无效');
    }
    const pageSuffix: string = page > 0 ? `?page=${page}` : '';
    const response: HttpTextResult = await this.client.get(
      `/u/${encodeURIComponent(normalizedUsername)}/bookmarks.json${pageSuffix}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<UserBookmarkItem>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<UserBookmarkItem>>(response.message);
    }
    return this.parser.parseUserBookmarks(response.body);
  }

  public async loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>> {
    const response: HttpTextResult = await this.client.get('/drafts.json');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ServerDraft>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ServerDraft>>(response.message);
    }
    return this.forumParser.parseServerDrafts(response.body);
  }

  public async updateUserProfile(request: ProfileUpdateRequest): Promise<RepositoryResult<boolean>> {
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(request.username)}.json`,
      request.formBody()
    ));
  }

  public async pickUploadedAvatar(username: string, uploadId: number): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isSafeInteger(uploadId) || uploadId <= 0) {
      return RepositoryResult.failure<boolean>('头像请求无效');
    }
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(normalizedUsername)}/preferences/avatar/pick.json`,
      `upload_id=${uploadId}&type=uploaded`
    ));
  }

  public async setUserFollowing(username: string, following: boolean): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<boolean>('用户名无效');
    }
    const path: string = `/follow/${encodeURIComponent(normalizedUsername)}.json`;
    const response: HttpTextResult = following ? await this.client.put(path) : await this.client.delete(path);
    return this.booleanWriteResult(response);
  }

  public async setUserNotificationLevel(
    username: string,
    level: ProfileNotificationLevel,
    actingUserId: number,
    expiringAt: string = ''
  ): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isSafeInteger(actingUserId) || actingUserId <= 0) {
      return RepositoryResult.failure<boolean>('用户通知请求无效');
    }
    const body: string = `notification_level=${encodeURIComponent(level)}` +
      `&expiring_at=${encodeURIComponent(expiringAt.trim())}&acting_user_id=${actingUserId}`;
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(normalizedUsername)}/notification_level.json`,
      body
    ));
  }

  private booleanWriteResult(response: HttpTextResult): RepositoryResult<boolean> {
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<boolean>();
    }
    return response.isSuccess()
      ? RepositoryResult.success<boolean>(true)
      : RepositoryResult.failure<boolean>(response.message);
  }
}
