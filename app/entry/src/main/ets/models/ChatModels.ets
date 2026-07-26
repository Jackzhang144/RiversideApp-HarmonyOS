import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';

function nonNegativeInteger(value: number | null): number {
  return value !== null && Number.isInteger(value) && value > 0 ? value : 0;
}

export function absoluteChatUrl(value: string): string {
  return RIVERSIDE_URL_RESOLVER.chat(value);
}

export function chatMessagePermalink(channelId: number, channelSlug: string, messageId: number): string {
  return RIVERSIDE_URL_RESOLVER.chatMessage(channelId, channelSlug, messageId);
}

export enum ChatChannelNotificationLevel {
  NEVER = 'never',
  MENTION = 'mention',
  ALWAYS = 'always'
}

export function chatChannelNotificationLevel(value: string): ChatChannelNotificationLevel | null {
  const normalized: string = value.trim().toLowerCase();
  if (normalized === ChatChannelNotificationLevel.NEVER) return ChatChannelNotificationLevel.NEVER;
  if (normalized === ChatChannelNotificationLevel.MENTION) return ChatChannelNotificationLevel.MENTION;
  if (normalized === ChatChannelNotificationLevel.ALWAYS) return ChatChannelNotificationLevel.ALWAYS;
  return null;
}

export function chatChannelNotificationLevelLabel(level: ChatChannelNotificationLevel): string {
  if (level === ChatChannelNotificationLevel.NEVER) return '从不提醒';
  if (level === ChatChannelNotificationLevel.ALWAYS) return '所有新消息';
  return '仅提及我时';
}

export class ChatChannelNotificationSettings {
  public readonly notificationLevel: ChatChannelNotificationLevel;
  public readonly muted: boolean;

  public constructor(notificationLevel: ChatChannelNotificationLevel, muted: boolean) {
    this.notificationLevel = notificationLevel;
    this.muted = muted;
  }
}

export class ChatChannelNotificationUpdate {
  public readonly notificationLevel: ChatChannelNotificationLevel | null;
  public readonly muted: boolean | null;

  private constructor(notificationLevel: ChatChannelNotificationLevel | null, muted: boolean | null) {
    this.notificationLevel = notificationLevel;
    this.muted = muted;
  }

  public static level(notificationLevel: ChatChannelNotificationLevel): ChatChannelNotificationUpdate {
    return new ChatChannelNotificationUpdate(notificationLevel, null);
  }

  public static mute(muted: boolean): ChatChannelNotificationUpdate {
    return new ChatChannelNotificationUpdate(null, muted);
  }

  public formBody(): string {
    if (this.notificationLevel !== null) {
      return `notifications_settings[notification_level]=${this.notificationLevel}`;
    }
    return `notifications_settings[muted]=${this.muted === true ? 'true' : 'false'}`;
  }
}

export class ChatChannel {
  public readonly id: number;
  public readonly title: string;
  public readonly subtitle: string;
  public readonly preview: string;
  public readonly lastMessageAt: string;
  public readonly isDirectMessage: boolean;
  public readonly unreadCount: number;
  public readonly lastMessageId: number;
  public readonly lastMessageUsername: string;
  public readonly slug: string;
  public readonly userSilenced: boolean;
  public readonly canDeleteSelf: boolean;
  public readonly canDeleteOthers: boolean;
  public readonly notificationLevel: ChatChannelNotificationLevel;
  public readonly muted: boolean;
  public readonly pinnedMessagesCount: number;
  public readonly canManagePins: boolean;
  public readonly hasUnseenPins: boolean;
  public readonly pinningEnabled: boolean;

