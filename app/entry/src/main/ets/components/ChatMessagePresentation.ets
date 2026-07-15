import { ChatChannel, ChatEmoji, ChatMessage } from '../models/ChatModels';

const CHAT_MESSAGE_GROUP_WINDOW_MILLISECONDS: number = 5 * 60 * 1000;

const EMOJI_NAME_PATTERN: RegExp = /^[A-Za-z0-9_+\-]+$/;

export enum ChatMessageFragmentKind {
  TEXT = 'text',
  EMOJI = 'emoji'
}

export class ChatMessageFragment {
  public readonly kind: ChatMessageFragmentKind;
  public readonly text: string;
  public readonly imageUrl: string;

  private constructor(kind: ChatMessageFragmentKind, text: string, imageUrl: string) {
    this.kind = kind;
    this.text = text;
    this.imageUrl = imageUrl;
  }

  public static text(value: string): ChatMessageFragment {
    return new ChatMessageFragment(ChatMessageFragmentKind.TEXT, value, '');
  }

  public static emoji(token: string, imageUrl: string): ChatMessageFragment {
    return new ChatMessageFragment(ChatMessageFragmentKind.EMOJI, token, imageUrl);
  }
}

export class ChatMessageContextCapabilities {
  public readonly canReply: boolean;
  public readonly canCopyLink: boolean;
  public readonly canMention: boolean;
  public readonly canReact: boolean;
  public readonly canDelete: boolean;
  public readonly canRestore: boolean;

  public constructor(
    canReply: boolean,
    canCopyLink: boolean,
    canMention: boolean,
    canReact: boolean,
    canDelete: boolean,
    canRestore: boolean
  ) {
    this.canReply = canReply;
    this.canCopyLink = canCopyLink;
    this.canMention = canMention;
    this.canReact = canReact;
    this.canDelete = canDelete;
    this.canRestore = canRestore;
  }
}

export function resolveChatMessageContextCapabilities(
  message: ChatMessage,
  channel: ChatChannel | null,
  currentUsername: string,
  hasEmojis: boolean
): ChatMessageContextCapabilities {
  const canWrite: boolean = channel !== null && !channel.userSilenced;
  const canModerate: boolean = channel !== null && (message.username === currentUsername
    ? channel.canDeleteSelf
    : channel.canDeleteOthers);
  return new ChatMessageContextCapabilities(
    !message.deleted && canWrite,
    channel !== null,
    !message.deleted && canWrite && message.username.length > 0,
    !message.deleted && canWrite && hasEmojis,
    !message.deleted && canModerate,
    message.deleted && canModerate
  );
}

export function selectQuickChatEmojis(
  emojis: Array<ChatEmoji>,
  preferredNames: Array<string>,
  limit: number
): Array<ChatEmoji> {
  const normalizedLimit: number = Math.max(0, Math.floor(limit));
  const selected: Array<ChatEmoji> = [];
  preferredNames.forEach((name: string): void => {
    if (selected.length >= normalizedLimit) {
      return;
    }
    const emoji: ChatEmoji | null = emojis.find((candidate: ChatEmoji): boolean => candidate.name === name) ?? null;
    if (emoji !== null && !selected.some((candidate: ChatEmoji): boolean => candidate.name === emoji.name)) {
      selected.push(emoji);
    }
  });
  emojis.forEach((emoji: ChatEmoji): void => {
    if (selected.length < normalizedLimit &&
      !selected.some((candidate: ChatEmoji): boolean => candidate.name === emoji.name)) {
      selected.push(emoji);
    }
  });
  return selected;
}

function emojiForName(emojis: Array<ChatEmoji>, name: string): ChatEmoji | null {
  return emojis.find((emoji: ChatEmoji): boolean => emoji.name === name) ?? null;
}

export function presentChatText(value: string, emojis: Array<ChatEmoji>): Array<ChatMessageFragment> {
  if (!value.includes(':') || emojis.length === 0) {
    return [ChatMessageFragment.text(value)];
  }
  const fragments: Array<ChatMessageFragment> = [];
  let textStart: number = 0;
  let cursor: number = 0;
  while (cursor < value.length) {
    const tokenStart: number = value.indexOf(':', cursor);
    if (tokenStart < 0) {
      break;
    }
    const tokenEnd: number = value.indexOf(':', tokenStart + 1);
    if (tokenEnd < 0) {
      break;
    }
    const name: string = value.substring(tokenStart + 1, tokenEnd);
    const emoji: ChatEmoji | null = EMOJI_NAME_PATTERN.test(name) ? emojiForName(emojis, name) : null;
    if (emoji === null) {
      cursor = tokenStart + 1;
      continue;
    }
    if (tokenStart > textStart) {
      fragments.push(ChatMessageFragment.text(value.substring(textStart, tokenStart)));
    }
    fragments.push(ChatMessageFragment.emoji(value.substring(tokenStart, tokenEnd + 1), emoji.imageUrl()));
    cursor = tokenEnd + 1;
    textStart = cursor;
  }
  if (textStart < value.length) {
    fragments.push(ChatMessageFragment.text(value.substring(textStart)));
  }
  return fragments.length > 0 ? fragments : [ChatMessageFragment.text(value)];
}

export function presentChatMessageBody(
  message: ChatMessage,
  emojis: Array<ChatEmoji>
): Array<ChatMessageFragment> {
  return presentChatText(message.displayText(), emojis);
}

export function formatChatMessageTimestamp(value: string): string {
  const normalized: string = value.trim();
  if (normalized.length >= 16 && normalized.includes('T')) {
    return normalized.slice(0, 16).replace('T', ' ');
  }
  return normalized;
}

export function isChatMessageGroupStart(messages: Array<ChatMessage>, index: number): boolean {
  if (index <= 0 || index >= messages.length) {
    return true;
  }
  const current: ChatMessage = messages[index];
  const previous: ChatMessage = messages[index - 1];
  if (current.username !== previous.username) {
    return true;
  }
  const currentTime: number = Date.parse(current.createdAt);
  const previousTime: number = Date.parse(previous.createdAt);
  if (!Number.isFinite(currentTime) || !Number.isFinite(previousTime)) {
    return true;
  }
  const elapsed: number = currentTime - previousTime;
  return elapsed < 0 || elapsed > CHAT_MESSAGE_GROUP_WINDOW_MILLISECONDS;
}
