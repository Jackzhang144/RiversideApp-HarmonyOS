import { JsonObjectReader } from '../core/JsonObjectReader';
import { forumPlainText, ForumPlainTextContext } from '../core/ForumPlainText';
import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';

function nonNegativeInteger(value: number | null): number {
  return value !== null && Number.isInteger(value) && value > 0 ? value : 0;
}

function firstString(reader: JsonObjectReader, names: Array<string>): string {
  for (const name of names) {
    const value: string | null = reader.string(name);
    if (value !== null && value.trim().length > 0) {
      return value.trim();
    }
  }
  return '';
}

function firstNumber(reader: JsonObjectReader, names: Array<string>): number {
  for (const name of names) {
    const value: number | null = reader.number(name);
    if (value !== null) {
      return nonNegativeInteger(value);
    }
  }
  return 0;
}

export function chatPlainText(value: string): string {
  return forumPlainText(value, ForumPlainTextContext.CHAT);
}

export function absoluteChatUrl(value: string): string {
  return RIVERSIDE_URL_RESOLVER.chat(value);
}

export function chatMessagePermalink(channelId: number, channelSlug: string, messageId: number): string {
  return RIVERSIDE_URL_RESOLVER.chatMessage(channelId, channelSlug, messageId);
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
    canDeleteOthers: boolean = false
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
      this.canDeleteOthers
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
    deleted: boolean
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
  }

  public displayText(): string {
    if (this.deleted) {
      return '消息已删除';
    }
    return this.message === '\u200B' ? '' : this.message;
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

function parseChannel(reader: JsonObjectReader): ChatChannel | null {
  const id: number = nonNegativeInteger(reader.number('id'));
  if (id === 0) {
    return null;
  }
  const chatable: JsonObjectReader | null = reader.object('chatable');
  const lastMessage: JsonObjectReader | null = reader.object('last_message') ?? reader.object('last_chat_message');
  const membership: JsonObjectReader | null = reader.object('current_user_membership');
  const meta: JsonObjectReader | null = reader.object('meta');
  const lastUser: JsonObjectReader | null = lastMessage?.object('user') ?? null;
  const rawType: string = firstString(reader, ['chatable_type', 'type']).toLowerCase() ||
    (chatable === null ? '' : firstString(chatable, ['type'])).toLowerCase();
  const isDirect: boolean = rawType === 'directmessage' || rawType === 'direct_message';
  let title: string = firstString(reader, ['title', 'name']);
  if (title.length === 0 && chatable !== null) {
    title = firstString(chatable, ['name', 'title']);
  }
  if (title.length === 0) {
    const users: Array<Object | null> = reader.array('users') ?? [];
    const usernames: Array<string> = [];
    for (const value of users) {
      const user: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const username: string = user === null ? '' : firstString(user, ['username', 'name']);
      if (username.length > 0 && usernames.length < 3) {
        usernames.push(username);
      }
    }
    title = usernames.join(', ');
  }
  const lastMessageId: number = lastMessage === null
    ? firstNumber(reader, ['last_message_id', 'last_chat_message_id'])
    : firstNumber(lastMessage, ['id']);
  const lastReadMessageId: number = membership === null ? 0 : firstNumber(membership, ['last_read_message_id']);
  const membershipUnread: number | null = membership?.number('unread_count') ?? null;
  const unreadCount: number = membershipUnread === null
    ? (lastMessageId > lastReadMessageId ? 1 : 0)
    : nonNegativeInteger(membershipUnread);
  const messageTime: string = lastMessage === null
    ? firstString(reader, ['last_message_created_at', 'last_posted_at'])
    : firstString(lastMessage, ['created_at']);
  const rawPreview: string = firstString(reader, ['last_message_excerpt', 'excerpt']) ||
    (lastMessage === null ? '' : firstString(lastMessage, ['excerpt', 'message', 'cooked']));
  const lastUsername: string = lastUser === null
    ? (lastMessage === null ? '' : firstString(lastMessage, ['username', 'display_username']))
    : firstString(lastUser, ['username', 'display_username']);
  const subtitle: string = firstString(reader, ['description', 'slug']) ||
    (chatable === null ? '' : firstString(chatable, ['description'])) ||
    (isDirect ? '直接消息' : '频道');
  return new ChatChannel(
    id,
    title.length > 0 ? chatPlainText(title) : '未命名聊天',
    chatPlainText(subtitle),
    chatPlainText(rawPreview),
    lastMessageId > 0 || rawPreview.length > 0 || lastUsername.length > 0 ? messageTime : '',
    isDirect,
    unreadCount,
    lastMessageId,
    lastUsername,
    firstString(reader, ['slug']),
    meta?.boolean('user_silenced') === true,
    meta?.boolean('can_delete_self') === true,
    meta?.boolean('can_delete_others') === true
  );
}

function mergeChannel(channels: Array<ChatChannel>, candidate: ChatChannel): void {
  const index: number = channels.findIndex((channel: ChatChannel): boolean => channel.id === candidate.id);
  if (index >= 0) {
    channels[index] = candidate;
  } else {
    channels.push(candidate);
  }
}

function collectChannels(envelope: JsonObjectReader, name: string, channels: Array<ChatChannel>): void {
  const directList: Array<Object | null> | null = envelope.array(name);
  const nested: JsonObjectReader | null = envelope.object(name);
  const values: Array<Object | null> = directList ?? nested?.array('channels') ?? [];
  for (const value of values) {
    const item: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (item === null) {
      continue;
    }
    const channelReader: JsonObjectReader = item.object('channel') ?? item;
    const channel: ChatChannel | null = parseChannel(channelReader);
    if (channel !== null) {
      mergeChannel(channels, channel);
    }
  }
}

export function parseChatChannels(text: string): Array<ChatChannel> | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const channels: Array<ChatChannel> = [];
  for (const name of ['channels', 'public_channels', 'direct_message_channels', 'memberships', 'data']) {
    collectChannels(envelope, name, channels);
  }
  const channelTracking: JsonObjectReader | null = envelope.object('tracking')?.object('channel_tracking') ?? null;
  if (channelTracking !== null) {
    for (let index: number = 0; index < channels.length; index += 1) {
      const tracking: JsonObjectReader | null = channelTracking.object(channels[index].id.toString());
      const unreadCount: number | null = tracking?.number('unread_count') ?? null;
      if (unreadCount !== null) {
        channels[index] = channels[index].withUnreadCount(unreadCount);
      }
    }
  }
  channels.sort((left: ChatChannel, right: ChatChannel): number => {
    const unread: number = right.unreadCount - left.unreadCount;
    if (unread !== 0) {
      return unread;
    }
    const time: number = right.lastMessageAt.localeCompare(left.lastMessageAt);
    return time !== 0 ? time : left.title.localeCompare(right.title);
  });
  return channels;
}

