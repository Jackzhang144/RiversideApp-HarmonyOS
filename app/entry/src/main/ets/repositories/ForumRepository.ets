import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import { ForumSearchResult, HomeChannel } from '../models/DiscoveryModels';
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

  loadTopicDetail(topicId: number): Promise<RepositoryResult<TopicDetail>>;

  loadTopicPosts(topicId: number, postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>>;

  loadCurrentUser(): Promise<RepositoryResult<CurrentUser>>;

  submitReply(request: ReplyRequest): Promise<ReplySubmitResult>;

  recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult>;
}
