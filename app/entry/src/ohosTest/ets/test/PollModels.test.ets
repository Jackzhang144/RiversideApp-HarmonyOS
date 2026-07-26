import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { ForumPost } from '../../../main/ets/models/ForumModels';
import {
  ForumPoll,
  ForumPollOption,
  ForumPollRankedVote,
  ForumPollResultsVisibility,
  ForumPollStatus,
  ForumPollType,
  ForumPollVote,
  removeDiscoursePollMarkup
} from '../../../main/ets/models/PollModels';
import { TopicResponseParser } from '../../../main/ets/repositories/TopicResponseParser';

function poll(
  type: ForumPollType,
  min: number = 1,
  max: number = 3
): ForumPoll {
  return new ForumPoll(
    'poll',
    '选择一个答案',
    type,
    ForumPollStatus.OPEN,
    ForumPollResultsVisibility.ALWAYS,
    true,
    min,
    max,
    [
      new ForumPollOption('a', 'A', 2),
      new ForumPollOption('b', 'B', 1),
      new ForumPollOption('c', 'C', 0)
    ],
    3,
    null
  );
}

export default function pollModelsTest(): void {
  describe('Discourse Poll models', () => {
    it('validates regular, multiple and ranked-choice ballots', 0, () => {
      expect(poll(ForumPollType.REGULAR).canSubmit(ForumPollVote.options(['a']))).assertTrue();
      expect(poll(ForumPollType.REGULAR).canSubmit(ForumPollVote.options(['a', 'b']))).assertFalse();
      expect(poll(ForumPollType.MULTIPLE, 2, 3).canSubmit(ForumPollVote.options(['a']))).assertFalse();
      expect(poll(ForumPollType.MULTIPLE, 2, 3).canSubmit(ForumPollVote.options(['a', 'b']))).assertTrue();

      const ranked: ForumPollVote = ForumPollVote.ranked([
        new ForumPollRankedVote('a', 1),
        new ForumPollRankedVote('b', 2),
        new ForumPollRankedVote('c', 0)
      ]);
      const duplicateRank: ForumPollVote = ForumPollVote.ranked([
        new ForumPollRankedVote('a', 1),
        new ForumPollRankedVote('b', 1),
        new ForumPollRankedVote('c', 0)
      ]);
      expect(poll(ForumPollType.RANKED_CHOICE).canSubmit(ranked)).assertTrue();
      expect(poll(ForumPollType.RANKED_CHOICE).canSubmit(duplicateRank)).assertFalse();
    });

    it('removes balanced cooked Poll markup without dropping surrounding content', 0, () => {
      const cooked: string =
        '<p>投票前</p><div class="poll" data-poll-name="poll">' +
        '<div class="poll-container"><ol><li>选项</li></ol></div>' +
        '<div class="poll-info"><span>1 voter</span></div></div><p>投票后</p>';

      expect(removeDiscoursePollMarkup(cooked)).assertEqual('<p>投票前</p><p>投票后</p>');
    });

    it('decodes Post Polls, dynamic votes and readable option content', 0, () => {
      const parser: TopicResponseParser = new TopicResponseParser();
      const result: RepositoryResult<Array<ForumPost>> = parser.parseTopicPosts(
        '{"post_stream":{"posts":[{' +
        '"id":102728,"user_id":24,"username":"Co-admin","post_number":1,' +
        '"raw":"投票","cooked":"<p>请选择</p><div class=\\"poll\\"></div>",' +
        '"polls":[' +
        '{"name":"poll","type":"regular","status":"open","results":"always",' +
        '"public":true,"voters":3,"title":"<strong>最喜欢哪个？</strong>",' +
        '"options":[{"id":"a","html":"苹果","votes":2},' +
        '{"id":"b","html":"<em>香蕉</em>","votes":1}]},' +
        '{"name":"ranked","type":"ranked_choice","status":"closed","results":"on_close",' +
        '"voters":2,"options":[{"id":"x","html":"甲"},{"id":"y","html":"乙"}],' +
        '"ranked_choice_outcome":{"winning_candidate":{"html":"<b>甲</b>"}}}' +
        '],"polls_votes":{"poll":["a"],"ranked":[' +
        '{"digest":"x","rank":1},{"digest":"y","rank":0}]}' +
        '}]}}'
      );

      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.[0].polls.length).assertEqual(2);
      expect(result.data?.[0].polls[0].title).assertEqual('最喜欢哪个？');
      expect(result.data?.[0].polls[0].options[1].text).assertEqual('香蕉');
      expect(result.data?.[0].polls[0].vote.includes('a')).assertTrue();
      expect(result.data?.[0].polls[0].resultPercentage(result.data[0].polls[0].options[0]))
        .assertEqual(67);
      expect(result.data?.[0].polls[1].type).assertEqual(ForumPollType.RANKED_CHOICE);
      expect(result.data?.[0].polls[1].vote.rankFor('x')).assertEqual(1);
      expect(result.data?.[0].polls[1].rankedChoiceOutcome?.winnerText).assertEqual('甲');
      expect(result.data?.[0].withBookmark(true, 88).polls.length).assertEqual(2);
    });
  });
}