export function parseChatChannelResponse(text: string): ChatChannel | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const channel: JsonObjectReader = envelope.object('channel') ??
    envelope.object('direct_message_channel') ?? envelope;
  return parseChannel(channel);
}

function parseReactionUser(value: Object | null): ChatReactionUser | null {
  const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  if (reader === null) {
    return null;
  }
  const username: string = firstString(reader, ['username', 'name']);
  if (username.length === 0) {
    return null;
  }
  const avatarTemplate: string = firstString(reader, ['avatar_url', 'avatar_template']);
  return new ChatReactionUser(username, absoluteChatUrl(avatarTemplate.replace('{size}', '96')));
}

function parseReaction(value: Object | null): ChatReaction | null {
  const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  if (reader === null) {
    return null;
  }
  const users: Array<ChatReactionUser> = [];
  for (const userValue of reader.array('users') ?? []) {
    const user: ChatReactionUser | null = parseReactionUser(userValue);
    if (user !== null) {
      users.push(user);
    }
  }
  const emoji: string = firstString(reader, ['emoji', 'id', 'name', 'reaction']);
  const countValue: number | null = reader.number('count');
  const count: number = countValue === null ? users.length : nonNegativeInteger(countValue);
  if (emoji.length === 0 || count === 0) {
    return null;
  }
  return new ChatReaction(emoji, count, reader.boolean('reacted') === true, users);
}

