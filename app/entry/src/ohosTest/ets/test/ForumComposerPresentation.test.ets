import { describe, expect, it } from '@ohos/hypium';
import {
  ForumComposerMode,
  ForumComposerPresentation,
  ForumComposerStatus
} from '../../../main/ets/components/ForumComposerPresentation';

export default function forumComposerPresentationTest(): void {
  describe('Forum composer presentation contract', () => {
    it('describes a Topic Reply without exposing a title field', 0, () => {
      const presentation: ForumComposerPresentation = ForumComposerPresentation.reply(
        2725,
        '图书馆座位预约系统使用体验优化建议',
        null,
        '收到',
        ForumComposerStatus.EDITING,
        ''
      );

      expect(presentation.mode).assertEqual(ForumComposerMode.REPLY);
      expect(presentation.sheetTitle).assertEqual('Reply 编辑器');
      expect(presentation.contextTitle).assertEqual('回复 Topic #2725');
      expect(presentation.contextBadge).assertEqual('Topic');
      expect(presentation.showsTitleInput).assertFalse();
      expect(presentation.imageActionAvailable).assertFalse();
      expect(presentation.imageActionAccessibilityText).assertEqual('图片，未实现');
      expect(presentation.mentionActionAvailable).assertFalse();
      expect(presentation.mentionActionAccessibilityText).assertEqual('@ 提及，未实现');
      expect(presentation.showsDraftActions).assertTrue();
      expect(presentation.canSubmit()).assertTrue();
      expect(presentation.submitLabel()).assertEqual('发布 Reply');
    });

    it('keeps long Post Reply drafts valid and exposes explicit retry after an error', 0, () => {
      const longDraft: string = '长'.repeat(1001);
      const presentation: ForumComposerPresentation = ForumComposerPresentation.reply(
        2725,
        '图书馆座位预约系统使用体验优化建议',
        3,
        longDraft,
        ForumComposerStatus.ERROR,
        '操作过于频繁'
      );

      expect(presentation.contextTitle).assertEqual('回复 Post #3');
      expect(presentation.contextBadge).assertEqual('#3');
      expect(presentation.characterCount()).assertEqual(1001);
      expect(presentation.canSubmit()).assertTrue();
      expect(presentation.submitLabel()).assertEqual('显式重试');
      expect(presentation.message).assertEqual('操作过于频繁');
    });

    it('locks blank, busy, and reauthentication Reply states', 0, () => {
      const blank: ForumComposerPresentation = ForumComposerPresentation.reply(
        2725, 'Topic', null, '   ', ForumComposerStatus.EDITING, ''
      );
      const checking: ForumComposerPresentation = ForumComposerPresentation.reply(
        2725, 'Topic', null, '收到', ForumComposerStatus.CHECKING, '正在确认 Reply 是否已创建'
      );
      const reauthenticate: ForumComposerPresentation = ForumComposerPresentation.reply(
        2725, 'Topic', null, '登录后继续', ForumComposerStatus.REAUTHENTICATE, '登录已失效'
      );

      expect(blank.canSubmit()).assertFalse();
      expect(checking.isBusy()).assertTrue();
      expect(checking.canSubmit()).assertFalse();
      expect(checking.submitLabel()).assertEqual('正在确认');
      expect(reauthenticate.needsAuthentication()).assertTrue();
      expect(reauthenticate.canSubmit()).assertFalse();
    });

    it('uses the same model for Topic creation while requiring title and body', 0, () => {
      const incomplete: ForumComposerPresentation = ForumComposerPresentation.topic(
        '水手之家', '', '正文', ForumComposerStatus.EDITING, ''
      );
      const complete: ForumComposerPresentation = ForumComposerPresentation.topic(
        '水手之家', '标题', '正文', ForumComposerStatus.EDITING, ''
      );

      expect(complete.mode).assertEqual(ForumComposerMode.TOPIC);
      expect(complete.sheetTitle).assertEqual('发帖 编辑器');
      expect(complete.contextTitle).assertEqual('发布到 RiverSide');
      expect(complete.contextBadge).assertEqual('水手之家');
      expect(complete.showsTitleInput).assertTrue();
      expect(incomplete.canSubmit()).assertFalse();
      expect(complete.canSubmit()).assertTrue();
      expect(complete.submitLabel()).assertEqual('发布 Topic');
      expect(complete.contextDescription).assertEqual('仅发布到测试专用 Category #111');
      expect(complete.showsDraftActions).assertTrue();
    });

    it('distinguishes Post and Topic editing from creation', 0, () => {
      const post: ForumComposerPresentation = ForumComposerPresentation.editPost(
        2725, 'Topic', '更新 Reply', ForumComposerStatus.EDITING, ''
      );
      const topic: ForumComposerPresentation = ForumComposerPresentation.editTopic(
        '原标题', '更新正文', ForumComposerStatus.ERROR, '服务器拒绝编辑'
      );

      expect(post.mode).assertEqual(ForumComposerMode.EDIT_POST);
      expect(post.showsTitleInput).assertFalse();
      expect(post.showsDraftActions).assertFalse();
      expect(post.submitLabel()).assertEqual('保存 Post');
      expect(topic.mode).assertEqual(ForumComposerMode.EDIT_TOPIC);
      expect(topic.showsTitleInput).assertTrue();
      expect(topic.showsDraftActions).assertFalse();
      expect(topic.submitLabel()).assertEqual('显式重试');
    });
  });
}
