import { RepositoryResult } from '../core/RepositoryResult';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind
} from '../models/MediaModels';
import { MediaRepository, MediaUploadOperation } from '../repositories/MediaRepository';

export type MediaUploadStateListener = (state: MediaUploadState) => void;
export type MediaUploadResultAcceptor = (result: MediaUploadResult) => boolean;
export type MediaUploadUnauthorizedHandler = () => Promise<void>;

export class MediaUploadCoordinator {
  private readonly repository: MediaRepository | null;
  private readonly handleUnauthorized: MediaUploadUnauthorizedHandler;
  private activeUpload: MediaUploadOperation | null = null;
  private activeState: MediaUploadState | null = null;
  private activeStateListener: MediaUploadStateListener | null = null;

  public constructor(
    repository: MediaRepository | null,
    handleUnauthorized: MediaUploadUnauthorizedHandler
  ) {
    this.repository = repository;
    this.handleUnauthorized = handleUnauthorized;
  }

  public hasActiveUpload(): boolean {
    return this.activeUpload !== null;
  }

  public async upload(
    media: CachedMedia,
    request: MediaUploadRequest,
    onStateChange: MediaUploadStateListener,
    acceptResult: MediaUploadResultAcceptor,
    rejectedResultMessage: string
  ): Promise<MediaUploadState> {
    let state: MediaUploadState = MediaUploadState.selected(media);
    onStateChange(state);
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

    state = state.uploading(0, media.sizeBytes);
    this.activeState = state;
    this.activeStateListener = onStateChange;
    onStateChange(state);
    const operation: MediaUploadOperation = this.repository.upload(
      request,
      (uploadedBytes: number, totalBytes: number): void => {
        if (this.activeState?.kind !== MediaUploadStateKind.CANCELLED) {
          state = state.uploading(uploadedBytes, totalBytes);
          this.activeState = state;
          onStateChange(state);
        }
      }
    );
    this.activeUpload = operation;
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
    if (!acceptResult(result.data)) {
      state = state.failed(rejectedResultMessage);
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
  }
}
