import { AppShellModel } from '../../../../main/ets/app/AppShellModel';
import {
  ReplyComposerState,
  ReplyComposerStateKind,
  TopicComposerStateKind
} from '../../../../main/ets/app/ComposerModels';
import { TopicReadStateKind } from '../../../../main/ets/app/TopicReadingModels';
import { BrowseStateKind } from '../../../../main/ets/app/BrowseModels';
import { AuthenticationLifecycle } from '../../../../main/ets/app/AuthenticationLifecycle';
import {
  RootDestination,
  SecondaryDestination
} from '../../../../main/ets/app/ShellNavigationModels';
import { CategoryCacheScope } from '../../../../main/ets/cache/CategoryCache';
import { RepositoryResult } from '../../../../main/ets/core/RepositoryResult';
import {
  Category,
  ForumPost,
  ForumPostMetadata,
  PostFlagRequest,
  PostReaction,
  PostReactionUser,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicDetailMetadata,
  TopicNotificationLevel,
  TopicPostBatch
} from '../../../../main/ets/models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../../../../main/ets/models/DiscoveryModels';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitResult
} from '../../../../main/ets/models/AuthoringModels';
import {
  CurrentUser,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitResult
} from '../../../../main/ets/models/ReplyModels';
import { ForumRepository } from '../../../../main/ets/repositories/ForumRepository';
import { MemoryCategoryCache } from './MemoryCategoryCache';

export class PendingRepositoryResult<T> {
  public readonly promise: Promise<RepositoryResult<T>>;
  private resolver: ((result: RepositoryResult<T>) => void) | null = null;

  public constructor() {
    this.promise = new Promise<RepositoryResult<T>>((resolve: (result: RepositoryResult<T>) => void): void => {
      this.resolver = resolve;
    });
  }

  public complete(result: RepositoryResult<T>): void {
    const resolve: ((result: RepositoryResult<T>) => void) | null = this.resolver;
    if (resolve === null) {
      return;
    }
    this.resolver = null;
    resolve(result);
  }
}

export class TopicReadingRepository implements ForumRepository {
  public topicDetailResults: Array<RepositoryResult<TopicDetail>> = [];
  public topicPostResults: Array<RepositoryResult<TopicPostBatch>> = [];
  public topicPostTasks: Array<Promise<RepositoryResult<TopicPostBatch>>> = [];
  public topicSuggestionResults: Array<RepositoryResult<Array<Topic>>> = [];
  public topicNotificationResults: Array<RepositoryResult<boolean>> = [];
  public reactionResults: Array<RepositoryResult<ForumPost>> = [];
  public reactionUsersResults: Array<RepositoryResult<Array<PostReactionUsers>>> = [];
  public createBookmarkResults: Array<RepositoryResult<number>> = [];
  public deleteBookmarkResults: Array<RepositoryResult<boolean>> = [];
  public deletePostResults: Array<RepositoryResult<boolean>> = [];
  public flagPostResults: Array<RepositoryResult<boolean>> = [];
  public deletePostTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public acceptedAnswerResults: Array<RepositoryResult<boolean>> = [];
  public acceptedAnswerTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public markTopicReadResults: Array<RepositoryResult<boolean>> = [];
  public markTopicReadTasks: Array<Promise<RepositoryResult<boolean>>> = [];
  public clearNotificationResults: Array<RepositoryResult<number>> = [];
  public clearNotificationTasks: Array<Promise<RepositoryResult<number>>> = [];
  public categoryTopicResults: Array<RepositoryResult<Array<Topic>>> = [];
  public topicDetailTasks: Array<Promise<RepositoryResult<TopicDetail>>> = [];
  public categoryTopicTasks: Array<Promise<RepositoryResult<Array<Topic>>>> = [];
  public requestedCategoryIds: Array<number> = [];
  public requestedPostIds: Array<Array<number>> = [];
  public requestedTopicPostNumbers: Array<number | null> = [];
  public requestedSuggestionTopicIds: Array<number> = [];
  public requestedTopicNotifications: Array<string> = [];
  public requestedReactions: Array<string> = [];
  public requestedReactionUserPostIds: Array<number> = [];
  public requestedBookmarkPostIds: Array<number> = [];
  public requestedDeleteBookmarkIds: Array<number> = [];
  public requestedDeletePostIds: Array<number> = [];
  public requestedFlags: Array<string> = [];
  public requestedAcceptedAnswers: Array<string> = [];
  public requestedReadTimings: Array<string> = [];
  public requestedNotificationProgress: Array<string> = [];
  public currentUserResults: Array<RepositoryResult<CurrentUser>> = [];
  public replySubmitResults: Array<ReplySubmitResult> = [];
  public replyRecoveryResults: Array<ReplyRecoveryResult> = [];
  public submittedReplies: Array<ReplyRequest> = [];
  public recoveryRequests: Array<ReplyRecoveryRequest> = [];
  public topicSubmitResults: Array<TopicSubmitResult> = [];
  public submittedTopics: Array<CreateTopicRequest> = [];
  public editPostResults: Array<RepositoryResult<boolean>> = [];
  public editedPosts: Array<EditPostRequest> = [];
  public draftResults: Array<RepositoryResult<Array<ServerDraft>>> = [];
  public savedDrafts: Array<DraftWriteRequest> = [];
  public savedDraftResults: Array<RepositoryResult<number>> = [];
  public deletedDrafts: Array<string> = [];
  public deletedDraftResults: Array<RepositoryResult<boolean>> = [];

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async loadHomeTopics(_channel: HomeChannel, _page: number): Promise<RepositoryResult<Array<Topic>>> {
    return RepositoryResult.success<Array<Topic>>([]);
  }

