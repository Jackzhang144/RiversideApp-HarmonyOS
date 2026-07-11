import { describe, expect, it } from '@ohos/hypium';
import { ForumPost } from '../../../main/ets/models/ForumModels';
import { CurrentUser, ReplyRecoveryRequest, ReplyRequest } from '../../../main/ets/models/ReplyModels';

export default function replyBoundaryTest(): void {
  describe('Reply request boundary', () => {
    it('rejects blank input and invalid Topic or Post targets', 0, () => {
      expect(ReplyRequest.create(2725, '   ', null)).assertNull();
      expect(ReplyRequest.create(0, '有效 Reply', null)).assertNull();
      expect(ReplyRequest.create(2725, '有效 Reply', 0)).assertNull();
    });

    it('normalizes a Topic Reply while preserving Markdown source', 0, () => {
      const request: ReplyRequest | null = ReplyRequest.create(
        2725,
        '  **Markdown** Reply  ',
        null
      );

      expect(request === null).assertFalse();
      expect(request?.topicId).assertEqual(2725);
      expect(request?.raw).assertEqual('**Markdown** Reply');
      expect(request?.replyToPostNumber).assertNull();
    });

    it('models a Reply addressed to a specific Post', 0, () => {
      const request: ReplyRequest | null = ReplyRequest.create(2725, '收到', 3);

      expect(request === null).assertFalse();
      expect(request?.replyToPostNumber).assertEqual(3);
    });

    it('does not recover a Topic Reply from a Post-targeted candidate', 0, () => {
      const reply: ReplyRequest | null = ReplyRequest.create(2725, '收到', null);
      const user: CurrentUser | null = CurrentUser.create(24, 'Co-admin');
      const recovery: ReplyRecoveryRequest | null = reply === null || user === null
        ? null
        : ReplyRecoveryRequest.create(reply, 4, user);
      if (recovery === null) {
        expect(false).assertTrue();
        return;
      }
      const targeted: ForumPost = new ForumPost(
        102731, 24, 'Co-admin', '<p>收到</p>', '收到', 4, 3, '2026-01-28T00:02:00Z'
      );
      const topicReply: ForumPost = new ForumPost(
        102732, 24, 'Co-admin', '<p>收到</p>', '收到', 5, null, '2026-01-28T00:03:00Z'
      );

      expect(recovery.matches(targeted)).assertFalse();
      expect(recovery.matches(topicReply)).assertTrue();
    });
  });
}
