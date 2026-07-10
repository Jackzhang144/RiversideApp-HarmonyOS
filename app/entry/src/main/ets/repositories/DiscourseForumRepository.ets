import { RepositoryResult } from '../core/RepositoryResult';
import { Category, Topic } from '../models/ForumModels';
import { DiscourseHttpClient, HttpTextResult } from '../network/DiscourseHttpClient';
import { ForumRepository } from './ForumRepository';
import { ForumResponseParser } from './ForumResponseParser';

export class DiscourseForumRepository implements ForumRepository {
  private readonly client: DiscourseHttpClient;
  private readonly parser: ForumResponseParser;

  public constructor(client: DiscourseHttpClient, parser: ForumResponseParser = new ForumResponseParser()) {
    this.client = client;
    this.parser = parser;
  }

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    const response: HttpTextResult = await this.client.get('/latest.json');
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.parser.parseLatestTopics(response.body);
  }

  public async loadCategories(): Promise<RepositoryResult<Array<Category>>> {
    const responses: Array<HttpTextResult> = await Promise.all([
      this.client.get('/site.json'),
      this.client.get('/categories.json')
    ]);
    const siteResponse: HttpTextResult = responses[0];
    const directoryResponse: HttpTextResult = responses[1];
    if (!siteResponse.isSuccess()) {
      return RepositoryResult.failure<Array<Category>>(siteResponse.message);
    }
    if (!directoryResponse.isSuccess()) {
      return RepositoryResult.failure<Array<Category>>(directoryResponse.message);
    }
    return this.parser.parseCategories(siteResponse.body, directoryResponse.body);
  }
}
