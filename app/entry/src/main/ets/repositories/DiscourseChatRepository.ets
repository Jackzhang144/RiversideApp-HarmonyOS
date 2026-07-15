import { RepositoryResult } from '../core/RepositoryResult';
import {
  ChatChannel,
  ChatEmoji,
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
  parseChatSearchResults,
  parseChatSendConfirmation
} from '../models/ChatModels';
import { ForumHttpClient, HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import { ChatRepository } from './ChatRepository';

interface DirectChatPayload {
  target_usernames: Array<string>;
  name: string;
}

export class DiscourseChatRepository implements ChatRepository {
  private readonly client: ForumHttpClient;

  public constructor(client: ForumHttpClient) {
    this.client = client;
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
    if (!this.validMessageIdentity(channelId, messageId)) {
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
    if (!this.validMessageIdentity(channelId, messageId) || normalizedEmoji.length === 0) {
      return RepositoryResult.failure<boolean>('聊天 Reaction 请求无效');
    }
    const body: string = `react_action=${action}&emoji=${encodeURIComponent(normalizedEmoji)}`;
    return this.booleanWriteResult(await this.client.putForm(`/chat/${channelId}/react/${messageId}`, body));
  }

  public async deleteChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    if (!this.validMessageIdentity(channelId, messageId)) {
      return RepositoryResult.failure<boolean>('聊天删除请求无效');
    }
    return this.booleanWriteResult(
      await this.client.delete(`/chat/api/channels/${channelId}/messages/${messageId}`)
    );
  }

  public async restoreChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>> {
    if (!this.validMessageIdentity(channelId, messageId)) {
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

  private booleanWriteResult(response: HttpTextResult): RepositoryResult<boolean> {
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<boolean>();
    }
    return response.isSuccess()
      ? RepositoryResult.success<boolean>(true)
      : RepositoryResult.failure<boolean>(response.message);
  }

  private validMessageIdentity(channelId: number, messageId: number): boolean {
    return Number.isSafeInteger(channelId) && channelId > 0 &&
      Number.isSafeInteger(messageId) && messageId > 0;
  }
}
