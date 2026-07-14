import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';

export enum ForumCardMode {
  TOPIC_PREVIEW = 'topic-preview',
  TOPIC_STARTER = 'topic-starter',
  REPLY = 'reply'
}

export enum ForumCardBadgeKind {
  PINNED = 'pinned',
  CATEGORY = 'category',
  FLOOR = 'floor'
}

export enum ForumCardStatisticKind {
  REPLIES = 'replies',
  VIEWS = 'views',
  LIKES = 'likes'
}

export class ForumCardAuthor {
  public readonly name: string;
  public readonly initial: string;
  public readonly timestamp: string;

  public constructor(name: string, initial: string, timestamp: string) {
    this.name = name;
    this.initial = initial;
    this.timestamp = timestamp;
  }
}

export class ForumCardBadge {
  public readonly kind: ForumCardBadgeKind;
  public readonly label: string;

  public constructor(kind: ForumCardBadgeKind, label: string) {
    this.kind = kind;
    this.label = label;
  }
}

export class ForumCardStatistic {
  public readonly kind: ForumCardStatisticKind;
  public readonly value: number;

  public constructor(kind: ForumCardStatisticKind, value: number) {
    this.kind = kind;
    this.value = value;
  }
}

export class ForumCardReplyAction {
  public readonly label: string;
  public readonly targetPostNumber: number | null;
  public readonly accessibilityText: string;

  public constructor(label: string, targetPostNumber: number | null, accessibilityText: string) {
    this.label = label;
    this.targetPostNumber = targetPostNumber;
    this.accessibilityText = accessibilityText;
  }
}

function displayAuthor(username: string): ForumCardAuthor {
  const name: string = username.trim().length > 0 ? username : '匿名';
  const initial: string = name === '匿名' ? '匿' : name.slice(0, 1).toUpperCase();
  return new ForumCardAuthor(name, initial, '');
}

function displayTimestamp(timestamp: string): string {
  const normalized: string = timestamp.trim();
  if (normalized.length >= 16 && normalized.includes('T')) {
    return normalized.slice(0, 16).replace('T', ' ');
  }
  return normalized.length > 0 ? normalized : '时间未知';
}

function topicCategoryName(topic: Topic, categories: Array<Category>): string {
  for (const category of categories) {
    if (category.id === topic.categoryId) {
      return category.name;
    }
  }
  return topic.categoryId > 0 ? `Category #${topic.categoryId}` : 'Category';
}

function postAuthor(post: ForumPost): ForumCardAuthor {
  const authorBase: ForumCardAuthor = displayAuthor(post.username);
  const displayName: string = post.userTitle.trim().length > 0
    ? `${authorBase.name} · ${post.userTitle.trim()}`
    : authorBase.name;
  return new ForumCardAuthor(displayName, authorBase.initial, displayTimestamp(post.createdAt));
}

function topicReplyRestriction(detail: TopicDetail): string {
  if (detail.archived) {
    return '此 Topic 已归档，不可 Reply';
  }
  if (detail.closed) {
    return '此 Topic 已关闭，不可 Reply';
  }
  return detail.canReply ? '' : '当前会话不可 Reply';
}

export class ForumCardPresentation {
  public readonly mode: ForumCardMode;
  public readonly author: ForumCardAuthor | null;
  public readonly title: string;
  public readonly body: string;
  public readonly headerBadge: ForumCardBadge | null;
  public readonly footerBadge: ForumCardBadge | null;
  public readonly statistics: Array<ForumCardStatistic>;
  public readonly replyAction: ForumCardReplyAction | null;
  public readonly restrictionText: string;
  public readonly accessibilityText: string;

  private constructor(
    mode: ForumCardMode,
    author: ForumCardAuthor | null,
    title: string,
    body: string,
    headerBadge: ForumCardBadge | null,
    footerBadge: ForumCardBadge | null,
    statistics: Array<ForumCardStatistic>,
    replyAction: ForumCardReplyAction | null,
    restrictionText: string,
    accessibilityText: string
  ) {
    this.mode = mode;
    this.author = author;
    this.title = title;
    this.body = body;
    this.headerBadge = headerBadge;
    this.footerBadge = footerBadge;
    this.statistics = statistics;
    this.replyAction = replyAction;
    this.restrictionText = restrictionText;
    this.accessibilityText = accessibilityText;
  }

