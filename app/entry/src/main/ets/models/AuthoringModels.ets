import { ForumPost } from './ForumModels';

const AUTO_REPLY_QUOTE_MAX_CHARS: number = 120;
const SINGLE_POLL_TEMPLATE: string =
  '[poll type=regular results=always public=true chartType=bar]\n' +
    '* 1\n* 2\n* 3\n[/poll]';
const MULTIPLE_POLL_TEMPLATE: string =
  '[poll name=poll2 type=multiple results=always min=1 max=2 public=true chartType=bar]\n' +
    '* 1\n* 2\n* 3\n[/poll]';

interface TopicCreatePayload {
  title: string;
  raw: string;
  category: number;
}

interface DraftDataPayload {
  action: string;
  title: string;
  reply: string;
  category_id?: number;
  topic_id?: number;
  reply_to_post_number?: number;
}

export class CreateTopicRequest {
  public readonly title: string;
  public readonly raw: string;
  public readonly categoryId: number;

  private constructor(title: string, raw: string, categoryId: number) {
    this.title = title;
    this.raw = raw;
    this.categoryId = categoryId;
  }

  public static create(title: string, raw: string, categoryId: number): CreateTopicRequest | null {
    const normalizedTitle: string = title.trim();
    const normalizedRaw: string = raw.trim();
    return normalizedTitle.length === 0 || normalizedRaw.length === 0 ||
      !Number.isInteger(categoryId) || categoryId <= 0
      ? null
      : new CreateTopicRequest(normalizedTitle, normalizedRaw, categoryId);
  }

  public toHttpExtraData(): Object {
    const payload: TopicCreatePayload = {
      title: this.title,
      raw: this.raw,
      category: this.categoryId
    };
    return payload;
  }
}

export class EditPostRequest {
  public readonly postId: number;
  public readonly raw: string;

  private constructor(postId: number, raw: string) {
    this.postId = postId;
    this.raw = raw;
  }

  public static create(postId: number, raw: string): EditPostRequest | null {
    const normalizedRaw: string = raw.trim();
    return !Number.isInteger(postId) || postId <= 0 || normalizedRaw.length === 0
      ? null
      : new EditPostRequest(postId, normalizedRaw);
  }
}

export class EditTopicRequest {
  public readonly topicId: number;
  public readonly title: string;
  public readonly originalTitle: string;
  public readonly categoryId: number;

  private constructor(topicId: number, title: string, originalTitle: string, categoryId: number) {
    this.topicId = topicId;
    this.title = title;
    this.originalTitle = originalTitle;
    this.categoryId = categoryId;
  }

  public static create(
    topicId: number,
    title: string,
    originalTitle: string,
    categoryId: number
  ): EditTopicRequest | null {
    const normalizedTitle: string = title.trim();
    const normalizedOriginalTitle: string = originalTitle.trim();
    return !Number.isInteger(topicId) || topicId <= 0 || normalizedTitle.length === 0 ||
      !Number.isInteger(categoryId) || categoryId <= 0
      ? null
      : new EditTopicRequest(topicId, normalizedTitle, normalizedOriginalTitle, categoryId);
  }
}

export class ServerDraft {
  public readonly draftKey: string;
  public readonly sequence: number;
  public readonly action: string;
  public readonly title: string;
  public readonly raw: string;
  public readonly categoryId: number | null;
  public readonly topicId: number | null;
  public readonly replyToPostNumber: number | null;

  public constructor(
    draftKey: string,
    sequence: number,
    action: string,
    title: string,
    raw: string,
    categoryId: number | null,
    topicId: number | null,
    replyToPostNumber: number | null
  ) {
    this.draftKey = draftKey;
    this.sequence = Math.max(0, sequence);
    this.action = action;
    this.title = title;
    this.raw = raw;
    this.categoryId = categoryId;
    this.topicId = topicId;
    this.replyToPostNumber = replyToPostNumber;
  }
}

export class DraftWriteRequest {
  public readonly draftKey: string;
  public readonly sequence: number;
  public readonly action: string;
  public readonly title: string;
  public readonly raw: string;
  public readonly categoryId: number | null;
  public readonly topicId: number | null;
  public readonly replyToPostNumber: number | null;

  private constructor(
    draftKey: string,
    sequence: number,
    action: string,
    title: string,
    raw: string,
    categoryId: number | null,
    topicId: number | null,
    replyToPostNumber: number | null
  ) {
    this.draftKey = draftKey;
    this.sequence = Math.max(0, sequence);
    this.action = action;
    this.title = title;
    this.raw = raw;
    this.categoryId = categoryId;
    this.topicId = topicId;
    this.replyToPostNumber = replyToPostNumber;
  }

