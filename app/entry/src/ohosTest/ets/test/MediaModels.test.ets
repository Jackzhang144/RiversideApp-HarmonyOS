import { describe, expect, it } from '@ohos/hypium';
import {
  appendUploadedImageMarkdown,
  CachedMedia,
  MediaUploadResult,
  MediaUploadState,
  MediaUploadStateKind
} from '../../../main/ets/models/MediaModels';

export default function mediaModelsTest(): void {
  describe('Media selection and upload contract', () => {
    it('accepts only supported images copied into the application cache', 0, () => {
      const cached: CachedMedia | null = CachedMedia.create(
        'media-1700000000',
        '/data/storage/el2/base/cache/media/media-1700000000.jpg',
        'internal://cache/media/media-1700000000.jpg',
        'river.jpg',
        'image/jpeg',
        4096
      );

      expect(cached === null).assertFalse();
      expect(CachedMedia.create(
        'media-1700000001',
        '/data/storage/el2/base/cache/media/source.jpg',
        'file://media/selected.jpg',
        'selected.jpg',
        'image/jpeg',
        4096
      ) === null).assertTrue();
      expect(CachedMedia.create(
        'media-1700000002',
        '/data/storage/el2/base/cache/media/video.mp4',
        'internal://cache/media/video.mp4',
        'video.mp4',
        'video/mp4',
        4096
      ) === null).assertTrue();
      expect(CachedMedia.create(
        'media-1700000003',
        '/data/storage/el2/base/cache/media/empty.png',
        'internal://cache/media/empty.png',
        'empty.png',
        'image/png',
        0
      ) === null).assertTrue();
    });

    it('exposes progress, cancellation, failure and explicit retry states', 0, () => {
      const cached: CachedMedia | null = CachedMedia.create(
        'media-1700000000',
        '/data/storage/el2/base/cache/media/media-1700000000.png',
        'internal://cache/media/media-1700000000.png',
        'river.png',
        'image/png',
        1024
      );
      expect(cached === null).assertFalse();
      if (cached === null) {
        return;
      }

      const selected: MediaUploadState = MediaUploadState.selected(cached);
      const uploading: MediaUploadState = selected.uploading(300, 1000);
      const failed: MediaUploadState = uploading.failed('网络连接失败');
      const cancelled: MediaUploadState = uploading.cancelled();

      expect(selected.kind).assertEqual(MediaUploadStateKind.SELECTED);
      expect(selected.canRetry()).assertFalse();
      expect(uploading.kind).assertEqual(MediaUploadStateKind.UPLOADING);
      expect(uploading.progressPercent).assertEqual(30);
      expect(uploading.canCancel()).assertTrue();
      expect(failed.kind).assertEqual(MediaUploadStateKind.FAILED);
      expect(failed.canRetry()).assertTrue();
      expect(failed.message).assertEqual('网络连接失败');
      expect(cancelled.kind).assertEqual(MediaUploadStateKind.CANCELLED);
      expect(cancelled.canRetry()).assertTrue();
    });

    it('inserts image Markdown only from a valid server upload result', 0, () => {
      const result: MediaUploadResult | null = MediaUploadResult.create(
        812,
        '/uploads/default/original/3X/river.png',
        'upload://river-short-url',
        'river].png',
        '![river.png](upload://server-markdown)'
      );

      expect(result === null).assertFalse();
      if (result === null) {
        return;
      }
      expect(result.composerMarkdown()).assertEqual('![river.png](upload://server-markdown)');
      expect(appendUploadedImageMarkdown('正文', result)).assertEqual(
        '正文\n\n![river.png](upload://server-markdown)\n'
      );
      expect(MediaUploadResult.create(0, '', '', 'missing.png', '') === null).assertTrue();
    });
  });
}