  public static topicPreview(topic: Topic, categories: Array<Category>): ForumCardPresentation {
    const categoryName: string = topicCategoryName(topic, categories);
    const authorBase: ForumCardAuthor = displayAuthor(topic.username);
    const author: ForumCardAuthor = new ForumCardAuthor(
      authorBase.name,
      authorBase.initial,
      displayTimestamp(topic.lastPostedAt)
    );
    const replyCount: number = Math.max(topic.postCount - 1, 0);
    const pinnedDescription: string = topic.pinned ? '，置顶' : '';
    return new ForumCardPresentation(
      ForumCardMode.TOPIC_PREVIEW,
      author,
      topic.title,
      topic.excerpt,
      topic.pinned ? new ForumCardBadge(ForumCardBadgeKind.PINNED, '置顶') : null,
      new ForumCardBadge(ForumCardBadgeKind.CATEGORY, categoryName),
      [
        new ForumCardStatistic(ForumCardStatisticKind.REPLIES, replyCount),
        new ForumCardStatistic(ForumCardStatisticKind.VIEWS, topic.viewCount)
      ],
      null,
      '',
      `${topic.title}，作者 ${author.name}，${categoryName}${pinnedDescription}，` +
        `${replyCount} 条 Reply，${topic.viewCount} 浏览`
    );
  }

  public static topicStarter(
    detail: TopicDetail,
    post: ForumPost | null,
    replyDraft: string
  ): ForumCardPresentation {
    let author: ForumCardAuthor | null = null;
    const replyCount: number = Math.max(detail.postCount - 1, 0);
    const restrictionText: string = topicReplyRestriction(detail);
    const replyAction: ForumCardReplyAction | null = restrictionText.length === 0
      ? new ForumCardReplyAction(
        replyDraft.trim().length > 0 ? '继续 Reply' : 'Reply',
        null,
        '回复当前 Topic'
      )
      : null;
    const restrictionDescription: string = restrictionText.length > 0 ? `，${restrictionText}` : '';
    let accessibilityText: string = `${detail.title}，${replyCount} 条 Reply，${detail.viewCount} 浏览，` +
      `${detail.likeCount} 赞${restrictionDescription}`;
    if (post !== null) {
      const starterAuthor: ForumCardAuthor = postAuthor(post);
      author = starterAuthor;
      accessibilityText = `${detail.title}，${starterAuthor.name} 的第 ${post.postNumber} 条 Post，` +
        `${replyCount} 条 Reply，${detail.viewCount} 浏览，${detail.likeCount} 赞${restrictionDescription}`;
    }
    return new ForumCardPresentation(
      ForumCardMode.TOPIC_STARTER,
      author,
      detail.title,
      post?.displayText ?? '',
      post === null ? null : new ForumCardBadge(ForumCardBadgeKind.FLOOR, `#${post.postNumber}`),
      null,
      [
        new ForumCardStatistic(ForumCardStatisticKind.REPLIES, replyCount),
        new ForumCardStatistic(ForumCardStatisticKind.VIEWS, detail.viewCount),
        new ForumCardStatistic(ForumCardStatisticKind.LIKES, detail.likeCount)
      ],
      replyAction,
      restrictionText,
      accessibilityText
    );
  }

  public static reply(post: ForumPost, canReply: boolean): ForumCardPresentation {
    const author: ForumCardAuthor = postAuthor(post);
    const replyAction: ForumCardReplyAction | null = canReply
      ? new ForumCardReplyAction('Reply', post.postNumber, `回复第 ${post.postNumber} 条 Post`)
      : null;
    const replyContext: string = post.replyToPostNumber === null
      ? ''
      : `，回复第 ${post.replyToPostNumber} 条 Post`;
    return new ForumCardPresentation(
      ForumCardMode.REPLY,
      author,
      '',
      post.displayText,
      new ForumCardBadge(ForumCardBadgeKind.FLOOR, `#${post.postNumber}`),
      null,
      [],
      replyAction,
      '',
      `${author.name} 的第 ${post.postNumber} 条 Post${replyContext}`
    );
  }
}
