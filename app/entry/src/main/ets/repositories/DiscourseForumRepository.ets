import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import { ReplyRequest, ReplySubmitResult } from '../models/ReplyModels';
import { ForumHttpClient, HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import { ForumRepository } from './ForumRepository';
import { ForumResponseParser } from './ForumResponseParser';

export class DiscourseForumRepository implements ForumRepository {
  private readonly client: ForumHttpClient;
  private readonly parser: ForumResponseParser;

  public constructor(client: ForumHttpClient, parser: ForumResponseParser = new ForumResponseParser()) {
    this.client = client;
    this.parser = parser;
  }

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    const response: HttpTextResult = await this.client.get('/latest.json');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
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
    if (
      siteResponse.kind === HttpTextResultKind.UNAUTHORIZED ||
      directoryResponse.kind === HttpTextResultKind.UNAUTHORIZED
    ) {
      return RepositoryResult.unauthorized<Array<Category>>();
    }
    if (!siteResponse.isSuccess()) {
      return RepositoryResult.failure<Array<Category>>(siteResponse.message);
    }
    if (!directoryResponse.isSuccess()) {
      return RepositoryResult.failure<Array<Category>>(directoryResponse.message);
    }
    return this.parser.parseCategories(siteResponse.body, directoryResponse.body);
  }

  public async loadCategoryTopics(categoryId: number): Promise<RepositoryResult<Array<Topic>>> {
    if (!Number.isInteger(categoryId) || categoryId <= 0) {
      return RepositoryResult.failure<Array<Topic>>('Category 标识无效');
    }
    const response: HttpTextResult = await this.client.get(`/c/${categoryId}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.parser.parseLatestTopics(response.body);
  }

  public async loadTopicDetail(topicId: number): Promise<RepositoryResult<TopicDetail>> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return RepositoryResult.failure<TopicDetail>('Topic 标识无效');
    }
    const response: HttpTextResult = await this.client.get(`/t/${topicId}.json?track_visit=true`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<TopicDetail>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<TopicDetail>(response.message);
    }
    return this.parser.parseTopicDetail(response.body);
  }

  public async loadTopicPosts(topicId: number, postIds: Array<number>): Promise<RepositoryResult<Array<ForumPost>>> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return RepositoryResult.failure<Array<ForumPost>>('Topic 标识无效');
    }
    if (postIds.length === 0) {
      return RepositoryResult.success<Array<ForumPost>>([]);
    }
    for (const postId of postIds) {
      if (!Number.isInteger(postId) || postId <= 0) {
        return RepositoryResult.failure<Array<ForumPost>>('Post 标识无效');
      }
    }
    const postQuery: string = postIds.map((postId: number) => `post_ids[]=${postId}`).join('&');
    const response: HttpTextResult = await this.client.get(
      `/t/${topicId}/posts.json?${postQuery}&include_suggested=true`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ForumPost>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ForumPost>>(response.message);
    }
    return this.parser.parseTopicPosts(response.body);
  }

  public async submitReply(request: ReplyRequest): Promise<ReplySubmitResult> {
    const response: HttpTextResult = await this.client.postReply(request);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return ReplySubmitResult.unauthorized();
    }
    if (!response.isSuccess()) {
      return response.statusCode > 0
        ? ReplySubmitResult.rejected(response.message)
        : ReplySubmitResult.uncertain(response.message);
    }
    const parsed: RepositoryResult<ForumPost> = this.parser.parseCreatedReply(response.body);
    if (!parsed.isSuccess() || parsed.data === null) {
      return ReplySubmitResult.uncertain(parsed.message);
    }
    return ReplySubmitResult.created(parsed.data);
  }
}
