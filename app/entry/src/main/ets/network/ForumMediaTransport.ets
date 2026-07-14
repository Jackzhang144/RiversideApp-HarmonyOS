import {
  CachedMedia,
  MediaUploadField,
  MediaUploadRequest
} from '../models/MediaModels';
import { HttpTextResult } from './DiscourseHttpClient';

export type MediaProgressListener = (uploadedBytes: number, totalBytes: number) => void;

export class MediaTransportRequest {
  public readonly path: string;
  public readonly media: CachedMedia;
  public readonly fields: Array<MediaUploadField>;

  public constructor(path: string, media: CachedMedia, fields: Array<MediaUploadField>) {
    this.path = path;
    this.media = media;
    this.fields = fields.slice();
  }

  public static fromUploadRequest(request: MediaUploadRequest): MediaTransportRequest {
    return new MediaTransportRequest(request.transportPath(), request.media, request.fields());
  }

  public fieldValue(name: string): string {
    const field: MediaUploadField | undefined = this.fields.find(
      (candidate: MediaUploadField): boolean => candidate.name === name
    );
    return field?.value ?? '';
  }
}

export interface MediaTransportOperation {
  readonly completion: Promise<HttpTextResult>;

  cancel(): void;
}

export interface ForumMediaTransport {
  upload(request: MediaTransportRequest, onProgress: MediaProgressListener): MediaTransportOperation;
}
