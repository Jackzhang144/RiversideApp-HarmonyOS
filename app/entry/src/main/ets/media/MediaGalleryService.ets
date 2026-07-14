import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { http } from '@kit.NetworkKit';
import { RepositoryResult } from '../core/RepositoryResult';
import { CachedMedia } from '../models/MediaModels';
import {
  AuthenticatedSessionProvider,
  DiscourseHeaders,
  DiscourseRequestHeadersFactory
} from '../network/DiscourseHttpClient';

const MAX_IMAGE_BYTES: number = 30 * 1024 * 1024;

class DetectedImageType {
  public readonly extension: string;
  public readonly mimeType: string;

  public constructor(extension: string, mimeType: string) {
    this.extension = extension;
    this.mimeType = mimeType;
  }
}

function detectImageType(bytes: Uint8Array): DetectedImageType | null {
  if (bytes.byteLength >= 3 && bytes[0] === 0xFF && bytes[1] === 0xD8 && bytes[2] === 0xFF) {
    return new DetectedImageType('jpg', 'image/jpeg');
  }
  if (
    bytes.byteLength >= 8 &&
    bytes[0] === 0x89 && bytes[1] === 0x50 && bytes[2] === 0x4E && bytes[3] === 0x47 &&
    bytes[4] === 0x0D && bytes[5] === 0x0A && bytes[6] === 0x1A && bytes[7] === 0x0A
  ) {
    return new DetectedImageType('png', 'image/png');
  }
  if (
    bytes.byteLength >= 6 && bytes[0] === 0x47 && bytes[1] === 0x49 && bytes[2] === 0x46 &&
    bytes[3] === 0x38 && (bytes[4] === 0x37 || bytes[4] === 0x39) && bytes[5] === 0x61
  ) {
    return new DetectedImageType('gif', 'image/gif');
  }
  if (
    bytes.byteLength >= 12 &&
    bytes[0] === 0x52 && bytes[1] === 0x49 && bytes[2] === 0x46 && bytes[3] === 0x46 &&
    bytes[8] === 0x57 && bytes[9] === 0x45 && bytes[10] === 0x42 && bytes[11] === 0x50
  ) {
    return new DetectedImageType('webp', 'image/webp');
  }
  return null;
}

export class MediaGalleryService {
  private readonly context: common.UIAbilityContext;
  private readonly headersFactory: DiscourseRequestHeadersFactory;
  private operationSequence: number = 0;

  public constructor(
    context: common.UIAbilityContext,
    sessionProvider: AuthenticatedSessionProvider | null = null
  ) {
    this.context = context;
    this.headersFactory = new DiscourseRequestHeadersFactory(sessionProvider);
  }

  public async prepareOriginal(remoteUrl: string): Promise<RepositoryResult<CachedMedia>> {
    const request: http.HttpRequest = http.createHttp();
    const headers: DiscourseHeaders = this.headersFactory.create();
    try {
      const response: http.HttpResponse = await request.request(remoteUrl, {
        method: http.RequestMethod.GET,
        header: headers.toHttpHeaderValues(),
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: 8000,
        readTimeout: 30000,
        usingCache: false
      });
      if (response.responseCode === 401) {
        return RepositoryResult.unauthorized<CachedMedia>();
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return RepositoryResult.failure<CachedMedia>(`原图下载失败：服务器返回 ${response.responseCode}`);
      }
      if (!(response.result instanceof ArrayBuffer)) {
        return RepositoryResult.failure<CachedMedia>('原图下载响应格式无效');
      }
      const bytes: Uint8Array = new Uint8Array(response.result);
      if (bytes.byteLength <= 0 || bytes.byteLength > MAX_IMAGE_BYTES) {
        return RepositoryResult.failure<CachedMedia>('原图大小无效或超过 30 MB');
      }
      const detected: DetectedImageType | null = detectImageType(bytes);
      if (detected === null) {
        return RepositoryResult.failure<CachedMedia>('原图不是受支持的 JPEG、PNG、GIF 或 WebP');
      }
      return await this.persistCacheCopy(bytes, detected);
    } catch (_) {
      return RepositoryResult.failure<CachedMedia>('原图下载网络连接失败');
    } finally {
      request.destroy();
    }
  }

  public async saveToGallery(media: CachedMedia): Promise<RepositoryResult<boolean>> {
    const helper: photoAccessHelper.PhotoAccessHelper = photoAccessHelper.getPhotoAccessHelper(this.context);
    try {
      const request: photoAccessHelper.MediaAssetChangeRequest =
        photoAccessHelper.MediaAssetChangeRequest.createImageAssetRequest(
          this.context,
          `file://${media.absoluteCachePath}`
        );
      await helper.applyChanges(request);
      return RepositoryResult.success<boolean>(true);
    } catch (_) {
      return RepositoryResult.failure<boolean>('无法将图片写入系统相册');
    } finally {
      try {
        await helper.release();
      } catch (_) {
      }
    }
  }

  private async persistCacheCopy(
    bytes: Uint8Array,
    detected: DetectedImageType
  ): Promise<RepositoryResult<CachedMedia>> {
    let file: fileIo.File | null = null;
    try {
      const mediaDirectory: string = `${this.context.cacheDir}/media`;
      if (!await fileIo.access(mediaDirectory)) {
        await fileIo.mkdir(mediaDirectory);
      }
      this.operationSequence += 1;
      const operationId: string = `viewer-${Date.now()}-${this.operationSequence}`;
      const filename: string = `${operationId}.${detected.extension}`;
      const absoluteCachePath: string = `${mediaDirectory}/${filename}`;
      file = await fileIo.open(
        absoluteCachePath,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC
      );
      const written: number = await fileIo.write(file.fd, bytes.buffer, { length: bytes.byteLength });
      if (written !== bytes.byteLength) {
        return RepositoryResult.failure<CachedMedia>('原图缓存写入不完整');
      }
      const media: CachedMedia | null = CachedMedia.create(
        operationId,
        absoluteCachePath,
        `internal://cache/media/${filename}`,
        filename,
        detected.mimeType,
        bytes.byteLength
      );
      return media === null
        ? RepositoryResult.failure<CachedMedia>('原图缓存信息无效')
        : RepositoryResult.success<CachedMedia>(media);
    } catch (_) {
      return RepositoryResult.failure<CachedMedia>('无法创建原图缓存副本');
    } finally {
      if (file !== null) {
        try {
          await fileIo.close(file);
        } catch (_) {
        }
      }
    }
  }
}
