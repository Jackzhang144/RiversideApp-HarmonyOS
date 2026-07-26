import {
  Category,
  ForumPost,
  PostReaction,
  TopicNotificationLevel
} from '../models/ForumModels';
import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';

export class PostFlagOption {
  public readonly typeId: number;
  public readonly label: string;
  public readonly description: string;
  public readonly needsMessage: boolean;

  public constructor(typeId: number, label: string, description: string, needsMessage: boolean) {
    this.typeId = typeId;
    this.label = label;
    this.description = description;
    this.needsMessage = needsMessage;
  }
}

export class TopicNotificationOption {
  public readonly level: TopicNotificationLevel;
  public readonly label: string;
  public readonly description: string;

  public constructor(level: TopicNotificationLevel, label: string, description: string) {
    this.level = level;
    this.label = label;
    this.description = description;
  }
}

export function topicNotificationOptions(): Array<TopicNotificationOption> {
  return [
    new TopicNotificationOption(
      TopicNotificationLevel.WATCHING,
      '关注',
      '每条新 Reply 都会通知，并显示新回复数量。'
    ),
    new TopicNotificationOption(
      TopicNotificationLevel.TRACKING,
      '跟踪',
      '提及或回复您时通知，并显示新回复数量。'
    ),
    new TopicNotificationOption(
      TopicNotificationLevel.REGULAR,
      '常规',
      '仅在别人提及或回复您时通知。'
    ),
    new TopicNotificationOption(
      TopicNotificationLevel.MUTED,
      '免打扰',
      '不接收这个 Topic 的任何通知。'
    )
  ];
}

export function topicNotificationLabel(level: TopicNotificationLevel): string {
  for (const option of topicNotificationOptions()) {
    if (option.level === level) {
      return option.label;
    }
  }
  return '常规';
}

export function postFlagOptions(username: string): Array<PostFlagOption> {
  const normalizedUsername: string = username.trim();
  return [
    new PostFlagOption(
      6,
      `向 @${normalizedUsername} 发送消息`,
      '我想亲自与此人私下交流关于其帖子的事情。',
      true
    ),
    new PostFlagOption(3, '偏离话题', '此帖子与当前讨论无关，可能应该移到其他地方。', false),
    new PostFlagOption(4, '不当言论', '该帖子包含冒犯性、侮辱性内容，或违反社区准则。', false),
    new PostFlagOption(8, '垃圾信息', '此帖子是广告或蓄意破坏讨论，与当前话题无关。', false),
    new PostFlagOption(10, '非法', '此帖子包含需要工作人员注意的非法内容。', true),
    new PostFlagOption(7, '其他内容', '由于上面未列出的原因，此帖子需要管理人员注意。', true)
  ];
}

export function normalizeTopicFloor(value: string, highestPostNumber: number): number | null {
  const normalized: string = value.trim();
  if (normalized.length === 0 || !Number.isSafeInteger(highestPostNumber) || highestPostNumber <= 0) {
    return null;
  }
  const parsed: number = Number(normalized);
  if (!Number.isFinite(parsed)) {
    return null;
  }
  return Math.min(highestPostNumber, Math.max(1, Math.floor(parsed)));
}

export function topicPostUrl(topicId: number, postNumber: number): string {
  return RIVERSIDE_URL_RESOLVER.topicPost(topicId, postNumber);
}

export function topicPostListIndex(posts: Array<ForumPost>, postNumber: number): number {
  if (!Number.isSafeInteger(postNumber) || postNumber <= 0) {
    return -1;
  }
  const stateIndex: number = posts.findIndex(
    (post: ForumPost): boolean => post.postNumber === postNumber
  );
  if (stateIndex < 0) {
    return -1;
  }
  const hasStarterPost: boolean = posts[0]?.postNumber === 1;
  if (hasStarterPost && stateIndex === 0) {
    return 0;
  }
  return hasStarterPost ? stateIndex + 5 : stateIndex + 6;
}

