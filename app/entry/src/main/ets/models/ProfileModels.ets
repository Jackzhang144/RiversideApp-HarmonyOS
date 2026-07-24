import { forumPlainText, ForumPlainTextContext } from '../core/ForumPlainText';
import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';
const VERIFIED_GROUP_NAMES: Array<string> = [
  'verified_uestcer',
  'scuer',
  'swufer',
  'swjtuer',
  'sicnuer'
];
const VERIFIED_GROUP_IDS: Array<number> = [41, 45, 46, 48, 49];

export function absoluteProfileUrl(value: string): string {
  return RIVERSIDE_URL_RESOLVER.absolute(value);
}

export class ProfileGroup {
  public readonly id: number;
  public readonly name: string;
  public readonly displayName: string;
  public readonly flairUrl: string;

  public constructor(id: number, name: string, displayName: string = '', flairUrl: string = '') {
    this.id = Number.isSafeInteger(id) && id > 0 ? id : 0;
    this.name = name.trim();
    this.displayName = displayName.trim();
    this.flairUrl = absoluteProfileUrl(flairUrl);
  }
}

export enum ProfileNotificationLevel {
  NORMAL = 'normal',
  MUTED = 'mute',
  IGNORED = 'ignore'
}

function twoDigits(value: number): string {
  return value.toString().padStart(2, '0');
}

export function profileIgnoreExpiry(days: number | null, now: Date = new Date()): string {
  if (days === null) {
    return `${now.getFullYear() + 1000}-05-01 08:00-05:00`;
  }
  const expires: Date = new Date(now.getTime() + days * 24 * 60 * 60 * 1000);
  const offsetMinutes: number = -expires.getTimezoneOffset();
  const offsetSign: string = offsetMinutes >= 0 ? '+' : '-';
  const absoluteOffset: number = Math.abs(offsetMinutes);
  return `${expires.getFullYear()}-${twoDigits(expires.getMonth() + 1)}-${twoDigits(expires.getDate())} ` +
    `${twoDigits(expires.getHours())}:${twoDigits(expires.getMinutes())}` +
    `${offsetSign}${twoDigits(Math.floor(absoluteOffset / 60))}:${twoDigits(absoluteOffset % 60)}`;
}

export interface UserProfileAttributes {
  name?: string;
  title?: string;
  avatarUrl?: string;
  primaryGroupId?: number | null;
  flairGroupId?: number | null;
  primaryGroupName?: string;
  flairGroupName?: string;
  trustLevel?: number;
  admin?: boolean;
  moderator?: boolean;
  groups?: Array<ProfileGroup>;
  canFollow?: boolean;
  following?: boolean;
  canMute?: boolean;
  canIgnore?: boolean;
  muted?: boolean;
  ignored?: boolean;
  canUploadProfileBackground?: boolean;
  canUploadCardBackground?: boolean;
  profileBackgroundUrl?: string;
  cardBackgroundUrl?: string;
  bioRaw?: string;
  bioExcerpt?: string;
  location?: string;
  website?: string;
  timezone?: string;
  hideProfile?: boolean;
  hidePresence?: boolean;
  canCreatePost?: boolean;
  canChat?: boolean;
  canDirectMessage?: boolean;
  canChatWithUser?: boolean;
}

