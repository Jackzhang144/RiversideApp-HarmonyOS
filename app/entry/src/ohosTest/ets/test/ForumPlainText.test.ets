import { describe, expect, it } from '@ohos/hypium';
import {
  forumPlainText,
  forumPostPlainText,
  ForumPlainTextContext
} from '../../../main/ets/core/ForumPlainText';

export default function forumPlainTextTest(): void {
  describe('ForumPlainText', () => {
    it('keeps context-specific line and image semantics behind one formatter', 0, () => {
      const source: string = '<script>bad()</script><p>河畔&nbsp;<strong>校友</strong><br>第二行</p>';
      expect(forumPlainText(source, ForumPlainTextContext.PROFILE)).assertEqual('河畔 校友\n第二行');
      expect(forumPlainText(source, ForumPlainTextContext.DISCOVERY)).assertEqual('河畔 校友 第二行');
      expect(forumPlainText('<p>消息<img alt=":wave:" src="x"></p>', ForumPlainTextContext.CHAT))
        .assertEqual('消息 :wave:');
      expect(forumPlainText('<p>通知 <strong>内容</strong></p>', ForumPlainTextContext.NOTIFICATION))
        .assertEqual('通知 内容');
    });

    it('keeps post list markers and falls back to raw content', 0, () => {
      expect(forumPostPlainText('raw fallback', '')).assertEqual('raw fallback');
      expect(forumPostPlainText('', '<ul><li>第一项</li><li>第二项</li></ul>'))
        .assertEqual('• 第一项\n• 第二项');
    });
  });
}
