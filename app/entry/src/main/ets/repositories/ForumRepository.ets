import { RepositoryResult } from '../core/RepositoryResult';
import { Category, Topic } from '../models/ForumModels';

export interface ForumRepository {
  loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>>;

  loadCategories(): Promise<RepositoryResult<Array<Category>>>;
}
