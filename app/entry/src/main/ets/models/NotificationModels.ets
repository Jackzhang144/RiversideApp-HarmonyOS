import { JSON as ArkJSON } from '@kit.ArkTS';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { Topic } from './ForumModels';

const RIVERSIDE_BASE_URL: string = 'https://river-side.cc';

export enum NotificationBucket {
  PRIVATE_MESSAGES = 'private-messages',
  REPLIES = 'replies',
  REACTIONS = 'reactions',
  MENTIONS = 'mentions'
}

export function notificationBucketLabel(bucket: NotificationBucket): string {
  if (bucket === NotificationBucket.PRIVATE_MESSAGES) return '私信';
  if (bucket === NotificationBucket.REPLIES) return '回复';
  if (bucket === NotificationBucket.REACTIONS) return '回应';
  return '提及';
}

export function notificationUserActionFilter(bucket: NotificationBucket): string | null {
  if (bucket === NotificationBucket.REPLIES) return '6,9';
  if (bucket === NotificationBucket.MENTIONS) return '7';
  return null;
}

export enum NotificationItemKind {
  PRIVATE_MESSAGE = 'private-message',
  ACTIVITY = 'activity'
}

export interface NotificationItemAttributes {
  excerpt?: string;
  topicId?: number;
  postId?: number;
  postNumber?: number;
  categoryId?: number;
  highestPostNumber?: number;
  createdAt?: string;
  actorUsername?: string;
  actorName?: string;
  avatarUrl?: string;
  flairUrl?: string;
  reaction?: string;
}

function positiveInteger(value: number | undefined): number {
  return value !== undefined && Number.isSafeInteger(value) && value > 0 ? value : 0;
}

