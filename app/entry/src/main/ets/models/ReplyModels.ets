import { ForumPost } from './ForumModels';
import { HomeChannel } from './DiscoveryModels';

export interface CurrentUserAttributes {
  name?: string;
  title?: string;
  admin?: boolean;
  moderator?: boolean;
  trustLevel?: number;
  canCreatePost?: boolean;
  canChat?: boolean;
  canDirectMessage?: boolean;
  canChatWithUser?: boolean;
  unreadNotifications?: number;
  groupNames?: Array<string>;
  groupIds?: Array<number>;
  primaryGroupId?: number | null;
  flairGroupId?: number | null;
  defaultHomeChannel?: HomeChannel | null;
}

export class CurrentUser {
  public readonly id: number;
  public readonly username: string;
  public readonly displayName: string;
  public readonly title: string;
  public readonly admin: boolean;
  public readonly moderator: boolean;
  public readonly trustLevel: number;
  public readonly canCreatePost: boolean;
  public readonly canChat: boolean;
  public readonly canDirectMessage: boolean;
  public readonly canChatWithUser: boolean;
  public readonly unreadNotifications: number;
  public readonly groups: Array<string>;
  public readonly groupIds: Array<number>;
  public readonly primaryGroupId: number | null;
  public readonly flairGroupId: number | null;
  public readonly isVerified: boolean;
  public readonly roleLabel: string;
  public readonly canReply: boolean;
  public readonly canStartDirectChat: boolean;
  public readonly defaultHomeChannel: HomeChannel | null;

  private constructor(
    id: number,
    username: string,
    displayName: string,
    title: string,
    admin: boolean,
    moderator: boolean,
    trustLevel: number,
    canCreatePost: boolean,
    canChat: boolean,
    canDirectMessage: boolean,
    canChatWithUser: boolean,
    unreadNotifications: number,
    groups: Array<string>,
    groupIds: Array<number>,
    primaryGroupId: number | null,
    flairGroupId: number | null,
    isVerified: boolean,
    roleLabel: string,
    defaultHomeChannel: HomeChannel | null
  ) {
    this.id = id;
    this.username = username;
    this.displayName = displayName;
    this.title = title;
    this.admin = admin;
    this.moderator = moderator;
    this.trustLevel = trustLevel;
    this.canCreatePost = canCreatePost;
    this.canChat = canChat;
    this.canDirectMessage = canDirectMessage;
    this.canChatWithUser = canChatWithUser;
    this.unreadNotifications = unreadNotifications;
    this.groups = groups;
    this.groupIds = groupIds;
    this.primaryGroupId = primaryGroupId;
    this.flairGroupId = flairGroupId;
    this.isVerified = isVerified;
    this.roleLabel = roleLabel;
    this.canReply = admin || moderator || canCreatePost;
    this.canStartDirectChat = canChatWithUser || (canChat && canDirectMessage);
    this.defaultHomeChannel = defaultHomeChannel;
  }

  public static create(
    id: number,
    username: string,
    attributes: CurrentUserAttributes = {}
  ): CurrentUser | null {
    const normalizedUsername: string = username.trim();
    if (!Number.isInteger(id) || id <= 0 || normalizedUsername.length === 0) {
      return null;
    }
    const normalizedName: string = (attributes.name ?? '').trim();
    const normalizedTitle: string = (attributes.title ?? '').trim();
    const normalizedGroups: Array<string> = (attributes.groupNames ?? [])
      .map((group: string): string => group.trim())
      .filter((group: string): boolean => group.length > 0);
    const normalizedGroupIds: Array<number> = (attributes.groupIds ?? [])
      .filter((groupId: number): boolean => Number.isInteger(groupId) && groupId > 0);
    const trustLevel: number = attributes.trustLevel ?? 0;
    const unreadNotifications: number = attributes.unreadNotifications ?? 0;
    const normalizedTrustLevel: number = Number.isInteger(trustLevel) && trustLevel >= 0 ? trustLevel : 0;
    const normalizedUnreadNotifications: number = Number.isInteger(unreadNotifications) && unreadNotifications >= 0
      ? unreadNotifications
      : 0;
    const verifiedGroupNames: Array<string> = [
      'verified_uestcer',
      'scuer',
      'swufer',
      'swjtuer',
      'sicnuer'
    ];
    const verifiedGroupIds: Array<number> = [41, 45, 46, 48, 49];
    const isVerified: boolean = normalizedGroups.some(
      (group: string): boolean => verifiedGroupNames.includes(group)
    ) || normalizedGroupIds.some((groupId: number): boolean => verifiedGroupIds.includes(groupId)) ||
      (attributes.primaryGroupId !== null && attributes.primaryGroupId !== undefined &&
        verifiedGroupIds.includes(attributes.primaryGroupId)) ||
      (attributes.flairGroupId !== null && attributes.flairGroupId !== undefined &&
        verifiedGroupIds.includes(attributes.flairGroupId));
    const admin: boolean = attributes.admin === true;
    const moderator: boolean = attributes.moderator === true;
    const roleLabel: string = admin || normalizedGroups.includes('管理员')
      ? '管理员'
      : moderator || normalizedGroups.includes('管理人员') || normalizedGroups.includes('版主')
        ? '版主'
        : normalizedGroups.includes('rs_developer')
          ? '开发者'
          : '普通成员';
    return new CurrentUser(
      id,
      normalizedUsername,
      normalizedName.length > 0 ? normalizedName : normalizedUsername,
      normalizedTitle,
      admin,
      moderator,
      normalizedTrustLevel,
      attributes.canCreatePost !== false,
      attributes.canChat === true,
      attributes.canDirectMessage === true,
      attributes.canChatWithUser === true,
      normalizedUnreadNotifications,
      normalizedGroups,
      normalizedGroupIds,
      attributes.primaryGroupId ?? null,
      attributes.flairGroupId ?? null,
      isVerified,
      roleLabel,
      attributes.defaultHomeChannel ?? null
    );
  }