  public async searchForum(_query: string, _page: number): Promise<RepositoryResult<ForumSearchResult>> {
    return RepositoryResult.unknown<ForumSearchResult>('missing search result');
  }

  public async searchSuggestions(_term: string): Promise<RepositoryResult<Array<string>>> {
    return RepositoryResult.success<Array<string>>([]);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    return RepositoryResult.success<Array<Category>>([]);
  }

  public async loadCategoryTopics(categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedCategoryIds.push(categoryId);
    const task: Promise<RepositoryResult<Array<Topic>>> | undefined = this.categoryTopicTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<Array<Topic>> | undefined = this.categoryTopicResults.shift();
    return result ?? RepositoryResult.unknown<Array<Topic>>('missing Category Topic result');
  }

  public async loadTopicDetail(
    _topicId: number,
    postNumber: number | null = null
  ): Promise<RepositoryResult<TopicDetail>> {
    this.requestedTopicPostNumbers.push(postNumber);
    const task: Promise<RepositoryResult<TopicDetail>> | undefined = this.topicDetailTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<TopicDetail> | undefined = this.topicDetailResults.shift();
    return result ?? RepositoryResult.unknown<TopicDetail>('missing Topic detail result');
  }

  public async loadTopicPosts(_topicId: number, postIds: Array<number>): Promise<RepositoryResult<TopicPostBatch>> {
    this.requestedPostIds.push(postIds);
    const task: Promise<RepositoryResult<TopicPostBatch>> | undefined = this.topicPostTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    const result: RepositoryResult<TopicPostBatch> | undefined = this.topicPostResults.shift();
    return result ?? RepositoryResult.unknown<TopicPostBatch>('missing Post result');
  }

  public async loadTopicSuggestions(topicId: number): Promise<RepositoryResult<Array<Topic>>> {
    this.requestedSuggestionTopicIds.push(topicId);
    const result: RepositoryResult<Array<Topic>> | undefined = this.topicSuggestionResults.shift();
    return result ?? RepositoryResult.success<Array<Topic>>([]);
  }

  public async setTopicNotificationLevel(
    topicId: number,
    notificationLevel: TopicNotificationLevel
  ): Promise<RepositoryResult<boolean>> {
    this.requestedTopicNotifications.push(`${topicId}:${notificationLevel}`);
    return this.topicNotificationResults.shift() ??
      RepositoryResult.unknown<boolean>('missing Topic notification result');
  }

