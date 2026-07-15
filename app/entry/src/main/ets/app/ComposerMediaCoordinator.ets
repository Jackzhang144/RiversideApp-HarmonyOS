import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult,
  MediaUploadState
} from '../models/MediaModels';
import { MediaRepository } from '../repositories/MediaRepository';
import { ComposerMediaTarget } from './ComposerModels';
import { MediaUploadCoordinator, MediaUploadStateListener } from './MediaUploadCoordinator';

export type ComposerEditableProbe = (target: ComposerMediaTarget) => boolean;
export type ComposerMediaAppender = (target: ComposerMediaTarget, result: MediaUploadResult) => boolean;
export type ComposerMediaUnauthorizedHandler = () => Promise<void>;

export class ComposerMediaCoordinator {
  private readonly isComposerEditable: ComposerEditableProbe;
  private readonly appendMedia: ComposerMediaAppender;
  private readonly uploadCoordinator: MediaUploadCoordinator;
  private activeTarget: ComposerMediaTarget | null = null;
  private replySession: number = 0;
  private topicSession: number = 0;

  public constructor(
    repository: MediaRepository | null,
    isComposerEditable: ComposerEditableProbe,
    appendMedia: ComposerMediaAppender,
    handleUnauthorized: ComposerMediaUnauthorizedHandler
  ) {
    this.isComposerEditable = isComposerEditable;
    this.appendMedia = appendMedia;
    this.uploadCoordinator = new MediaUploadCoordinator(repository, handleUnauthorized);
  }

  public beginSession(target: ComposerMediaTarget): void {
    if (this.uploadCoordinator.hasActiveUpload()) {
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
    if (!this.isComposerEditable(target)) {
      const state: MediaUploadState = MediaUploadState.selected(media).failed('编辑器已关闭，未开始图片上传');
      onStateChange(state);
      return state;
    }
    const targetSession: number = this.session(target);
    const ownsUpload: boolean = !this.uploadCoordinator.hasActiveUpload();
    if (ownsUpload) {
      this.activeTarget = target;
    }
    const state: MediaUploadState = await this.uploadCoordinator.upload(
      media,
      MediaUploadRequest.composer(media),
      onStateChange,
      (result: MediaUploadResult): boolean => {
        return this.session(target) === targetSession && this.appendMedia(target, result);
      },
      '编辑器已关闭或切换，上传结果未插入草稿'
    );
    if (ownsUpload && this.activeTarget === target) {
      this.activeTarget = null;
    }
    return state;
  }

  public cancelUpload(): void {
    this.uploadCoordinator.cancelUpload();
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