  public constructor(
    id: number,
    title: string,
    subtitle: string,
    preview: string,
    lastMessageAt: string,
    isDirectMessage: boolean,
    unreadCount: number,
    lastMessageId: number,
    lastMessageUsername: string,
    slug: string,
    userSilenced: boolean = false,
    canDeleteSelf: boolean = false,
    canDeleteOthers: boolean = false,
    notificationLevel: ChatChannelNotificationLevel = ChatChannelNotificationLevel.MENTION,
    muted: boolean = false,
    pinnedMessagesCount: number = 0,
    canManagePins: boolean = false,
    hasUnseenPins: boolean = false,
    pinningEnabled: boolean = false
  ) {
    this.id = id;
    this.title = title;
    this.subtitle = subtitle;
    this.preview = preview;
    this.lastMessageAt = lastMessageAt;
    this.isDirectMessage = isDirectMessage;
    this.unreadCount = unreadCount;
    this.lastMessageId = lastMessageId;
    this.lastMessageUsername = lastMessageUsername;
    this.slug = slug;
    this.userSilenced = userSilenced;
    this.canDeleteSelf = canDeleteSelf;
    this.canDeleteOthers = canDeleteOthers;
    this.notificationLevel = notificationLevel;
    this.muted = muted;
    this.pinnedMessagesCount = nonNegativeInteger(pinnedMessagesCount);
    this.canManagePins = canManagePins;
    this.hasUnseenPins = hasUnseenPins;
    this.pinningEnabled = pinningEnabled;
  }

  public withUnreadCount(unreadCount: number): ChatChannel {
    return new ChatChannel(
      this.id,
      this.title,
      this.subtitle,
      this.preview,
      this.lastMessageAt,
      this.isDirectMessage,
      nonNegativeInteger(unreadCount),
      this.lastMessageId,
      this.lastMessageUsername,
      this.slug,
      this.userSilenced,
      this.canDeleteSelf,
      this.canDeleteOthers,
      this.notificationLevel,
      this.muted,
      this.pinnedMessagesCount,
      this.canManagePins,
      this.hasUnseenPins,
      this.pinningEnabled
    );
  }

  public withNotificationSettings(settings: ChatChannelNotificationSettings): ChatChannel {
    return new ChatChannel(
      this.id,
      this.title,
      this.subtitle,
      this.preview,
      this.lastMessageAt,
      this.isDirectMessage,
      this.unreadCount,
      this.lastMessageId,
      this.lastMessageUsername,
      this.slug,
      this.userSilenced,
      this.canDeleteSelf,
      this.canDeleteOthers,
      settings.notificationLevel,
      settings.muted,
      this.pinnedMessagesCount,
      this.canManagePins,
      this.hasUnseenPins,
      this.pinningEnabled
    );
  }

  public withPinSummary(pinnedMessagesCount: number, hasUnseenPins: boolean): ChatChannel {
    return new ChatChannel(
      this.id,
      this.title,
      this.subtitle,
      this.preview,
      this.lastMessageAt,
      this.isDirectMessage,
      this.unreadCount,
      this.lastMessageId,
      this.lastMessageUsername,
      this.slug,
      this.userSilenced,
      this.canDeleteSelf,
      this.canDeleteOthers,
      this.notificationLevel,
      this.muted,
      pinnedMessagesCount,
      this.canManagePins,
      hasUnseenPins,
      this.pinningEnabled
    );
  }
}

export class ChatReactionUser {
  public readonly username: string;
  public readonly avatarUrl: string;

  public constructor(username: string, avatarUrl: string) {
    this.username = username;
    this.avatarUrl = avatarUrl;
  }
}

export class ChatReaction {
  public readonly emoji: string;
  public readonly count: number;
  public readonly reacted: boolean;
  public readonly users: Array<ChatReactionUser>;

  public constructor(emoji: string, count: number, reacted: boolean, users: Array<ChatReactionUser>) {
    this.emoji = emoji;
    this.count = count;
    this.reacted = reacted;
    this.users = users;
  }
}

export class ChatReplyPreview {
  public readonly messageId: number;
  public readonly username: string;
  public readonly excerpt: string;

  public constructor(messageId: number, username: string, excerpt: string) {
    this.messageId = messageId;
    this.username = username;
    this.excerpt = excerpt;
  }
}

export class ChatMessage {
  public readonly id: number;
  public readonly username: string;
  public readonly avatarUrl: string;
  public readonly message: string;
  public readonly cooked: string;
  public readonly uploadUrls: Array<string>;
  public readonly reactions: Array<ChatReaction>;
  public readonly replyTo: ChatReplyPreview | null;
  public readonly createdAt: string;
  public readonly deleted: boolean;
  public readonly pinned: boolean;

