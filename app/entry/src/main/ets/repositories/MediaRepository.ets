import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import {
  MediaUploadRequest,
  MediaUploadResult
} from '../models/MediaModels';
import { HttpTextResult, HttpTextResultKind } from '../network/DiscourseHttpClient';
import {
  ForumMediaTransport,
  MediaProgressListener,
  MediaTransportOperation,
  MediaTransportRequest
} from '../network/ForumMediaTransport';

export class MediaUploadOperation {
  public readonly completion: Promise<RepositoryResult<MediaUploadResult>>;
  private readonly transportOperation: MediaTransportOperation;

  public constructor(
    transportOperation: MediaTransportOperation,
    completion: Promise<RepositoryResult<MediaUploadResult>>
  ) {
    this.transportOperation = transportOperation;
    this.completion = completion;
  }

  public cancel(): void {
    this.transportOperation.cancel();
  }
}

export interface MediaRepository {
  upload(request: MediaUploadRequest, onProgress: MediaProgressListener): MediaUploadOperation;
}

export class DiscourseMediaRepository implements MediaRepository {
  private readonly transport: ForumMediaTransport;

  public constructor(transport: ForumMediaTransport) {
    this.transport = transport;
  }

  public upload(request: MediaUploadRequest, onProgress: MediaProgressListener): MediaUploadOperation {
    const transportOperation: MediaTransportOperation = this.transport.upload(
      MediaTransportRequest.fromUploadRequest(request),
      onProgress
    );
    const completion: Promise<RepositoryResult<MediaUploadResult>> = transportOperation.completion.then(
      (result: HttpTextResult): RepositoryResult<MediaUploadResult> => this.parseResult(result)
    );
    return new MediaUploadOperation(transportOperation, completion);
  }

  private parseResult(response: HttpTextResult): RepositoryResult<MediaUploadResult> {
    if (response.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<MediaUploadResult>();
    }
    if (!response.isSuccess()) {
      return response.asRepositoryFailure<MediaUploadResult>();
    }
    const reader: JsonObjectReader | null = JsonObjectReader.parse(response.body);
    if (reader === null) {
      return RepositoryResult.invalidResponse<MediaUploadResult>('上传响应格式无效');
    }
    const id: number = Math.trunc(reader.number('id') ?? 0);
    const result: MediaUploadResult | null = MediaUploadResult.create(
      id,
      reader.string('url') ?? reader.string('short_path') ?? '',
      reader.string('short_url') ?? '',
      reader.string('original_filename') ?? '',
      reader.string('markdown') ?? ''
    );
    return result === null
      ? RepositoryResult.invalidResponse<MediaUploadResult>('上传响应缺少有效媒体信息')
      : RepositoryResult.success<MediaUploadResult>(result);
  }
}
