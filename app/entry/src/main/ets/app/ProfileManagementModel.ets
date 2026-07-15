import { RepositoryResult, RepositoryResultKind } from '../core/RepositoryResult';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState
} from '../models/MediaModels';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary
} from '../models/ProfileModels';
import { ProfileRepository } from '../repositories/ProfileRepository';
import { MediaRepository, MediaUploadOperation } from '../repositories/MediaRepository';

export interface ProfileSessionLifecycle {
  handleUnauthorized(): Promise<void>;
}

export type ProfileMediaStateListener = (state: MediaUploadState | null) => void;

export enum ProfileViewStateKind {
  INITIAL = 'initial',
  LOADING = 'loading',
  CONTENT = 'content',
  ERROR = 'error'
}

export class ProfileViewState {
  public readonly kind: ProfileViewStateKind;
  public readonly profile: UserProfile | null;
  public readonly summary: UserProfileSummary;
  public readonly emails: UserEmailInfo | null;
  public readonly message: string;
  public readonly busy: boolean;

  private constructor(
    kind: ProfileViewStateKind,
    profile: UserProfile | null,
    summary: UserProfileSummary,
    emails: UserEmailInfo | null,
    message: string,
    busy: boolean
  ) {
    this.kind = kind;
    this.profile = profile;
    this.summary = summary;
    this.emails = emails;
    this.message = message;
    this.busy = busy;
  }

  public static initial(): ProfileViewState {
    return new ProfileViewState(
      ProfileViewStateKind.INITIAL,
      null,
      UserProfileSummary.unavailable(),
      null,
      '',
      false
    );
  }

  public static loading(): ProfileViewState {
    return new ProfileViewState(
      ProfileViewStateKind.LOADING,
      null,
      UserProfileSummary.unavailable(),
      null,
      '',
      true
    );
  }

  public static content(
    profile: UserProfile,
    summary: UserProfileSummary,
    emails: UserEmailInfo | null,
    message: string = '',
    busy: boolean = false
  ): ProfileViewState {
    return new ProfileViewState(
      ProfileViewStateKind.CONTENT,
      profile,
      summary,
      emails,
      message.trim(),
      busy
    );
  }

  public static error(message: string): ProfileViewState {
    const normalized: string = message.trim();
    return new ProfileViewState(
      ProfileViewStateKind.ERROR,
      null,
      UserProfileSummary.unavailable(),
      null,
      normalized.length > 0 ? normalized : '个人资料加载失败',
      false
    );
  }
}

export class ProfileManagementModel {
  public state: ProfileViewState = ProfileViewState.initial();
  public mediaState: MediaUploadState | null = null;
  private readonly repository: ProfileRepository;
  private readonly sessionLifecycle: ProfileSessionLifecycle;
  private readonly mediaRepository: MediaRepository | null;
  private readonly mediaStateListener: ProfileMediaStateListener;
  private activeUsername: string = '';
  private loadGeneration: number = 0;
  private mutationGeneration: number = 0;

  public constructor(
    repository: ProfileRepository,
    sessionLifecycle: ProfileSessionLifecycle,
    mediaRepository: MediaRepository | null = null,
    mediaStateListener: ProfileMediaStateListener = (_state: MediaUploadState | null): void => {}
  ) {
    this.repository = repository;
    this.sessionLifecycle = sessionLifecycle;
    this.mediaRepository = mediaRepository;
    this.mediaStateListener = mediaStateListener;
  }

  public reset(): void {
    this.loadGeneration += 1;
    this.mutationGeneration += 1;
    this.activeUsername = '';
    this.state = ProfileViewState.initial();
    this.setMediaState(null);
  }

