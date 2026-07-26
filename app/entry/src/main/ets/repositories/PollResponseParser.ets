import { ForumPlainTextContext, forumPlainText } from '../core/ForumPlainText';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  ForumPoll,
  ForumPollOption,
  ForumPollRankedVote,
  ForumPollResultsVisibility,
  forumPollResultsVisibilityFromValue,
  ForumPollStatus,
  ForumPollType,
  forumPollTypeFromValue,
  ForumPollVote,
  ForumRankedChoiceOutcome
} from '../models/PollModels';

function integerField(reader: JsonObjectReader, name: string, fallback: number): number {
  const numericValue: number | null = reader.number(name);
  if (numericValue !== null && Number.isFinite(numericValue)) {
    return Math.floor(numericValue);
  }
  const textValue: string | null = reader.string(name);
  if (textValue === null || !/^-?\d+$/.test(textValue.trim())) {
    return fallback;
  }
  const parsed: number = Number.parseInt(textValue, 10);
  return Number.isFinite(parsed) ? parsed : fallback;
}

function optionFromValue(value: Object | null): ForumPollOption | null {
  const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
  if (reader === null) {
    return null;
  }
  const id: string = reader.string('id')?.trim() ?? '';
  if (id.length === 0) {
    return null;
  }
  const votes: number | null = reader.has('votes')
    ? Math.max(0, integerField(reader, 'votes', 0))
    : null;
  return new ForumPollOption(id, reader.string('html') ?? '', votes);
}

function optionsFromReader(reader: JsonObjectReader): Array<ForumPollOption> {
  const values: Array<Object | null> | null = reader.array('options');
  const options: Array<ForumPollOption> = [];
  if (values === null) {
    return options;
  }
  for (const value of values) {
    const option: ForumPollOption | null = optionFromValue(value);
    if (option !== null) {
      options.push(option);
    }
  }
  return options;
}

function voteFromValues(
  values: Array<Object | null> | null,
  type: ForumPollType
): ForumPollVote {
  if (values === null) {
    return ForumPollVote.empty();
  }
  if (type === ForumPollType.RANKED_CHOICE) {
    const rankedVotes: Array<ForumPollRankedVote> = [];
    for (const value of values) {
      const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      if (reader !== null) {
        rankedVotes.push(new ForumPollRankedVote(
          reader.string('digest') ?? '',
          integerField(reader, 'rank', 0)
        ));
      }
    }
    return ForumPollVote.ranked(rankedVotes);
  }
  const optionIds: Array<string> = [];
  for (const value of values) {
    if (typeof value === 'string') {
      optionIds.push(value);
    }
  }
  return ForumPollVote.options(optionIds);
}

function tiedOptionHtml(outcome: JsonObjectReader): Array<string> {
  const values: Array<Object | null> | null = outcome.array('tied_candidates');
  const html: Array<string> = [];
  if (values === null) {
    return html;
  }
  for (const value of values) {
    const candidate: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    const candidateHtml: string = candidate?.string('html') ?? '';
    if (candidateHtml.length > 0) {
      html.push(candidateHtml);
    }
  }
  return html;
}

function rankedChoiceOutcomeFromReader(
  reader: JsonObjectReader
): ForumRankedChoiceOutcome | null {
  const outcome: JsonObjectReader | null = reader.object('ranked_choice_outcome');
  if (outcome === null) {
    return null;
  }
  const winnerHtml: string = outcome.object('winning_candidate')?.string('html') ?? '';
  const parsed: ForumRankedChoiceOutcome =
    new ForumRankedChoiceOutcome(winnerHtml, tiedOptionHtml(outcome));
  return parsed.isAvailable() ? parsed : null;
}

function pollFromReader(
  reader: JsonObjectReader,
  vote: ForumPollVote,
  fallbackName: string = ''
): ForumPoll | null {
  const name: string = reader.string('name')?.trim() || fallbackName.trim();
  const options: Array<ForumPollOption> = optionsFromReader(reader);
  if (name.length === 0 || options.length === 0) {
    return null;
  }
  const type: ForumPollType = forumPollTypeFromValue(reader.string('type'));
  const min: number = Math.max(1, integerField(reader, 'min', 1));
  const max: number = Math.max(min, integerField(reader, 'max', options.length));
  const titleHtml: string = reader.string('title') ?? '';
  return new ForumPoll(
    name,
    forumPlainText(titleHtml, ForumPlainTextContext.POST),
    type,
    reader.string('status') === ForumPollStatus.CLOSED
      ? ForumPollStatus.CLOSED
      : ForumPollStatus.OPEN,
    forumPollResultsVisibilityFromValue(reader.string('results')),
    reader.boolean('public') ?? false,
    min,
    max,
    options,
    Math.max(0, integerField(reader, 'voters', 0)),
    reader.string('close'),
    vote,
    rankedChoiceOutcomeFromReader(reader)
  );
}

export function forumPollsFromPostReader(post: JsonObjectReader): Array<ForumPoll> {
  const values: Array<Object | null> | null = post.array('polls');
  const polls: Array<ForumPoll> = [];
  if (values === null) {
    return polls;
  }
  const votesByPoll: JsonObjectReader | null = post.object('polls_votes');
  for (const value of values) {
    const reader: JsonObjectReader | null = JsonObjectReader.fromValue(value);
    if (reader === null) {
      continue;
    }
    const name: string = reader.string('name')?.trim() ?? '';
    const type: ForumPollType = forumPollTypeFromValue(reader.string('type'));
    const vote: ForumPollVote = voteFromValues(votesByPoll?.array(name) ?? null, type);
    const poll: ForumPoll | null = pollFromReader(reader, vote);
    if (poll !== null) {
      polls.push(poll);
    }
  }
  return polls;
}

export class PollResponseParser {
  public parseMutation(
    text: string,
    fallbackPollName: string,
    removingVote: boolean = false
  ): RepositoryResult<ForumPoll> {
    const envelope: JsonObjectReader | null = JsonObjectReader.parse(text);
    const pollReader: JsonObjectReader | null = envelope?.object('poll') ?? null;
    if (envelope === null || pollReader === null) {
      return RepositoryResult.invalidResponse<ForumPoll>('服务器响应缺少 Poll');
    }
    const type: ForumPollType = forumPollTypeFromValue(pollReader.string('type'));
    const vote: ForumPollVote = removingVote
      ? ForumPollVote.empty()
      : voteFromValues(envelope.array('vote'), type);
    const poll: ForumPoll | null = pollFromReader(pollReader, vote, fallbackPollName);
    if (poll === null) {
      return RepositoryResult.invalidResponse<ForumPoll>('服务器 Poll 响应格式无效');
    }
    return RepositoryResult.success<ForumPoll>(poll);
  }
}