export class UserProfile {
  public readonly id: number;
  public readonly username: string;
  public readonly name: string;
  public readonly displayName: string;
  public readonly title: string;
  public readonly avatarUrl: string;
  public readonly primaryGroupId: number | null;
  public readonly flairGroupId: number | null;
  public readonly primaryGroupName: string;
  public readonly flairGroupName: string;
  public readonly trustLevel: number;
  public readonly admin: boolean;
  public readonly moderator: boolean;
  public readonly groups: Array<ProfileGroup>;
  public readonly isVerified: boolean;
  public readonly roleLabel: string;
  public readonly canFollow: boolean;
  public readonly following: boolean;
  public readonly canMute: boolean;
  public readonly canIgnore: boolean;
  public readonly notificationLevel: ProfileNotificationLevel;
  public readonly canUploadProfileBackground: boolean;
  public readonly canUploadCardBackground: boolean;
  public readonly profileBackgroundUrl: string;
  public readonly cardBackgroundUrl: string;
  public readonly bioRaw: string;
  public readonly bioExcerpt: string;
  public readonly location: string;
  public readonly website: string;
  public readonly timezone: string;
  public readonly hideProfile: boolean;
  public readonly hidePresence: boolean;
  public readonly canCreatePost: boolean;
  public readonly canChat: boolean;
  public readonly canDirectMessage: boolean;
  public readonly canChatWithUser: boolean;

  private constructor(id: number, username: string, attributes: UserProfileAttributes) {
    this.id = id;
    this.username = username;
    this.name = (attributes.name ?? '').trim();
    this.displayName = this.name.length > 0 ? this.name : username;
    this.title = (attributes.title ?? '').trim();
    this.avatarUrl = absoluteProfileUrl(attributes.avatarUrl ?? '');
    this.primaryGroupId = attributes.primaryGroupId ?? null;
    this.flairGroupId = attributes.flairGroupId ?? null;
    this.primaryGroupName = (attributes.primaryGroupName ?? '').trim();
    this.flairGroupName = (attributes.flairGroupName ?? '').trim();
    this.trustLevel = Math.max(0, Math.trunc(attributes.trustLevel ?? 0));
    this.admin = attributes.admin === true;
    this.moderator = attributes.moderator === true;
    this.groups = (attributes.groups ?? []).slice();
    const groupNames: Array<string> = this.groups.map((group: ProfileGroup): string => group.name);
    const groupIds: Array<number> = this.groups.map((group: ProfileGroup): number => group.id);
    const authorityGroupNames: Array<string> = groupNames.concat([
      this.primaryGroupName,
      this.flairGroupName
    ]);
    this.isVerified = authorityGroupNames.some(
      (name: string): boolean => VERIFIED_GROUP_NAMES.includes(name)
    ) ||
      groupIds.some((groupId: number): boolean => VERIFIED_GROUP_IDS.includes(groupId)) ||
      (this.primaryGroupId !== null && VERIFIED_GROUP_IDS.includes(this.primaryGroupId)) ||
      (this.flairGroupId !== null && VERIFIED_GROUP_IDS.includes(this.flairGroupId));
    this.roleLabel = this.admin || groupNames.includes('管理员')
      ? '管理员'
      : this.moderator || groupNames.includes('管理人员') || groupNames.includes('版主')
        ? '版主'
        : groupNames.includes('rs_developer')
          ? '开发者'
          : '普通成员';
    this.canFollow = attributes.canFollow === true;
    this.following = attributes.following === true;
    this.canMute = attributes.canMute === true;
    this.canIgnore = attributes.canIgnore === true;
    this.notificationLevel = attributes.ignored === true
      ? ProfileNotificationLevel.IGNORED
      : attributes.muted === true
        ? ProfileNotificationLevel.MUTED
        : ProfileNotificationLevel.NORMAL;
    this.canUploadProfileBackground = attributes.canUploadProfileBackground === true;
    this.canUploadCardBackground = attributes.canUploadCardBackground === true;
    this.profileBackgroundUrl = absoluteProfileUrl(attributes.profileBackgroundUrl ?? '');
    this.cardBackgroundUrl = absoluteProfileUrl(attributes.cardBackgroundUrl ?? '');
    this.bioRaw = attributes.bioRaw ?? '';
    this.bioExcerpt = forumPlainText(
      attributes.bioExcerpt ?? attributes.bioRaw ?? '',
      ForumPlainTextContext.PROFILE
    );
    this.location = (attributes.location ?? '').trim();
    this.website = (attributes.website ?? '').trim();
    this.timezone = (attributes.timezone ?? '').trim();
    this.hideProfile = attributes.hideProfile === true;
    this.hidePresence = attributes.hidePresence === true;
    this.canCreatePost = attributes.canCreatePost !== false;
    this.canChat = attributes.canChat === true;
    this.canDirectMessage = attributes.canDirectMessage === true;
    this.canChatWithUser = attributes.canChatWithUser === true;
  }

