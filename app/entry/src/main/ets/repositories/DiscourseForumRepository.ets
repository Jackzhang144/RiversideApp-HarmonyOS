import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail, TopicPostBatch } from '../models/ForumModels';
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

  public async loadTopicDetail(
    topicId: number,
    postNumber: number | null = null
  ): Promise<RepositoryResult<TopicDetail>> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return RepositoryResult.failure<TopicDetail>('Topic 标识无效');
    }
    if (postNumber !== null && (!Number.isInteger(postNumber) || postNumber <= 0)) {
      return RepositoryResult.failure<TopicDetail>('Post 楼层无效');
    }
    const path: string = postNumber === null ? `/t/${topicId}.json` : `/t/${topicId}/${postNumber}.json`;
    const response: HttpTextResult = await this.client.get(`${path}?track_visit=true`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<TopicDetail>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<TopicDetail>(response.message);
    }
    return this.parser.parseTopicDetail(response.body);
  }

  public async loadTopicPosts(topicId: number, postIds: Array<number>): Promise<RepositoryResult<TopicPostBatch>> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return RepositoryResult.failure<TopicPostBatch>('Topic 标识无效');
    }
    if (postIds.length === 0) {
      return RepositoryResult.success<TopicPostBatch>(new TopicPostBatch([]));
    }
    for (const postId of postIds) {
      if (!Number.isInteger(postId) || postId <= 0) {
        return RepositoryResult.failure<TopicPostBatch>('Post 标识无效');
      }
    }
    const postQuery: string = postIds.map((postId: number) => `post_ids[]=${postId}`).join('&');
    const response: HttpTextResult = await this.client.get(
      `/t/${topicId}/posts.json?${postQuery}&include_suggested=true`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<TopicPostBatch>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<TopicPostBatch>(response.message);
    }
    return this.parser.parseTopicPostBatch(response.body);
  }

  public async loadTopicSuggestions(topicId: number): Promise<RepositoryResult<Array<Topic>>> {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return RepositoryResult.failure<Array<Topic>>('Topic 标识无效');
    }
    const response: HttpTextResult = await this.client.get(`/t/${topicId}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.parser.parseTopicSuggestions(response.body);
  }

  public async togglePostReaction(postId: number, reaction: string): Promise<RepositoryResult<ForumPost>> {
    const normalizedReaction: string = reaction.trim();
    if (!Number.isInteger(postId) || postId <= 0 || normalizedReaction.length === 0) {
      return RepositoryResult.failure<ForumPost>('Reaction 请求无效');
    }
    const response: HttpTextResult = await this.client.put(
      `/discourse-reactions/posts/${postId}/custom-reactions/${encodeURIComponent(normalizedReaction)}/toggle.json`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<ForumPost>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<ForumPost>(response.message);
    }
    return this.parser.parseCreatedReply(response.body);
  }

  public async createPostBookmark(postId: number): Promise<RepositoryResult<number>> {
    if (!Number.isInteger(postId) || postId <= 0) {
      return RepositoryResult.failure<number>('Post 标识无效');
    }
    const response: HttpTextResult = await this.client.postForm(
      '/bookmarks.json',
      `reminder_at=&auto_delete_preference=3&bookmarkable_id=${postId}&bookmarkable_type=Post`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<number>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<number>(response.message);
    }
    return this.parser.parseBookmarkId(response.body);
  }

  public async deletePostBookmark(bookmarkId: number): Promise<RepositoryResult<boolean>> {
    if (!Number.isInteger(bookmarkId) || bookmarkId <= 0) {
      return RepositoryResult.failure<boolean>('书签标识无效');
    }
    const response: HttpTextResult = await this.client.delete(`/bookmarks/${bookmarkId}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<boolean>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<boolean>(response.message);
    }
    return RepositoryResult.success<boolean>(true);
  }

  public async markTopicRead(
    topicId: number,
    postNumbers: Array<number>,
    milliseconds: number
  ): Promise<RepositoryResult<boolean>> {
    if (!Number.isInteger(topicId) || topicId <= 0 || !Number.isInteger(milliseconds) || milliseconds <= 0) {
      return RepositoryResult.failure<boolean>('Topic 阅读进度无效');
    }
    const uniquePostNumbers: Set<number> = new Set<number>();
    for (const postNumber of postNumbers) {
      if (Number.isInteger(postNumber) && postNumber > 0) {
        uniquePostNumbers.add(postNumber);
      }
    }
    const sortedPostNumbers: Array<number> = Array.from(uniquePostNumbers.values());
    sortedPostNumbers.sort((left: number, right: number): number => left - right);
    if (sortedPostNumbers.length === 0) {
      return RepositoryResult.success<boolean>(true);
    }
    const timingParts: Array<string> = [
      `topic_id=${topicId}`,
      `topic_time=${milliseconds}`
    ];
    for (const postNumber of sortedPostNumbers) {
      timingParts.push(`timings[${postNumber}]=${milliseconds}`);
    }
    const response: HttpTextResult = await this.client.postForm('/topics/timings', timingParts.join('&'));
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<boolean>();
    }
    return response.isSuccess()
      ? RepositoryResult.success<boolean>(true)
      : RepositoryResult.failure<boolean>(response.message);
  }

  public async clearTopicNotifications(
    topicId: number,
    upToPostNumber: number
  ): Promise<RepositoryResult<number>> {
    if (
      !Number.isInteger(topicId) || topicId <= 0 ||
      !Number.isInteger(upToPostNumber) || upToPostNumber <= 0
    ) {
      return RepositoryResult.failure<number>('通知阅读进度无效');
    }
    const listResponse: HttpTextResult = await this.client.get('/notifications.json?filter=unread');
    if (listResponse.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<number>();
    }
    if (!listResponse.isSuccess()) {
      return RepositoryResult.failure<number>(listResponse.message);
    }
    const parsed: RepositoryResult<Array<number>> = this.parser.parseNotificationIdsForTopic(
      listResponse.body,
      topicId,
      upToPostNumber
    );
    if (!parsed.isSuccess() || parsed.data === null) {
      return RepositoryResult.failure<number>(parsed.message);
    }
    for (const notificationId of parsed.data) {
      const markResponse: HttpTextResult = await this.client.put(
        `/notifications/mark-read.json?id=${notificationId}`
      );
      if (markResponse.kind === HttpTextResultKind.UNAUTHORIZED) {
        return RepositoryResult.unauthorized<number>();
      }
      if (!markResponse.isSuccess()) {
        return RepositoryResult.failure<number>(markResponse.message);
      }
    }
    return RepositoryResult.success<number>(parsed.data.length);
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
