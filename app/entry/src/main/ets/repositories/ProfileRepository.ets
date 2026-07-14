import { RepositoryResult } from '../core/RepositoryResult';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary
} from '../models/ProfileModels';

export interface ProfileRepository {
  loadFullUserProfile(username: string): Promise<RepositoryResult<UserProfile>>;

  loadUserSummary(username: string): Promise<RepositoryResult<UserProfileSummary>>;

  loadUserEmails(username: string): Promise<RepositoryResult<UserEmailInfo>>;

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
