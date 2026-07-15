import { RepositoryResult } from '../core/RepositoryResult';
import {
  CreateTopicRequest,
  DraftWriteRequest,
  EditPostRequest,
  EditTopicRequest,
  ServerDraft,
  TopicSubmitKind,
  TopicSubmitResult
} from '../models/AuthoringModels';
import { ForumPost, TopicDetail } from '../models/ForumModels';
import { MediaUploadResult, appendUploadedImageMarkdown } from '../models/MediaModels';
import { ForumRepository } from '../repositories/ForumRepository';
import { TopicComposerState, TopicComposerStateKind } from './ComposerModels';
import { replacePost, TopicReadState } from './TopicReadingModels';

export type TopicReadStateProvider = () => TopicReadState;
export type TopicReadStateUpdater = (state: TopicReadState) => void;
export type TopicMediaSessionHandler = () => void;
export type TopicAuthenticationStateUpdater = (required: boolean) => void;
export type TopicUnauthorizedHandler = () => Promise<void>;

export class TopicAuthoringCoordinator {
  public state: TopicComposerState = TopicComposerState.closed();
  public editingTopicId: number | null = null;
  public editingPostId: number | null = null;

  private readonly repository: ForumRepository;
  private readonly readTopicState: TopicReadStateProvider;
  private readonly updateTopicState: TopicReadStateUpdater;
  private readonly beginMediaSession: TopicMediaSessionHandler;
  private readonly endMediaSession: TopicMediaSessionHandler;
  private readonly updateAuthenticationState: TopicAuthenticationStateUpdater;
  private readonly handleUnauthorized: TopicUnauthorizedHandler;
  private requestVersion: number = 0;
  private ignoredDraftSequence: number | null = null;
  private draftKey: string = 'new_topic';
  private editingOriginalTitle: string = '';

  public constructor(
    repository: ForumRepository,
    readTopicState: TopicReadStateProvider,
    updateTopicState: TopicReadStateUpdater,
    beginMediaSession: TopicMediaSessionHandler,
    endMediaSession: TopicMediaSessionHandler,
    updateAuthenticationState: TopicAuthenticationStateUpdater,
    handleUnauthorized: TopicUnauthorizedHandler
  ) {
    this.repository = repository;
    this.readTopicState = readTopicState;
    this.updateTopicState = updateTopicState;
    this.beginMediaSession = beginMediaSession;
    this.endMediaSession = endMediaSession;
    this.updateAuthenticationState = updateAuthenticationState;
    this.handleUnauthorized = handleUnauthorized;
  }

  public openNew(initialCategoryId: number | null = null): void {
    this.beginMediaSession();
    this.requestVersion += 1;
    this.editingTopicId = null;
    this.editingPostId = null;
    this.editingOriginalTitle = '';
    this.draftKey = 'new_topic';
    this.state = TopicComposerState.editing('', '', initialCategoryId);
  }

  public openDraft(draft: ServerDraft): boolean {
    if (!draft.draftKey.startsWith('new_topic')) {
      return false;
    }
    this.openNew(draft.categoryId);
    this.draftKey = draft.draftKey;
    this.state = TopicComposerState.editing(
      draft.title,
      draft.raw,
      draft.categoryId,
      draft.sequence
    );
    return true;
  }

  public openEditor(detail: TopicDetail, post: ForumPost): void {
    this.beginMediaSession();
    this.editingTopicId = detail.id;
    this.editingPostId = post.id;
    this.editingOriginalTitle = detail.title;
    this.state = TopicComposerState.editing(detail.title, post.raw, detail.categoryId);
  }

  public updateTitle(title: string): void {
    if (this.isEditable()) {
      this.state = this.state.withTitle(title);
    }
  }

  public updateRaw(raw: string): void {
    if (this.isEditable()) {
      this.state = this.state.withRaw(raw);
    }
  }

  public updateCategory(categoryId: number): void {
    if (this.isEditable() && Number.isInteger(categoryId) && categoryId > 0) {
      this.state = this.state.withCategoryId(categoryId);
    }
  }

