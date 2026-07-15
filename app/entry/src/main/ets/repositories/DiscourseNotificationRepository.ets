import { RepositoryResult } from '../core/RepositoryResult';
import { Topic } from '../models/ForumModels';
import {
  NotificationBucket,
  NotificationItem,
  notificationUserActionFilter,
  parseReactionReceivedItems,
  parseUserActivityItems,
  sortNotificationItemsNewestFirst
} from '../models/NotificationModels';
import { ForumHttpClient, HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import { NotificationRepository } from './NotificationRepository';
import { ForumListingResponseParser } from './ForumListingResponseParser';

export class DiscourseNotificationRepository implements NotificationRepository {
  private readonly client: ForumHttpClient;
  private readonly parser: ForumListingResponseParser;

  public constructor(
    client: ForumHttpClient,
    parser: ForumListingResponseParser = new ForumListingResponseParser()
  ) {
    this.client = client;
    this.parser = parser;
  }

  public async loadNotificationItems(
    username: string,
    bucket: NotificationBucket,
    page: number,
    offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    const normalizedUsername: string = username.trim();
    if (
      normalizedUsername.length === 0 ||
      !Number.isSafeInteger(page) || page < 0 ||
      !Number.isSafeInteger(offset) || offset < 0
    ) {
      return RepositoryResult.invalidInput<Array<NotificationItem>>('消息查询参数无效');
    }
    const encodedUsername: string = encodeURIComponent(normalizedUsername);
    if (bucket === NotificationBucket.PRIVATE_MESSAGES) {
      return this.loadPrivateMessageItems(encodedUsername, page);
    }
    if (bucket === NotificationBucket.REACTIONS) {
      return this.loadReactionItems(encodedUsername, page, page * 20);
    }
    const filter: string | null = notificationUserActionFilter(bucket);
    if (filter === null) {
      return RepositoryResult.invalidInput<Array<NotificationItem>>('消息分桶无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/user_actions.json?offset=${offset}&username=${encodedUsername}&filter=${filter}`
    );
    return this.parseUserActivityResponse(response);
  }

  private async loadPrivateMessageItems(
    encodedUsername: string,
    page: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    const response: HttpTextResult = await this.client.get(
      `/topics/private-messages/${encodedUsername}.json?page=${page}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<NotificationItem>>();
    }
    if (!response.isSuccess()) {
      return response.asRepositoryFailure<Array<NotificationItem>>();
    }
    const topics: RepositoryResult<Array<Topic>> = this.parser.parseLatestTopics(response.body);
    if (!topics.isSuccess() || topics.data === null) {
      return topics.asFailure<Array<NotificationItem>>();
    }
    return RepositoryResult.success<Array<NotificationItem>>(
      topics.data.map((topic: Topic): NotificationItem => NotificationItem.privateMessage(topic))
    );
  }

  private async loadReactionItems(
    encodedUsername: string,
    page: number,
    offset: number
  ): Promise<RepositoryResult<Array<NotificationItem>>> {
    const responses: Array<HttpTextResult> = await Promise.all([
      this.client.get(
        `/discourse-reactions/posts/reactions-received.json?username=${encodedUsername}&page=${page}`
      ),
      this.client.get(`/user_actions.json?offset=${offset}&username=${encodedUsername}&filter=2`)
    ]);
    for (const response of responses) {
      if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
        return RepositoryResult.unauthorized<Array<NotificationItem>>();
      }
      if (!response.isSuccess()) {
        return response.asRepositoryFailure<Array<NotificationItem>>();
      }
    }
    const customReactions: Array<NotificationItem> | null = parseReactionReceivedItems(responses[0].body);
    const likes: Array<NotificationItem> | null = parseUserActivityItems(responses[1].body, '+1');
    if (customReactions === null || likes === null) {
      return RepositoryResult.invalidResponse<Array<NotificationItem>>('回应消息响应无效');
    }
    return RepositoryResult.success<Array<NotificationItem>>(
      sortNotificationItemsNewestFirst(customReactions.concat(likes))
    );
  }

  private parseUserActivityResponse(response: HttpTextResult): RepositoryResult<Array<NotificationItem>> {
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<NotificationItem>>();
    }
    if (!response.isSuccess()) {
      return response.asRepositoryFailure<Array<NotificationItem>>();
    }
    const items: Array<NotificationItem> | null = parseUserActivityItems(response.body);
    return items === null
      ? RepositoryResult.invalidResponse<Array<NotificationItem>>('活动消息响应无效')
      : RepositoryResult.success<Array<NotificationItem>>(items);
  }
}
