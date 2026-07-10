export class Topic {
  public readonly id: number;
  public readonly title: string;
  public readonly categoryId: number;
  public readonly postCount: number;
  public readonly viewCount: number;
  public readonly likeCount: number;
  public readonly excerpt: string;
  public readonly lastPostedAt: string;
  public readonly pinned: boolean;
  public readonly username: string;

  public constructor(
    id: number,
    title: string,
    categoryId: number,
    postCount: number,
    viewCount: number,
    likeCount: number,
    excerpt: string,
    lastPostedAt: string,
    pinned: boolean,
    username: string
  ) {
    this.id = id;
    this.title = title;
    this.categoryId = categoryId;
    this.postCount = postCount;
    this.viewCount = viewCount;
    this.likeCount = likeCount;
    this.excerpt = excerpt;
    this.lastPostedAt = lastPostedAt;
    this.pinned = pinned;
    this.username = username;
  }
}

export class Category {
  public readonly id: number;
  public readonly name: string;
  public readonly color: string;
  public readonly description: string;
  public readonly position: number;
  public readonly parentCategoryId: number | null;
  public readonly subcategoryIds: Array<number>;

  public constructor(
    id: number,
    name: string,
    color: string,
    description: string,
    position: number,
    parentCategoryId: number | null,
    subcategoryIds: Array<number>
  ) {
    this.id = id;
    this.name = name;
    this.color = color;
    this.description = description;
    this.position = position;
    this.parentCategoryId = parentCategoryId;
    this.subcategoryIds = subcategoryIds;
  }
}

function readablePostText(raw: string, cooked: string): string {
  const source: string = cooked.trim();
  if (source.length === 0) {
    return raw.trim();
  }
  return source
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<li[^>]*>/gi, '• ')
    .replace(/<\/(p|div|h[1-6]|li|blockquote)>/gi, '\n')
    .replace(/<[^>]+>/g, '')
    .replace(/&nbsp;/gi, ' ')
    .replace(/&amp;/gi, '&')
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&quot;/gi, '"')
    .replace(/&#39;/gi, "'")
    .replace(/\n[ \t]+/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

export class ForumPost {
  public readonly id: number;
  public readonly userId: number;
  public readonly username: string;
  public readonly cooked: string;
  public readonly raw: string;
  public readonly displayText: string;
  public readonly postNumber: number;
  public readonly replyToPostNumber: number | null;
  public readonly createdAt: string;

  public constructor(
    id: number,
    userId: number,
    username: string,
    cooked: string,
    raw: string,
    postNumber: number,
    replyToPostNumber: number | null,
    createdAt: string
  ) {
    this.id = id;
    this.userId = userId;
    this.username = username;
    this.cooked = cooked;
    this.raw = raw;
    this.displayText = readablePostText(raw, cooked);
    this.postNumber = postNumber;
    this.replyToPostNumber = replyToPostNumber;
    this.createdAt = createdAt;
  }
}

export class TopicDetail {
  public readonly id: number;
  public readonly title: string;
  public readonly viewCount: number;
  public readonly postCount: number;
  public readonly likeCount: number;
  public readonly closed: boolean;
  public readonly archived: boolean;
  public readonly canReply: boolean;
  public readonly postIds: Array<number>;
  public readonly posts: Array<ForumPost>;

  public constructor(
    id: number,
    title: string,
    viewCount: number,
    postCount: number,
    likeCount: number,
    closed: boolean,
    archived: boolean,
    canReply: boolean,
    postIds: Array<number>,
    posts: Array<ForumPost>
  ) {
    this.id = id;
    this.title = title;
    this.viewCount = viewCount;
    this.postCount = postCount;
    this.likeCount = likeCount;
    this.closed = closed;
    this.archived = archived;
    this.canReply = !closed && !archived && canReply;
    this.postIds = postIds;
    this.posts = posts;
  }
}
