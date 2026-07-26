import {
  ForumPoll,
  ForumPollOption,
  ForumPollRankedVote,
  ForumPollType,
  ForumPollVote
} from '../models/PollModels';

export function pollTypeLabel(poll: ForumPoll): string {
  if (poll.type === ForumPollType.MULTIPLE) {
    return poll.min === poll.max
      ? `选择 ${poll.min} 项`
      : `选择 ${poll.min}–${poll.max} 项`;
  }
  if (poll.type === ForumPollType.RANKED_CHOICE) {
    return '按偏好排序';
  }
  if (poll.type === ForumPollType.NUMBER) {
    return '选择一个数字';
  }
  return '单选';
}

export function toggledPollOptionIds(
  selectedOptionIds: Array<string>,
  optionId: string
): Array<string> {
  if (selectedOptionIds.includes(optionId)) {
    return selectedOptionIds.filter((candidate: string): boolean => candidate !== optionId);
  }
  return [...selectedOptionIds, optionId];
}

export function toggledRankedOptionIds(
  rankedOptionIds: Array<string>,
  optionId: string
): Array<string> {
  if (rankedOptionIds.includes(optionId)) {
    return rankedOptionIds.filter((candidate: string): boolean => candidate !== optionId);
  }
  return [...rankedOptionIds, optionId];
}

export function rankedPollVote(
  options: Array<ForumPollOption>,
  rankedOptionIds: Array<string>
): ForumPollVote {
  const votes: Array<ForumPollRankedVote> = options.map(
    (option: ForumPollOption): ForumPollRankedVote => {
      const rankIndex: number = rankedOptionIds.indexOf(option.id);
      return new ForumPollRankedVote(option.id, rankIndex < 0 ? 0 : rankIndex + 1);
    }
  );
  return ForumPollVote.ranked(votes);
}

export function savedRankedOptionIds(poll: ForumPoll): Array<string> {
  const rankedVotes: Array<ForumPollRankedVote> = poll.vote.rankedVotes
    .filter((vote: ForumPollRankedVote): boolean => vote.rank > 0)
    .sort((left: ForumPollRankedVote, right: ForumPollRankedVote): number => left.rank - right.rank);
  return rankedVotes.map((vote: ForumPollRankedVote): string => vote.digest);
}