  public constructor(
    id: number,
    username: string,
    avatarUrl: string,
    message: string,
    cooked: string,
    uploadUrls: Array<string>,
    reactions: Array<ChatReaction>,
    replyTo: ChatReplyPreview | null,
    createdAt: string,
    deleted: boolean,
    pinned: boolean = false
  ) {
    this.id = id;
    this.username = username;
    this.avatarUrl = avatarUrl;
    this.message = message;
    this.cooked = cooked;
    this.uploadUrls = uploadUrls;
    this.reactions = reactions;
    this.replyTo = replyTo;
    this.createdAt = createdAt;
    this.deleted = deleted;
    this.pinned = pinned;
  }

  public displayText(): string {
    if (this.deleted) {
      return '消息已删除';
    }
    return this.message === '\u200B' ? '' : this.message;
  }

  public withPinned(pinned: boolean): ChatMessage {
    return new ChatMessage(
      this.id,
      this.username,
      this.avatarUrl,
      this.message,
      this.cooked,
      this.uploadUrls,
      this.reactions,
      this.replyTo,
      this.createdAt,
      this.deleted,
      pinned
    );
  }
}

export class ChatPinnedMessage {
  public readonly id: number;
  public readonly chatMessageId: number;
  public readonly pinnedAt: string;
  public readonly pinnedByUsername: string;
  public readonly pinnedByAvatarUrl: string;
  public readonly message: ChatMessage;

  public constructor(
    id: number,
    chatMessageId: number,
    pinnedAt: string,
    pinnedByUsername: string,
    pinnedByAvatarUrl: string,
    message: ChatMessage
  ) {
    this.id = id;
    this.chatMessageId = chatMessageId;
    this.pinnedAt = pinnedAt;
    this.pinnedByUsername = pinnedByUsername;
    this.pinnedByAvatarUrl = pinnedByAvatarUrl;
    this.message = message;
  }
}

export class ChatPinnedMessagePage {
  public readonly pinnedMessages: Array<ChatPinnedMessage>;
  public readonly hasUnseenPins: boolean;
  public readonly lastViewedPinsAt: string;

  public constructor(
    pinnedMessages: Array<ChatPinnedMessage>,
    hasUnseenPins: boolean,
    lastViewedPinsAt: string
  ) {
    this.pinnedMessages = pinnedMessages;
    this.hasUnseenPins = hasUnseenPins;
    this.lastViewedPinsAt = lastViewedPinsAt;
  }
}

export class ChatMessagePage {
  public readonly messages: Array<ChatMessage>;
  public readonly canLoadMorePast: boolean;
  public readonly canLoadMoreFuture: boolean;

  public constructor(messages: Array<ChatMessage>, canLoadMorePast: boolean, canLoadMoreFuture: boolean) {
    this.messages = messages;
    this.canLoadMorePast = canLoadMorePast;
    this.canLoadMoreFuture = canLoadMoreFuture;
  }
}

export class ChatEmoji {
  public readonly name: string;
  public readonly url: string;
  public readonly group: string;

  public constructor(name: string, url: string, group: string) {
    this.name = name;
    this.url = absoluteChatUrl(url);
    this.group = group;
  }

  public imageUrl(): string {
    return this.url.length > 0
      ? this.url
      : RIVERSIDE_URL_RESOLVER.reactionEmoji(this.name);
  }
}

export class ChatSearchResult {
  public readonly message: ChatMessage;
  public readonly channel: ChatChannel;

  public constructor(message: ChatMessage, channel: ChatChannel) {
    this.message = message;
    this.channel = channel;
  }
}

export class ChatMessageQuery {
  public readonly targetMessageId: number | null;
  public readonly direction: string;
  public readonly fetchFromLastRead: boolean;

  private constructor(targetMessageId: number | null, direction: string, fetchFromLastRead: boolean) {
    this.targetMessageId = targetMessageId;
    this.direction = direction;
    this.fetchFromLastRead = fetchFromLastRead;
  }

  public static initial(): ChatMessageQuery {
    return new ChatMessageQuery(null, '', true);
  }

  public static latest(): ChatMessageQuery {
    return new ChatMessageQuery(null, '', false);
  }