  public withDefaultHomeChannel(channel: HomeChannel): CurrentUser {
    return new CurrentUser(
      this.id,
      this.username,
      this.displayName,
      this.title,
      this.admin,
      this.moderator,
      this.trustLevel,
      this.canCreatePost,
      this.canChat,
      this.canDirectMessage,
      this.canChatWithUser,
      this.unreadNotifications,
      this.groups,
      this.groupIds,
      this.primaryGroupId,
      this.flairGroupId,
      this.isVerified,
      this.roleLabel,
      channel
    );
  }

  public withUnreadNotifications(unreadNotifications: number): CurrentUser {
    const normalizedUnreadNotifications: number =
      Number.isInteger(unreadNotifications) && unreadNotifications >= 0
        ? unreadNotifications
        : this.unreadNotifications;
    return new CurrentUser(
      this.id,
      this.username,
      this.displayName,
      this.title,
      this.admin,
      this.moderator,
      this.trustLevel,
      this.canCreatePost,
      this.canChat,
      this.canDirectMessage,
      this.canChatWithUser,
      normalizedUnreadNotifications,
      this.groups,
      this.groupIds,
      this.primaryGroupId,
      this.flairGroupId,
      this.isVerified,
      this.roleLabel,
      this.defaultHomeChannel
    );
  }
}

export class ReplyRequest {
  public readonly topicId: number;
  public readonly raw: string;
  public readonly replyToPostNumber: number | null;

  private constructor(topicId: number, raw: string, replyToPostNumber: number | null) {
    this.topicId = topicId;
    this.raw = raw;
    this.replyToPostNumber = replyToPostNumber;
  }

  public static create(topicId: number, raw: string, replyToPostNumber: number | null): ReplyRequest | null {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return null;
    }
    const normalizedRaw: string = raw.trim();
    if (normalizedRaw.length === 0) {
      return null;
    }
    if (
      replyToPostNumber !== null &&
      (!Number.isInteger(replyToPostNumber) || replyToPostNumber <= 0)
    ) {
      return null;
    }
    return new ReplyRequest(topicId, normalizedRaw, replyToPostNumber);
  }
}

export enum ReplySubmitKind {
  CREATED = 'created',
  UNAUTHORIZED = 'unauthorized',
  REJECTED = 'rejected',
  UNCERTAIN = 'uncertain'
}

export class ReplySubmitResult {
  public readonly kind: ReplySubmitKind;
  public readonly post: ForumPost | null;
  public readonly message: string;

  private constructor(kind: ReplySubmitKind, post: ForumPost | null, message: string) {
    this.kind = kind;
    this.post = post;
    this.message = message;
  }

  public static created(post: ForumPost): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.CREATED, post, '');
  }

  public static unauthorized(): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.UNAUTHORIZED, null, '登录已失效');
  }

  public static rejected(message: string): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.REJECTED, null, message);
  }

  public static uncertain(message: string): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.UNCERTAIN, null, message);
  }
}

export class ReplyRecoveryRequest {
  public readonly reply: ReplyRequest;
  public readonly expectedPostNumber: number;
  public readonly currentUser: CurrentUser;

  private constructor(reply: ReplyRequest, expectedPostNumber: number, currentUser: CurrentUser) {
    this.reply = reply;
    this.expectedPostNumber = expectedPostNumber;
    this.currentUser = currentUser;
  }

  public static create(
    reply: ReplyRequest,
    expectedPostNumber: number,
    currentUser: CurrentUser
  ): ReplyRecoveryRequest | null {
    if (!Number.isInteger(expectedPostNumber) || expectedPostNumber <= 0) {
      return null;
    }
    return new ReplyRecoveryRequest(reply, expectedPostNumber, currentUser);
  }

  public matches(post: ForumPost): boolean {
    if (
      post.postNumber < this.expectedPostNumber ||
      post.userId !== this.currentUser.id ||
      post.raw.trim() !== this.reply.raw
    ) {
      return false;
    }
    return post.replyToPostNumber === this.reply.replyToPostNumber;
  }
}

export enum ReplyRecoveryKind {
  CONFIRMED = 'confirmed',
  NOT_FOUND = 'not-found',
  UNAUTHORIZED = 'unauthorized',
  FAILED = 'failed'
}

export class ReplyRecoveryResult {
  public readonly kind: ReplyRecoveryKind;
  public readonly post: ForumPost | null;
  public readonly message: string;

  private constructor(kind: ReplyRecoveryKind, post: ForumPost | null, message: string) {
    this.kind = kind;
    this.post = post;
    this.message = message;
  }

  public static confirmed(post: ForumPost): ReplyRecoveryResult {
    return new ReplyRecoveryResult(ReplyRecoveryKind.CONFIRMED, post, '');
  }

  public static notFound(): ReplyRecoveryResult {
    return new ReplyRecoveryResult(
      ReplyRecoveryKind.NOT_FOUND,
      null,
      '未确认 Reply 已创建，请检查 Topic 后再显式重试'
    );
  }

  public static unauthorized(): ReplyRecoveryResult {
    return new ReplyRecoveryResult(ReplyRecoveryKind.UNAUTHORIZED, null, '登录已失效');
  }

  public static failed(message: string): ReplyRecoveryResult {
    return new ReplyRecoveryResult(ReplyRecoveryKind.FAILED, null, message);
  }
}