  public appendMedia(result: MediaUploadResult): boolean {
    if (!this.isEditable()) {
      return false;
    }
    this.updateRaw(appendUploadedImageMarkdown(this.state.raw, result));
    return true;
  }

  public async restoreDraft(): Promise<void> {
    if (this.editingTopicId !== null || this.state.kind !== TopicComposerStateKind.EDITING) {
      return;
    }
    const requestVersion: number = this.requestVersion;
    const title: string = this.state.title;
    const raw: string = this.state.raw;
    const categoryId: number | null = this.state.categoryId;
    const result: RepositoryResult<Array<ServerDraft>> = await this.repository.loadDrafts();
    if (
      requestVersion !== this.requestVersion ||
      this.state.title !== title ||
      this.state.raw !== raw ||
      this.state.categoryId !== categoryId
    ) {
      return;
    }
    if (result.isUnauthorized()) {
      await this.requireAuthentication(this.state);
      return;
    }
    if (!result.isSuccess() || result.data === null) {
      this.state = TopicComposerState.error(this.state, result.message);
      return;
    }
    const draft: ServerDraft | undefined = result.data.find(
      (candidate: ServerDraft): boolean => candidate.draftKey.startsWith('new_topic') &&
        (this.ignoredDraftSequence === null || candidate.sequence !== this.ignoredDraftSequence)
    );
    if (draft !== undefined) {
      this.draftKey = draft.draftKey;
      this.state = TopicComposerState.editing(
        draft.title,
        draft.raw,
        draft.categoryId,
        draft.sequence
      );
    }
  }

  public async saveDraft(): Promise<boolean> {
    if (this.editingTopicId !== null || this.state.isBusy()) {
      return false;
    }
    const request: DraftWriteRequest | null = DraftWriteRequest.newTopic(
      this.state.title,
      this.state.raw,
      this.state.categoryId ?? 0,
      this.state.draftSequence,
      this.draftKey
    );
    if (request === null) {
      this.state = TopicComposerState.error(this.state, '草稿内容为空');
      return false;
    }
    const editing: TopicComposerState = this.state;
    this.state = TopicComposerState.savingDraft(editing);
    const result: RepositoryResult<number> = await this.repository.saveDraft(request);
    if (result.isUnauthorized()) {
      await this.requireAuthentication(editing);
      return false;
    }
    if (!result.isSuccess() || result.data === null) {
      this.state = TopicComposerState.error(editing, result.message);
      return false;
    }
    this.state = TopicComposerState.editing(
      editing.title,
      editing.raw,
      editing.categoryId,
      result.data
    );
    this.ignoredDraftSequence = null;
    return true;
  }

  public dismiss(): void {
    if (this.state.isBusy()) {
      return;
    }
    this.endMediaSession();
    this.requestVersion += 1;
    this.state = TopicComposerState.closed();
    this.editingTopicId = null;
    this.editingPostId = null;
    this.editingOriginalTitle = '';
  }

  public async discardDraft(): Promise<boolean> {
    if (this.state.isBusy()) {
      return false;
    }
    if (this.editingTopicId !== null || this.state.draftSequence === 0) {
      this.dismiss();
      return true;
    }
    const editing: TopicComposerState = this.state;
    const result: RepositoryResult<boolean> = await this.repository.deleteDraft(
      this.draftKey,
      editing.draftSequence
    );
    if (result.isUnauthorized()) {
      await this.requireAuthentication(editing);
      return false;
    }
    if (!result.isSuccess() || result.data !== true) {
      this.state = TopicComposerState.error(editing, result.message);
      return false;
    }
    this.ignoredDraftSequence = null;
    this.dismiss();
    return true;
  }

  public resumeAfterAuthentication(): void {
    if (this.state.kind === TopicComposerStateKind.REAUTHENTICATE) {
      this.updateAuthenticationState(false);
      this.state = TopicComposerState.editing(
        this.state.title,
        this.state.raw,
        this.state.categoryId,
        this.state.draftSequence
      );
    }
  }

