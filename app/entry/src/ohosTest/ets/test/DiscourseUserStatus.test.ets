import { describe, expect, it } from '@ohos/hypium';
import { DiscourseUserStatus } from '../../../main/ets/models/DiscourseUserStatus';

export default function discourseUserStatusTest(): void {
  describe('Discourse user status contract', () => {
    it('keeps an active status and resolves its emoji image', 0, () => {
      const status: DiscourseUserStatus | null = DiscourseUserStatus.create(
        ' 正在图书馆 ',
        ':books:',
        '2026-08-01T08:00:00Z',
        Date.parse('2026-07-27T08:00:00Z')
      );

      expect(status === null).assertFalse();
      expect(status?.description).assertEqual('正在图书馆');
      expect(status?.emoji).assertEqual('books');
      expect(status?.endsAt).assertEqual('2026-08-01T08:00:00Z');
      expect(status?.emojiUrl())
        .assertEqual('https://river-side.cc/images/emoji/twitter/books.png?v=15');
    });

    it('drops empty, expired, and malformed expiry values', 0, () => {
      const nowMs: number = Date.parse('2026-07-27T08:00:00Z');

      expect(DiscourseUserStatus.create('  ', 'books', null, nowMs)).assertNull();
      expect(DiscourseUserStatus.create(
        '已经过期',
        'books',
        '2026-07-27T07:59:59Z',
        nowMs
      )).assertNull();
      expect(DiscourseUserStatus.create('时间异常', 'books', 'not-a-date', nowMs)).assertNull();
    });

    it('keeps the description but rejects an unsafe emoji identifier', 0, () => {
      const status: DiscourseUserStatus | null = DiscourseUserStatus.create(
        '专注中',
        '../custom',
        null
      );

      expect(status?.description).assertEqual('专注中');
      expect(status?.emoji).assertEqual('');
      expect(status?.emojiUrl()).assertEqual('');
    });
  });
}
