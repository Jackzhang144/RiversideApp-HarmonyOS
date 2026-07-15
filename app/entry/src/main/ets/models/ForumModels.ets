import { forumPostPlainText } from '../core/ForumPlainText';

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

export class PostReaction {
  public readonly id: string;
  public readonly count: number;

  public constructor(id: string, count: number) {
    this.id = id;
    this.count = Math.max(0, count);
  }
}

const POST_FLAG_TYPE_IDS: Array<number> = [3, 4, 6, 7, 8, 10];
const POST_FLAG_MESSAGE_TYPE_IDS: Array<number> = [6, 7, 10];

export class PostFlagRequest {
  public readonly postId: number;
  public readonly typeId: number;
  public readonly message: string | null;

  private constructor(postId: number, typeId: number, message: string | null) {
    this.postId = postId;
    this.typeId = typeId;
    this.message = message;
  }

  public static create(postId: number, typeId: number, message: string | null): PostFlagRequest | null {
    const normalizedMessage: string = message?.trim() ?? '';
    if (!Number.isSafeInteger(postId) || postId <= 0 || !POST_FLAG_TYPE_IDS.includes(typeId) ||
      (POST_FLAG_MESSAGE_TYPE_IDS.includes(typeId) && normalizedMessage.length === 0)) {
      return null;
    }
    return new PostFlagRequest(postId, typeId, normalizedMessage.length > 0 ? normalizedMessage : null);
  }

  public formBody(): string {
    const parts: Array<string> = [
      `id=${this.postId}`,
      `post_action_type_id=${this.typeId}`,
      'flag_topic=false'
    ];
    if (this.message !== null) {
      parts.push(`message=${encodeURIComponent(this.message)}`);
    }
    return parts.join('&');
  }
}

function absoluteForumAvatarUrl(value: string): string {
  const normalized: string = value.trim().replace('{size}', '64');
  if (normalized.length === 0 || normalized.startsWith('https://')) {
    return normalized;
  }
  if (normalized.startsWith('/')) {
    return `https://river-side.cc${normalized}`;
  }
  return '';
}

export class PostReactionUser {
  public readonly username: string;
  public readonly avatarUrl: string;

  public constructor(username: string, avatarUrl: string) {
    this.username = username.trim();
    this.avatarUrl = absoluteForumAvatarUrl(avatarUrl);
  }
}

export class PostReactionUsers {
  public readonly id: string;
  public readonly count: number;
  public readonly users: Array<PostReactionUser>;

  public constructor(id: string, count: number, users: Array<PostReactionUser>) {
    this.id = id.trim();
    this.count = Math.max(0, count);
    this.users = users;
  }
}

export class ForumPostMetadata {
  public readonly userTitle: string;
  public readonly avatarUrl: string;
  public readonly flairUrl: string;
  public readonly replyToUsername: string | null;
  public readonly replyToAvatarUrl: string | null;
  public readonly likeCount: number;
  public readonly reactions: Array<PostReaction>;
  public readonly currentUserReaction: string | null;
  public readonly canEdit: boolean;
  public readonly canDelete: boolean;
  public readonly acceptedAnswer: boolean;
  public readonly canAcceptAnswer: boolean;
  public readonly canUnacceptAnswer: boolean;
  public readonly bookmarked: boolean;
  public readonly bookmarkId: number | null;
  public readonly postType: number;
  public readonly actionCode: string;

  public constructor(
    userTitle: string = '',
    avatarUrl: string = '',
    flairUrl: string = '',
    replyToUsername: string | null = null,
    replyToAvatarUrl: string | null = null,
    likeCount: number = 0,
    reactions: Array<PostReaction> = [],
    currentUserReaction: string | null = null,
    canEdit: boolean = false,
    canDelete: boolean = false,
    acceptedAnswer: boolean = false,
    canAcceptAnswer: boolean = false,
    canUnacceptAnswer: boolean = false,
    bookmarked: boolean = false,
    bookmarkId: number | null = null,
    postType: number = 1,
    actionCode: string = ''
  ) {
    this.userTitle = userTitle;
    this.avatarUrl = avatarUrl;
    this.flairUrl = flairUrl;
    this.replyToUsername = replyToUsername;
    this.replyToAvatarUrl = replyToAvatarUrl;
    this.likeCount = Math.max(0, likeCount);
    this.reactions = reactions;
    this.currentUserReaction = currentUserReaction;
    this.canEdit = canEdit;
    this.canDelete = canDelete;
    this.acceptedAnswer = acceptedAnswer;
    this.canAcceptAnswer = canAcceptAnswer;
    this.canUnacceptAnswer = canUnacceptAnswer;
    this.bookmarked = bookmarked;
    this.bookmarkId = bookmarkId;
    this.postType = postType;
    this.actionCode = actionCode;
  }
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
  public readonly userTitle: string;
  public readonly avatarUrl: string;
  public readonly flairUrl: string;
  public readonly replyToUsername: string | null;
  public readonly replyToAvatarUrl: string | null;
  public readonly likeCount: number;
  public readonly reactions: Array<PostReaction>;
  public readonly currentUserReaction: string | null;
  public readonly canEdit: boolean;
  public readonly canDelete: boolean;
  public readonly acceptedAnswer: boolean;
  public readonly canAcceptAnswer: boolean;
  public readonly canUnacceptAnswer: boolean;
  public readonly bookmarked: boolean;
  public readonly bookmarkId: number | null;
  public readonly postType: number;
  public readonly actionCode: string;

