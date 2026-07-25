import { MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';

export function canOpenTopicComposer(
  authenticated: boolean,
  hasCategories: boolean,
  currentUserCanCreatePost: boolean | null,
  profileCanCreatePost: boolean | null
): boolean {
  if (!authenticated) {
    return true;
  }
  if (!hasCategories) {
    return false;
  }
  return profileCanCreatePost ?? currentUserCanCreatePost ?? true;
}

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
  public readonly showsCategoryInput: boolean;
  public readonly categorySelected: boolean;
  public readonly titlePlaceholder: string;
  public readonly bodyPlaceholder: string;
  public readonly showsDraftActions: boolean;
  public readonly imageActionAvailable: boolean;
  public readonly imageActionAccessibilityText: string = '选择并上传图片';
  public readonly mentionActionAvailable: boolean;
  public readonly mentionActionAccessibilityText: string = '插入用户提及';
  public readonly mediaState: MediaUploadState | null;

  private constructor(
    mode: ForumComposerMode,
    contextTitle: string,
    contextDescription: string,
    contextBadge: string,
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string,
    mediaState: MediaUploadState | null,
    categorySelected: boolean = true
  ) {
    this.mode = mode;
    this.contextTitle = contextTitle;
    this.contextDescription = contextDescription;
    this.contextBadge = contextBadge;
    this.sheetTitle = this.composerTitle();
    this.sheetSubtitle = '支持 Markdown';
    this.titleDraft = titleDraft;
    this.bodyDraft = bodyDraft;
    this.status = status;
    this.message = message;
    this.mediaState = mediaState;
    this.mentionActionAvailable = this.canEdit();
    this.showsTitleInput = this.isTopicMode();
    this.showsCategoryInput = this.isTopicMode();
    this.categorySelected = categorySelected;
    this.showsDraftActions = mode === ForumComposerMode.REPLY || mode === ForumComposerMode.TOPIC;
    this.titlePlaceholder = '标题';
    this.bodyPlaceholder = this.isReplyMode()
      ? '写下你的回复…'
      : '分享内容、问题或想法';
    this.imageActionAvailable = this.canEdit() && !this.isMediaPending();
  }

  public static reply(
    topicId: number,
    topicTitle: string,
    replyToPostNumber: number | null,
    draft: string,
    status: ForumComposerStatus,
    message: string,
    mediaState: MediaUploadState | null = null
  ): ForumComposerPresentation {
    const targetsPost: boolean = replyToPostNumber !== null;
    return new ForumComposerPresentation(
      ForumComposerMode.REPLY,
      targetsPost ? `回复 #${replyToPostNumber}` : `回复 Topic #${topicId}`,
      topicTitle,
      targetsPost ? `#${replyToPostNumber}` : 'Topic',
      '',
      draft,
      status,
      message,
      mediaState
    );
  }

  public static topic(
    categoryName: string,
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string,
    mediaState: MediaUploadState | null = null,
    categorySelected: boolean = true
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.TOPIC,
      '发布到 RiverSide',
      categorySelected ? `发布到 ${categoryName}` : '请选择分类',
      categoryName,
      titleDraft,
      bodyDraft,
      status,
      message,
      mediaState,
      categorySelected
    );
  }

  public static editPost(
    topicId: number,
    topicTitle: string,
    draft: string,
    status: ForumComposerStatus,
    message: string,
    mediaState: MediaUploadState | null = null
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.EDIT_POST,
      `编辑 Topic #${topicId} 的 Post`,
      topicTitle,
      '编辑',
      '',
      draft,
      status,
      message,
      mediaState
    );
  }

  public static editTopic(
    titleDraft: string,
    bodyDraft: string,
    status: ForumComposerStatus,
    message: string,
    mediaState: MediaUploadState | null = null
  ): ForumComposerPresentation {
    return new ForumComposerPresentation(
      ForumComposerMode.EDIT_TOPIC,
      '编辑 Topic',
      '标题和首个 Post 将按服务端权限保存',
      '编辑',
      titleDraft,
      bodyDraft,
      status,
      message,
      mediaState
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

  public canEdit(): boolean {
    return !this.isBusy() && !this.needsAuthentication();
  }

  public canSubmit(): boolean {
    if (
      this.isBusy() ||
      this.needsAuthentication() ||
      this.isMediaPending() ||
      this.bodyDraft.trim().length === 0 ||
      (this.showsCategoryInput && !this.categorySelected)
    ) {
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
      return '保存';
    }
    if (this.mode === ForumComposerMode.EDIT_TOPIC) {
      return '保存';
    }
    return this.mode === ForumComposerMode.REPLY ? '回复' : '发布';
  }

  public hasMediaStatus(): boolean {
    return this.mediaState !== null;
  }

  public mediaStatusText(): string {
    const state: MediaUploadState | null = this.mediaState;
    if (state === null) {
      return '';
    }
    if (state.kind === MediaUploadStateKind.SELECTED) {
      return `已选择 ${state.media.filename}，等待上传`;
    }
    if (state.kind === MediaUploadStateKind.UPLOADING) {
      return `正在上传 ${state.media.filename} · ${state.progressPercent}%`;
    }
    return `${state.media.filename} · ${state.message}`;
  }

  public canCancelMedia(): boolean {
    return this.mediaState?.canCancel() ?? false;
  }

  public canRetryMedia(): boolean {
    return this.mediaState?.canRetry() ?? false;
  }

  public canRemoveMedia(): boolean {
    return this.mediaState !== null && !this.mediaState.canCancel();
  }

  private isMediaPending(): boolean {
    return this.mediaState?.kind === MediaUploadStateKind.SELECTED ||
      this.mediaState?.kind === MediaUploadStateKind.UPLOADING;
  }

  private composerTitle(): string {
    if (this.mode === ForumComposerMode.REPLY) {
      return this.contextBadge === 'Topic' ? '回复 Topic' : `回复 ${this.contextBadge}`;
    }
    if (this.mode === ForumComposerMode.EDIT_POST) {
      return '编辑 Post';
    }
    return this.mode === ForumComposerMode.EDIT_TOPIC ? '编辑 Topic' : '发布新 Topic';
  }

  private isReplyMode(): boolean {
    return this.mode === ForumComposerMode.REPLY || this.mode === ForumComposerMode.EDIT_POST;
  }

  private isTopicMode(): boolean {
    return this.mode === ForumComposerMode.TOPIC || this.mode === ForumComposerMode.EDIT_TOPIC;
  }
}
