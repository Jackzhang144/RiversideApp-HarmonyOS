import { describe, expect, it } from '@ohos/hypium';
import {
  ForumPoll,
  ForumPollOption,
  ForumPollResultsVisibility,
  ForumPollStatus,
  ForumPollType,
  ForumPollVote
} from '../../../main/ets/models/PollModels';
import {
  pollTypeLabel,
  rankedPollVote,
  savedRankedOptionIds,
  toggledPollOptionIds,
  toggledRankedOptionIds
} from '../../../main/ets/components/PollPresentation';

function rankedPoll(vote: ForumPollVote = ForumPollVote.empty()): ForumPoll {
  return new ForumPoll(
    'ranked',
    '排序投票',
    ForumPollType.RANKED_CHOICE,
    ForumPollStatus.OPEN,
    ForumPollResultsVisibility.ON_VOTE,
    false,
    1,
    3,
    [
      new ForumPollOption('a', '甲'),
      new ForumPollOption('b', '乙'),
      new ForumPollOption('c', '丙')
    ],
    0,
    null,
    vote
  );
}

export default function pollPresentationTest(): void {
  describe('Poll presentation', () => {
    it('toggles multiple selections without reordering the remaining options', 0, () => {
      expect(toggledPollOptionIds(['a', 'b'], 'a').join(',')).assertEqual('b');
      expect(toggledPollOptionIds(['a'], 'c').join(',')).assertEqual('a,c');
    });

    it('compacts ranked selections after removing an option', 0, () => {
      const options: Array<string> = toggledRankedOptionIds(['a', 'b', 'c'], 'b');
      expect(options.join(',')).assertEqual('a,c');
      const vote: ForumPollVote = rankedPollVote(rankedPoll().options, options);
      expect(vote.rankFor('a')).assertEqual(1);
      expect(vote.rankFor('b')).assertEqual(0);
      expect(vote.rankFor('c')).assertEqual(2);
    });

    it('restores saved ranked selections in rank order', 0, () => {
      const poll: ForumPoll = rankedPoll(rankedPollVote(
        rankedPoll().options,
        ['c', 'a']
      ));
      expect(savedRankedOptionIds(poll).join(',')).assertEqual('c,a');
      expect(poll.canSubmit(poll.vote)).assertTrue();
      expect(pollTypeLabel(poll)).assertEqual('按偏好排序');
    });
  });
}