function looksLikeImage(value: string): boolean {
  const normalized: string = value.trim().toLowerCase();
  return value.startsWith('upload://') ||
    (normalized.includes('/uploads/') && /\.(png|jpe?g|gif|webp|avif)(\?|$)/.test(normalized));
}

function appendUploadUrl(urls: Array<string>, value: string): void {
  const normalized: string = value.trim();
  if (looksLikeImage(normalized) && !urls.includes(normalized)) {
    urls.push(normalized);
  }
}

function collectUpload(value: Object | null, urls: Array<string>): void {
  if (typeof value === 'string') {
    appendUploadUrl(urls, value);
    return;
  }
  if (Array.isArray(value)) {
    const values: Array<Object | null> = Array.from<Object | null>(value);
    for (const item of values) {
      collectUpload(item, urls);
    }
    return;
  }
  const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  if (reader === null) {
    return;
  }
  collectUploadReader(reader, urls);
}

function collectUploadReader(reader: JsonObjectReader, urls: Array<string>): void {
  const thumbnail: JsonObjectReader | null = reader.object('thumbnail');
  const thumbnailUrl: string = thumbnail === null ? '' : firstString(thumbnail, ['url']);
  if (thumbnailUrl.length > 0 && looksLikeImage(thumbnailUrl)) {
    appendUploadUrl(urls, thumbnailUrl);
    return;
  }
  appendUploadUrl(urls, firstString(reader, ['thumbnail_url', 'url', 'short_path', 'short_url']));
}

function parseMessage(reader: JsonObjectReader): ChatMessage | null {
  const id: number = nonNegativeInteger(reader.number('id'));
  if (id === 0) {
    return null;
  }
  const user: JsonObjectReader | null = reader.object('user');
  const cooked: string = firstString(reader, ['cooked']);
  const rawMessage: string = firstString(reader, ['message', 'excerpt']);
  const username: string = firstString(reader, ['username']) ||
    (user === null ? '' : firstString(user, ['username']));
  const avatarTemplate: string = firstString(reader, ['avatar_template']) ||
    (user === null ? '' : firstString(user, ['avatar_template']));
  const uploadUrls: Array<string> = [];
  for (const name of ['uploads', 'upload', 'chat_uploads', 'chat_message_uploads', 'upload_urls']) {
    for (const value of reader.array(name) ?? []) {
      collectUpload(value, uploadUrls);
    }
    const nested: JsonObjectReader | null = reader.object(name);
    if (nested !== null) {
      collectUploadReader(nested, uploadUrls);
    }
  }
  const reactions: Array<ChatReaction> = [];
  for (const value of reader.array('reactions') ?? []) {
    const reaction: ChatReaction | null = parseReaction(value);
    if (reaction !== null) {
      reactions.push(reaction);
    }
  }
  const replyReader: JsonObjectReader | null = reader.object('in_reply_to');
  let replyTo: ChatReplyPreview | null = null;
  if (replyReader !== null) {
    const replyUser: JsonObjectReader | null = replyReader.object('user');
    const replyUsername: string = firstString(replyReader, ['username']) ||
      (replyUser === null ? '' : firstString(replyUser, ['username']));
    const excerpt: string = chatPlainText(firstString(replyReader, ['excerpt', 'cooked', 'message']));
    if (replyUsername.length > 0 || excerpt.length > 0) {
      replyTo = new ChatReplyPreview(nonNegativeInteger(replyReader.number('id')), replyUsername, excerpt);
    }
  }
  const deleted: boolean = reader.has('deleted_at') && !reader.isNull('deleted_at');
  const parsedMessage: string = chatPlainText(cooked.length > 0 ? cooked : rawMessage);
  const uploadPlaceholder: boolean = uploadUrls.length > 0 && (
    parsedMessage.includes('upload://') ||
    /^[\w.()\[\] -]+\.(?:jpe?g|png|gif|webp|avif|heic|heif)$/i.test(parsedMessage)
  );
  const message: string = rawMessage === '\u200B' || uploadPlaceholder ? '\u200B' : parsedMessage;
  if (!deleted && message.length === 0 && uploadUrls.length === 0 && reactions.length === 0 && replyTo === null) {
    return null;
  }
  return new ChatMessage(
    id,
    username,
    absoluteChatUrl(avatarTemplate.replace('{size}', '96')),
    message,
    cooked,
    uploadUrls,
    reactions,
    replyTo,
    firstString(reader, ['created_at']),
    deleted
  );
}

