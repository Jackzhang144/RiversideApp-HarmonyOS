import { ComposerEdit } from './AuthoringModels';

export class ComposerMentionUser {
  public readonly username: string;
  public readonly name: string;
  public readonly avatarTemplate: string;

  public constructor(username: string, name: string, avatarTemplate: string) {
    this.username = username.trim();
    this.name = name.trim();
    this.avatarTemplate = avatarTemplate.trim();
  }
}

export class ComposerMentionQuery {
  public readonly term: string;
  public readonly start: number;
  public readonly end: number;

  public constructor(term: string, start: number, end: number) {
    this.term = term;
    this.start = start;
    this.end = end;
  }
}

function isWhitespace(value: string): boolean {
  return value === ' ' || value === '\n' || value === '\r' || value === '\t';
}

export function findComposerMentionQuery(source: string, cursor: number): ComposerMentionQuery | null {
  if (!Number.isSafeInteger(cursor) || cursor < 0 || cursor > source.length) {
    return null;
  }
  let start: number = cursor;
  while (start > 0 && !isWhitespace(source.charAt(start - 1))) {
    start -= 1;
  }
  if (start >= cursor || source.charAt(start) !== '@') {
    return null;
  }
  const term: string = source.substring(start + 1, cursor);
  if (term.length === 0 || term.includes('@')) {
    return null;
  }
  return new ComposerMentionQuery(term, start, cursor);
}

export function applyComposerMention(source: string, cursor: number, username: string): ComposerEdit | null {
  const query: ComposerMentionQuery | null = findComposerMentionQuery(source, cursor);
  const normalizedUsername: string = username.trim();
  if (query === null || normalizedUsername.length === 0 || normalizedUsername.includes(' ')) {
    return null;
  }
  const replacement: string = `@${normalizedUsername} `;
  const suffixStart: number = source.charAt(query.end) === ' ' ? query.end + 1 : query.end;
  const text: string = source.substring(0, query.start) + replacement + source.substring(suffixStart);
  const restoredCursor: number = query.start + replacement.length;
  return new ComposerEdit(text, restoredCursor, restoredCursor);
}

export class ComposerMentionRequestGate {
  private generation: number = 0;

  public issue(): number {
    this.generation += 1;
    return this.generation;
  }

  public invalidate(): void {
    this.generation += 1;
  }

  public isCurrent(generation: number): boolean {
    return generation === this.generation;
  }
}
