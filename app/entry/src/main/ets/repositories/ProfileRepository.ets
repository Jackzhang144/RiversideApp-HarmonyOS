import { RepositoryResult } from '../core/RepositoryResult';
import { ServerDraft } from '../models/AuthoringModels';
import { Topic } from '../models/ForumModels';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserEmailInfo,
  UserBookmarkItem,
  UserProfile,
  UserProfileSummary,
  UserReplyItem
} from '../models/ProfileModels';

export interface ProfileRepository {
  loadFullUserProfile(username: string): Promise<RepositoryResult<UserProfile>>;

  loadUserSummary(username: string): Promise<RepositoryResult<UserProfileSummary>>;

  loadUserEmails(username: string): Promise<RepositoryResult<UserEmailInfo>>;

  loadUserTopics(username: string, page: number): Promise<RepositoryResult<Array<Topic>>>;

  loadUserReplies(username: string, offset: number): Promise<RepositoryResult<Array<UserReplyItem>>>;

  loadUserBookmarks(username: string, page: number): Promise<RepositoryResult<Array<UserBookmarkItem>>>;

  loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>>;

  updateUserProfile(request: ProfileUpdateRequest): Promise<RepositoryResult<boolean>>;

  pickUploadedAvatar(username: string, uploadId: number): Promise<RepositoryResult<boolean>>;

  setUserFollowing(username: string, following: boolean): Promise<RepositoryResult<boolean>>;

  setUserNotificationLevel(
    username: string,
    level: ProfileNotificationLevel,
    actingUserId: number,
    expiringAt?: string
  ): Promise<RepositoryResult<boolean>>;
}
