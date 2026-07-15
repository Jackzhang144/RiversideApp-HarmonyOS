import { Category, ForumPost, PostReaction } from '../models/ForumModels';

const REACTION_EMOJI_BASE_URL: string = 'https://river-side.cc/images/emoji/twitter';
const RIVERSIDE_ORIGIN: string = 'https://river-side.cc';

export function topicPostUrl(topicId: number, postNumber: number): string {
  if (!Number.isInteger(topicId) || topicId <= 0 || !Number.isInteger(postNumber) || postNumber <= 0) {
    return '';
  }
  return `${RIVERSIDE_ORIGIN}/t/${topicId}/${postNumber}`;
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
    if (reaction.count > 0) {
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
  return `${REACTION_EMOJI_BASE_URL}/${reactionEmojiKey(reactionId)}.png?v=15`;
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