  public async loadProfile(username: string, includeEmails: boolean = false): Promise<void> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      this.state = ProfileViewState.error('用户名无效');
      return;
    }
    const generation: number = this.loadGeneration + 1;
    this.loadGeneration = generation;
    this.mutationGeneration += 1;
    this.setMediaState(null);
    this.activeUsername = normalizedUsername;
    this.state = ProfileViewState.loading();
    const profileResult: RepositoryResult<UserProfile> =
      await this.repository.loadFullUserProfile(normalizedUsername);
    if (generation !== this.loadGeneration) {
      return;
    }
    if (!profileResult.isSuccess() || profileResult.data === null) {
      await this.failAuthoritativeLoad(profileResult);
      return;
    }

    const profile: UserProfile = profileResult.data;
    this.state = ProfileViewState.content(profile, UserProfileSummary.unavailable(), null);
    const summaryResult: RepositoryResult<UserProfileSummary> =
      await this.repository.loadUserSummary(normalizedUsername);
    if (generation !== this.loadGeneration) {
      return;
    }
    if (summaryResult.kind === RepositoryResultKind.UNAUTHORIZED) {
      await this.invalidateSession(summaryResult.message);
      return;
    }
    const summary: UserProfileSummary = summaryResult.data ?? UserProfileSummary.unavailable();
    const summaryMessage: string = summaryResult.kind === RepositoryResultKind.FAILURE ? summaryResult.message : '';
    this.state = ProfileViewState.content(profile, summary, null, summaryMessage);

    if (!includeEmails) {
      return;
    }
    const emailResult: RepositoryResult<UserEmailInfo> = await this.repository.loadUserEmails(normalizedUsername);
    if (generation !== this.loadGeneration) {
      return;
    }
    if (emailResult.kind === RepositoryResultKind.UNAUTHORIZED) {
      await this.invalidateSession(emailResult.message);
      return;
    }
    const emailMessage: string = emailResult.kind === RepositoryResultKind.FAILURE
      ? emailResult.message
      : summaryMessage;
    this.state = ProfileViewState.content(profile, summary, emailResult.data, emailMessage);
  }

  public async saveProfile(request: ProfileUpdateRequest): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || request.username !== profile.username) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    const result: RepositoryResult<boolean> = await this.repository.updateUserProfile(request);
    return this.finishWrite(result, profile, generation);
  }

  public async setFollowing(following: boolean): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || !profile.canFollow) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    const result: RepositoryResult<boolean> = await this.repository.setUserFollowing(profile.username, following);
    return this.finishWrite(result, profile, generation);
  }

  public async setHidePresence(hidden: boolean): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || profile.hidePresence === hidden || this.state.busy) {
      return false;
    }
    const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
      profile.username,
      null,
      null,
      null,
      null,
      null,
      hidden
    );
    if (request === null) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    return this.finishWrite(
      await this.repository.updateUserProfile(request),
      profile,
      generation
    );
  }

  public async setNotificationLevel(
    level: ProfileNotificationLevel,
    actingUserId: number,
    expiringAt?: string
  ): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || (level === ProfileNotificationLevel.MUTED && !profile.canMute) ||
      (level === ProfileNotificationLevel.IGNORED && !profile.canIgnore)) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    const result: RepositoryResult<boolean> = await this.repository.setUserNotificationLevel(
      profile.username,
      level,
      actingUserId,
      expiringAt
    );
    return this.finishWrite(result, profile, generation);
  }

  public async uploadAvatar(media: CachedMedia): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || this.mediaRepository === null) {
      return false;
    }
    const request: MediaUploadRequest | null = MediaUploadRequest.avatar(media, profile.id);
    if (request === null) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    const upload: RepositoryResult<MediaUploadResult> = await this.uploadMedia(request, generation, profile.username);
    if (!this.isMutationActive(generation, profile.username)) {
      return false;
    }
    if (!upload.isSuccess() || upload.data === null) {
      await this.finishFailedUpload(upload, profile, generation);
      return false;
    }
    const selected: RepositoryResult<boolean> = await this.repository.pickUploadedAvatar(
      profile.username,
      upload.data.id
    );
    const saved: boolean = await this.finishWrite(selected, profile, generation);
    if (!saved) {
      this.setMediaState(this.mediaState?.failed(this.state.message) ?? null);
      return false;
    }
    this.setMediaState(this.mediaState?.succeeded(upload.data) ?? null);
    return true;
  }

  public async uploadProfileBackground(media: CachedMedia): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || this.mediaRepository === null || !profile.canUploadProfileBackground) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    const upload: RepositoryResult<MediaUploadResult> = await this.uploadMedia(
      MediaUploadRequest.profileBackground(media),
      generation,
      profile.username
    );
    if (!this.isMutationActive(generation, profile.username)) {
      return false;
    }
    if (!upload.isSuccess() || upload.data === null) {
      await this.finishFailedUpload(upload, profile, generation);
      return false;
    }
    const uploadUrl: string = upload.data.url.length > 0 ? upload.data.url : upload.data.shortUrl;
    if (uploadUrl.trim().length === 0) {
      this.state = ProfileViewState.content(
        profile,
        this.state.summary,
        this.state.emails,
        '背景图上传响应缺少地址'
      );
      this.setMediaState(this.mediaState?.failed('背景图上传响应缺少地址') ?? null);
      return false;
    }
    const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
      profile.username,
      null,
      null,
      null,
      null,
      uploadUrl
    );
    if (request === null) {
      this.setMediaState(this.mediaState?.failed('背景图上传响应缺少地址') ?? null);
      return false;
    }
    const saved: boolean = await this.finishWrite(
      await this.repository.updateUserProfile(request),
      profile,
      generation
    );
    if (!saved) {
      this.setMediaState(this.mediaState?.failed(this.state.message) ?? null);
      return false;
    }
    this.setMediaState(this.mediaState?.succeeded(upload.data) ?? null);
    return true;
  }

  public async clearProfileBackground(): Promise<boolean> {
    const profile: UserProfile | null = this.state.profile;
    if (profile === null || !profile.canUploadProfileBackground ||
      profile.profileBackgroundUrl.length === 0 || this.state.busy) {
      return false;
    }
    const request: ProfileUpdateRequest | null = ProfileUpdateRequest.create(
      profile.username,
      null,
      null,
      null,
      null,
      ''
    );
    if (request === null) {
      return false;
    }
    const generation: number = this.beginMutation(profile);
    return this.finishWrite(
      await this.repository.updateUserProfile(request),
      profile,
      generation
    );
  }

  private async uploadMedia(
    request: MediaUploadRequest,
    generation: number,
    username: string
  ): Promise<RepositoryResult<MediaUploadResult>> {
    const mediaRepository: MediaRepository | null = this.mediaRepository;
    if (mediaRepository === null) {
      return RepositoryResult.unavailable<MediaUploadResult>('媒体上传不可用');
    }
    this.setMediaState(MediaUploadState.selected(request.media));
    const operation: MediaUploadOperation = mediaRepository.upload(
      request,
      (uploadedBytes: number, totalBytes: number): void => {
        if (this.isMutationActive(generation, username)) {
          this.setMediaState(this.mediaState?.uploading(uploadedBytes, totalBytes) ?? null);
        }
      }
    );
    return operation.completion;
  }

  private async finishFailedUpload(
    result: RepositoryResult<MediaUploadResult>,
    profile: UserProfile,
    generation: number
  ): Promise<void> {
    if (!this.isMutationActive(generation, profile.username)) {
      return;
    }
    if (result.kind === RepositoryResultKind.UNAUTHORIZED) {
      await this.invalidateSession(result.message);
      return;
    }
    this.state = ProfileViewState.content(profile, this.state.summary, this.state.emails, result.message);
    this.setMediaState(this.mediaState?.failed(result.message) ?? null);
  }

  private async finishWrite(
    result: RepositoryResult<boolean>,
    target: UserProfile,
    generation: number
  ): Promise<boolean> {
    if (!this.isMutationActive(generation, target.username)) {
      return false;
    }
    if (!result.isSuccess() || result.data !== true) {
      if (result.kind === RepositoryResultKind.UNAUTHORIZED) {
        await this.invalidateSession(result.message);
        return false;
      }
      this.state = ProfileViewState.content(
        target,
        this.state.summary,
        this.state.emails,
        result.message
      );
      return false;
    }
    const refreshed: RepositoryResult<UserProfile> =
      await this.repository.loadFullUserProfile(target.username);
    if (!this.isMutationActive(generation, target.username)) {
      return false;
    }
    if (!refreshed.isSuccess() || refreshed.data === null) {
      if (refreshed.kind === RepositoryResultKind.UNAUTHORIZED) {
        await this.invalidateSession(refreshed.message);
        return false;
      }
      this.state = ProfileViewState.content(
        target,
        this.state.summary,
        this.state.emails,
        refreshed.message.length > 0 ? refreshed.message : '资料已提交，但刷新失败'
      );
      return false;
    }
    this.state = ProfileViewState.content(refreshed.data, this.state.summary, this.state.emails);
    return true;
  }

  private async failAuthoritativeLoad(result: RepositoryResult<UserProfile>): Promise<void> {
    if (result.kind === RepositoryResultKind.UNAUTHORIZED) {
      await this.invalidateSession(result.message);
      return;
    }
    this.state = ProfileViewState.error(result.message);
  }

  private beginMutation(profile: UserProfile): number {
    this.mutationGeneration += 1;
    this.state = ProfileViewState.content(profile, this.state.summary, this.state.emails, '', true);
    return this.mutationGeneration;
  }

  private isMutationActive(generation: number, username: string): boolean {
    return generation === this.mutationGeneration &&
      username === this.activeUsername &&
      this.state.profile?.username === username;
  }

  private async invalidateSession(message: string): Promise<void> {
    this.loadGeneration += 1;
    this.mutationGeneration += 1;
    this.activeUsername = '';
    this.setMediaState(null);
    await this.sessionLifecycle.handleUnauthorized();
    this.state = ProfileViewState.error(message.length > 0 ? message : '登录已失效');
  }

  private setMediaState(state: MediaUploadState | null): void {
    this.mediaState = state;
    this.mediaStateListener(state);
  }
}