  public async submit(): Promise<void> {
    if (this.state.isBusy()) {
      return;
    }
    if (this.editingTopicId !== null && this.editingPostId !== null) {
      await this.submitEdit();
      return;
    }
    const request: CreateTopicRequest | null = CreateTopicRequest.create(
      this.state.title,
      this.state.raw,
      this.state.categoryId ?? 0
    );
    if (request === null) {
      this.state = TopicComposerState.error(this.state, '请填写标题、Category 和内容');
      return;
    }
    const editing: TopicComposerState = this.state;
    this.state = TopicComposerState.submitting(editing);
    const result: TopicSubmitResult = await this.repository.submitTopic(request);
    if (result.kind === TopicSubmitKind.UNAUTHORIZED) {
      await this.requireAuthentication(editing);
      return;
    }
    if (result.kind !== TopicSubmitKind.CREATED || result.topicId === null) {
      this.state = TopicComposerState.error(editing, result.message);
      return;
    }
    if (editing.draftSequence > 0) {
      const cleanupResult: RepositoryResult<boolean> = await this.repository.deleteDraft(
        this.draftKey,
        editing.draftSequence
      );
      if (!cleanupResult.isSuccess() || cleanupResult.data !== true) {
        this.ignoredDraftSequence = editing.draftSequence;
        this.state = TopicComposerState.success(
          result.topicId,
          `Topic 已发布；服务器草稿清理失败：${cleanupResult.message}`
        );
        return;
      }
    }
    this.ignoredDraftSequence = null;
    this.state = TopicComposerState.success(result.topicId);
  }

  private async submitEdit(): Promise<void> {
    const topicId: number | null = this.editingTopicId;
    const postId: number | null = this.editingPostId;
    const topicRequest: EditTopicRequest | null = topicId === null
      ? null
      : EditTopicRequest.create(
        topicId,
        this.state.title,
        this.editingOriginalTitle,
        this.state.categoryId ?? 0
      );
    const postRequest: EditPostRequest | null = postId === null
      ? null
      : EditPostRequest.create(postId, this.state.raw);
    if (topicRequest === null || postRequest === null) {
      this.state = TopicComposerState.error(this.state, '请填写标题、Category 和内容');
      return;
    }
    const editing: TopicComposerState = this.state;
    this.state = TopicComposerState.submitting(editing);
    const topicResult: RepositoryResult<boolean> = await this.repository.editTopic(topicRequest);
    if (!topicResult.isSuccess() || topicResult.data !== true) {
      await this.handleEditFailure(editing, topicResult);
      return;
    }
    const postResult: RepositoryResult<boolean> = await this.repository.editPost(postRequest);
    if (!postResult.isSuccess() || postResult.data !== true) {
      await this.handleEditFailure(editing, postResult);
      return;
    }
    const topicState: TopicReadState = this.readTopicState();
    const post: ForumPost | undefined = topicState.posts.find(
      (candidate: ForumPost): boolean => candidate.id === postId
    );
    if (post !== undefined) {
      const posts: Array<ForumPost> = replacePost(topicState.posts, post.withRawContent(postRequest.raw));
      const detail: TopicDetail | null = topicState.detail;
      this.updateTopicState(detail === null
        ? TopicReadState.withPosts(topicState, posts)
        : TopicReadState.withDetailAndPosts(
          topicState,
          detail.withTitleAndPosts(topicRequest.title, posts, topicRequest.categoryId),
          posts
        ));
    }
    this.state = TopicComposerState.success(topicRequest.topicId);
  }

  private isEditable(): boolean {
    return this.state.kind === TopicComposerStateKind.EDITING ||
      this.state.kind === TopicComposerStateKind.ERROR;
  }

  private async requireAuthentication(editing: TopicComposerState): Promise<void> {
    this.updateAuthenticationState(true);
    this.state = TopicComposerState.reauthenticate(editing);
    await this.handleUnauthorized();
  }

  private async handleEditFailure(
    editing: TopicComposerState,
    result: RepositoryResult<boolean>
  ): Promise<void> {
    if (result.isUnauthorized()) {
      await this.requireAuthentication(editing);
      return;
    }
    this.state = TopicComposerState.error(editing, result.message);
  }
}