  public static create(id: number, username: string, attributes: UserProfileAttributes = {}): UserProfile | null {
    const normalizedUsername: string = username.trim();
    if (!Number.isSafeInteger(id) || id <= 0 || normalizedUsername.length === 0) {
      return null;
    }
    return new UserProfile(id, normalizedUsername, attributes);
  }

  public canStartDirectChat(): boolean {
    return this.canChatWithUser || (this.canChat && this.canDirectMessage);
  }
}

export class UserProfileSummary {
  public readonly available: boolean;
  public readonly likesGiven: number;
  public readonly likesReceived: number;
  public readonly daysVisited: number;
  public readonly topicCount: number;
  public readonly postCount: number;
  public readonly solvedCount: number;
  public readonly badges: Array<ProfileBadge>;

  public constructor(
    available: boolean,
    likesGiven: number = 0,
    likesReceived: number = 0,
    daysVisited: number = 0,
    topicCount: number = 0,
    postCount: number = 0,
    solvedCount: number = 0,
    badges: Array<ProfileBadge> = []
  ) {
    this.available = available;
    this.likesGiven = Math.max(0, Math.trunc(likesGiven));
    this.likesReceived = Math.max(0, Math.trunc(likesReceived));
    this.daysVisited = Math.max(0, Math.trunc(daysVisited));
    this.topicCount = Math.max(0, Math.trunc(topicCount));
    this.postCount = Math.max(0, Math.trunc(postCount));
    this.solvedCount = Math.max(0, Math.trunc(solvedCount));
    this.badges = badges.filter((badge: ProfileBadge): boolean => badge.name.length > 0);
  }

  public static unavailable(): UserProfileSummary {
    return new UserProfileSummary(false);
  }
}

export class ProfileBadge {
  public readonly name: string;
  public readonly imageUrl: string;

  public constructor(name: string, imageUrl: string = '') {
    this.name = name.trim();
    this.imageUrl = absoluteProfileUrl(imageUrl);
  }
}

export class UserEmailInfo {
  public readonly primaryEmail: string;
  public readonly secondaryEmails: Array<string>;
  public readonly unconfirmedEmails: Array<string>;

  public constructor(primaryEmail: string, secondaryEmails: Array<string>, unconfirmedEmails: Array<string>) {
    this.primaryEmail = primaryEmail.trim();
    this.secondaryEmails = secondaryEmails
      .map((email: string): string => email.trim())
      .filter((email: string): boolean => email.length > 0);
    this.unconfirmedEmails = unconfirmedEmails
      .map((email: string): string => email.trim())
      .filter((email: string): boolean => email.length > 0);
  }

  public allEmails(): Array<string> {
    const result: Array<string> = [];
    if (this.primaryEmail.length > 0) {
      result.push(this.primaryEmail);
    }
    return result.concat(this.secondaryEmails, this.unconfirmedEmails);
  }
}

export class UserReplyItem {
  public readonly actionId: number;
  public readonly topicId: number;
  public readonly topicTitle: string;
  public readonly categoryId: number;
  public readonly postNumber: number;
  public readonly createdAt: string;
  public readonly username: string;
  public readonly excerpt: string;

  public constructor(
    actionId: number,
    topicId: number,
    topicTitle: string,
    categoryId: number,
    postNumber: number,
    createdAt: string,
    username: string,
    excerpt: string
  ) {
    this.actionId = Math.max(0, Math.trunc(actionId));
    this.topicId = Math.max(0, Math.trunc(topicId));
    this.topicTitle = forumPlainText(topicTitle, ForumPlainTextContext.PROFILE);
    this.categoryId = Math.max(0, Math.trunc(categoryId));
    this.postNumber = Math.max(1, Math.trunc(postNumber));
    this.createdAt = createdAt.trim();
    this.username = username.trim();
    this.excerpt = forumPlainText(excerpt, ForumPlainTextContext.PROFILE);
  }
}

