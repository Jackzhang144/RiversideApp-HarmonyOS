import { ForumPlainTextContext, forumPlainText } from '../core/ForumPlainText';

export enum ForumPollType {
  REGULAR = 'regular',
  MULTIPLE = 'multiple',
  NUMBER = 'number',
  RANKED_CHOICE = 'ranked_choice',
  UNKNOWN = 'unknown'
}

export enum ForumPollStatus {
  OPEN = 'open',
  CLOSED = 'closed'
}

export enum ForumPollResultsVisibility {
  ALWAYS = 'always',
  ON_VOTE = 'on_vote',
  ON_CLOSE = 'on_close',
  STAFF_ONLY = 'staff_only',
  UNKNOWN = 'unknown'
}

export class ForumPollOption {
  public readonly id: string;
  public readonly html: string;
  public readonly text: string;
  public readonly votes: number | null;

  public constructor(id: string, html: string, votes: number | null = null) {
    this.id = id.trim();
    this.html = html.trim();
    const accessibleHtml: string = this.html
      .replace(/<img\b[^>]*\balt=["']([^"']*)["'][^>]*>/gi, ' $1 ')
      .replace(/<img\b[^>]*\btitle=["']([^"']*)["'][^>]*>/gi, ' $1 ');
    this.text = forumPlainText(accessibleHtml, ForumPlainTextContext.POST);
    this.votes = votes === null ? null : Math.max(0, Math.floor(votes));
  }
}

export class ForumPollRankedVote {
  public readonly digest: string;
  public readonly rank: number;

  public constructor(digest: string, rank: number) {
    this.digest = digest.trim();
    this.rank = Number.isInteger(rank) && rank > 0 ? rank : 0;
  }
}

function uniqueOptionIds(values: Array<string>): Array<string> {
  const ids: Array<string> = [];
  const seen: Set<string> = new Set<string>();
  for (const value of values) {
    const id: string = value.trim();
    if (id.length > 0 && !seen.has(id)) {
      seen.add(id);
      ids.push(id);
    }
  }
  return ids;
}

function uniqueRankedVotes(values: Array<ForumPollRankedVote>): Array<ForumPollRankedVote> {
  const votes: Array<ForumPollRankedVote> = [];
  const seen: Set<string> = new Set<string>();
  for (const value of values) {
    if (value.digest.length > 0 && !seen.has(value.digest)) {
      seen.add(value.digest);
      votes.push(value);
    }
  }
  return votes;
}

export class ForumPollVote {
  public readonly optionIds: Array<string>;
  public readonly rankedVotes: Array<ForumPollRankedVote>;

  public constructor(
    optionIds: Array<string> = [],
    rankedVotes: Array<ForumPollRankedVote> = []
  ) {
    this.optionIds = uniqueOptionIds(optionIds);
    this.rankedVotes = uniqueRankedVotes(rankedVotes);
  }

  public static empty(): ForumPollVote {
    return new ForumPollVote();
  }

  public static options(optionIds: Array<string>): ForumPollVote {
    return new ForumPollVote(optionIds);
  }

  public static ranked(rankedVotes: Array<ForumPollRankedVote>): ForumPollVote {
    return new ForumPollVote([], rankedVotes);
  }

  public hasSelection(): boolean {
    if (this.optionIds.length > 0) {
      return true;
    }
    return this.rankedVotes.some((vote: ForumPollRankedVote): boolean => vote.rank > 0);
  }

  public includes(optionId: string): boolean {
    return this.optionIds.includes(optionId);
  }

  public rankFor(optionId: string): number {
    const vote: ForumPollRankedVote | undefined = this.rankedVotes.find(
      (candidate: ForumPollRankedVote): boolean => candidate.digest === optionId
    );
    return vote?.rank ?? 0;
  }
}

export class ForumRankedChoiceOutcome {
  public readonly winnerText: string;
  public readonly tiedOptionTexts: Array<string>;

  public constructor(winnerHtml: string = '', tiedOptionHtml: Array<string> = []) {
    this.winnerText = forumPlainText(winnerHtml, ForumPlainTextContext.POST);
    this.tiedOptionTexts = tiedOptionHtml
      .map((html: string): string => forumPlainText(html, ForumPlainTextContext.POST))
      .filter((text: string): boolean => text.length > 0);
  }

  public isAvailable(): boolean {
    return this.winnerText.length > 0 || this.tiedOptionTexts.length > 0;
  }
}

export class ForumPoll {
  public readonly name: string;
  public readonly title: string;
  public readonly type: ForumPollType;
  public readonly status: ForumPollStatus;
  public readonly resultsVisibility: ForumPollResultsVisibility;
  public readonly isPublic: boolean;
  public readonly min: number;
  public readonly max: number;
  public readonly options: Array<ForumPollOption>;
  public readonly voters: number;
  public readonly closeAt: string | null;
  public readonly vote: ForumPollVote;
  public readonly rankedChoiceOutcome: ForumRankedChoiceOutcome | null;

