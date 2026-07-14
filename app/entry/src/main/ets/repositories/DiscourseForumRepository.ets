import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail } from '../models/ForumModels';
import { ForumSearchResult, HomeChannel, homeChannelPath } from '../models/DiscoveryModels';
import {
  CurrentUser,
  ReplyRecoveryRequest,
  ReplyRecoveryResult,
  ReplyRequest,
  ReplySubmitResult
} from '../models/ReplyModels';
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
    return this.loadHomeTopics(HomeChannel.LATEST_REPLIES, 0);
  }

  public async loadHomeTopics(channel: HomeChannel, page: number): Promise<RepositoryResult<Array<Topic>>> {
    if (!Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<Topic>>('首页页码无效');
    }
    const response: HttpTextResult = await this.client.get(homeChannelPath(channel, page));
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

  public async loadCategoryTopics(categoryId: number, page: number = 0): Promise<RepositoryResult<Array<Topic>>> {
    if (!Number.isInteger(categoryId) || categoryId <= 0) {
      return RepositoryResult.failure<Array<Topic>>('Category 标识无效');
    }
    if (!Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<Topic>>('Category 页码无效');
    }
    const suffix: string = page > 0 ? `?page=${page}` : '';
    const response: HttpTextResult = await this.client.get(`/c/${categoryId}.json${suffix}`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.parser.parseLatestTopics(response.body);
  }

  public async searchForum(query: string, page: number): Promise<RepositoryResult<ForumSearchResult>> {
    const normalizedQuery: string = query.trim();
    if (normalizedQuery.length === 0) {
      return RepositoryResult.failure<ForumSearchResult>('请输入搜索关键词');
    }
    if (!Number.isInteger(page) || page < 1) {
      return RepositoryResult.failure<ForumSearchResult>('搜索页码无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/search.json?q=${encodeURIComponent(normalizedQuery)}&page=${page}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<ForumSearchResult>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<ForumSearchResult>(response.message);
    }
    return this.parser.parseSearch(response.body);
  }

  public async searchSuggestions(term: string): Promise<RepositoryResult<Array<string>>> {
    const normalizedTerm: string = term.trim();
    if (normalizedTerm.length < 2) {
      return RepositoryResult.success<Array<string>>([]);
    }
    const response: HttpTextResult = await this.client.get(
      `/search/query?term=${encodeURIComponent(normalizedTerm)}&typeahead=true`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<string>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<string>>(response.message);
    }
    return this.parser.parseSearchSuggestions(response.body);
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
      const resultIsUncertain: boolean = response.statusCode === 0 ||
        response.statusCode === 408 ||
        response.statusCode >= 500;
      return resultIsUncertain
        ? ReplySubmitResult.uncertain(response.message)
        : ReplySubmitResult.rejected(response.message);
    }
    const parsed: RepositoryResult<ForumPost> = this.parser.parseCreatedReply(response.body);
    if (!parsed.isSuccess() || parsed.data === null) {
      return ReplySubmitResult.uncertain(parsed.message);
    }
    return ReplySubmitResult.created(parsed.data);
  }

  public async loadCurrentUser(): Promise<RepositoryResult<CurrentUser>> {
    const response: HttpTextResult = await this.client.get('/session/current.json');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<CurrentUser>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<CurrentUser>(response.message);
    }
    return this.parser.parseCurrentUser(response.body);
  }

  public async loadUserProfile(username: string): Promise<RepositoryResult<CurrentUser>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<CurrentUser>('用户名无效');
    }
    const response: HttpTextResult = await this.client.get(`/u/${encodeURIComponent(normalizedUsername)}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<CurrentUser>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<CurrentUser>(response.message);
    }
    return this.parser.parseUserProfile(response.body);
  }

  public async recoverReply(request: ReplyRecoveryRequest): Promise<ReplyRecoveryResult> {
    const response: HttpTextResult = await this.client.get(
      `/t/${request.reply.topicId}/${request.expectedPostNumber}.json?track_visit=true`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return ReplyRecoveryResult.unauthorized();
    }
    if (!response.isSuccess()) {
      return ReplyRecoveryResult.failed(`无法确认 Reply 是否已创建：${response.message}`);
    }
    const parsed: RepositoryResult<TopicDetail> = this.parser.parseTopicDetail(response.body);
    if (!parsed.isSuccess() || parsed.data === null) {
      return ReplyRecoveryResult.failed(`无法确认 Reply 是否已创建：${parsed.message}`);
    }
    const candidates: Array<ForumPost> = parsed.data.posts
      .filter((post: ForumPost): boolean => request.matches(post))
      .sort((left: ForumPost, right: ForumPost): number => right.postNumber - left.postNumber);
    return candidates.length === 0
      ? ReplyRecoveryResult.notFound()
      : ReplyRecoveryResult.confirmed(candidates[0]);
  }
}
