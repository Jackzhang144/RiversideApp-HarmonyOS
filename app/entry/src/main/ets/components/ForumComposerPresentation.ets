export enum ForumComposerMode {
  REPLY = 'reply',
  EDIT_POST = 'edit-post',
  TOPIC = 'topic',
  EDIT_TOPIC = 'edit-topic'
}

export enum ForumComposerStatus {
  EDITING = 'editing',
  SUBMITTING = 'submitting',
  CHECKING = 'checking',
  ERROR = 'error',
  REAUTHENTICATE = 'reauthenticate'
}

export class ForumComposerPresentation {
  public readonly mode: ForumComposerMode;
  public readonly sheetTitle: string;
  public readonly sheetSubtitle: string;
  public readonly contextTitle: string;
  public readonly contextDescription: string;
  public readonly contextBadge: string;
  public readonly titleDraft: string;
  public readonly bodyDraft: string;
  public readonly status: ForumComposerStatus;
  public readonly message: string;
  public readonly showsTitleInput: boolean;
  public readonly titlePlaceholder: string;
  public readonly bodyPlaceholder: string;
  public readonly showsDraftActions: boolean;
  public readonly imageActionAvailable: boolean = false;
  public readonly imageActionAccessibilityText: string = '图片，未实现';
  public readonly mentionActionAvailable: boolean = false;
  public readonly mentionActionAccessibilityText: string = '@ 提及，未实现';

  private constructor(
    mode: ForumComposerMode,
    contextTitle: string,
    contextDescription: string,
    contextBadge: string,
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string
  ) {
    this.mode = mode;
    this.sheetTitle = this.isReplyMode() ? 'Reply 编辑器' : '发帖 编辑器';
    this.sheetSubtitle = '快速输入';
    this.contextTitle = contextTitle;
    this.contextDescription = contextDescription;
    this.contextBadge = contextBadge;
    this.titleDraft = titleDraft;
    this.bodyDraft = bodyDraft;
    this.status = status;
    this.message = message;
    this.showsTitleInput = this.isTopicMode();
    this.showsDraftActions = mode === ForumComposerMode.REPLY || mode === ForumComposerMode.TOPIC;
    this.titlePlaceholder = 'Topic 标题';
    this.bodyPlaceholder = this.isReplyMode()
      ? '输入纯文本或 Markdown Reply'
      : '分享内容、问题或想法';
  }

  public static reply(
    topicId: number,
    topicTitle: string,
    replyToPostNumber: number | null,
    draft: string,
    status: ForumComposerStatus,
    message: string
  ): ForumComposerPresentation {
    const targetsPost: boolean = replyToPostNumber !== null;
    return new ForumComposerPresentation(
      ForumComposerMode.REPLY,
      targetsPost ? `回复 Post #${replyToPostNumber}` : `回复 Topic #${topicId}`,
      topicTitle,
      targetsPost ? `#${replyToPostNumber}` : 'Topic',
      '',
      draft,
      status,
      message
    );
  }

  public static topic(
    categoryName: string,
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.TOPIC,
      '发布到 RiverSide',
      '仅发布到测试专用 Category #111',
      categoryName,
      titleDraft,
      bodyDraft,
      status,
      message
    );
  }

  public static editPost(
    topicId: number,
    topicTitle: string,
    draft: string,
    status: ForumComposerStatus,
    message: string
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.EDIT_POST,
      `编辑 Topic #${topicId} 的 Post`,
      topicTitle,
      '编辑',
      '',
      draft,
      status,
      message
    );
  }

  public static editTopic(
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.EDIT_TOPIC,
      '编辑 Topic',
      '标题和首个 Post 将按服务端权限保存',
      '编辑',
      titleDraft,
      bodyDraft,
      status,
      message
    );
  }

  public characterCount(): number {
    return this.bodyDraft.length;
  }

  public isBusy(): boolean {
    return this.status === ForumComposerStatus.SUBMITTING || this.status === ForumComposerStatus.CHECKING;
  }

  public needsAuthentication(): boolean {
    return this.status === ForumComposerStatus.REAUTHENTICATE;
  }

  public canSubmit(): boolean {
    if (this.isBusy() || this.needsAuthentication() || this.bodyDraft.trim().length === 0) {
      return false;
    }
    return this.isReplyMode() || this.titleDraft.trim().length > 0;
  }

  public submitLabel(): string {
    if (this.status === ForumComposerStatus.SUBMITTING) {
      return '正在提交';
    }
    if (this.status === ForumComposerStatus.CHECKING) {
      return '正在确认';
    }
    if (this.status === ForumComposerStatus.ERROR) {
      return '显式重试';
    }
    if (this.mode === ForumComposerMode.EDIT_POST) {
      return '保存 Post';
    }
    if (this.mode === ForumComposerMode.EDIT_TOPIC) {
      return '保存 Topic';
    }
    return this.mode === ForumComposerMode.REPLY ? '发布 Reply' : '发布 Topic';
  }

  private isReplyMode(): boolean {
    return this.mode === ForumComposerMode.REPLY || this.mode === ForumComposerMode.EDIT_POST;
  }

  private isTopicMode(): boolean {
    return this.mode === ForumComposerMode.TOPIC || this.mode === ForumComposerMode.EDIT_TOPIC;
  }
}
