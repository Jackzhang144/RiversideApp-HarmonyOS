import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import {
  CachedMedia,
  MediaUploadRequest,
  MediaUploadResult
} from '../../../main/ets/models/MediaModels';
import { HttpTextResult } from '../../../main/ets/network/DiscourseHttpClient';
import {
  ForumMediaTransport,
  MediaProgressListener,
  MediaTransportOperation,
  MediaTransportRequest
} from '../../../main/ets/network/ForumMediaTransport';
import {
  DiscourseMediaRepository,
  MediaUploadOperation
} from '../../../main/ets/repositories/MediaRepository';

class StubMediaTransportOperation implements MediaTransportOperation {
  public readonly completion: Promise<HttpTextResult>;
  public cancelled: boolean = false;

  public constructor(result: HttpTextResult) {
    this.completion = Promise.resolve(result);
  }

  public cancel(): void {
    this.cancelled = true;
  }
}

export class StubMediaTransport implements ForumMediaTransport {
  public readonly requests: Array<MediaTransportRequest> = [];
  public readonly operations: Array<StubMediaTransportOperation> = [];
  public results: Array<HttpTextResult> = [];

  public upload(request: MediaTransportRequest, onProgress: MediaProgressListener): MediaTransportOperation {
    this.requests.push(request);
    onProgress(512, 1024);
    const result: HttpTextResult = this.results.shift() ?? HttpTextResult.failure(0, 'missing upload result');
    const operation: StubMediaTransportOperation = new StubMediaTransportOperation(result);
    this.operations.push(operation);
    return operation;
  }
}

export function cachedPng(): CachedMedia {
  const media: CachedMedia | null = CachedMedia.create(
    'media-1700000000-abcd',
    '/data/storage/el2/base/cache/media/media-1700000000-abcd.png',
    'internal://cache/media/media-1700000000-abcd.png',
    'river.png',
    'image/png',
    1024
  );
  if (media === null) {
    throw new Error('test media must be valid');
  }
  return media;
}

export default function mediaRepositoryTest(): void {
  describe('Discourse media repository contract', () => {
    it('uploads a Composer image with progress and parses the server result', 0, async (done: Function) => {
      const transport: StubMediaTransport = new StubMediaTransport();
      transport.results.push(HttpTextResult.success(200,
        '{"id":812,"url":"/uploads/default/original/river.png",' +
        '"short_url":"upload://river-short","original_filename":"river.png",' +
        '"markdown":"![river.png](upload://river-short)"}'
      ));
      const repository: DiscourseMediaRepository = new DiscourseMediaRepository(transport);
      const progress: Array<number> = [];

      const operation: MediaUploadOperation = repository.upload(
        MediaUploadRequest.composer(cachedPng()),
        (uploadedBytes: number, totalBytes: number): void => {
          progress.push(uploadedBytes * 100 / totalBytes);
        }
      );
      const result: RepositoryResult<MediaUploadResult> = await operation.completion;

      expect(transport.requests[0].path).assertEqual('/uploads.json');
      expect(transport.requests[0].fieldValue('type')).assertEqual('composer');
      expect(transport.requests[0].fieldValue('synchronous')).assertEqual('true');
      expect(transport.requests[0].media.uploadUri).assertEqual('internal://cache/media/media-1700000000-abcd.png');
      expect(progress[0]).assertEqual(50);
      expect(result.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(result.data?.id).assertEqual(812);
      expect(result.data?.composerMarkdown()).assertEqual('![river.png](upload://river-short)');
      done();
    });

    it('builds the frozen avatar multipart fields and forwards cancellation', 0, async (done: Function) => {
      const transport: StubMediaTransport = new StubMediaTransport();
      transport.results.push(HttpTextResult.success(200,
        '{"id":813,"url":"/uploads/default/original/avatar.png","original_filename":"avatar.png"}'
      ));
      const repository: DiscourseMediaRepository = new DiscourseMediaRepository(transport);
      const request: MediaUploadRequest | null = MediaUploadRequest.avatar(cachedPng(), 38290);
      expect(request === null).assertFalse();
      if (request === null) {
        done();
        return;
      }

      const operation: MediaUploadOperation = repository.upload(request, (): void => {});
      operation.cancel();
      await operation.completion;

      expect(transport.requests[0].path).assertEqual('/uploads.json?client_id=media1700000000abcd');
      expect(transport.requests[0].fieldValue('client_id')).assertEqual('media1700000000abcd');
      expect(transport.requests[0].fieldValue('upload_type')).assertEqual('avatar');
      expect(transport.requests[0].fieldValue('user_id')).assertEqual('38290');
      expect(transport.requests[0].fieldValue('pasted')).assertEqual('undefined');
      expect(transport.requests[0].fieldValue('name')).assertEqual('river.png');
      expect(transport.requests[0].fieldValue('type')).assertEqual('image/png');
      expect(transport.operations[0].cancelled).assertTrue();
      expect(MediaUploadRequest.avatar(cachedPng(), 0) === null).assertTrue();
      done();
    });

    it('does not accept unauthorized, failed, or malformed uploads as successful', 0, async (done: Function) => {
      const transport: StubMediaTransport = new StubMediaTransport();
      transport.results.push(HttpTextResult.unauthorized());
      transport.results.push(HttpTextResult.failure(413, '服务器返回 413'));
      transport.results.push(HttpTextResult.success(200, '{"url":"/uploads/missing-id.png"}'));
      const repository: DiscourseMediaRepository = new DiscourseMediaRepository(transport);

      const unauthorized: RepositoryResult<MediaUploadResult> = await repository
        .upload(MediaUploadRequest.composer(cachedPng()), (): void => {}).completion;
      const failed: RepositoryResult<MediaUploadResult> = await repository
        .upload(MediaUploadRequest.composer(cachedPng()), (): void => {}).completion;
      const malformed: RepositoryResult<MediaUploadResult> = await repository
        .upload(MediaUploadRequest.composer(cachedPng()), (): void => {}).completion;

      expect(unauthorized.kind).assertEqual(RepositoryResultKind.UNAUTHORIZED);
      expect(failed.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(failed.message).assertEqual('服务器返回 413');
      expect(malformed.kind).assertEqual(RepositoryResultKind.FAILURE);
      expect(malformed.message).assertEqual('上传响应缺少有效媒体信息');
      done();
    });
  });
}
