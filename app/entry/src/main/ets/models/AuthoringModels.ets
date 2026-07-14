import { ForumPost } from './ForumModels';

export const AUTHORING_CATEGORY_ID: number = 111;
const AUTO_REPLY_QUOTE_MAX_CHARS: number = 120;
const SINGLE_POLL_TEMPLATE: string =
  '[poll type=regular results=always public=true chartType=bar]\n' +
    '* 1\n* 2\n* 3\n[/poll]';
const MULTIPLE_POLL_TEMPLATE: string =
  '[poll name=poll2 type=multiple results=always min=1 max=2 public=true chartType=bar]\n' +
    '* 1\n* 2\n* 3\n[/poll]';

export enum ComposerTool {
  BOLD = 'bold',
  ITALIC = 'italic',
  HEADING_1 = 'heading-1',
  HEADING_2 = 'heading-2',
  HEADING_3 = 'heading-3',
  LINK = 'link',
  QUOTE = 'quote',
  CODE_BLOCK = 'code-block',
  INLINE_CODE = 'inline-code',
  BULLET_LIST = 'bullet-list',
  ORDERED_LIST = 'ordered-list',
  POLL_SINGLE = 'poll-single',
  POLL_MULTIPLE = 'poll-multiple'
}

export class ComposerEdit {
  public readonly text: string;
  public readonly selectionStart: number;
  public readonly selectionEnd: number;

  public constructor(text: string, selectionStart: number, selectionEnd: number) {
    this.text = text;
    this.selectionStart = Math.max(0, Math.min(selectionStart, text.length));
    this.selectionEnd = Math.max(this.selectionStart, Math.min(selectionEnd, text.length));
  }
}

class NormalizedSelection {
  public readonly start: number;
  public readonly end: number;
  public readonly selected: string;

  public constructor(source: string, selectionStart: number, selectionEnd: number) {
    const safeStart: number = Math.max(0, Math.min(selectionStart, source.length));
    const safeEnd: number = Math.max(0, Math.min(selectionEnd, source.length));
    this.start = Math.min(safeStart, safeEnd);
    this.end = Math.max(safeStart, safeEnd);
    this.selected = source.substring(this.start, this.end);
  }
}

function replaceSelection(
  source: string,
  selection: NormalizedSelection,
  replacement: string,
  relativeSelectionStart: number = replacement.length,
  relativeSelectionEnd: number = relativeSelectionStart
): ComposerEdit {
  const text: string = source.substring(0, selection.start) + replacement + source.substring(selection.end);
  return new ComposerEdit(
    text,
    selection.start + relativeSelectionStart,
    selection.start + relativeSelectionEnd
  );
}

function wrapSelection(
  source: string,
  selection: NormalizedSelection,
  before: string,
  after: string,
  placeholder: string
): ComposerEdit {
  const selected: string = selection.selected.length > 0 ? selection.selected : placeholder;
  const replacement: string = `${before}${selected}${after}`;
  if (selection.selected.length > 0) {
    return replaceSelection(source, selection, replacement);
  }
  return replaceSelection(source, selection, replacement, before.length, before.length + selected.length);
}

function insertBlock(source: string, selection: NormalizedSelection, block: string): ComposerEdit {
  const needsLeadingLineBreak: boolean = selection.start > 0 && source.charAt(selection.start - 1) !== '\n';
  const needsTrailingLineBreak: boolean = selection.end < source.length && source.charAt(selection.end) !== '\n';
  const replacement: string = `${needsLeadingLineBreak ? '\n' : ''}${block}${needsTrailingLineBreak ? '\n' : ''}`;
  return replaceSelection(source, selection, replacement);
}

function headingEdit(
  source: string,
  selection: NormalizedSelection,
  marker: string
): ComposerEdit {
  const normalized: string = selection.selected.trim();
  const text: string = normalized.length > 0 ? normalized : '标题';
  const block: string = `${marker} ${text}`;
  const edit: ComposerEdit = insertBlock(source, selection, block);
  if (normalized.length > 0) {
    return edit;
  }
  const placeholderStart: number = edit.selectionEnd - block.length + marker.length + 1;
  return new ComposerEdit(edit.text, placeholderStart, placeholderStart + text.length);
}

function quoteEdit(source: string, selection: NormalizedSelection): ComposerEdit {
  const normalized: string = selection.selected.trim();
  if (normalized.length === 0) {
    const block: string = '> 块引用';
    const edit: ComposerEdit = insertBlock(source, selection, block);
    const placeholderStart: number = edit.selectionEnd - block.length + 2;
    return new ComposerEdit(edit.text, placeholderStart, placeholderStart + 3);
  }
  const lines: Array<string> = normalized.split(/\r?\n/);
  const quoted: Array<string> = [];
  for (const line of lines) {
    quoted.push(line.trim().length === 0 ? '>' : `> ${line}`);
  }
  return insertBlock(source, selection, quoted.join('\n'));
}

