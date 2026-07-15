import { Category, Topic } from './ForumModels';
import { forumPlainText, ForumPlainTextContext } from '../core/ForumPlainText';

const RIVERSIDE_ORIGIN: string = 'https://river-side.cc';

function onlineAvatarUrl(template: string): string {
  const normalizedTemplate: string = template.trim().replace('{size}', '96');
  if (normalizedTemplate.length === 0) {
    return '';
  }
  if (normalizedTemplate.startsWith('https://') || normalizedTemplate.startsWith('http://')) {
    return normalizedTemplate;
  }
  return `${RIVERSIDE_ORIGIN}${normalizedTemplate.startsWith('/') ? '' : '/'}${normalizedTemplate}`;
}

export class OnlineUser {
  public readonly id: number;
  public readonly username: string;
  public readonly name: string;
  public readonly avatarUrl: string;

  public constructor(id: number, username: string, name: string, avatarTemplate: string) {
    this.id = Number.isInteger(id) && id >= 0 ? id : 0;
    this.username = username.trim();
    this.name = name.trim();
    this.avatarUrl = onlineAvatarUrl(avatarTemplate);
  }

  public get displayName(): string {
    return this.name.length > 0 ? this.name : this.username;
  }
}

export class OnlineUsers {
  public readonly count: number;
  public readonly lastMessageId: number;
  public readonly users: Array<OnlineUser>;

  public constructor(count: number, lastMessageId: number, users: Array<OnlineUser>) {
    this.count = Number.isInteger(count) && count >= 0 ? count : users.length;
    this.lastMessageId = Number.isInteger(lastMessageId) && lastMessageId >= 0 ? lastMessageId : 0;
    this.users = users.slice();
  }
}

export enum HomeChannel {
  LATEST_REPLIES = 0,
  LATEST_CREATED = 1,
  UNREAD = 2,
  HOT = 3,
  FEATURED = 4
}

export function homeChannelFromIndex(index: number): HomeChannel | null {
  if (index === HomeChannel.LATEST_REPLIES) {
    return HomeChannel.LATEST_REPLIES;
  }
  if (index === HomeChannel.LATEST_CREATED) {
    return HomeChannel.LATEST_CREATED;
  }
  if (index === HomeChannel.UNREAD) {
    return HomeChannel.UNREAD;
  }
  if (index === HomeChannel.HOT) {
    return HomeChannel.HOT;
  }
  if (index === HomeChannel.FEATURED) {
    return HomeChannel.FEATURED;
  }
  return null;
}

export function homeChannelLabel(channel: HomeChannel): string {
  if (channel === HomeChannel.LATEST_CREATED) {
    return '最新发表';
  }
  if (channel === HomeChannel.UNREAD) {
    return '未读';
  }
  if (channel === HomeChannel.HOT) {
    return '热门';
  }
  if (channel === HomeChannel.FEATURED) {
    return '精华';
  }
  return '最新回复';
}

export function homeChannelPath(channel: HomeChannel, page: number): string {
  let path: string = '/latest.json';
  if (channel === HomeChannel.LATEST_CREATED) {
    path = '/latest.json?order=created';
  } else if (channel === HomeChannel.UNREAD) {
    path = '/new.json';
  } else if (channel === HomeChannel.HOT) {
    path = '/hot.json';
  } else if (channel === HomeChannel.FEATURED) {
    path = '/tag/2-tag/2.json';
  }
  if (page <= 0) {
    return path;
  }
  return `${path}${path.includes('?') ? '&' : '?'}page=${page}`;
}

export class SearchPost {
  public readonly id: number;
  public readonly topic: Topic;
  public readonly postNumber: number;
  public readonly username: string;
  public readonly displayText: string;
  public readonly createdAt: string;

  public constructor(
    id: number,
    topic: Topic,
    postNumber: number,
    username: string,
    blurb: string,
    createdAt: string
  ) {
    this.id = id;
    this.topic = topic;
    this.postNumber = postNumber;
    this.username = username.trim();
    this.displayText = forumPlainText(blurb, ForumPlainTextContext.DISCOVERY);
    this.createdAt = createdAt;
  }
}

export class SearchUser {
  public readonly id: number;
  public readonly username: string;
  public readonly name: string;
  public readonly avatarTemplate: string;

  public constructor(id: number, username: string, name: string, avatarTemplate: string) {
    this.id = id;
    this.username = username.trim();
    this.name = name.trim();
    this.avatarTemplate = avatarTemplate.trim();
  }

  public get displayName(): string {
    return this.name.length > 0 ? this.name : this.username;
  }
}

export class SearchTag {
  public readonly id: string;
  public readonly name: string;
  public readonly topicCount: number;

  public constructor(id: string, name: string, topicCount: number) {
    this.id = id.trim();
    this.name = name.trim();
    this.topicCount = Number.isInteger(topicCount) && topicCount >= 0 ? topicCount : 0;
  }
}

export class SearchGroup {
  public readonly id: number;
  public readonly name: string;
  public readonly fullName: string;
  public readonly userCount: number;

  public constructor(id: number, name: string, fullName: string, userCount: number) {
    this.id = id;
    this.name = name.trim();
    this.fullName = fullName.trim();
    this.userCount = Number.isInteger(userCount) && userCount >= 0 ? userCount : 0;
  }
}

export class ForumSearchResult {
  public readonly topics: Array<Topic>;
  public readonly posts: Array<SearchPost>;
  public readonly users: Array<SearchUser>;
  public readonly categories: Array<Category>;
  public readonly tags: Array<SearchTag>;
  public readonly groups: Array<SearchGroup>;
  public readonly hasMore: boolean;

  public constructor(
    topics: Array<Topic>,
    posts: Array<SearchPost>,
    users: Array<SearchUser>,
    categories: Array<Category>,
    tags: Array<SearchTag>,
    groups: Array<SearchGroup>,
    hasMore: boolean
  ) {
    this.topics = topics;
    this.posts = posts;
    this.users = users;
    this.categories = categories;
    this.tags = tags;
    this.groups = groups;
    this.hasMore = hasMore;
  }

  public isEmpty(): boolean {
    return this.topics.length === 0 && this.posts.length === 0 && this.users.length === 0 &&
      this.categories.length === 0 && this.tags.length === 0 && this.groups.length === 0;
  }
}
