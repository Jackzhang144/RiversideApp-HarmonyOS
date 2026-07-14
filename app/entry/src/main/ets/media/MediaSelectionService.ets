import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { CachedMedia, isUploadImageSizeSupported } from '../models/MediaModels';

export enum MediaSelectionResultKind {
  SELECTED = 'selected',
  CANCELLED = 'cancelled',
  FAILURE = 'failure'
}

export class MediaSelectionResult {
  public readonly kind: MediaSelectionResultKind;
  public readonly media: Array<CachedMedia>;
  public readonly message: string;

  private constructor(kind: MediaSelectionResultKind, media: Array<CachedMedia>, message: string) {
    this.kind = kind;
    this.media = media;
    this.message = message;
  }

  public static selected(media: Array<CachedMedia>): MediaSelectionResult {
    return new MediaSelectionResult(MediaSelectionResultKind.SELECTED, media.slice(), '');
  }

  public static cancelled(): MediaSelectionResult {
    return new MediaSelectionResult(MediaSelectionResultKind.CANCELLED, [], '');
  }

  public static failure(message: string): MediaSelectionResult {
    return new MediaSelectionResult(MediaSelectionResultKind.FAILURE, [], message);
  }
}

class SelectedImageType {
  public readonly extension: string;
  public readonly mimeType: string;

  public constructor(extension: string, mimeType: string) {
    this.extension = extension;
    this.mimeType = mimeType;
  }
}

function imageType(filename: string): SelectedImageType | null {
  const normalized: string = filename.trim().toLowerCase();
  if (normalized.endsWith('.jpg') || normalized.endsWith('.jpeg')) {
    return new SelectedImageType('jpg', 'image/jpeg');
  }
  if (normalized.endsWith('.png')) {
    return new SelectedImageType('png', 'image/png');
  }
  if (normalized.endsWith('.gif')) {
    return new SelectedImageType('gif', 'image/gif');
  }
  if (normalized.endsWith('.webp')) {
    return new SelectedImageType('webp', 'image/webp');
  }
  return null;
}

export class MediaSelectionService {
  private readonly context: common.UIAbilityContext;
  private operationSequence: number = 0;

  public constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  public async selectImages(maxSelectNumber: number = 5): Promise<MediaSelectionResult> {
    const normalizedMaximum: number = Math.max(1, Math.min(9, Math.trunc(maxSelectNumber)));
    const options: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    options.maxSelectNumber = normalizedMaximum;
    options.isOriginalSupported = true;
    options.isPhotoTakingSupported = false;
    try {
      const picker: photoAccessHelper.PhotoViewPicker = new photoAccessHelper.PhotoViewPicker();
      const result: photoAccessHelper.PhotoSelectResult = await picker.select(options);
      if (result.photoUris.length === 0) {
        return MediaSelectionResult.cancelled();
      }
      const cachedMedia: Array<CachedMedia> = [];
      for (const sourceUri of result.photoUris) {
        const copied: CachedMedia | null = await this.copySelectionToCache(sourceUri);
        if (copied === null) {
          await this.removeCachedMedia(cachedMedia);
          return MediaSelectionResult.failure('所选图片格式不受支持或无法复制到应用缓存');
        }
        cachedMedia.push(copied);
      }
      return MediaSelectionResult.selected(cachedMedia);
    } catch (_) {
      return MediaSelectionResult.failure('无法打开系统图片选择器');
    }
  }

  private async removeCachedMedia(media: Array<CachedMedia>): Promise<void> {
    for (const cached of media) {
      try {
        await fileIo.unlink(cached.absoluteCachePath);
      } catch (_) {
      }
    }
  }

  private async copySelectionToCache(sourceUri: string): Promise<CachedMedia | null> {
    let source: fileIo.File | null = null;
    try {
      source = await fileIo.open(sourceUri, fileIo.OpenMode.READ_ONLY);
      const type: SelectedImageType | null = imageType(source.name);
      if (type === null) {
        return null;
      }
      const sourceStat: fileIo.Stat = await fileIo.stat(source.fd);
      if (!isUploadImageSizeSupported(sourceStat.size)) {
        return null;
      }
      const mediaDirectory: string = `${this.context.cacheDir}/media`;
      if (!await fileIo.access(mediaDirectory)) {
        await fileIo.mkdir(mediaDirectory);
      }
      this.operationSequence += 1;
      const operationId: string = `media-${Date.now()}-${this.operationSequence}`;
      const cacheFilename: string = `${operationId}.${type.extension}`;
      const absoluteCachePath: string = `${mediaDirectory}/${cacheFilename}`;
      await fileIo.copyFile(source.fd, absoluteCachePath);
      const stat: fileIo.Stat = await fileIo.stat(absoluteCachePath);
      return CachedMedia.create(
        operationId,
        absoluteCachePath,
        `internal://cache/media/${cacheFilename}`,
        source.name,
        type.mimeType,
        stat.size
      );
    } catch (_) {
      return null;
    } finally {
      if (source !== null) {
        try {
          await fileIo.close(source);
        } catch (_) {
        }
      }
    }
  }
}