  public async togglePostReaction(postId: number, reaction: string): Promise<RepositoryResult<ForumPost>> {
    this.requestedReactions.push(`${postId}:${reaction}`);
    return this.reactionResults.shift() ?? RepositoryResult.unknown<ForumPost>('missing Reaction result');
  }

  public async loadPostReactionUsers(postId: number): Promise<RepositoryResult<Array<PostReactionUsers>>> {
    this.requestedReactionUserPostIds.push(postId);
    return this.reactionUsersResults.shift() ??
      RepositoryResult.unknown<Array<PostReactionUsers>>('missing Reaction users result');
  }

  public async createPostBookmark(postId: number): Promise<RepositoryResult<number>> {
    this.requestedBookmarkPostIds.push(postId);
    return this.createBookmarkResults.shift() ?? RepositoryResult.unknown<number>('missing bookmark result');
  }

  public async deletePostBookmark(bookmarkId: number): Promise<RepositoryResult<boolean>> {
    this.requestedDeleteBookmarkIds.push(bookmarkId);
    return this.deleteBookmarkResults.shift() ?? RepositoryResult.unknown<boolean>('missing bookmark result');
  }

  public async deletePost(postId: number): Promise<RepositoryResult<boolean>> {
    this.requestedDeletePostIds.push(postId);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.deletePostTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.deletePostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post delete result');
  }

  public async flagPost(request: PostFlagRequest): Promise<RepositoryResult<boolean>> {
    this.requestedFlags.push(`${request.postId}:${request.typeId}:${request.message ?? ''}`);
    return this.flagPostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post flag result');
  }

  public async setPostAcceptedAnswer(postId: number, accepted: boolean): Promise<RepositoryResult<boolean>> {
    this.requestedAcceptedAnswers.push(`${postId}:${accepted}`);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.acceptedAnswerTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.acceptedAnswerResults.shift() ?? RepositoryResult.unknown<boolean>('missing solution result');
  }

  public async markTopicRead(
    topicId: number,
    postNumbers: Array<number>,
    milliseconds: number
  ): Promise<RepositoryResult<boolean>> {
    this.requestedReadTimings.push(`${topicId}:${postNumbers.join(',')}:${milliseconds}`);
    const task: Promise<RepositoryResult<boolean>> | undefined = this.markTopicReadTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.markTopicReadResults.shift() ?? RepositoryResult.unknown<boolean>('missing Topic timing result');
  }

  public async clearTopicNotifications(
    topicId: number,
    upToPostNumber: number
  ): Promise<RepositoryResult<number>> {
    this.requestedNotificationProgress.push(`${topicId}:${upToPostNumber}`);
    const task: Promise<RepositoryResult<number>> | undefined = this.clearNotificationTasks.shift();
    if (task !== undefined) {
      return await task;
    }
    return this.clearNotificationResults.shift() ?? RepositoryResult.success<number>(0);
  }

  public async submitReply(request: ReplyRequest): Promise<ReplySubmitResult> {
    this.submittedReplies.push(request);
    const result: ReplySubmitResult | undefined = this.replySubmitResults.shift();
    return result ?? ReplySubmitResult.rejected('missing Reply result');
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const result: RepositoryResult<CurrentUser> | undefined = this.currentUserResults.shift();
    return result ?? RepositoryResult.unknown<CurrentUser>('missing current user result');
  }

  public async loadUserProfile(_username: string): Promise<RepositoryResult<CurrentUser>> {
    return RepositoryResult.unknown<CurrentUser>('missing user profile result');
  }

  public async recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult> {
    this.recoveryRequests.push(request);
    const result: ReplyRecoveryResult | undefined = this.replyRecoveryResults.shift();
    return result ?? ReplyRecoveryResult.failed('missing Reply recovery result');
  }

  public async submitTopic(request: CreateTopicRequest): Promise<TopicSubmitResult> {
    this.submittedTopics.push(request);
    return this.topicSubmitResults.shift() ?? TopicSubmitResult.rejected('missing Topic result');
  }

