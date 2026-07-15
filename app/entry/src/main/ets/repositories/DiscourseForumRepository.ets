import { RepositoryResult } from '../core/RepositoryResult';
import { Category, ForumPost, Topic, TopicDetail, TopicPostBatch } from '../models/ForumModels';
import { ForumSearchResult, HomeChannel, homeChannelPath } from '../models/DiscoveryModels';
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
import { ForumHttpClient, HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import { ForumRepository } from './ForumRepository';
import { ProfileRepository } from './ProfileRepository';
import { ChatRepository } from './ChatRepository';
import { NotificationRepository } from './NotificationRepository';
import { ForumResponseParser } from './ForumResponseParser';
import {
  ProfileNotificationLevel,
  ProfileUpdateRequest,
  UserBookmarkItem,
  UserEmailInfo,
  UserProfile,
  UserProfileSummary,
  UserReplyItem
} from '../models/ProfileModels';
import {
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatReactionAction,
  ChatSearchResult,
  ChatSendConfirmation,
  ChatSendRequest,
  parseChatChannelResponse,
  parseChatChannels,
  parseChatEmojis,
  parseChatMessagePage,
  parseChatSendConfirmation,
  parseChatSearchResults
} from '../models/ChatModels';
import {
  NotificationBucket,
  NotificationItem,
  notificationUserActionFilter,
  parseReactionReceivedItems,
  parseUserActivityItems,
  sortNotificationItemsNewestFirst
} from '../models/NotificationModels';

interface DraftSavePayload {
  draft_key: string;
  data: string;
  sequence: number;
}

interface DirectChatPayload {
  target_usernames: Array<string>;
  name: string;
}

export class DiscourseForumRepository implements
  ForumRepository,
  ProfileRepository,
  ChatRepository,
  NotificationRepository {
  private readonly client: ForumHttpClient;
  private readonly parser: ForumResponseParser;

  public constructor(client: ForumHttpClient, parser: ForumResponseParser = new ForumResponseParser()) {
    this.client = client;
    this.parser = parser;
  }

  public async loadLatestTopics(): Promise<RepositoryResult<Array<Topic>>> {
    return this.loadHomeTopics(HomeChannel.LATEST_REPLIES, 0);
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
      return RepositoryResult.failure<Array<NotificationItem>>('消息查询参数无效');
    }
    const encodedUsername: string = encodeURIComponent(normalizedUsername);
    if (bucket === NotificationBucket.PRIVATE_MESSAGES) {
      return this.loadPrivateMessageItems(encodedUsername, page);
    }
    if (bucket === NotificationBucket.REACTIONS) {
      return this.loadReactionItems(encodedUsername, page, offset);
    }
    const filter: string | null = notificationUserActionFilter(bucket);
    if (filter === null) {
      return RepositoryResult.failure<Array<NotificationItem>>('消息分桶无效');
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
      return RepositoryResult.failure<Array<NotificationItem>>(response.message);
    }
    const topics: RepositoryResult<Array<Topic>> = this.parser.parseLatestTopics(response.body);
    if (!topics.isSuccess() || topics.data === null) {
      return RepositoryResult.failure<Array<NotificationItem>>(topics.message);
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
        return RepositoryResult.failure<Array<NotificationItem>>(response.message);
      }
    }
    const customReactions: Array<NotificationItem> | null = parseReactionReceivedItems(responses[0].body);
    const likes: Array<NotificationItem> | null = parseUserActivityItems(responses[1].body, '+1');
    if (customReactions === null || likes === null) {
      return RepositoryResult.failure<Array<NotificationItem>>('回应消息响应无效');
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
      return RepositoryResult.failure<Array<NotificationItem>>(response.message);
    }
    const items: Array<NotificationItem> | null = parseUserActivityItems(response.body);
    return items === null
      ? RepositoryResult.failure<Array<NotificationItem>>('活动消息响应无效')
      : RepositoryResult.success<Array<NotificationItem>>(items);
  }

  public async loadChatChannels(): Promise<RepositoryResult<Array<ChatChannel>>> {
    const response: HttpTextResult = await this.client.get('/chat/api/me/channels');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ChatChannel>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ChatChannel>>(response.message);
    }
    const channels: Array<ChatChannel> | null = parseChatChannels(response.body);
    return channels === null
      ? RepositoryResult.failure<Array<ChatChannel>>('聊天频道响应无效')
      : RepositoryResult.success<Array<ChatChannel>>(channels);
  }

  public async loadChatMessages(
    channelId: number,
    query: ChatMessageQuery
  ): Promise<RepositoryResult<ChatMessagePage>> {
    if (!Number.isSafeInteger(channelId) || channelId <= 0) {
      return RepositoryResult.failure<ChatMessagePage>('聊天频道标识无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/chat/api/channels/${channelId}/messages.json?${query.queryString()}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<ChatMessagePage>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<ChatMessagePage>(response.message);
    }
    const page: ChatMessagePage | null = parseChatMessagePage(response.body);
    return page === null
      ? RepositoryResult.failure<ChatMessagePage>('聊天消息响应无效')
      : RepositoryResult.success<ChatMessagePage>(page);
  }

  public async openDirectChat(username: string): Promise<RepositoryResult<ChatChannel>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<ChatChannel>('私聊用户名无效');
    }
    const payload: DirectChatPayload = { target_usernames: [normalizedUsername], name: '' };
    const response: HttpTextResult = await this.client.postJson(
      '/chat/api/direct-message-channels.json',
      JSON.stringify(payload)
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<ChatChannel>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<ChatChannel>(response.message);
    }
    const channel: ChatChannel | null = parseChatChannelResponse(response.body);
    return channel === null
      ? RepositoryResult.failure<ChatChannel>('私聊频道响应无效')
      : RepositoryResult.success<ChatChannel>(channel);
  }

  public async markChatRead(channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    if (!this.validChatMessageIdentity(channelId, messageId)) {
      return RepositoryResult.failure<boolean>('聊天已读标识无效');
    }
    return this.booleanWriteResult(
      await this.client.put(`/chat/api/channels/${channelId}/read?message_id=${messageId}`)
    );
  }

  public async sendChatMessage(request: ChatSendRequest): Promise<RepositoryResult<ChatSendConfirmation>> {
    const response: HttpTextResult = await this.client.postJson(
      `/chat/${request.channelId}.json`,
      JSON.stringify(request.toHttpExtraData())
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<ChatSendConfirmation>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<ChatSendConfirmation>(response.message);
    }
    const confirmation: ChatSendConfirmation | null = parseChatSendConfirmation(response.body);
    return confirmation === null
      ? RepositoryResult.failure<ChatSendConfirmation>('服务器未确认已发送消息')
      : RepositoryResult.success<ChatSendConfirmation>(confirmation);
  }

  public async reactToChatMessage(
    channelId: number,
    messageId: number,
    emoji: string,
    action: ChatReactionAction
  ): Promise<RepositoryResult<boolean>> {
    const normalizedEmoji: string = emoji.trim().replace(/:/g, '');
    if (!this.validChatMessageIdentity(channelId, messageId) || normalizedEmoji.length === 0) {
      return RepositoryResult.failure<boolean>('聊天 Reaction 请求无效');
    }
    const body: string = `react_action=${action}&emoji=${encodeURIComponent(normalizedEmoji)}`;
    return this.booleanWriteResult(await this.client.putForm(`/chat/${channelId}/react/${messageId}`, body));
  }

  public async deleteChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    if (!this.validChatMessageIdentity(channelId, messageId)) {
      return RepositoryResult.failure<boolean>('聊天删除请求无效');
    }
    return this.booleanWriteResult(
      await this.client.delete(`/chat/api/channels/${channelId}/messages/${messageId}`)
    );
  }

  public async restoreChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    if (!this.validChatMessageIdentity(channelId, messageId)) {
      return RepositoryResult.failure<boolean>('聊天恢复请求无效');
    }
    return this.booleanWriteResult(
      await this.client.put(`/chat/api/channels/${channelId}/messages/${messageId}/restore`)
    );
  }

  public async loadChatEmojis(): Promise<RepositoryResult<Array<ChatEmoji>>> {
    const response: HttpTextResult = await this.client.get('/emojis.json');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ChatEmoji>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ChatEmoji>>(response.message);
    }
    const emojis: Array<ChatEmoji> | null = parseChatEmojis(response.body);
    return emojis === null
      ? RepositoryResult.failure<Array<ChatEmoji>>('Emoji 响应无效')
      : RepositoryResult.success<Array<ChatEmoji>>(emojis);
  }

  public async searchChat(
    query: string,
    offset: number,
    limit: number
  ): Promise<RepositoryResult<Array<ChatSearchResult>>> {
    const normalizedQuery: string = query.trim();
    if (
      normalizedQuery.length === 0 ||
      !Number.isSafeInteger(offset) || offset < 0 ||
      !Number.isSafeInteger(limit) || limit <= 0 || limit > 100
    ) {
      return RepositoryResult.failure<Array<ChatSearchResult>>('聊天搜索参数无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/chat/api/search?query=${encodeURIComponent(normalizedQuery)}` +
      `&sort=relevance&offset=${offset}&limit=${limit}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ChatSearchResult>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ChatSearchResult>>(response.message);
    }
    const results: Array<ChatSearchResult> | null = parseChatSearchResults(response.body);
    return results === null
      ? RepositoryResult.failure<Array<ChatSearchResult>>('聊天搜索响应无效')
      : RepositoryResult.success<Array<ChatSearchResult>>(results);
  }

  public async leaveChatChannel(channelId: number): Promise<RepositoryResult<boolean>> {
    if (!Number.isSafeInteger(channelId) || channelId <= 0) {
      return RepositoryResult.failure<boolean>('聊天频道标识无效');
    }
    return this.booleanWriteResult(
      await this.client.delete(`/chat/api/channels/${channelId}/memberships/me/follows`)
    );
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

  public async loadUserTopics(username: string, page: number): Promise<RepositoryResult<Array<Topic>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<Topic>>('用户主题查询参数无效');
    }
    const pageSuffix: string = page > 0 ? `?page=${page}` : '';
    const response: HttpTextResult = await this.client.get(
      `/topics/created-by/${encodeURIComponent(normalizedUsername)}.json${pageSuffix}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<Topic>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<Topic>>(response.message);
    }
    return this.parser.parseLatestTopics(response.body);
  }

  public async loadUserReplies(username: string, offset: number): Promise<RepositoryResult<Array<UserReplyItem>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(offset) || offset < 0) {
      return RepositoryResult.failure<Array<UserReplyItem>>('用户回复查询参数无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/user_actions.json?offset=${offset}&username=${encodeURIComponent(normalizedUsername)}&filter=5`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<UserReplyItem>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<UserReplyItem>>(response.message);
    }
    return this.parser.parseUserReplies(response.body);
  }

  public async loadUserBookmarks(
    username: string,
    page: number
  ): Promise<RepositoryResult<Array<UserBookmarkItem>>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isInteger(page) || page < 0) {
      return RepositoryResult.failure<Array<UserBookmarkItem>>('用户收藏查询参数无效');
    }
    const pageSuffix: string = page > 0 ? `?page=${page}` : '';
    const response: HttpTextResult = await this.client.get(
      `/u/${encodeURIComponent(normalizedUsername)}/bookmarks.json${pageSuffix}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<UserBookmarkItem>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<UserBookmarkItem>>(response.message);
    }
    return this.parser.parseUserBookmarks(response.body);
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

  public async loadFullUserProfile(username: string): Promise<RepositoryResult<UserProfile>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserProfile>('用户名无效');
    }
    const response: HttpTextResult = await this.client.get(`/u/${encodeURIComponent(normalizedUsername)}.json`);
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserProfile>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserProfile>(response.message);
    }
    return this.parser.parseFullUserProfile(response.body);
  }

  public async loadUserSummary(username: string): Promise<RepositoryResult<UserProfileSummary>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserProfileSummary>('用户名无效');
    }
    const response: HttpTextResult = await this.client.get(
      `/u/${encodeURIComponent(normalizedUsername)}/summary.json`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserProfileSummary>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserProfileSummary>(response.message);
    }
    return this.parser.parseUserProfileSummary(response.body);
  }

  public async loadUserEmails(username: string): Promise<RepositoryResult<UserEmailInfo>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<UserEmailInfo>('用户名无效');
    }
    const encodedUsername: string = encodeURIComponent(normalizedUsername);
    const context: string = encodeURIComponent(`/u/${normalizedUsername}/preferences/account`);
    const response: HttpTextResult = await this.client.get(
      `/u/${encodedUsername}/emails.json?context=${context}`
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<UserEmailInfo>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<UserEmailInfo>(response.message);
    }
    return this.parser.parseUserEmails(response.body);
  }

  public async updateUserProfile(request: ProfileUpdateRequest): Promise<RepositoryResult<boolean>> {
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(request.username)}.json`,
      request.formBody()
    ));
  }

  public async pickUploadedAvatar(username: string, uploadId: number): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isSafeInteger(uploadId) || uploadId <= 0) {
      return RepositoryResult.failure<boolean>('头像请求无效');
    }
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(normalizedUsername)}/preferences/avatar/pick.json`,
      `upload_id=${uploadId}&type=uploaded`
    ));
  }

  public async setUserFollowing(username: string, following: boolean): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0) {
      return RepositoryResult.failure<boolean>('用户名无效');
    }
    const path: string = `/follow/${encodeURIComponent(normalizedUsername)}.json`;
    const response: HttpTextResult = following ? await this.client.put(path) : await this.client.delete(path);
    return this.booleanWriteResult(response);
  }

  public async setUserNotificationLevel(
    username: string,
    level: ProfileNotificationLevel,
    actingUserId: number,
    expiringAt: string = ''
  ): Promise<RepositoryResult<boolean>> {
    const normalizedUsername: string = username.trim();
    if (normalizedUsername.length === 0 || !Number.isSafeInteger(actingUserId) || actingUserId <= 0) {
      return RepositoryResult.failure<boolean>('用户通知请求无效');
    }
    const body: string = `notification_level=${encodeURIComponent(level)}` +
      `&expiring_at=${encodeURIComponent(expiringAt.trim())}&acting_user_id=${actingUserId}`;
    return this.booleanWriteResult(await this.client.putForm(
      `/u/${encodeURIComponent(normalizedUsername)}/notification_level.json`,
      body
    ));
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

  public async submitTopic(request: CreateTopicRequest): Promise<TopicSubmitResult> {
    const response: HttpTextResult = await this.client.postJson(
      '/posts.json',
      JSON.stringify(request.toHttpExtraData())
    );
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return TopicSubmitResult.unauthorized();
    }
    if (!response.isSuccess()) {
      const uncertain: boolean = response.statusCode === 0 || response.statusCode === 408 || response.statusCode >= 500;
      return uncertain ? TopicSubmitResult.uncertain(response.message) : TopicSubmitResult.rejected(response.message);
    }
    const parsed: RepositoryResult<number> = this.parser.parseCreatedTopicId(response.body);
    return parsed.data === null || !parsed.isSuccess()
      ? TopicSubmitResult.uncertain(parsed.message)
      : TopicSubmitResult.created(parsed.data);
  }

  public async editPost(request: EditPostRequest): Promise<RepositoryResult<boolean>> {
    const body: string = `post%5Braw%5D=${encodeURIComponent(request.raw)}&post%5Bedit_reason%5D=`;
    return this.booleanWriteResult(await this.client.putForm(`/posts/${request.postId}`, body));
  }

  public async editTopic(request: EditTopicRequest): Promise<RepositoryResult<boolean>> {
    const parts: Array<string> = [
      `title=${encodeURIComponent(request.title)}`,
      `category_id=${request.categoryId}`
    ];
    if (request.originalTitle.length > 0) {
      parts.push(`original_title=${encodeURIComponent(request.originalTitle)}`);
    }
    return this.booleanWriteResult(
      await this.client.putForm(`/t/-/${request.topicId}.json`, parts.join('&'))
    );
  }

  public async loadDrafts(): Promise<RepositoryResult<Array<ServerDraft>>> {
    const response: HttpTextResult = await this.client.get('/drafts.json');
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<Array<ServerDraft>>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<Array<ServerDraft>>(response.message);
    }
    return this.parser.parseServerDrafts(response.body);
  }

  public async saveDraft(request: DraftWriteRequest): Promise<RepositoryResult<number>> {
    const payload: DraftSavePayload = {
      draft_key: request.draftKey,
      data: JSON.stringify(request.toData()),
      sequence: request.sequence
    };
    const response: HttpTextResult = await this.client.postJson('/drafts.json', JSON.stringify(payload));
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<number>();
    }
    if (!response.isSuccess()) {
      return RepositoryResult.failure<number>(response.message);
    }
    return this.parser.parseDraftSequence(response.body);
  }

  public async deleteDraft(draftKey: string, sequence: number): Promise<RepositoryResult<boolean>> {
    const normalizedKey: string = draftKey.trim();
    if (normalizedKey.length === 0 || !Number.isInteger(sequence) || sequence < 0) {
      return RepositoryResult.failure<boolean>('草稿标识无效');
    }
    const body: string = `draft_key=${encodeURIComponent(normalizedKey)}&sequence=${sequence}`;
    return this.booleanWriteResult(
      await this.client.deleteForm(`/drafts/${encodeURIComponent(normalizedKey)}.json`, body)
    );
  }

  private booleanWriteResult(response: HttpTextResult): RepositoryResult<boolean> {
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<boolean>();
    }
    return response.isSuccess()
      ? RepositoryResult.success<boolean>(true)
      : RepositoryResult.failure<boolean>(response.message);
  }

  private validChatMessageIdentity(channelId: number, messageId: number): boolean {
    return Number.isSafeInteger(channelId) && channelId > 0 &&
      Number.isSafeInteger(messageId) && messageId > 0;
  }
}