export function parseChatMessagePage(text: string): ChatMessagePage | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const rawMessages: Array<Object | null> = envelope.array('messages') ??
    envelope.array('chat_messages') ?? envelope.array('data') ?? [];
  const messages: Array<ChatMessage> = [];
  for (const value of rawMessages) {
    const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    const message: ChatMessage | null = reader === null ? null : parseMessage(reader);
    if (message !== null) {
      messages.push(message);
    }
  }
  messages.sort((left: ChatMessage, right: ChatMessage): number => {
    if (left.createdAt.length === 0 && right.createdAt.length > 0) {
      return 1;
    }
    if (right.createdAt.length === 0 && left.createdAt.length > 0) {
      return -1;
    }
    const time: number = left.createdAt.localeCompare(right.createdAt);
    return time !== 0 ? time : left.id - right.id;
  });
  const meta: JsonObjectReader | null = envelope.object('meta');
  return new ChatMessagePage(
    messages,
    meta?.boolean('can_load_more_past') === true,
    meta?.boolean('can_load_more_future') === true
  );
}

export function parseChatMessageResponse(text: string): ChatMessage | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const message: JsonObjectReader = envelope.object('message') ?? envelope.object('chat_message') ?? envelope;
  return parseMessage(message);
}

export function parseChatSendConfirmation(text: string): ChatSendConfirmation | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const nested: JsonObjectReader | null = envelope.object('message') ?? envelope.object('chat_message');
  const message: ChatMessage | null = nested === null ? null : parseMessage(nested);
  const responseMessageId: number = nonNegativeInteger(envelope.number('message_id'));
  const messageId: number = responseMessageId > 0 ? responseMessageId : (message?.id ?? 0);
  return messageId > 0 ? new ChatSendConfirmation(messageId, message) : null;
}

export function parseChatEmojis(text: string): Array<ChatEmoji> | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const emojis: Array<ChatEmoji> = [];
  for (const entry of envelope.entries()) {
    if (!Array.isArray(entry[1])) {
      continue;
    }
    const values: Array<Object | null> = Array.from<Object | null>(entry[1]);
    for (const value of values) {
      const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (reader === null) {
        continue;
      }
      const name: string = firstString(reader, ['name']);
      if (name.length > 0 && !emojis.some((emoji: ChatEmoji): boolean => emoji.name === name)) {
        emojis.push(new ChatEmoji(name, firstString(reader, ['url']), firstString(reader, ['group']) || entry[0]));
      }
    }
  }
  return emojis;
}

export function parseChatSearchResults(text: string): Array<ChatSearchResult> | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  if (envelope === null) {
    return null;
  }
  const results: Array<ChatSearchResult> = [];
  for (const value of envelope.array('messages') ?? []) {
    const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (reader === null) {
      continue;
    }
    const message: ChatMessage | null = parseMessage(reader);
    const channelReader: JsonObjectReader | null = reader.object('channel');
    const channel: ChatChannel | null = channelReader === null ? null : parseChannel(channelReader);
    if (message !== null && channel !== null) {
      results.push(new ChatSearchResult(message, channel));
    }
  }
  return results;
}