  public static newTopic(
    title: string,
    raw: string,
    categoryId: number,
    sequence: number = 0,
    draftKey: string = 'new_topic'
  ): DraftWriteRequest | null {
    const normalizedTitle: string = title.trim();
    const normalizedRaw: string = raw.trim();
    const normalizedDraftKey: string = draftKey.trim();
    if ((normalizedTitle.length === 0 && normalizedRaw.length === 0) ||
      !Number.isInteger(categoryId) || categoryId <= 0 ||
      !normalizedDraftKey.startsWith('new_topic')) {
      return null;
    }
    return new DraftWriteRequest(
      normalizedDraftKey,
      sequence,
      'createTopic',
      normalizedTitle,
      normalizedRaw,
      categoryId,
      null,
      null
    );
  }

  public static reply(
    topicId: number,
    raw: string,
    replyToPostNumber: number | null,
    sequence: number = 0,
    draftKey: string = `topic_${topicId}`
  ): DraftWriteRequest | null {
    const normalizedRaw: string = raw.trim();
    const normalizedDraftKey: string = draftKey.trim();
    if (!Number.isInteger(topicId) || topicId <= 0 || normalizedRaw.length === 0 ||
      normalizedDraftKey.length === 0) {
      return null;
    }
    const normalizedReplyTo: number | null = replyToPostNumber !== null &&
      Number.isInteger(replyToPostNumber) && replyToPostNumber > 0
      ? replyToPostNumber
      : null;
    return new DraftWriteRequest(
      normalizedDraftKey,
      sequence,
      'reply',
      '',
      normalizedRaw,
      null,
      topicId,
      normalizedReplyTo
    );
  }

  public toData(): Object {
    const payload: DraftDataPayload = {
      action: this.action,
      title: this.title,
      reply: this.raw
    };
    if (this.categoryId !== null) {
      payload.category_id = this.categoryId;
    }
    if (this.topicId !== null) {
      payload.topic_id = this.topicId;
    }
    if (this.replyToPostNumber !== null) {
      payload.reply_to_post_number = this.replyToPostNumber;
    }
    return payload;
  }
}

export enum TopicSubmitKind {
  CREATED = 'created',
  REJECTED = 'rejected',
  UNCERTAIN = 'uncertain',
  UNAUTHORIZED = 'unauthorized'
}

export class TopicSubmitResult {
  public readonly kind: TopicSubmitKind;
  public readonly topicId: number | null;
  public readonly message: string;

  private constructor(kind: TopicSubmitKind, topicId: number | null, message: string) {
    this.kind = kind;
    this.topicId = topicId;
    this.message = message;
  }

  public static created(topicId: number): TopicSubmitResult {
    return new TopicSubmitResult(TopicSubmitKind.CREATED, topicId, 'Topic 已发布');
  }

  public static rejected(message: string): TopicSubmitResult {
    return new TopicSubmitResult(TopicSubmitKind.REJECTED, null, message);
  }

  public static uncertain(message: string): TopicSubmitResult {
    return new TopicSubmitResult(TopicSubmitKind.UNCERTAIN, null, message);
  }

  public static unauthorized(): TopicSubmitResult {
    return new TopicSubmitResult(TopicSubmitKind.UNAUTHORIZED, null, '登录已失效');
  }
}

export enum ComposerTool {
  BOLD = 'bold',
  ITALIC = 'italic',
  HEADING_1 = 'heading-1',
  HEADING_2 = 'heading-2',
  HEADING_3 = 'heading-3',
  HEADING_4 = 'heading-4',
  LINK = 'link',
  QUOTE = 'quote',
  CODE_BLOCK = 'code-block',
  INLINE_CODE = 'inline-code',
  BULLET_LIST = 'bullet-list',
  ORDERED_LIST = 'ordered-list',
  CHECKLIST = 'checklist',
  CHECKLIST_DONE = 'checklist-done',
  SPOILER = 'spoiler',
  TABLE_OF_CONTENTS = 'table-of-contents',
  TABLE = 'table',
  MATH = 'math',
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
  if (tool === ComposerTool.HEADING_4) {
    return headingEdit(source, selection, '####');
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
  if (tool === ComposerTool.CHECKLIST || tool === ComposerTool.CHECKLIST_DONE) {
    const marker: string = tool === ComposerTool.CHECKLIST ? '- [ ] ' : '- [x] ';
    return wrapSelection(source, selection, marker, '', '列表条目');
  }
  if (tool === ComposerTool.SPOILER) {
    return wrapSelection(source, selection, '[spoiler]', '[/spoiler]', '此文本将被模糊处理');
  }
  if (tool === ComposerTool.TABLE_OF_CONTENTS) {
    return insertBlock(source, selection, '<div data-theme-toc="true"> </div>');
  }
  if (tool === ComposerTool.TABLE) {
    return insertBlock(
      source,
      selection,
      '|第 1 列 | 第 2 列 | 第 3 列 |\n|--- | --- | ---|\n|1 | 2 | 3 |'
    );
  }
  if (tool === ComposerTool.MATH) {
    return insertBlock(source, selection, '$$\nE=mc^2\n$$');
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