  public async editPost(request: EditPostRequest): Promise<RepositoryResult<boolean>> {
    this.editedPosts.push(request);
    return this.editPostResults.shift() ?? RepositoryResult.unknown<boolean>('missing Post edit result');
  }

  public async editTopic(_request: EditTopicRequest): Promise<RepositoryResult<boolean>> {
    return RepositoryResult.unknown<boolean>('missing Topic edit result');
  }

  public async loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>> {
    return this.draftResults.shift() ?? RepositoryResult.success<Array<ServerDraft>>([]);
  }

  public async saveDraft(request: DraftWriteRequest): Promise<RepositoryResult<number>> {
    this.savedDrafts.push(request);
    return this.savedDraftResults.shift() ?? RepositoryResult.unknown<number>('missing draft result');
  }

  public async deleteDraft(draftKey: string, sequence: number): Promise<RepositoryResult<boolean>> {
    this.deletedDrafts.push(`${draftKey}:${sequence}`);
    return this.deletedDraftResults.shift() ?? RepositoryResult.success<boolean>(true);
  }
}

export class TopicAuthenticationLifecycle implements AuthenticationLifecycle {
  public unauthorizedCallCount: number = 0;

  public async handleUnauthorized(): Promise<void> {
    this.unauthorizedCallCount += 1;
  }
}

export function topic(): Topic {
  return new Topic(2725, '站务管理区重要主题导航', 60, 1, 1959, 4, '', '', true, 'Co-admin');
}

export function topicWithId(id: number, title: string): Topic {
  return new Topic(id, title, 60, 1, 10, 0, '', '', false, 'Co-admin');
}

export function category(): Category {
  return new Category(60, '站务管理', '25AAE2', '站务与公告', 1, null, []);
}

export function firstPost(): ForumPost {
  return new ForumPost(102728, 24, 'Co-admin', '<h1>站务公告</h1>', '站务公告', 1, null, '2026-01-27T14:46:08.722Z');
}

export function secondPost(): ForumPost {
  return new ForumPost(102729, 1, 'admin', '<p>第一条 Reply</p>', '第一条 Reply', 2, null, '2026-01-28T00:00:00Z');
}

export function deletableSecondPost(): ForumPost {
  return new ForumPost(
    102729,
    24,
    'Co-admin',
    '<p>我自己的 Reply</p>',
    '我自己的 Reply',
    2,
    null,
    '2026-01-28T00:00:00Z',
    new ForumPostMetadata('', '', '', null, null, 0, [], null, false, true)
  );
}

export function thirdPost(): ForumPost {
  return new ForumPost(102730, 24, 'Co-admin', '<p>第二条 Reply</p>', '第二条 Reply', 3, 2, '2026-01-28T00:01:00Z');
}

export function fourthPost(): ForumPost {
  return new ForumPost(102731, 24, 'Co-admin', '<p>收到</p>', '收到', 4, 3, '2026-01-28T00:02:00Z');
}

export function reactedFirstPost(): ForumPost {
  return new ForumPost(
    102728,
    24,
    'Co-admin',
    '<h1>站务公告</h1>',
    '站务公告',
    1,
    null,
    '2026-01-27T14:46:08.722Z',
    new ForumPostMetadata('', '', '', null, null, 1, [new PostReaction('heart', 1)], 'heart')
  );
}

export function solutionReply(
  acceptedAnswer: boolean,
  canAcceptAnswer: boolean,
  canUnacceptAnswer: boolean
): ForumPost {
  return new ForumPost(
    102729,
    1,
    'admin',
    '<p>可采纳的回答</p>',
    '可采纳的回答',
    2,
    null,
    '2026-01-28T00:00:00Z',
    new ForumPostMetadata(
      '', '', '', null, null, 0, [], null, false, false,
      acceptedAnswer, canAcceptAnswer, canUnacceptAnswer
    )
  );
}

export function authenticatedUserResult(): RepositoryResult<CurrentUser> {
  const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
  return user === null
    ? RepositoryResult.unknown<CurrentUser>('invalid test user')
    : RepositoryResult.success<CurrentUser>(user);
}