  public static target(targetMessageId: number): ChatMessageQuery | null {
    if (!Number.isSafeInteger(targetMessageId) || targetMessageId <= 0) {
      return null;
    }
    return new ChatMessageQuery(targetMessageId, '', false);
  }

  public static around(targetMessageId: number, direction: string): ChatMessageQuery | null {
    const normalizedDirection: string = direction.trim().toLowerCase();
    if (
      !Number.isSafeInteger(targetMessageId) ||
      targetMessageId <= 0 ||
      (normalizedDirection !== 'past' && normalizedDirection !== 'future')
    ) {
      return null;
    }
    return new ChatMessageQuery(targetMessageId, normalizedDirection, false);
  }

  public queryString(): string {
    const values: Array<string> = ['page_size=30'];
    if (this.fetchFromLastRead && this.targetMessageId === null) {
      values.push('fetch_from_last_read=true');
    }
    if (this.targetMessageId !== null) {
      values.push(`target_message_id=${this.targetMessageId}`);
    }
    if (this.direction.length > 0) {
      values.push(`direction=${this.direction}`);
    }
    return values.join('&');
  }
}

export enum ChatReactionAction {
  ADD = 'add',
  REMOVE = 'remove'
}

interface ChatSendPayload {
  message: string;
  staged_id: string;
  client_created_at: string;
  in_reply_to_id?: number;
  upload_ids?: Array<number>;
}

export class ChatSendRequest {
  public readonly channelId: number;
  public readonly message: string;
  public readonly uploadIds: Array<number>;
  public readonly inReplyToId: number | null;
  public readonly stagedId: string;
  public readonly clientCreatedAt: string;

  private constructor(
    channelId: number,
    message: string,
    uploadIds: Array<number>,
    inReplyToId: number | null,
    stagedId: string,
    clientCreatedAt: string
  ) {
    this.channelId = channelId;
    this.message = message;
    this.uploadIds = uploadIds;
    this.inReplyToId = inReplyToId;
    this.stagedId = stagedId;
    this.clientCreatedAt = clientCreatedAt;
  }

  public static create(
    channelId: number,
    message: string,
    uploadIds: Array<number>,
    inReplyToId: number | null,
    stagedId: string,
    clientCreatedAt: string
  ): ChatSendRequest | null {
    const normalizedMessage: string = message.trim();
    const normalizedStagedId: string = stagedId.trim();
    const normalizedCreatedAt: string = clientCreatedAt.trim();
    const normalizedUploadIds: Array<number> = [];
    for (const uploadId of uploadIds) {
      if (!Number.isSafeInteger(uploadId) || uploadId <= 0) {
        return null;
      }
      if (!normalizedUploadIds.includes(uploadId)) {
        normalizedUploadIds.push(uploadId);
      }
    }
    if (
      !Number.isSafeInteger(channelId) ||
      channelId <= 0 ||
      (normalizedMessage.length === 0 && normalizedUploadIds.length === 0) ||
      (inReplyToId !== null && (!Number.isSafeInteger(inReplyToId) || inReplyToId <= 0)) ||
      normalizedStagedId.length === 0 ||
      normalizedCreatedAt.length === 0
    ) {
      return null;
    }
    return new ChatSendRequest(
      channelId,
      normalizedMessage.length === 0 ? '\u200B' : normalizedMessage,
      normalizedUploadIds,
      inReplyToId,
      normalizedStagedId,
      normalizedCreatedAt
    );
  }

  public toHttpExtraData(): ChatSendPayload {
    const payload: ChatSendPayload = {
      message: this.message,
      staged_id: this.stagedId,
      client_created_at: this.clientCreatedAt
    };
    if (this.inReplyToId !== null) {
      payload.in_reply_to_id = this.inReplyToId;
    }
    if (this.uploadIds.length > 0) {
      payload.upload_ids = this.uploadIds;
    }
    return payload;
  }
}

export class ChatSendConfirmation {
  public readonly messageId: number;
  public readonly message: ChatMessage | null;

  public constructor(messageId: number, message: ChatMessage | null = null) {
    this.messageId = messageId;
    this.message = message;
  }
}
