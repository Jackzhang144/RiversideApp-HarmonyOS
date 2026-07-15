import { ComposerEdit, insertComposerText } from './AuthoringModels';
import { ChatEmoji } from './ChatModels';

function normalizedEmojiName(value: string): string {
  return value.trim().replace(/:/g, '');
}

export function filterComposerEmojis(emojis: Array<ChatEmoji>, query: string): Array<ChatEmoji> {
  const normalizedQuery: string = query.trim().toLowerCase();
  if (normalizedQuery.length === 0) {
    return emojis;
  }
  return emojis.filter((emoji: ChatEmoji): boolean => {
    return emoji.name.toLowerCase().includes(normalizedQuery);
  });
}

export function insertComposerEmoji(
  source: string,
  selectionStart: number,
  selectionEnd: number,
  name: string
): ComposerEdit | null {
  const normalizedName: string = normalizedEmojiName(name);
  if (normalizedName.length === 0) {
    return null;
  }
  return insertComposerText(source, selectionStart, selectionEnd, `:${normalizedName}:`);
}
