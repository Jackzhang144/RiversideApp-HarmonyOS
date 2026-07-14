import { CachedMedia } from './MediaModels';

function httpsOrigin(value: string): string {
  const normalized: string = value.trim();
  if (!normalized.startsWith('https://')) {
    return '';
  }
  const authorityStart: number = 'https://'.length;
  let authorityEnd: number = normalized.length;
  for (const delimiter of ['/', '?', '#']) {
    const index: number = normalized.indexOf(delimiter, authorityStart);
    if (index >= 0) {
      authorityEnd = Math.min(authorityEnd, index);
    }
  }
  const authority: string = normalized.substring(authorityStart, authorityEnd).toLowerCase();
  if (authority.length === 0 || authority.includes('@') || authority.includes(' ')) {
    return '';
  }
  return `https://${authority}`;
}

export function normalizeRemoteImageUrl(value: string, baseUrl: string): string {
  const normalized: string = value.trim();
  if (normalized.startsWith('https://')) {
    return httpsOrigin(normalized).length > 0 ? normalized : '';
  }
  const normalizedBase: string = baseUrl.trim().replace(/\/$/, '');
  if (
    normalized.startsWith('/') &&
    httpsOrigin(normalizedBase).length > 0
  ) {
    return `${normalizedBase}${normalized}`;
  }
  return '';
}

export function isSameHttpsOrigin(url: string, baseUrl: string): boolean {
  const urlOrigin: string = httpsOrigin(url);
  return urlOrigin.length > 0 && urlOrigin === httpsOrigin(baseUrl);
}

export enum ImageViewerStateKind {
  PREPARING = 'preparing',
  READY = 'ready',
  SAVING = 'saving',
  SAVED = 'saved',
  ERROR = 'error'
}

export class ImageViewerState {
  public readonly kind: ImageViewerStateKind;
  public readonly remoteUrl: string;
  public readonly title: string;
  public readonly cachedMedia: CachedMedia | null;
  public readonly message: string;

  private constructor(
    kind: ImageViewerStateKind,
    remoteUrl: string,
    title: string,
    cachedMedia: CachedMedia | null,
    message: string
  ) {
    this.kind = kind;
    this.remoteUrl = remoteUrl;
    this.title = title;
    this.cachedMedia = cachedMedia;
    this.message = message;
  }

  public static preparing(remoteUrl: string, title: string): ImageViewerState {
    return new ImageViewerState(ImageViewerStateKind.PREPARING, remoteUrl, title, null, '');
  }

  public ready(cachedMedia: CachedMedia): ImageViewerState {
    return new ImageViewerState(ImageViewerStateKind.READY, this.remoteUrl, this.title, cachedMedia, '');
  }

  public saving(): ImageViewerState {
    return new ImageViewerState(
      ImageViewerStateKind.SAVING,
      this.remoteUrl,
      this.title,
      this.cachedMedia,
      '正在保存图片'
    );
  }

  public saved(): ImageViewerState {
    return new ImageViewerState(
      ImageViewerStateKind.SAVED,
      this.remoteUrl,
      this.title,
      this.cachedMedia,
      '图片已保存到系统相册'
    );
  }

  public failed(message: string): ImageViewerState {
    const normalized: string = message.trim();
    return new ImageViewerState(
      ImageViewerStateKind.ERROR,
      this.remoteUrl,
      this.title,
      this.cachedMedia,
      normalized.length > 0 ? normalized : '图片操作失败'
    );
  }
}

export class ImageViewerPresentation {
  private readonly state: ImageViewerState;

  public constructor(state: ImageViewerState) {
    this.state = state;
  }

  public canCopyUrl(): boolean {
    return this.state.remoteUrl.length > 0;
  }

  public canOpenExternally(): boolean {
    return this.state.remoteUrl.length > 0;
  }

  public canSave(): boolean {
    return this.state.cachedMedia !== null && this.state.kind !== ImageViewerStateKind.SAVING;
  }

  public statusText(): string {
    if (this.state.kind === ImageViewerStateKind.PREPARING) {
      return '正在准备原图';
    }
    return this.state.message;
  }

  public imageSource(): string {
    return this.state.cachedMedia?.absoluteCachePath ?? this.state.remoteUrl;
  }
}
