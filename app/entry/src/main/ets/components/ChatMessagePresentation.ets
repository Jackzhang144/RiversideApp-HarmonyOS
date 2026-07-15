import { ChatEmoji, ChatMessage } from '../models/ChatModels';

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
