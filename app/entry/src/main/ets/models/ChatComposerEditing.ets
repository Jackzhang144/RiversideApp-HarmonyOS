import { ComposerEdit, insertComposerText } from './AuthoringModels';
import {
  applyComposerMention,
  ComposerMentionQuery,
  findComposerMentionQuery
} from './ComposerMentionModels';

export function findChatComposerMention(source: string, cursor: number): ComposerMentionQuery | null {
  return findComposerMentionQuery(source, cursor);
}

export function applyChatComposerMention(
  source: string,
  cursor: number,
  username: string
): ComposerEdit | null {
  return applyComposerMention(source, cursor, username);
}

export function insertChatEmojiText(
  source: string,
  selectionStart: number,
  selectionEnd: number,
  name: string
): ComposerEdit | null {
  const normalized: string = name.trim().replace(/:/g, '');
  return normalized.length === 0
    ? null
    : insertComposerText(source, selectionStart, selectionEnd, `:${normalized}:`);
}
