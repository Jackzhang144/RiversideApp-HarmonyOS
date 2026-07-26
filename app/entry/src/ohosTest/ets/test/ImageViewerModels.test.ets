import { describe, expect, it } from '@ohos/hypium';
import {
  ImageViewerPresentation,
  ImageViewerState,
  ImageViewerStateKind,
  imageViewerTransitionId,
  isSameHttpsOrigin,
  normalizeRemoteImageUrl
} from '../../../main/ets/models/ImageViewerModels';
import { CachedMedia } from '../../../main/ets/models/MediaModels';

function cachedViewerImage(): CachedMedia {
  const media: CachedMedia | null = CachedMedia.create(
    'viewer-image',
    '/data/storage/el2/base/cache/media/viewer-image.jpg',
    'internal://cache/media/viewer-image.jpg',
    'viewer-image.jpg',
    'image/jpeg',
    2048
  );
  if (media === null) {
    throw new Error('测试查看器缓存模型创建失败');
  }
  return media;
}

export default function imageViewerModelsTest(): void {
  describe('Image viewer presentation contract', () => {
    it('normalizes only trusted HTTP image targets', 0, () => {
      expect(normalizeRemoteImageUrl('/uploads/default/original/1X/a.jpg', 'https://river-side.cc'))
        .assertEqual('https://river-side.cc/uploads/default/original/1X/a.jpg');
      expect(normalizeRemoteImageUrl('https://cdn.example.com/a.png', 'https://river-side.cc'))
        .assertEqual('https://cdn.example.com/a.png');
      expect(normalizeRemoteImageUrl('http://cdn.example.com/a.png', 'https://river-side.cc')).assertEqual('');
      expect(normalizeRemoteImageUrl('file:///data/private/a.png', 'https://river-side.cc')).assertEqual('');
      expect(normalizeRemoteImageUrl('javascript:alert(1)', 'https://river-side.cc')).assertEqual('');
      expect(isSameHttpsOrigin('https://river-side.cc/a.jpg', 'https://river-side.cc')).assertTrue();
      expect(isSameHttpsOrigin('https://cdn.example.com/a.jpg', 'https://river-side.cc')).assertFalse();
      expect(isSameHttpsOrigin('https://river-side.cc.evil.example/a.jpg', 'https://river-side.cc')).assertFalse();
    });

    it('offers copy and external open while preparing a gallery-safe cache copy', 0, () => {
      const transitionId: string = imageViewerTransitionId('topic-12-post-34', 2);
      const state: ImageViewerState = ImageViewerState.preparing(
        'https://river-side.cc/a.jpg',
        '示例图',
        transitionId
      );
      const presentation: ImageViewerPresentation = new ImageViewerPresentation(state);

      expect(state.kind).assertEqual(ImageViewerStateKind.PREPARING);
      expect(state.transitionId).assertEqual('image-viewer-topic-12-post-34-2');
      expect(presentation.canCopyUrl()).assertTrue();
      expect(presentation.canOpenExternally()).assertTrue();
      expect(presentation.canSave()).assertFalse();
      expect(presentation.statusText()).assertEqual('正在准备原图');
      expect(imageViewerTransitionId('', 0)).assertEqual('');
      expect(imageViewerTransitionId('topic-12', -1)).assertEqual('');
    });

    it('enables save only after the original image is cached', 0, () => {
      const state: ImageViewerState = ImageViewerState
        .preparing('https://river-side.cc/a.jpg', '示例图')
        .ready(cachedViewerImage());
      const presentation: ImageViewerPresentation = new ImageViewerPresentation(state);

      expect(state.kind).assertEqual(ImageViewerStateKind.READY);
      expect(presentation.canSave()).assertTrue();
      expect(presentation.imageSource()).assertEqual('/data/storage/el2/base/cache/media/viewer-image.jpg');
      expect(state.saving().kind).assertEqual(ImageViewerStateKind.SAVING);
      expect(state.saved().message).assertEqual('图片已保存到系统相册');
      expect(state.saved().transitionId).assertEqual(state.transitionId);
    });
  });
}
