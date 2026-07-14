const SUPPORTED_IMAGE_MIME_TYPES: Array<string> = [
  'image/jpeg',
  'image/png',
  'image/gif',
  'image/webp'
];

export const MAX_UPLOAD_IMAGE_BYTES: number = 20 * 1024 * 1024;

export function isUploadImageSizeSupported(sizeBytes: number): boolean {
  return Number.isSafeInteger(sizeBytes) && sizeBytes > 0 && sizeBytes <= MAX_UPLOAD_IMAGE_BYTES;
}

function normalizedFilename(value: string, fallback: string): string {
  const normalized: string = value
    .replace(/\r/g, '')
    .replace(/\n/g, '')
    .replace(/\//g, '-')
    .replace(/\\/g, '-')
    .trim();
  return normalized.length === 0 ? fallback : normalized;
}

export class CachedMedia {
  public readonly operationId: string;
  public readonly absoluteCachePath: string;
  public readonly uploadUri: string;
  public readonly filename: string;
  public readonly mimeType: string;
  public readonly sizeBytes: number;

  private constructor(
    operationId: string,
    absoluteCachePath: string,
    uploadUri: string,
    filename: string,
    mimeType: string,
    sizeBytes: number
  ) {
    this.operationId = operationId;
    this.absoluteCachePath = absoluteCachePath;
    this.uploadUri = uploadUri;
    this.filename = filename;
    this.mimeType = mimeType;
    this.sizeBytes = sizeBytes;
  }

  public static create(
    operationId: string,
    absoluteCachePath: string,
    uploadUri: string,
    filename: string,
    mimeType: string,
    sizeBytes: number
  ): CachedMedia | null {
    const normalizedOperationId: string = operationId.trim();
    const normalizedPath: string = absoluteCachePath.trim();
    const normalizedUploadUri: string = uploadUri.trim();
    const normalizedMimeType: string = mimeType.trim().toLowerCase();
    if (
      normalizedOperationId.length === 0 ||
      normalizedPath.length === 0 ||
      !normalizedUploadUri.startsWith('internal://cache/') ||
      !SUPPORTED_IMAGE_MIME_TYPES.includes(normalizedMimeType) ||
      !Number.isSafeInteger(sizeBytes) ||
      sizeBytes <= 0
    ) {
      return null;
    }
    return new CachedMedia(
      normalizedOperationId,
      normalizedPath,
      normalizedUploadUri,
      normalizedFilename(filename, `riverside-${normalizedOperationId}.png`),
      normalizedMimeType,
      sizeBytes
    );
  }
}

export class MediaUploadResult {
  public readonly id: number;
  public readonly url: string;
  public readonly shortUrl: string;
  public readonly originalFilename: string;
  public readonly markdown: string;

  private constructor(
    id: number,
    url: string,
    shortUrl: string,
    originalFilename: string,
    markdown: string
  ) {
    this.id = id;
    this.url = url;
    this.shortUrl = shortUrl;
    this.originalFilename = originalFilename;
    this.markdown = markdown;
  }

  public static create(
    id: number,
    url: string,
    shortUrl: string,
    originalFilename: string,
    markdown: string
  ): MediaUploadResult | null {
    const normalizedUrl: string = url.trim();
    const normalizedShortUrl: string = shortUrl.trim();
    const normalizedMarkdown: string = markdown.trim();
    if (
      !Number.isSafeInteger(id) ||
      id <= 0 ||
      (normalizedUrl.length === 0 && normalizedShortUrl.length === 0 && normalizedMarkdown.length === 0)
    ) {
      return null;
    }
    return new MediaUploadResult(
      id,
      normalizedUrl,
      normalizedShortUrl,
      normalizedFilename(originalFilename, 'upload.png'),
      normalizedMarkdown
    );
  }

  public composerMarkdown(): string {
    if (this.markdown.length > 0) {
      return this.markdown;
    }
    const destination: string = this.shortUrl.length > 0 ? this.shortUrl : this.url;
    const altText: string = this.originalFilename.replace(/\]/g, '');
    return `![${altText}](${destination})`;
  }
}

export enum MediaUploadPurpose {
  COMPOSER = 'composer',
  CHAT = 'chat',
  AVATAR = 'avatar',
  PROFILE_BACKGROUND = 'profile-background'
}

export class MediaUploadField {
  public readonly name: string;
  public readonly value: string;

  public constructor(name: string, value: string) {
    this.name = name;
    this.value = value;
  }
}

export class MediaUploadRequest {
  public readonly purpose: MediaUploadPurpose;
  public readonly media: CachedMedia;
  public readonly userId: number | null;

  private constructor(purpose: MediaUploadPurpose, media: CachedMedia, userId: number | null) {
    this.purpose = purpose;
    this.media = media;
    this.userId = userId;
  }