export class UserBookmarkItem {
  public readonly bookmarkId: number;
  public readonly topicId: number;
  public readonly title: string;
  public readonly excerpt: string;
  public readonly postNumber: number;
  public readonly categoryId: number;
  public readonly highestPostNumber: number;
  public readonly bumpedAt: string;
  public readonly username: string;

  public constructor(
    bookmarkId: number,
    topicId: number,
    title: string,
    excerpt: string,
    postNumber: number,
    categoryId: number,
    highestPostNumber: number,
    bumpedAt: string,
    username: string
  ) {
    this.bookmarkId = Math.max(0, Math.trunc(bookmarkId));
    this.topicId = Math.max(0, Math.trunc(topicId));
    this.title = forumPlainText(title, ForumPlainTextContext.PROFILE);
    this.excerpt = forumPlainText(excerpt, ForumPlainTextContext.PROFILE);
    this.postNumber = Math.max(1, Math.trunc(postNumber));
    this.categoryId = Math.max(0, Math.trunc(categoryId));
    this.highestPostNumber = Math.max(this.postNumber, Math.trunc(highestPostNumber));
    this.bumpedAt = bumpedAt.trim();
    this.username = username.trim();
  }
}

export class ProfileUpdateRequest {
  public readonly username: string;
  public readonly name: string | null;
  public readonly title: string | null;
  public readonly bioRaw: string | null;
  public readonly location: string | null;
  public readonly profileBackgroundUploadUrl: string | null;
  public readonly hidePresence: boolean | null;

  private constructor(
    username: string,
    name: string | null,
    title: string | null,
    bioRaw: string | null,
    location: string | null,
    profileBackgroundUploadUrl: string | null,
    hidePresence: boolean | null
  ) {
    this.username = username;
    this.name = name;
    this.title = title;
    this.bioRaw = bioRaw;
    this.location = location;
    this.profileBackgroundUploadUrl = profileBackgroundUploadUrl;
    this.hidePresence = hidePresence;
  }

  public static create(
    username: string,
    name: string | null,
    title: string | null,
    bioRaw: string | null,
    location: string | null,
    profileBackgroundUploadUrl: string | null,
    hidePresence: boolean | null = null
  ): ProfileUpdateRequest | null {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 ||
      (name === null && title === null && bioRaw === null && location === null &&
        profileBackgroundUploadUrl === null && hidePresence === null)) {
      return null;
    }
    return new ProfileUpdateRequest(
      normalizedUsername,
      name === null ? null : name.trim(),
      title === null ? null : title.trim(),
      bioRaw === null ? null : bioRaw.trim(),
      location === null ? null : location.trim(),
      profileBackgroundUploadUrl === null ? null : profileBackgroundUploadUrl.trim(),
      hidePresence
    );
  }

  public formBody(): string {
    const parts: Array<string> = [];
    if (this.name !== null) {
      parts.push(`name=${encodeURIComponent(this.name)}`);
    }
    if (this.title !== null) {
      parts.push(`title=${encodeURIComponent(this.title)}`);
    }
    if (this.bioRaw !== null) {
      parts.push(`bio_raw=${encodeURIComponent(this.bioRaw)}`);
    }
    if (this.location !== null) {
      parts.push(`location=${encodeURIComponent(this.location)}`);
    }
    if (this.profileBackgroundUploadUrl !== null) {
      parts.push(`profile_background_upload_url=${encodeURIComponent(this.profileBackgroundUploadUrl)}`);
    }
    if (this.hidePresence !== null) {
      parts.push(`hide_presence=${this.hidePresence}`);
    }
    return parts.join('&');
  }
}
