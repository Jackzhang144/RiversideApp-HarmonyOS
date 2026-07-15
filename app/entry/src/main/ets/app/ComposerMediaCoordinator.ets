import { RepositoryResult } from '../core/RepositoryResult';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind
} from '../models/MediaModels';
import { MediaRepository, MediaUploadOperation } from '../repositories/MediaRepository';
import { ComposerMediaTarget } from './ComposerModels';

export type MediaUploadStateListener = (state: MediaUploadState) => void;
export type ComposerEditableProbe = (target: ComposerMediaTarget) => boolean;
export type ComposerMediaAppender = (target: ComposerMediaTarget, result: MediaUploadResult) => boolean;
export type ComposerMediaUnauthorizedHandler = () => Promise<void>;

export class ComposerMediaCoordinator {
  private readonly repository: MediaRepository | null;
  private readonly isComposerEditable: ComposerEditableProbe;
  private readonly appendMedia: ComposerMediaAppender;
  private readonly handleUnauthorized: ComposerMediaUnauthorizedHandler;
  private activeUpload: MediaUploadOperation | null = null;
  private activeState: MediaUploadState | null = null;
  private activeStateListener: MediaUploadStateListener | null = null;
  private activeTarget: ComposerMediaTarget | null = null;
  private replySession: number = 0;
  private topicSession: number = 0;

  public constructor(
    repository: MediaRepository | null,
    isComposerEditable: ComposerEditableProbe,
    appendMedia: ComposerMediaAppender,
    handleUnauthorized: ComposerMediaUnauthorizedHandler
  ) {
    this.repository = repository;
    this.isComposerEditable = isComposerEditable;
    this.appendMedia = appendMedia;
    this.handleUnauthorized = handleUnauthorized;
  }

  public beginSession(target: ComposerMediaTarget): void {
    if (this.activeUpload !== null) {
      this.cancelUpload();
    }
    this.incrementSession(target);
  }

  public endSession(target: ComposerMediaTarget): void {
    if (this.activeTarget === target) {
      this.cancelUpload();
    }
    this.incrementSession(target);
  }

  public async upload(
    media: CachedMedia,
    target: ComposerMediaTarget,
    onStateChange: MediaUploadStateListener
  ): Promise<MediaUploadState> {
    let state: MediaUploadState = MediaUploadState.selected(media);
    onStateChange(state);
    if (!this.isComposerEditable(target)) {
      state = state.failed('编辑器已关闭，未开始图片上传');
      onStateChange(state);
      return state;
    }
    if (this.repository === null) {
      state = state.failed('图片上传服务不可用');
      onStateChange(state);
      return state;
    }
    if (this.activeUpload !== null) {
      state = state.failed('已有图片正在上传');
      onStateChange(state);
      return state;
    }
    const targetSession: number = this.session(target);

    state = state.uploading(0, media.sizeBytes);
    onStateChange(state);
    const operation: MediaUploadOperation = this.repository.upload(
      MediaUploadRequest.composer(media),
      (uploadedBytes: number, totalBytes: number): void => {
        if (this.activeState?.kind !== MediaUploadStateKind.CANCELLED) {
          state = state.uploading(uploadedBytes, totalBytes);
          this.activeState = state;
          onStateChange(state);
        }
      }
    );
    this.activeUpload = operation;
    this.activeState = state;
    this.activeStateListener = onStateChange;
    this.activeTarget = target;
    const result: RepositoryResult<MediaUploadResult> = await operation.completion;
    if (this.activeState?.kind === MediaUploadStateKind.CANCELLED) {
      const cancelled: MediaUploadState = this.activeState;
      this.clearActiveUpload(operation);
      return cancelled;
    }
    this.clearActiveUpload(operation);
    if (!result.isSuccess() || result.data === null) {
      if (result.isUnauthorized()) {
        await this.handleUnauthorized();
      }
      state = state.failed(result.message);
      onStateChange(state);
      return state;
    }
    if (this.session(target) !== targetSession || !this.appendMedia(target, result.data)) {
      state = state.failed('编辑器已关闭或切换，上传结果未插入草稿');
      onStateChange(state);
      return state;
    }
    state = state.succeeded(result.data);
    onStateChange(state);
    return state;
  }

  public cancelUpload(): void {
    const operation: MediaUploadOperation | null = this.activeUpload;
    const state: MediaUploadState | null = this.activeState;
    const listener: MediaUploadStateListener | null = this.activeStateListener;
    if (operation === null || state === null || listener === null || !state.canCancel()) {
      return;
    }
    const cancelled: MediaUploadState = state.cancelled();
    this.activeState = cancelled;
    listener(cancelled);
    operation.cancel();
  }

  private clearActiveUpload(operation: MediaUploadOperation): void {
    if (this.activeUpload !== operation) {
      return;
    }
    this.activeUpload = null;
    this.activeState = null;
    this.activeStateListener = null;
    this.activeTarget = null;
  }

  private incrementSession(target: ComposerMediaTarget): void {
    if (target === ComposerMediaTarget.REPLY) {
      this.replySession += 1;
    } else {
      this.topicSession += 1;
    }
  }

  private session(target: ComposerMediaTarget): number {
    return target === ComposerMediaTarget.REPLY ? this.replySession : this.topicSession;
  }
}