  public static composer(media: CachedMedia): MediaUploadRequest {
    return new MediaUploadRequest(MediaUploadPurpose.COMPOSER, media, null);
  }

  public static chat(media: CachedMedia): MediaUploadRequest {
    return new MediaUploadRequest(MediaUploadPurpose.CHAT, media, null);
  }

  public static avatar(media: CachedMedia, userId: number): MediaUploadRequest | null {
    if (!Number.isSafeInteger(userId) || userId <= 0) {
      return null;
    }
    return new MediaUploadRequest(MediaUploadPurpose.AVATAR, media, userId);
  }

  public static profileBackground(media: CachedMedia): MediaUploadRequest {
    return new MediaUploadRequest(MediaUploadPurpose.PROFILE_BACKGROUND, media, null);
  }

  public transportPath(): string {
    if (this.purpose === MediaUploadPurpose.COMPOSER || this.purpose === MediaUploadPurpose.CHAT) {
      return '/uploads.json';
    }
    return `/uploads.json?client_id=${this.clientId()}`;
  }

  public fields(): Array<MediaUploadField> {
    if (this.purpose === MediaUploadPurpose.COMPOSER || this.purpose === MediaUploadPurpose.CHAT) {
      return [
        new MediaUploadField('type', 'composer'),
        new MediaUploadField('synchronous', 'true')
      ];
    }
    const fields: Array<MediaUploadField> = [
      new MediaUploadField('client_id', this.clientId()),
      new MediaUploadField(
        'upload_type',
        this.purpose === MediaUploadPurpose.AVATAR ? 'avatar' : 'profile_background'
      ),
      new MediaUploadField('pasted', 'undefined'),
      new MediaUploadField('name', this.media.filename),
      new MediaUploadField('type', this.media.mimeType)
    ];
    if (this.purpose === MediaUploadPurpose.AVATAR && this.userId !== null) {
      fields.push(new MediaUploadField('user_id', this.userId.toString()));
    }
    return fields;
  }

  private clientId(): string {
    const normalized: string = this.media.operationId.replace(/[^a-zA-Z0-9]/g, '');
    return normalized.length > 0 ? normalized : 'riversidemedia';
  }
}

export enum MediaUploadStateKind {
  SELECTED = 'selected',
  UPLOADING = 'uploading',
  FAILED = 'failed',
  CANCELLED = 'cancelled',
  SUCCEEDED = 'succeeded'
}

export class MediaUploadState {
  public readonly kind: MediaUploadStateKind;
  public readonly media: CachedMedia;
  public readonly progressPercent: number;
  public readonly message: string;
  public readonly result: MediaUploadResult | null;

  private constructor(
    kind: MediaUploadStateKind,
    media: CachedMedia,
    progressPercent: number,
    message: string,
    result: MediaUploadResult | null
  ) {
    this.kind = kind;
    this.media = media;
    this.progressPercent = progressPercent;
    this.message = message;
    this.result = result;
  }

  public static selected(media: CachedMedia): MediaUploadState {
    return new MediaUploadState(MediaUploadStateKind.SELECTED, media, 0, '', null);
  }

  public uploading(uploadedBytes: number, totalBytes: number): MediaUploadState {
    const validTotal: number = totalBytes > 0 ? totalBytes : this.media.sizeBytes;
    const rawPercent: number = validTotal > 0 ? Math.floor(uploadedBytes * 100 / validTotal) : 0;
    const progressPercent: number = Math.max(0, Math.min(100, rawPercent));
    return new MediaUploadState(MediaUploadStateKind.UPLOADING, this.media, progressPercent, '', null);
  }

  public failed(message: string): MediaUploadState {
    const normalizedMessage: string = message.trim();
    return new MediaUploadState(
      MediaUploadStateKind.FAILED,
      this.media,
      this.progressPercent,
      normalizedMessage.length === 0 ? '图片上传失败' : normalizedMessage,
      null
    );
  }

  public cancelled(): MediaUploadState {
    return new MediaUploadState(
      MediaUploadStateKind.CANCELLED,
      this.media,
      this.progressPercent,
      '已取消图片上传',
      null
    );
  }

  public succeeded(result: MediaUploadResult): MediaUploadState {
    return new MediaUploadState(MediaUploadStateKind.SUCCEEDED, this.media, 100, '图片上传成功', result);
  }

  public canCancel(): boolean {
    return this.kind === MediaUploadStateKind.UPLOADING;
  }

  public canRetry(): boolean {
    return this.kind === MediaUploadStateKind.FAILED || this.kind === MediaUploadStateKind.CANCELLED;
  }
}

export function appendUploadedImageMarkdown(source: string, result: MediaUploadResult): string {
  const markdown: string = result.composerMarkdown();
  if (source.length === 0) {
    return `${markdown}\n`;
  }
  const separator: string = source.endsWith('\n') ? '\n' : '\n\n';
  return `${source}${separator}${markdown}\n`;
}
