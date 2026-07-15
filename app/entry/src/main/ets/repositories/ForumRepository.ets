import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail, TopicPostBatch } from '../models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../models/DiscoveryModels';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitResult
} from '../models/AuthoringModels';
import {
  CurrentUser,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitResult
} from '../models/ReplyModels';

export interface ForumRepository {
  loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>>;

  loadHomeTopics(channel: HomeChannel, page: number): Promise<RepositoryResult<Array<Topic>>>;

  loadCategories(): Promise<RepositoryResult<Array<Category>>>;

  loadCategoryTopics(categoryId: number, page?: number): Promise<RepositoryResult<Array<Topic>>>;

  searchForum(query: string, page: number): Promise<RepositoryResult<ForumSearchResult>>;

  searchSuggestions(term: string): Promise<RepositoryResult<Array<string>>>;

  loadTopicDetail(topicId: number, postNumber?: number | null): Promise<RepositoryResult<TopicDetail>>;

  loadTopicPosts(topicId: number, postIds: Array<number>): Promise<RepositoryResult<TopicPostBatch>>;

  loadTopicSuggestions(topicId: number): Promise<RepositoryResult<Array<Topic>>>;

  togglePostReaction(postId: number, reaction: string): Promise<RepositoryResult<ForumPost>>;

  createPostBookmark(postId: number): Promise<RepositoryResult<number>>;

  deletePostBookmark(bookmarkId: number): Promise<RepositoryResult<boolean>>;

  deletePost(postId: number): Promise<RepositoryResult<boolean>>;

  setPostAcceptedAnswer(postId: number, accepted: boolean): Promise<RepositoryResult<boolean>>;

  markTopicRead(
    topicId: number,
    postNumbers: Array<number>,
    milliseconds: number
  ): Promise<RepositoryResult<boolean>>;

  clearTopicNotifications(topicId: number, upToPostNumber: number): Promise<RepositoryResult<number>>;

  loadCurrentUser(): Promise<RepositoryResult<CurrentUser>>;

  loadUserProfile(username: string): Promise<RepositoryResult<CurrentUser>>;

  submitReply(request: ReplyRequest): Promise<ReplySubmitResult>;

  recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult>;

  submitTopic(request: CreateTopicRequest): Promise<TopicSubmitResult>;

  editPost(request: EditPostRequest): Promise<RepositoryResult<boolean>>;

  editTopic(request: EditTopicRequest): Promise<RepositoryResult<boolean>>;

  loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>>;

  saveDraft(request: DraftWriteRequest): Promise<RepositoryResult<number>>;

  deleteDraft(draftKey: string, sequence: number): Promise<RepositoryResult<boolean>>;
}