/**
 * Makes ArkUI recreate a Post card when information visible in the card changes.
 * A Post id alone is not sufficient here: reactions, bookmarks and edits retain
 * the same id after the server confirms an operation.
 */
export function topicPostRenderKey(post: ForumPost): string {
  const reactions: string = post.reactions
    .map((reaction: PostReaction): string => `${reaction.id}:${reaction.count}`)
    .join(',');
  return [
    post.id.toString(),
    post.cooked,
    post.raw,
    post.likeCount.toString(),
    reactions,
    post.currentUserReaction ?? '',
    post.bookmarked ? '1' : '0',
    post.acceptedAnswer ? '1' : '0',
    post.canEdit ? '1' : '0',
    post.canDelete ? '1' : '0'
  ].join('|');
}

export function shouldShowSuggestedTopics(hasNextPosts: boolean, suggestionCount: number): boolean {
  return !hasNextPosts && Number.isInteger(suggestionCount) && suggestionCount > 0;
}

export function systemActionLabel(actionCode: string): string {
  if (actionCode === 'closed.enabled') {
    return '关闭了 Topic';
  }
  if (actionCode === 'closed.disabled') {
    return '重新开放了 Topic';
  }
  if (actionCode === 'pinned_globally.enabled') {
    return '将 Topic 设为全站置顶';
  }
  if (actionCode === 'pinned.enabled') {
    return '置顶了 Topic';
  }
  if (actionCode === 'pinned.disabled') {
    return '取消了 Topic 置顶';
  }
  if (actionCode === 'archived.enabled') {
    return '归档了 Topic';
  }
  if (actionCode === 'archived.disabled') {
    return '取消了 Topic 归档';
  }
  if (actionCode === 'visible.disabled') {
    return '将 Topic 设为不公开';
  }
  if (actionCode === 'visible.enabled') {
    return '将 Topic 设为公开';
  }
  return '更新了 Topic 状态';
}

export function categoryLabel(categoryId: number, categories: Array<Category>): string {
  for (const category of categories) {
    if (category.id === categoryId) {
      return category.name;
    }
  }
  return categoryId > 0 ? `Category #${categoryId}` : 'Category';
}

export function reactionCount(reactionId: string, reactions: Array<PostReaction>): number {
  for (const reaction of reactions) {
    if (reaction.id === reactionId) {
      return reaction.count;
    }
  }
  return 0;
}

export function displayedReactions(reactions: Array<PostReaction>): Array<PostReaction> {
  const displayed: Array<PostReaction> = [];
  for (const reaction of reactions) {
    if (reaction.count > 0 && reactionEmojiKey(reaction.id) !== '+1') {
      displayed.push(reaction);
    }
  }
  return displayed;
}

export function selectedBookmarkPostIds(posts: Array<ForumPost>): Array<number> {
  return posts
    .filter((post: ForumPost): boolean => post.bookmarked)
    .map((post: ForumPost): number => post.id);
}

export function reactionEmojiKey(value: string): string {
  return value
    .replace('reaction.', '')
    .replace('emoji.', '')
    .replaceAll(':', '')
    .trim()
    .toLowerCase();
}

export function reactionEmojiUrl(reactionId: string): string {
  return RIVERSIDE_URL_RESOLVER.reactionEmoji(reactionEmojiKey(reactionId));
}

export function reactionAccessibilityLabel(reactionId: string): string {
  const normalized: string = reactionEmojiKey(reactionId);
  if (normalized === '+1') {
    return '赞同';
  }
  if (normalized === '-1') {
    return '不赞同';
  }
  if (normalized === 'laughing') {
    return '大笑';
  }
  if (normalized === 'heart') {
    return '喜欢';
  }
  if (normalized === 'open_mouth') {
    return '惊讶';
  }
  if (normalized === 'thinking') {
    return '思考';
  }
  if (normalized === 'anxious_face_with_sweat') {
    return '紧张';
  }
  if (normalized === 'distorted_face') {
    return '眩晕';
  }
  if (normalized === 'saluting_face') {
    return '敬礼';
  }
  if (normalized === 'sob') {
    return '难过';
  }
  return '回应';
}