function visibleText(value: string): string {
  return value
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<[^>]+>/g, ' ')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/[ \t]+/g, ' ')
    .replace(/ *\n */g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function absoluteNotificationUrl(value: string): string {
  const normalized: string = value.trim().replace('{size}', '96');
  if (normalized.length === 0) return '';
  if (normalized.startsWith('https://') || normalized.startsWith('http://')) return normalized;
  return normalized.startsWith('/')
    ? `${RIVERSIDE_BASE_URL}${normalized}`
    : `${RIVERSIDE_BASE_URL}/${normalized}`;
}

export class NotificationItem {
  public readonly id: number;
  public readonly kind: NotificationItemKind;
  public readonly title: string;
  public readonly excerpt: string;
  public readonly topicId: number;
  public readonly postId: number;
  public readonly postNumber: number;
  public readonly categoryId: number;
  public readonly highestPostNumber: number;
  public readonly createdAt: string;
  public readonly actorUsername: string;
  public readonly actorName: string;
  public readonly avatarUrl: string;
  public readonly flairUrl: string;
  public readonly reaction: string;

  public constructor(
    id: number,
    kind: NotificationItemKind,
    title: string,
    attributes: NotificationItemAttributes = {}
  ) {
    this.id = positiveInteger(id);
    this.kind = kind;
    this.title = visibleText(title);
    this.excerpt = visibleText(attributes.excerpt ?? '');
    this.topicId = positiveInteger(attributes.topicId);
    this.postId = positiveInteger(attributes.postId);
    this.postNumber = positiveInteger(attributes.postNumber);
    this.categoryId = positiveInteger(attributes.categoryId);
    this.highestPostNumber = positiveInteger(attributes.highestPostNumber);
    this.createdAt = (attributes.createdAt ?? '').trim();
    this.actorUsername = visibleText(attributes.actorUsername ?? '');
    this.actorName = visibleText(attributes.actorName ?? '');
    this.avatarUrl = absoluteNotificationUrl(attributes.avatarUrl ?? '');
    this.flairUrl = absoluteNotificationUrl(attributes.flairUrl ?? '');
    this.reaction = visibleText(attributes.reaction ?? '').replace(/:/g, '');
  }

  public static privateMessage(topic: Topic): NotificationItem {
    return new NotificationItem(topic.id, NotificationItemKind.PRIVATE_MESSAGE, topic.title, {
      excerpt: topic.excerpt,
      topicId: topic.id,
      categoryId: topic.categoryId,
      highestPostNumber: topic.postCount,
      createdAt: topic.lastPostedAt,
      actorUsername: topic.username
    });
  }

  public actorDisplayName(): string {
    if (this.actorUsername.length > 0) return this.actorUsername;
    if (this.actorName.length > 0) return this.actorName;
    return '有人';
  }
}

export function notificationActionText(bucket: NotificationBucket, item: NotificationItem): string {
  const actor: string = item.actorDisplayName();
  if (bucket === NotificationBucket.PRIVATE_MESSAGES) return `${actor} 发来私信`;
  if (bucket === NotificationBucket.REPLIES) return `${actor} 回复了`;
  if (bucket === NotificationBucket.MENTIONS) return `${actor} 提及了`;
  return `${actor} 回应了 ${item.reaction.length > 0 ? item.reaction : 'Reaction'}`;
}

function activityItem(reader: JsonObjectReader, reaction: string = ''): NotificationItem | null {
  const topicId: number | null = reader.number('topic_id') ?? reader.number('target_topic_id');
  const postNumber: number | null = reader.number('post_number') ?? reader.number('target_post_number');
  if (topicId === null || topicId <= 0 || postNumber === null || postNumber <= 0) return null;
  const postId: number = reader.number('post_id') ?? 0;
  const id: number = reader.number('id') ?? postId;
  return new NotificationItem(id, NotificationItemKind.ACTIVITY,
    reader.string('title') ?? reader.string('topic_title') ?? '', {
      excerpt: reader.string('excerpt') ?? reader.string('action_excerpt') ?? '',
      topicId: topicId,
      postId: postId,
      postNumber: postNumber,
      categoryId: reader.number('category_id') ?? 0,
      createdAt: reader.string('created_at') ?? '',
      actorUsername: reader.string('acting_username') ?? reader.string('username') ??
        reader.string('target_username') ?? '',
      actorName: reader.string('acting_name') ?? reader.string('name') ??
        reader.string('display_username') ?? '',
      avatarUrl: reader.string('acting_avatar_template') ?? reader.string('avatar_template') ??
        reader.string('user_avatar_template') ?? '',
      flairUrl: reader.string('acting_flair_url') ?? reader.string('flair_url') ?? '',
      reaction: reaction
    });
}

export function parseUserActivityItems(text: string, reaction: string = ''): Array<NotificationItem> | null {
  const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
  const values: Array<Object | null> | null = envelope?.array('user_actions') ?? null;
  if (envelope === null || values === null) return null;
  const items: Array<NotificationItem> = [];
  for (const value of values) {
    const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    const item: NotificationItem | null = reader === null ? null : activityItem(reader, reaction);
    if (item !== null) items.push(item);
  }
  return items;
}

function reactionItem(value: Object | null): NotificationItem | null {
  const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  const user: JsonObjectReader | null = reader?.object('user') ?? null;
  const post: JsonObjectReader | null = reader?.object('post') ?? null;
  const reaction: JsonObjectReader | null = reader?.object('reaction') ?? null;
  const topicId: number | null = post?.number('topic_id') ?? null;
  const postId: number | null = post?.number('id') ?? null;
  const postNumber: number | null = post?.number('post_number') ?? null;
  if (reader === null || user === null || post === null || reaction === null ||
    topicId === null || topicId <= 0 || postId === null || postId <= 0 ||
    postNumber === null || postNumber <= 0) {
    return null;
  }
  return new NotificationItem(postId, NotificationItemKind.ACTIVITY, post.string('topic_title') ?? '', {
    excerpt: post.string('excerpt') ?? '',
    topicId: topicId,
    postId: postId,
    postNumber: postNumber,
    categoryId: post.number('category_id') ?? 0,
    createdAt: reader.string('created_at') ?? '',
    actorUsername: user.string('username') ?? '',
    actorName: user.string('name') ?? '',
    avatarUrl: user.string('avatar_template') ?? '',
    flairUrl: user.string('flair_url') ?? '',
    reaction: reaction.string('reaction_value') ?? ''
  });
}

export function parseReactionReceivedItems(text: string): Array<NotificationItem> | null {
  try {
    const value: Object | null = ArkJSON.parse(text);
    if (!Array.isArray(value)) return null;
    const items: Array<NotificationItem> = [];
    for (const entry of Array.from<Object | null>(value)) {
      const item: NotificationItem | null = reactionItem(entry);
      if (item !== null) items.push(item);
    }
    return items;
  } catch (_) {
    return null;
  }
}

export function sortNotificationItemsNewestFirst(items: Array<NotificationItem>): Array<NotificationItem> {
  const sorted: Array<NotificationItem> = items.slice();
  sorted.sort((left: NotificationItem, right: NotificationItem): number => {
    return right.createdAt.localeCompare(left.createdAt);
  });
  return sorted;
}
