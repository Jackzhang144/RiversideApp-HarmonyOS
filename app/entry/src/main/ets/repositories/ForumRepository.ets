import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import { CurrentUser, ReplyRequest, ReplySubmitResult } from '../models/ReplyModels';

export interface ForumRepository {
  loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>>;

  loadCategories(): Promise<RepositoryResult<Array<Category>>>;

  loadCategoryTopics(categoryId: number): Promise<RepositoryResult<Array<Topic>>>;

  loadTopicDetail(topicId: number): Promise<RepositoryResult<TopicDetail>>;

  loadTopicPosts(topicId: number, postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>>;

  loadCurrentUser(): Promise<RepositoryResult<CurrentUser>>;

  submitReply(request: ReplyRequest): Promise<ReplySubmitResult>;
}
