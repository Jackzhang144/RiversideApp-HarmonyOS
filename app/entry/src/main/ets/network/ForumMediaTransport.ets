import { util } from '@kit.ArkTS';
import { fileIo } from '@kit.CoreFileKit';
import { http } from '@kit.NetworkKit';
import { RIVERSIDE_ORIGIN } from '../core/RiversideEnvironment';
import {
  CachedMedia,
  isUploadImageSizeSupported,
  MediaUploadField,
  MediaUploadRequest
} from '../models/MediaModels';
import {
  AuthenticatedSessionProvider,
  DiscourseHeaders,
  DiscourseRequestHeadersFactory,
  HttpTextResult
} from './DiscourseHttpClient';

const CONNECT_TIMEOUT_MS: number = 8000;
const READ_TIMEOUT_MS: number = 30000;

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

function escapedDispositionValue(value: string): string {
  return value.replace(/\r/g, '').replace(/\n/g, '').replace(/"/g, '');
}

function textBytes(value: string): Uint8Array {
  return util.TextEncoder.create('utf-8').encodeInto(value);
}

function combinedBytes(parts: Array<Uint8Array>): ArrayBuffer {
  let byteLength: number = 0;
  for (const part of parts) {
    byteLength += part.byteLength;
  }
  const output: Uint8Array = new Uint8Array(byteLength);
  let offset: number = 0;
  for (const part of parts) {
    output.set(part, offset);
    offset += part.byteLength;
  }
  return output.buffer;
}

async function readMediaBytes(media: CachedMedia): Promise<Uint8Array | null> {
  let file: fileIo.File | null = null;
  try {
    file = await fileIo.open(media.absoluteCachePath, fileIo.OpenMode.READ_ONLY);
    const stat: fileIo.Stat = await fileIo.stat(file.fd);
    if (!Number.isSafeInteger(stat.size) || stat.size <= 0 || stat.size !== media.sizeBytes) {
      return null;
    }
    const bytes: Uint8Array = new Uint8Array(stat.size);
    let offset: number = 0;
    while (offset < stat.size) {
      const chunk: Uint8Array = new Uint8Array(Math.min(1024 * 1024, stat.size - offset));
      const readLength: number = await fileIo.read(file.fd, chunk.buffer, { length: chunk.byteLength });
      if (readLength <= 0) {
        return null;
      }
      bytes.set(chunk.subarray(0, readLength), offset);
      offset += readLength;
    }
    return bytes;
  } catch (_) {
    return null;
  } finally {
    if (file !== null) {
      try {
        await fileIo.close(file);
      } catch (_) {
      }
    }
  }
}

async function multipartBody(request: MediaTransportRequest, boundary: string): Promise<ArrayBuffer | null> {
  const parts: Array<Uint8Array> = [];
  for (const field of request.fields) {
    parts.push(textBytes(
      `--${boundary}\r\n` +
      `Content-Disposition: form-data; name="${escapedDispositionValue(field.name)}"\r\n\r\n` +
      `${field.value}\r\n`
    ));
  }
  parts.push(textBytes(
    `--${boundary}\r\n` +
    `Content-Disposition: form-data; name="file"; filename="${escapedDispositionValue(request.media.filename)}"\r\n` +
    `Content-Type: ${request.media.mimeType}\r\n\r\n`
  ));
  const fileBytes: Uint8Array | null = await readMediaBytes(request.media);
  if (fileBytes === null) {
    return null;
  }
  parts.push(fileBytes);
  parts.push(textBytes(`\r\n--${boundary}--\r\n`));
  return combinedBytes(parts);
}

class HttpMediaTransportOperation implements MediaTransportOperation {
  public completion: Promise<HttpTextResult> = Promise.resolve(
    HttpTextResult.invalidInput('图片上传尚未开始')
  );
  private activeRequest: http.HttpRequest | null = null;
  private cancelled: boolean = false;

  public begin(completion: Promise<HttpTextResult>): void {
    this.completion = completion;
  }

  public attach(request: http.HttpRequest): boolean {
    if (this.cancelled) {
      request.destroy();
      return false;
    }
    this.activeRequest = request;
    return true;
  }

  public detach(request: http.HttpRequest): void {
    if (this.activeRequest === request) {
      this.activeRequest = null;
    }
  }

  public isCancelled(): boolean {
    return this.cancelled;
  }

  public cancel(): void {
    this.cancelled = true;
    if (this.activeRequest !== null) {
      try {
        this.activeRequest.destroy();
      } catch (_) {
      }
      this.activeRequest = null;
    }
  }
}

export class DiscourseMediaTransport implements ForumMediaTransport {
  private readonly baseUrl: string;
  private readonly headersFactory: DiscourseRequestHeadersFactory;

  public constructor(
    baseUrl: string = RIVERSIDE_ORIGIN,
    sessionProvider: AuthenticatedSessionProvider | null = null
  ) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    this.headersFactory = new DiscourseRequestHeadersFactory(sessionProvider);
  }

  public upload(request: MediaTransportRequest, onProgress: MediaProgressListener): MediaTransportOperation {
    const operation: HttpMediaTransportOperation = new HttpMediaTransportOperation();
    operation.begin(this.executeUpload(operation, request, onProgress));
    return operation;
  }

  private async executeUpload(
    operation: HttpMediaTransportOperation,
    request: MediaTransportRequest,
    onProgress: MediaProgressListener
  ): Promise<HttpTextResult> {
    if (!request.path.startsWith('/')) {
      return HttpTextResult.invalidInput('上传路径无效');
    }
    if (!isUploadImageSizeSupported(request.media.sizeBytes)) {
      return HttpTextResult.invalidInput('图片大小无效或超过 20 MB');
    }
    const boundary: string = `----RiversideMedia${request.media.operationId.replace(/[^a-zA-Z0-9]/g, '')}`;
    const body: ArrayBuffer | null = await multipartBody(request, boundary);
    if (body === null) {
      return HttpTextResult.storage('无法读取图片缓存副本');
    }
    if (operation.isCancelled()) {
      return HttpTextResult.cancelled('已取消图片上传');
    }

    const httpRequest: http.HttpRequest = http.createHttp();
    if (!operation.attach(httpRequest)) {
      return HttpTextResult.cancelled('已取消图片上传');
    }
    const headers: DiscourseHeaders = this.headersFactory.create();
    httpRequest.on('dataSendProgress', (info: http.DataSendProgressInfo): void => {
      onProgress(info.sendSize, info.totalSize);
    });
    try {
      const response: http.HttpResponse = await httpRequest.request(
        `${this.baseUrl}${request.path}`,
        {
          method: http.RequestMethod.POST,
          header: headers.toHttpHeaderValues(`multipart/form-data; boundary=${boundary}`),
          extraData: body,
          expectDataType: http.HttpDataType.STRING,
          connectTimeout: CONNECT_TIMEOUT_MS,
          readTimeout: READ_TIMEOUT_MS,
          usingCache: false
        }
      );
      if (operation.isCancelled()) {
        return HttpTextResult.cancelled('已取消图片上传');
      }
      if (response.responseCode === 401) {
        return HttpTextResult.unauthorized();
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return HttpTextResult.failure(response.responseCode, `服务器返回 ${response.responseCode}`);
      }
      if (typeof response.result !== 'string') {
        return HttpTextResult.invalidResponse(response.responseCode, '上传响应格式无效');
      }
      return HttpTextResult.success(response.responseCode, response.result);
    } catch (_) {
      return operation.isCancelled()
        ? HttpTextResult.cancelled('已取消图片上传')
        : HttpTextResult.failure(0, '图片上传网络连接失败');
    } finally {
      httpRequest.off('dataSendProgress');
      operation.detach(httpRequest);
      httpRequest.destroy();
    }
  }
}
