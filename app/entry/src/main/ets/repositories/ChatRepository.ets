import { RepositoryResult } from '../core/RepositoryResult';
import {
  ChatChannel,
  ChatChannelNotificationSettings,
  ChatChannelNotificationUpdate,
  ChatEmoji,
  ChatMessage,
  ChatMessagePage,
  ChatMessageQuery,
  ChatReactionAction,
  ChatSearchResult,
  ChatSendConfirmation,
  ChatSendRequest
} from '../models/ChatModels';

export interface ChatRepository {
  loadChatChannels(): Promise<RepositoryResult<Array<ChatChannel>>>;

  loadChatMessages(channelId: number, query: ChatMessageQuery): Promise<RepositoryResult<ChatMessagePage>>;

  openDirectChat(username: string): Promise<RepositoryResult<ChatChannel>>;

  markChatRead(channelId: number, messageId: number): Promise<RepositoryResult<boolean>>;

  sendChatMessage(request: ChatSendRequest): Promise<RepositoryResult<ChatSendConfirmation>>;

  reactToChatMessage(
    channelId: number,
    messageId: number,
    emoji: string,
    action: ChatReactionAction
  ): Promise<RepositoryResult<boolean>>;

  deleteChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>>;

  restoreChatMessage(channelId: number, messageId: number): Promise<RepositoryResult<boolean>>;

  loadChatEmojis(): Promise<RepositoryResult<Array<ChatEmoji>>>;

  searchChat(query: string, offset: number, limit: number): Promise<RepositoryResult<Array<ChatSearchResult>>>;

  updateChatChannelNotifications(
    channelId: number,
    update: ChatChannelNotificationUpdate
  ): Promise<RepositoryResult<ChatChannelNotificationSettings>>;

  leaveChatChannel(channelId: number): Promise<RepositoryResult<boolean>>;
}
