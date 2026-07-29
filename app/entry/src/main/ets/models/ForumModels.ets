import { forumPostPlainText } from '../core/ForumPlainText';
import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';
import {
  absoluteDiscourseFlairUrl,
  normalizedDiscourseFlairColor
} from '../core/DiscourseFlair';
import { DiscourseUserStatus } from './DiscourseUserStatus';
import { ForumPoll } from './PollModels';

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
  public readonly avatarUrl: string;

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
    username: string,
    avatarUrl: string = ''
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
    this.avatarUrl = absoluteForumAvatarUrl(avatarUrl);
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

export enum TopicNotificationLevel {
  MUTED = 0,
  REGULAR = 1,
  TRACKING = 2,
  WATCHING = 3
}

export function topicNotificationLevelFromId(value: number | null): TopicNotificationLevel {
  if (value === TopicNotificationLevel.MUTED) {
    return TopicNotificationLevel.MUTED;
  }
  if (value === TopicNotificationLevel.TRACKING) {
    return TopicNotificationLevel.TRACKING;
  }
  if (value === TopicNotificationLevel.WATCHING) {
    return TopicNotificationLevel.WATCHING;
  }
  return TopicNotificationLevel.REGULAR;
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
  return RIVERSIDE_URL_RESOLVER.avatar(value, 64, false, true);
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
  public readonly replyCount: number;
  public readonly flairName: string;
  public readonly flairBackgroundColor: string;
  public readonly flairColor: string;
  public readonly userStatus: DiscourseUserStatus | null;
  public readonly polls: Array<ForumPoll>;

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
    actionCode: string = '',
    replyCount: number = 0,
    flairName: string = '',
    flairBackgroundColor: string = '',
    flairColor: string = '',
    userStatus: DiscourseUserStatus | null = null,
    polls: Array<ForumPoll> = []
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
    this.replyCount = Math.max(0, replyCount);
    this.flairName = flairName.trim();
    this.flairBackgroundColor = normalizedDiscourseFlairColor(flairBackgroundColor);
    this.flairColor = normalizedDiscourseFlairColor(flairColor);
    this.userStatus = userStatus;
    this.polls = polls;
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
  public readonly replyCount: number;
  public readonly flairName: string;
  public readonly flairBackgroundColor: string;
  public readonly flairColor: string;
  public readonly userStatus: DiscourseUserStatus | null;
  public readonly polls: Array<ForumPoll>;

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
    this.avatarUrl = absoluteForumAvatarUrl(metadata.avatarUrl);
    this.flairUrl = absoluteDiscourseFlairUrl(metadata.flairUrl);
    this.replyToUsername = metadata.replyToUsername;
    this.replyToAvatarUrl = metadata.replyToAvatarUrl === null
      ? null
      : absoluteForumAvatarUrl(metadata.replyToAvatarUrl);
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
    this.replyCount = metadata.replyCount;
    this.flairName = metadata.flairName;
    this.flairBackgroundColor = metadata.flairBackgroundColor;
    this.flairColor = metadata.flairColor;
    this.userStatus = metadata.userStatus;
    this.polls = metadata.polls;
  }

  public isSystemAction(): boolean {
    return this.postType === 3 && this.actionCode.length > 0;
  }

  public withToggledReaction(reactionId: string): ForumPost {
    const normalizedReaction: string = reactionId.trim();
    if (normalizedReaction.length === 0) {
      return this;
    }
    const previousReaction: string = this.currentUserReaction?.trim() ?? '';
    const nextReaction: string = previousReaction === normalizedReaction ? '' : normalizedReaction;
    const updatedReactions: Array<PostReaction> = [];
    let nextReactionFound: boolean = false;
    for (const reaction of this.reactions) {
      let count: number = reaction.count;
      if (reaction.id === previousReaction) {
        count -= 1;
      }
      if (reaction.id === nextReaction) {
        count += 1;
        nextReactionFound = true;
      }
      if (count > 0) {
        updatedReactions.push(new PostReaction(reaction.id, count));
      }
    }
    if (nextReaction.length > 0 && !nextReactionFound) {
      updatedReactions.push(new PostReaction(nextReaction, 1));
    }
    let updatedLikeCount: number = 0;
    for (const reaction of updatedReactions) {
      updatedLikeCount += reaction.count;
    }
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
        updatedLikeCount,
        updatedReactions,
        nextReaction.length > 0 ? nextReaction : null,
        this.canEdit,
        this.canDelete,
        this.acceptedAnswer,
        this.canAcceptAnswer,
        this.canUnacceptAnswer,
        this.bookmarked,
        this.bookmarkId,
        this.postType,
        this.actionCode,
        this.replyCount,
        this.flairName,
        this.flairBackgroundColor,
        this.flairColor,
        this.userStatus,
        this.polls
      )
    );
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
        this.actionCode,
        this.replyCount,
        this.flairName,
        this.flairBackgroundColor,
        this.flairColor,
        this.userStatus,
        this.polls
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
        this.actionCode,
        this.replyCount,
        this.flairName,
        this.flairBackgroundColor,
        this.flairColor,
        this.userStatus,
        this.polls
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
        this.actionCode,
        this.replyCount,
        this.flairName,
        this.flairBackgroundColor,
        this.flairColor,
        this.userStatus,
        this.polls
      )
    );
  }

  public withPoll(updatedPoll: ForumPoll): ForumPost {
    const updatedPolls: Array<ForumPoll> = this.polls.map((poll: ForumPoll): ForumPoll => {
      return poll.name === updatedPoll.name ? updatedPoll : poll;
    });
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
        this.bookmarked,
        this.bookmarkId,
        this.postType,
        this.actionCode,
        this.replyCount,
        this.flairName,
        this.flairBackgroundColor,
        this.flairColor,
        this.userStatus,
        updatedPolls
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
  public readonly notificationLevel: TopicNotificationLevel;
  public readonly notificationReasonId: number | null;
  public readonly messageBusLastId: number;

  public constructor(
    categoryId: number = 0,
    canEdit: boolean = false,
    authorUsername: string = '',
    validReactions: Array<string> = [],
    suggestedTopics: Array<Topic> = [],
    lastReadPostNumber: number = 0,
    notificationLevel: TopicNotificationLevel = TopicNotificationLevel.REGULAR,
    notificationReasonId: number | null = null,
    messageBusLastId: number = -1
  ) {
    this.categoryId = categoryId;
    this.canEdit = canEdit;
    this.authorUsername = authorUsername;
    this.validReactions = validReactions;
    this.suggestedTopics = suggestedTopics;
    this.lastReadPostNumber = Math.max(0, lastReadPostNumber);
    this.notificationLevel = notificationLevel;
    this.notificationReasonId = notificationReasonId;
    this.messageBusLastId = Number.isSafeInteger(messageBusLastId) ? messageBusLastId : -1;
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
  public readonly notificationLevel: TopicNotificationLevel;
  public readonly notificationReasonId: number | null;
  public readonly messageBusLastId: number;

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
    this.notificationLevel = metadata.notificationLevel;
    this.notificationReasonId = metadata.notificationReasonId;
    this.messageBusLastId = metadata.messageBusLastId;
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
        this.lastReadPostNumber,
        this.notificationLevel,
        this.notificationReasonId,
        this.messageBusLastId
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
        this.lastReadPostNumber,
        this.notificationLevel,
        this.notificationReasonId,
        this.messageBusLastId
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
        lastReadPostNumber,
        this.notificationLevel,
        this.notificationReasonId,
        this.messageBusLastId
      )
    );
  }

  public withNotificationLevel(notificationLevel: TopicNotificationLevel): TopicDetail {
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
        this.lastReadPostNumber,
        notificationLevel,
        null,
        this.messageBusLastId
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
        this.lastReadPostNumber,
        this.notificationLevel,
        this.notificationReasonId,
        this.messageBusLastId
      )
    );
  }

  public withMergedPosts(updatedPosts: Array<ForumPost>): TopicDetail {
    const mergedPosts: Array<ForumPost> = this.posts.slice();
    const mergedPostIds: Array<number> = this.postIds.slice();
    for (const updatedPost of updatedPosts) {
      const existingIndex: number = mergedPosts.findIndex((post: ForumPost): boolean => {
        return post.id === updatedPost.id;
      });
      if (existingIndex >= 0) {
        mergedPosts[existingIndex] = updatedPost;
      } else {
        mergedPosts.push(updatedPost);
      }
      if (!mergedPostIds.includes(updatedPost.id)) {
        mergedPostIds.push(updatedPost.id);
      }
    }
    mergedPosts.sort((left: ForumPost, right: ForumPost): number => {
      return left.postNumber - right.postNumber;
    });
    let highestPostNumber: number = this.highestPostNumber;
    for (const post of updatedPosts) {
      highestPostNumber = Math.max(highestPostNumber, post.postNumber);
    }
    return new TopicDetail(
      this.id,
      this.title,
      this.viewCount,
      Math.max(this.postCount, highestPostNumber),
      this.likeCount,
      this.closed,
      this.archived,
      this.canReply,
      mergedPostIds,
      mergedPosts,
      highestPostNumber,
      new TopicDetailMetadata(
        this.categoryId,
        this.canEdit,
        this.authorUsername,
        this.validReactions,
        this.suggestedTopics,
        this.lastReadPostNumber,
        this.notificationLevel,
        this.notificationReasonId,
        this.messageBusLastId
      )
    );
  }
}