  public constructor(
    id: number,
    userId: number,
    username: string,
    cooked: string,
    raw: string,
    postNumber: number,
    replyToPostNumber: number | null,
    createdAt: string,
    metadata: ForumPostMetadata = new ForumPostMetadata()
  ) {
    this.id = id;
    this.userId = userId;
    this.username = username;
    this.cooked = cooked;
    this.raw = raw;
    this.displayText = forumPostPlainText(raw, cooked);
    this.postNumber = postNumber;
    this.replyToPostNumber = replyToPostNumber;
    this.createdAt = createdAt;
    this.userTitle = metadata.userTitle;
    this.avatarUrl = metadata.avatarUrl;
    this.flairUrl = metadata.flairUrl;
    this.replyToUsername = metadata.replyToUsername;
    this.replyToAvatarUrl = metadata.replyToAvatarUrl;
    this.likeCount = metadata.likeCount;
    this.reactions = metadata.reactions;
    this.currentUserReaction = metadata.currentUserReaction;
    this.canEdit = metadata.canEdit;
    this.canDelete = metadata.canDelete;
    this.acceptedAnswer = metadata.acceptedAnswer;
    this.canAcceptAnswer = metadata.canAcceptAnswer;
    this.canUnacceptAnswer = metadata.canUnacceptAnswer;
    this.bookmarked = metadata.bookmarked;
    this.bookmarkId = metadata.bookmarkId;
    this.postType = metadata.postType;
    this.actionCode = metadata.actionCode;
  }

  public isSystemAction(): boolean {
    return this.postType === 3 && this.actionCode.length > 0;
  }

  public withBookmark(bookmarked: boolean, bookmarkId: number | null): ForumPost {
    return new ForumPost(
      this.id,
      this.userId,
      this.username,
      this.cooked,
      this.raw,
      this.postNumber,
      this.replyToPostNumber,
      this.createdAt,
      new ForumPostMetadata(
        this.userTitle,
        this.avatarUrl,
        this.flairUrl,
        this.replyToUsername,
        this.replyToAvatarUrl,
        this.likeCount,
        this.reactions,
        this.currentUserReaction,
        this.canEdit,
        this.canDelete,
        this.acceptedAnswer,
        this.canAcceptAnswer,
        this.canUnacceptAnswer,
        bookmarked,
        bookmarkId,
        this.postType,
        this.actionCode
      )
    );
  }

  public withAcceptedAnswer(acceptedAnswer: boolean): ForumPost {
    return new ForumPost(
      this.id,
      this.userId,
      this.username,
      this.cooked,
      this.raw,
      this.postNumber,
      this.replyToPostNumber,
      this.createdAt,
      new ForumPostMetadata(
        this.userTitle,
        this.avatarUrl,
        this.flairUrl,
        this.replyToUsername,
        this.replyToAvatarUrl,
        this.likeCount,
        this.reactions,
        this.currentUserReaction,
        this.canEdit,
        this.canDelete,
        acceptedAnswer,
        !acceptedAnswer,
        acceptedAnswer,
        this.bookmarked,
        this.bookmarkId,
        this.postType,
        this.actionCode
      )
    );
  }

  public withRawContent(raw: string): ForumPost {
    return new ForumPost(
      this.id,
      this.userId,
      this.username,
      '',
      raw,
      this.postNumber,
      this.replyToPostNumber,
      this.createdAt,
      new ForumPostMetadata(
        this.userTitle,
        this.avatarUrl,
        this.flairUrl,
        this.replyToUsername,
        this.replyToAvatarUrl,
        this.likeCount,
        this.reactions,
        this.currentUserReaction,
        this.canEdit,
        this.canDelete,
        this.acceptedAnswer,
        this.canAcceptAnswer,
        this.canUnacceptAnswer,
        this.bookmarked,
        this.bookmarkId,
        this.postType,
        this.actionCode
      )
    );
  }
}

