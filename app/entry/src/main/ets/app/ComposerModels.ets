export enum ComposerMediaTarget {
  REPLY = 'reply',
  TOPIC = 'topic'
}

export enum ReplyComposerStateKind {
  CLOSED = 'closed',
  EDITING = 'editing',
  SUBMITTING = 'submitting',
  CHECKING = 'checking',
  ERROR = 'error',
  REAUTHENTICATE = 'reauthenticate',
  SUCCESS = 'success'
}

export class ReplyComposerState {
  public readonly kind: ReplyComposerStateKind;
  public readonly draft: string;
  public readonly replyToPostNumber: number | null;
  public readonly message: string;
  public readonly editingPostId: number | null;

  private constructor(
    kind: ReplyComposerStateKind,
    draft: string,
    replyToPostNumber: number | null,
    message: string,
    editingPostId: number | null = null
  ) {
    this.kind = kind;
    this.draft = draft;
    this.replyToPostNumber = replyToPostNumber;
    this.message = message;
    this.editingPostId = editingPostId;
  }

  public static closed(draft: string = '', replyToPostNumber: number | null = null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.CLOSED, draft, replyToPostNumber, '');
  }

  public static editing(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.EDITING, draft, replyToPostNumber, '');
  }

  public static editingPost(postId: number, draft: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.EDITING, draft, null, '', postId);
  }

  public static submitting(
    draft: string,
    replyToPostNumber: number | null,
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.SUBMITTING,
      draft,
      replyToPostNumber,
      editingPostId === null ? '正在提交 Reply' : '正在保存 Post',
      editingPostId
    );
  }

  public static checking(draft: string, replyToPostNumber: number | null): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.CHECKING,
      draft,
      replyToPostNumber,
      '正在确认 Reply 是否已创建'
    );
  }

  public static error(
    draft: string,
    replyToPostNumber: number | null,
    message: string,
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.ERROR, draft, replyToPostNumber, message, editingPostId);
  }

  public static reauthenticate(
    draft: string,
    replyToPostNumber: number | null,
    message: string = '登录已失效，重新登录后可继续提交',
    editingPostId: number | null = null
  ): ReplyComposerState {
    return new ReplyComposerState(
      ReplyComposerStateKind.REAUTHENTICATE,
      draft,
      replyToPostNumber,
      message,
      editingPostId
    );
  }

  public static success(message: string): ReplyComposerState {
    return new ReplyComposerState(ReplyComposerStateKind.SUCCESS, '', null, message);
  }

  public isBusy(): boolean {
    return this.kind === ReplyComposerStateKind.SUBMITTING || this.kind === ReplyComposerStateKind.CHECKING;
  }

  public isEditingPost(): boolean {
    return this.editingPostId !== null;
  }
}

export enum TopicComposerStateKind {
  CLOSED = 'closed',
  EDITING = 'editing',
  SUBMITTING = 'submitting',
  SAVING_DRAFT = 'saving-draft',
  ERROR = 'error',
  REAUTHENTICATE = 'reauthenticate',
  SUCCESS = 'success'
}

export class TopicComposerState {
  public readonly kind: TopicComposerStateKind;
  public readonly title: string;
  public readonly raw: string;
  public readonly categoryId: number | null;
  public readonly draftSequence: number;
  public readonly createdTopicId: number | null;
  public readonly message: string;

  private constructor(
    kind: TopicComposerStateKind,
    title: string,
    raw: string,
    categoryId: number | null,
    draftSequence: number,
    createdTopicId: number | null,
    message: string
  ) {
    this.kind = kind;
    this.title = title;
    this.raw = raw;
    this.categoryId = categoryId !== null && Number.isInteger(categoryId) && categoryId > 0 ? categoryId : null;
    this.draftSequence = Math.max(0, draftSequence);
    this.createdTopicId = createdTopicId;
    this.message = message;
  }

  public static closed(): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.CLOSED, '', '', null, 0, null, '');
  }

  public static editing(
    title: string = '',
    raw: string = '',
    categoryId: number | null = null,
    draftSequence: number = 0
  ): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.EDITING, title, raw, categoryId, draftSequence, null, '');
  }

  public static submitting(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.SUBMITTING,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '正在发布 Topic'
    );
  }

  public static savingDraft(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.SAVING_DRAFT,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '正在保存草稿'
    );
  }

  public static error(state: TopicComposerState, message: string): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.ERROR,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      message
    );
  }

  public static reauthenticate(state: TopicComposerState): TopicComposerState {
    return new TopicComposerState(
      TopicComposerStateKind.REAUTHENTICATE,
      state.title,
      state.raw,
      state.categoryId,
      state.draftSequence,
      null,
      '登录已失效，重新登录后可继续发布'
    );
  }

  public static success(topicId: number, message: string = 'Topic 已发布'): TopicComposerState {
    return new TopicComposerState(TopicComposerStateKind.SUCCESS, '', '', null, 0, topicId, message);
  }

  public withTitle(title: string): TopicComposerState {
    return TopicComposerState.editing(title, this.raw, this.categoryId, this.draftSequence);
  }

  public withRaw(raw: string): TopicComposerState {
    return TopicComposerState.editing(this.title, raw, this.categoryId, this.draftSequence);
  }

  public withCategoryId(categoryId: number | null): TopicComposerState {
    return TopicComposerState.editing(this.title, this.raw, categoryId, this.draftSequence);
  }

  public isBusy(): boolean {
    return this.kind === TopicComposerStateKind.SUBMITTING || this.kind === TopicComposerStateKind.SAVING_DRAFT;
  }
}