  public constructor(
    name: string,
    title: string,
    type: ForumPollType,
    status: ForumPollStatus,
    resultsVisibility: ForumPollResultsVisibility,
    isPublic: boolean,
    min: number,
    max: number,
    options: Array<ForumPollOption>,
    voters: number,
    closeAt: string | null,
    vote: ForumPollVote = ForumPollVote.empty(),
    rankedChoiceOutcome: ForumRankedChoiceOutcome | null = null
  ) {
    this.name = name.trim();
    this.title = title.trim();
    this.type = type;
    this.status = status;
    this.resultsVisibility = resultsVisibility;
    this.isPublic = isPublic;
    this.options = options;
    const optionCount: number = Math.max(1, options.length);
    this.min = Math.min(optionCount, Math.max(1, Math.floor(min)));
    this.max = Math.min(optionCount, Math.max(this.min, Math.floor(max)));
    this.voters = Math.max(0, Math.floor(voters));
    this.closeAt = closeAt?.trim() || null;
    this.vote = vote;
    this.rankedChoiceOutcome = rankedChoiceOutcome;
  }

  public isClosed(nowMilliseconds: number = Date.now()): boolean {
    if (this.status === ForumPollStatus.CLOSED) {
      return true;
    }
    if (this.closeAt === null) {
      return false;
    }
    const closeMilliseconds: number = Date.parse(this.closeAt);
    return Number.isFinite(closeMilliseconds) && closeMilliseconds <= nowMilliseconds;
  }

  public hasSavedVote(): boolean {
    return this.vote.hasSelection();
  }

  public hasResults(): boolean {
    return this.options.some((option: ForumPollOption): boolean => option.votes !== null) ||
      (this.rankedChoiceOutcome?.isAvailable() ?? false);
  }

  public canSubmit(vote: ForumPollVote): boolean {
    if (this.isClosed()) {
      return false;
    }
    if (this.type === ForumPollType.MULTIPLE) {
      return vote.optionIds.length >= this.min && vote.optionIds.length <= this.max;
    }
    if (this.type === ForumPollType.RANKED_CHOICE) {
      if (vote.rankedVotes.length !== this.options.length) {
        return false;
      }
      const ranks: Set<number> = new Set<number>();
      let hasRank: boolean = false;
      for (const rankedVote of vote.rankedVotes) {
        if (rankedVote.rank <= 0) {
          continue;
        }
        if (ranks.has(rankedVote.rank)) {
          return false;
        }
        ranks.add(rankedVote.rank);
        hasRank = true;
      }
      return hasRank;
    }
    return vote.optionIds.length === 1;
  }

  public resultPercentage(option: ForumPollOption): number {
    if (option.votes === null || this.voters <= 0) {
      return 0;
    }
    return Math.max(0, Math.min(100, Math.round(option.votes / this.voters * 100)));
  }

  public resultOptions(): Array<ForumPollOption> {
    const options: Array<ForumPollOption> = Array.from(this.options);
    options.sort((left: ForumPollOption, right: ForumPollOption): number => {
      const voteDifference: number = (right.votes ?? 0) - (left.votes ?? 0);
      return voteDifference !== 0 ? voteDifference : left.text.localeCompare(right.text);
    });
    return options;
  }
}

export function forumPollTypeFromValue(value: string | null): ForumPollType {
  if (value === ForumPollType.MULTIPLE) {
    return ForumPollType.MULTIPLE;
  }
  if (value === ForumPollType.NUMBER) {
    return ForumPollType.NUMBER;
  }
  if (value === ForumPollType.RANKED_CHOICE) {
    return ForumPollType.RANKED_CHOICE;
  }
  if (value === ForumPollType.REGULAR) {
    return ForumPollType.REGULAR;
  }
  return ForumPollType.UNKNOWN;
}

export function forumPollResultsVisibilityFromValue(
  value: string | null
): ForumPollResultsVisibility {
  if (value === ForumPollResultsVisibility.ALWAYS) {
    return ForumPollResultsVisibility.ALWAYS;
  }
  if (value === ForumPollResultsVisibility.ON_VOTE) {
    return ForumPollResultsVisibility.ON_VOTE;
  }
  if (value === ForumPollResultsVisibility.ON_CLOSE) {
    return ForumPollResultsVisibility.ON_CLOSE;
  }
  if (value === ForumPollResultsVisibility.STAFF_ONLY) {
    return ForumPollResultsVisibility.STAFF_ONLY;
  }
  return ForumPollResultsVisibility.UNKNOWN;
}

export function removeDiscoursePollMarkup(html: string): string {
  const tagPattern: RegExp = /<\/?div\b[^>]*>/gi;
  let output: string = '';
  let cursor: number = 0;
  let pollStart: number = -1;
  let depth: number = 0;
  let match: RegExpExecArray | null = tagPattern.exec(html);
  while (match !== null) {
    const tag: string = match[0];
    const closing: boolean = /^<\s*\//.test(tag);
    if (pollStart < 0) {
      const pollContainer: boolean = !closing &&
        /\bclass=["'][^"']*\bpoll\b[^"']*["']/i.test(tag);
      if (pollContainer) {
        output += html.slice(cursor, match.index);
        pollStart = match.index;
        depth = 1;
      }
    } else if (closing) {
      depth -= 1;
      if (depth === 0) {
        cursor = tagPattern.lastIndex;
        pollStart = -1;
      }
    } else {
      depth += 1;
    }
    match = tagPattern.exec(html);
  }
  if (pollStart >= 0) {
    return output + html.slice(pollStart);
  }
  return output + html.slice(cursor);
}
