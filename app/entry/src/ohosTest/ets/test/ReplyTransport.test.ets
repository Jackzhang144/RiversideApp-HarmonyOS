import { describe, expect, it } from '@ohos/hypium';
import { ReplyRequest } from '../../../main/ets/models/ReplyModels';
import { DiscourseReplyPayload } from '../../../main/ets/network/DiscourseHttpClient';

export default function replyTransportTest(): void {
  describe('Discourse Reply transport payload', () => {
    it('encodes a Topic Reply without a Post target', 0, () => {
      const request: ReplyRequest | null = ReplyRequest.create(2725, '**收到**', null);
      expect(request === null).assertFalse();
      if (request === null) {
        return;
      }

      const payload: DiscourseReplyPayload = new DiscourseReplyPayload(request);

      expect(JSON.stringify(payload.toHttpExtraData())).assertEqual(
        '{"topic_id":2725,"raw":"**收到**"}'
      );
    });

    it('encodes reply_to_post_number only for a targeted Post Reply', 0, () => {
      const request: ReplyRequest | null = ReplyRequest.create(2725, '具体回复', 3);
      expect(request === null).assertFalse();
      if (request === null) {
        return;
      }

      const payload: DiscourseReplyPayload = new DiscourseReplyPayload(request);

      expect(JSON.stringify(payload.toHttpExtraData())).assertEqual(
        '{"topic_id":2725,"raw":"具体回复","reply_to_post_number":3}'
      );
    });
  });
}
