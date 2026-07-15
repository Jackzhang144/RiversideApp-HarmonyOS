import { ComposerEdit, insertComposerText } from './AuthoringModels';

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