export class TopicDetailMetadata {
  public readonly categoryId: number;
  public readonly canEdit: boolean;
  public readonly authorUsername: string;
  public readonly validReactions: Array<string>;
  public readonly suggestedTopics: Array<Topic>;
  public readonly lastReadPostNumber: number;

  public constructor(
    categoryId: number = 0,
    canEdit: boolean = false,
    authorUsername: string = '',
    validReactions: Array<string> = [],
    suggestedTopics: Array<Topic> = [],
    lastReadPostNumber: number = 0
  ) {
    this.categoryId = categoryId;
    this.canEdit = canEdit;
    this.authorUsername = authorUsername;
    this.validReactions = validReactions;
    this.suggestedTopics = suggestedTopics;
    this.lastReadPostNumber = Math.max(0, lastReadPostNumber);
  }
}

export class TopicPostBatch {
  public readonly posts: Array<ForumPost>;
  public readonly suggestedTopics: Array<Topic>;

  public constructor(posts: Array<ForumPost>, suggestedTopics: Array<Topic> = []) {
    this.posts = posts;
    this.suggestedTopics = suggestedTopics;
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
  public readonly highestPostNumber: number;
  public readonly categoryId: number;
  public readonly canEdit: boolean;
  public readonly authorUsername: string;
  public readonly validReactions: Array<string>;
  public readonly suggestedTopics: Array<Topic>;
  public readonly lastReadPostNumber: number;

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
    posts: Array<ForumPost>,
    highestPostNumber: number = 0,
    metadata: TopicDetailMetadata = new TopicDetailMetadata()
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
    this.categoryId = metadata.categoryId;
    this.canEdit = metadata.canEdit;
    this.authorUsername = metadata.authorUsername;
    this.validReactions = metadata.validReactions;
    this.suggestedTopics = metadata.suggestedTopics;
    this.lastReadPostNumber = metadata.lastReadPostNumber;
    let observedHighestPostNumber: number = Math.max(postCount, highestPostNumber);
    for (const post of posts) {
      observedHighestPostNumber = Math.max(observedHighestPostNumber, post.postNumber);
    }
    this.highestPostNumber = observedHighestPostNumber;
  }

  public withSuggestedTopics(suggestedTopics: Array<Topic>): TopicDetail {
    return new TopicDetail(
      this.id,
      this.title,
      this.viewCount,
      this.postCount,
      this.likeCount,
      this.closed,
      this.archived,
      this.canReply,
      this.postIds,
      this.posts,
      this.highestPostNumber,
      new TopicDetailMetadata(
        this.categoryId,
        this.canEdit,
        this.authorUsername,
        this.validReactions,
        suggestedTopics,
        this.lastReadPostNumber
      )
    );
  }

  public withTitleAndPosts(
    title: string,
    posts: Array<ForumPost>,
    categoryId: number = this.categoryId
  ): TopicDetail {
    return new TopicDetail(
      this.id,
      title,
      this.viewCount,
      this.postCount,
      this.likeCount,
      this.closed,
      this.archived,
      this.canReply,
      this.postIds,
      posts,
      this.highestPostNumber,
      new TopicDetailMetadata(
        categoryId,
        this.canEdit,
        this.authorUsername,
        this.validReactions,
        this.suggestedTopics,
        this.lastReadPostNumber
      )
    );
  }

  public withLastReadPostNumber(lastReadPostNumber: number): TopicDetail {
    return new TopicDetail(
      this.id,
      this.title,
      this.viewCount,
      this.postCount,
      this.likeCount,
      this.closed,
      this.archived,
      this.canReply,
      this.postIds,
      this.posts,
      this.highestPostNumber,
      new TopicDetailMetadata(
        this.categoryId,
        this.canEdit,
        this.authorUsername,
        this.validReactions,
        this.suggestedTopics,
        lastReadPostNumber
      )
    );
  }

  public withoutPost(postId: number): TopicDetail {
    const remainingPostIds: Array<number> = this.postIds.filter((candidateId: number): boolean => {
      return candidateId !== postId;
    });
    const remainingPosts: Array<ForumPost> = this.posts.filter((post: ForumPost): boolean => {
      return post.id !== postId;
    });
    const removed: boolean =
      remainingPostIds.length < this.postIds.length || remainingPosts.length < this.posts.length;
    return new TopicDetail(
      this.id,
      this.title,
      this.viewCount,
      removed ? Math.max(0, this.postCount - 1) : this.postCount,
      this.likeCount,
      this.closed,
      this.archived,
      this.canReply,
      remainingPostIds,
      remainingPosts,
      this.highestPostNumber,
      new TopicDetailMetadata(
        this.categoryId,
        this.canEdit,
        this.authorUsername,
        this.validReactions,
        this.suggestedTopics,
        this.lastReadPostNumber
      )
    );
  }
}