function listEdit(source: string, selection: NormalizedSelection, ordered: boolean): ComposerEdit {
  const normalized: string = selection.selected.trim();
  const lines: Array<string> = normalized.length === 0 ? ['列表条目'] : normalized.split(/\r?\n/);
  const rendered: Array<string> = [];
  let visibleIndex: number = 1;
  for (const line of lines) {
    const text: string = line.trim();
    if (text.length === 0) {
      continue;
    }
    rendered.push(ordered ? `${visibleIndex}. ${text}` : `* ${text}`);
    visibleIndex += 1;
  }
  const block: string = rendered.length > 0
    ? rendered.join('\n')
    : ordered ? '1. 列表条目' : '* 列表条目';
  return insertBlock(source, selection, block);
}

export function applyComposerTool(
  source: string,
  selectionStart: number,
  selectionEnd: number,
  tool: ComposerTool
): ComposerEdit {
  const selection: NormalizedSelection = new NormalizedSelection(source, selectionStart, selectionEnd);
  if (tool === ComposerTool.BOLD) {
    return wrapSelection(source, selection, '**', '**', '粗体文本');
  }
  if (tool === ComposerTool.ITALIC) {
    return wrapSelection(source, selection, '*', '*', '强调文本');
  }
  if (tool === ComposerTool.HEADING_1) {
    return headingEdit(source, selection, '#');
  }
  if (tool === ComposerTool.HEADING_2) {
    return headingEdit(source, selection, '##');
  }
  if (tool === ComposerTool.HEADING_3) {
    return headingEdit(source, selection, '###');
  }
  if (tool === ComposerTool.LINK) {
    if (selection.selected.trim().length > 0) {
      const label: string = selection.selected;
      const replacement: string = `[${label}](https://example.com)`;
      const urlStart: number = label.length + 3;
      return replaceSelection(
        source,
        selection,
        replacement,
        urlStart,
        urlStart + 'https://example.com'.length
      );
    }
    return replaceSelection(
      source,
      selection,
      '[链接文本（可选）](https://example.com)',
      1,
      9
    );
  }
  if (tool === ComposerTool.QUOTE) {
    return quoteEdit(source, selection);
  }
  if (tool === ComposerTool.CODE_BLOCK) {
    const normalized: string = selection.selected.trim();
    const code: string = normalized.length > 0 ? normalized : '在此处键入或粘贴代码';
    return insertBlock(source, selection, `\`\`\`\n${code}\n\`\`\``);
  }
  if (tool === ComposerTool.INLINE_CODE) {
    return wrapSelection(source, selection, '`', '`', 'code');
  }
  if (tool === ComposerTool.BULLET_LIST) {
    return listEdit(source, selection, false);
  }
  if (tool === ComposerTool.ORDERED_LIST) {
    return listEdit(source, selection, true);
  }
  if (tool === ComposerTool.POLL_SINGLE) {
    return insertBlock(source, selection, SINGLE_POLL_TEMPLATE);
  }
  return insertBlock(source, selection, MULTIPLE_POLL_TEMPLATE);
}

export function insertComposerText(
  source: string,
  selectionStart: number,
  selectionEnd: number,
  text: string
): ComposerEdit {
  return replaceSelection(source, new NormalizedSelection(source, selectionStart, selectionEnd), text);
}

export function autoReplyQuote(
  post: ForumPost,
  topicId: number,
  highestPostNumber: number,
  existingDraft: string
): string {
  if (existingDraft.trim().length > 0) {
    return existingDraft;
  }
  if (
    !Number.isInteger(topicId) || topicId <= 0 ||
    !Number.isInteger(post.postNumber) || post.postNumber <= 0 ||
    highestPostNumber + 1 - post.postNumber <= 1
  ) {
    return existingDraft;
  }
  const username: string = post.username.trim();
  const source: string = post.raw.trim().length > 0 ? post.raw : post.displayText;
  let excerpt: string = source.replace(/\s+/g, ' ').trim();
  if (username.length === 0 || excerpt.length === 0) {
    return existingDraft;
  }
  if (excerpt.length > AUTO_REPLY_QUOTE_MAX_CHARS) {
    excerpt = `${excerpt.substring(0, AUTO_REPLY_QUOTE_MAX_CHARS).trim()}...`;
  }
  return `[quote="${username}, post:${post.postNumber}, topic:${topicId}"]\n${excerpt}\n[/quote]\n\n`;
}
