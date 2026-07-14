import { describe, expect, it } from '@ohos/hypium';
import {
  applyComposerTool,
  autoReplyQuote,
  ComposerEdit,
  ComposerTool
} from '../../../main/ets/models/AuthoringModels';
import { ForumPost } from '../../../main/ets/models/ForumModels';

export default function authoringModelsTest(): void {
  describe('Topic authoring public behavior', () => {
    it('applies Markdown tools to the active text selection', 0, () => {
      const bold: ComposerEdit = applyComposerTool('前缀正文后缀', 2, 4, ComposerTool.BOLD);
      const link: ComposerEdit = applyComposerTool('', 0, 0, ComposerTool.LINK);
      const list: ComposerEdit = applyComposerTool('第一项\n第二项', 0, 7, ComposerTool.ORDERED_LIST);
      const code: ComposerEdit = applyComposerTool('print(1)', 0, 8, ComposerTool.CODE_BLOCK);

      expect(bold.text).assertEqual('前缀**正文**后缀');
      expect(link.text).assertEqual('[链接文本（可选）](https://example.com)');
      expect(link.selectionStart).assertEqual(1);
      expect(link.selectionEnd).assertEqual(9);
      expect(list.text).assertEqual('1. 第一项\n2. 第二项');
      expect(code.text).assertEqual('```\nprint(1)\n```');
    });

    it('inserts the frozen Discourse poll templates', 0, () => {
      const regular: ComposerEdit = applyComposerTool('', 0, 0, ComposerTool.POLL_SINGLE);
      const multiple: ComposerEdit = applyComposerTool('', 0, 0, ComposerTool.POLL_MULTIPLE);

      expect(regular.text).assertEqual(
        '[poll type=regular results=always public=true chartType=bar]\n' +
          '* 1\n* 2\n* 3\n[/poll]'
      );
      expect(multiple.text).assertEqual(
        '[poll name=poll2 type=multiple results=always min=1 max=2 public=true chartType=bar]\n' +
          '* 1\n* 2\n* 3\n[/poll]'
      );
    });

    it('covers every frozen non-media composer template', 0, () => {
      expect(applyComposerTool('', 0, 0, ComposerTool.HEADING_4).text).assertEqual('#### 标题');
      expect(applyComposerTool('', 0, 0, ComposerTool.INLINE_CODE).text).assertEqual('`code`');
      expect(applyComposerTool('', 0, 0, ComposerTool.CHECKLIST).text).assertEqual('- [ ] 列表条目');
      expect(applyComposerTool('', 0, 0, ComposerTool.CHECKLIST_DONE).text).assertEqual('- [x] 列表条目');
      expect(applyComposerTool('', 0, 0, ComposerTool.SPOILER).text)
        .assertEqual('[spoiler]此文本将被模糊处理[/spoiler]');
      expect(applyComposerTool('', 0, 0, ComposerTool.TABLE_OF_CONTENTS).text)
        .assertEqual('<div data-theme-toc="true"> </div>');
      expect(applyComposerTool('', 0, 0, ComposerTool.TABLE).text).assertContain('|第 1 列');
      expect(applyComposerTool('', 0, 0, ComposerTool.MATH).text).assertEqual('$$\nE=mc^2\n$$');
    });

    it('auto-quotes a non-adjacent Post with author Topic and Post identity', 0, () => {
      const post = new ForumPost(
        103066,
        24,
        'Antarctica',
        '<p>谈吧多谈谈，谈恋爱还是很美好的。</p><p>和前任分手后总是委屈。</p>',
        '',
        35,
        null,
        '2026-05-21T00:00:00Z'
      );

      const quote: string = autoReplyQuote(post, 19139, 36, '');

      expect(quote.startsWith('[quote="Antarctica, post:35, topic:19139"]')).assertTrue();
      expect(quote.includes('谈吧多谈谈，谈恋爱还是很美好的')).assertTrue();
      expect(quote.includes('和前任分手后总是委屈')).assertTrue();
      expect(quote.endsWith('[/quote]\n\n')).assertTrue();
    });

    it('does not replace a draft or quote the immediately preceding Post', 0, () => {
      const post = new ForumPost(
        103066,
        24,
        'Antarctica',
        '<p>正文</p>',
        '正文',
        35,
        null,
        '2026-05-21T00:00:00Z'
      );

      expect(autoReplyQuote(post, 19139, 35, '')).assertEqual('');
      expect(autoReplyQuote(post, 19139, 40, '已有草稿')).assertEqual('已有草稿');
    });
  });
}
