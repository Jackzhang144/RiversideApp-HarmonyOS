import { describe, expect, it } from '@ohos/hypium';
import { ReplyRequest } from '../../../main/ets/models/ReplyModels';

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
  });
}
