import { hilog } from '@kit.PerformanceAnalysisKit';
import { rcp } from '@kit.RemoteCommunicationKit';
import { AuthenticatedSession } from '../auth/AuthModels';
import { RIVERSIDE_ORIGIN } from '../core/RiversideEnvironment';
import { AppMetadata } from '../core/AppMetadata';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryFailureCode, RepositoryResult } from '../core/RepositoryResult';
import { AppLogger } from '../logging/DiagnosticLogStore';
import { ReplyRequest } from '../models/ReplyModels';
import {
  AlwaysAvailableNetworkProvider,
  NetworkAvailabilityProvider
} from './NetworkStatusMonitor';

const HTTP_LOG_DOMAIN: number = 0x0000;
const HTTP_LOG_TAG: string = 'DiscourseHttp';
const RCP_OPERATION_TIMEOUT_CODE: number = 1007900028;
const CONNECT_TIMEOUT_MS: number = 15000;
const READ_TIMEOUT_MS: number = 30000;

export enum HttpTextResultKind {
  SUCCESS = 'success',
  UNAUTHORIZED = 'unauthorized',
  FAILURE = 'failure'
}

export class HttpTextResult {
  public readonly kind: HttpTextResultKind;
  public readonly statusCode: number;
  public readonly body: string;
  public readonly failureCode: RepositoryFailureCode | null;
  public readonly message: string;

  private constructor(
    kind: HttpTextResultKind,
    statusCode: number,
    body: string,
    failureCode: RepositoryFailureCode | null,
    message: string
  ) {
    this.kind = kind;
    this.statusCode = statusCode;
    this.body = body;
    this.failureCode = failureCode;
    this.message = message;
  }

  public static success(statusCode: number, body: string): HttpTextResult {
    return new HttpTextResult(HttpTextResultKind.SUCCESS, statusCode, body, null, '');
  }

  public static unauthorized(): HttpTextResult {
    return new HttpTextResult(
      HttpTextResultKind.UNAUTHORIZED,
      401,
      '',
      RepositoryFailureCode.UNAUTHORIZED,
      '登录已失效'
    );
  }

  public static failure(statusCode: number, message: string): HttpTextResult {
    const code: RepositoryFailureCode = statusCode > 0
      ? RepositoryFailureCode.SERVER
      : RepositoryFailureCode.NETWORK;
    return HttpTextResult.failed(statusCode, code, message);
  }

  public static timeout(message: string): HttpTextResult {
    return HttpTextResult.failed(0, RepositoryFailureCode.TIMEOUT, message);
  }

  public static invalidInput(message: string): HttpTextResult {
    return HttpTextResult.failed(0, RepositoryFailureCode.INVALID_INPUT, message);
  }

  public static invalidResponse(statusCode: number, message: string): HttpTextResult {
    return HttpTextResult.failed(statusCode, RepositoryFailureCode.INVALID_RESPONSE, message);
  }

  public static storage(message: string): HttpTextResult {
    return HttpTextResult.failed(0, RepositoryFailureCode.STORAGE, message);
  }

  public static cancelled(message: string): HttpTextResult {
    return HttpTextResult.failed(0, RepositoryFailureCode.CANCELLED, message);
  }

  public isSuccess(): boolean {
    return this.kind === HttpTextResultKind.SUCCESS;
  }

  public asRepositoryFailure<T>(): RepositoryResult<T> {
    if (this.kind === HttpTextResultKind.UNAUTHORIZED) {
      return RepositoryResult.unauthorized<T>();
    }
    return RepositoryResult.withFailure<T>(
      this.failureCode ?? RepositoryFailureCode.UNKNOWN,
      this.message
    );
  }

  private static failed(
    statusCode: number,
    failureCode: RepositoryFailureCode,
    message: string
  ): HttpTextResult {
    return new HttpTextResult(HttpTextResultKind.FAILURE, statusCode, '', failureCode, message);
  }
}

export class DiscourseRequestPolicy {
  public readonly connectTimeoutMs: number = CONNECT_TIMEOUT_MS;
  public readonly transferTimeoutMs: number = READ_TIMEOUT_MS;

  public shouldRetryTopicGet(
    path: string,
    result: HttpTextResult,
    completedAttempts: number
  ): boolean {
    return path.startsWith('/t/') &&
      result.failureCode === RepositoryFailureCode.TIMEOUT &&
      completedAttempts < 2;
  }
}

export function httpFailureForErrorCode(errorCode: number | null): HttpTextResult {
  return errorCode === RCP_OPERATION_TIMEOUT_CODE
    ? HttpTextResult.timeout('请求超时，请重试')
    : HttpTextResult.failure(0, '网络连接失败');
}

export function httpTextResultForSuccessfulResponse(
  statusCode: number,
  body: ArrayBuffer | undefined,
  responseText: string | null
): HttpTextResult {
  if (body === undefined || body.byteLength === 0) {
    return HttpTextResult.success(statusCode, '');
  }
  if (responseText === null) {
    return HttpTextResult.invalidResponse(statusCode, '服务器响应格式无效');
  }
  return HttpTextResult.success(statusCode, responseText);
}

function caughtHttpErrorCode(error: Object): number | null {
  try {
    return JsonObjectReader.parse(JSON.stringify(error))?.number('code') ?? null;
  } catch (_) {
    return null;
  }
}

export class HttpTextRequestAttempt {
  private readonly request: () => Promise<HttpTextResult>;

  public constructor(request: () => Promise<HttpTextResult>) {
    this.request = request;
  }

  public execute(): Promise<HttpTextResult> {
    return this.request();
  }
}

export async function executeTopicGetWithRetry(
  path: string,
  operation: HttpTextRequestAttempt,
  policy: DiscourseRequestPolicy = new DiscourseRequestPolicy()
): Promise<HttpTextResult> {
  let completedAttempts: number = 0;
  while (true) {
    const result: HttpTextResult = await operation.execute();
    completedAttempts += 1;
    if (!policy.shouldRetryTopicGet(path, result, completedAttempts)) {
      return result;
    }
  }
}

interface HttpHeaderValues {
  'User-Agent': string;
  Accept: string;
  'User-Api-Key'?: string;
  'User-Api-Client-Id'?: string;
  'Content-Type'?: string;
}

interface TopicReplyPayloadValues {
  topic_id: number;
  raw: string;
}

interface TargetedReplyPayloadValues {
  topic_id: number;
  raw: string;
  reply_to_post_number: number;
}

export class DiscourseReplyPayload {
  private readonly request: ReplyRequest;

  public constructor(request: ReplyRequest) {
    this.request = request;
  }

  public toHttpExtraData(): Object {
    if (this.request.replyToPostNumber === null) {
      const payload: TopicReplyPayloadValues = {
        topic_id: this.request.topicId,
        raw: this.request.raw
      };
      return payload;
    }
    const payload: TargetedReplyPayloadValues = {
      topic_id: this.request.topicId,
      raw: this.request.raw,
      reply_to_post_number: this.request.replyToPostNumber
    };
    return payload;
  }
}

export class DiscourseHeaders {
  public readonly userAgent: string;
  public readonly accept: string;
  public readonly userApiKey: string | null;
  public readonly userApiClientId: string | null;

  public constructor(userApiKey: string | null, userApiClientId: string | null) {
    this.userAgent = AppMetadata.current().userAgent();
    this.accept = 'application/json';
    this.userApiKey = userApiKey;
    this.userApiClientId = userApiClientId;
  }

  public toHttpHeaderValues(contentType: string | null = null): HttpHeaderValues {
    if (this.userApiKey === null || this.userApiClientId === null) {
      if (contentType === null) {
        return {
          'User-Agent': this.userAgent,
          Accept: this.accept
        };
      }
      return {
        'User-Agent': this.userAgent,
        Accept: this.accept,
        'Content-Type': contentType
      };
    }
    if (contentType === null) {
      return {
        'User-Agent': this.userAgent,
        Accept: this.accept,
        'User-Api-Key': this.userApiKey,
        'User-Api-Client-Id': this.userApiClientId
      };
    }
    return {
      'User-Agent': this.userAgent,
      Accept: this.accept,
      'User-Api-Key': this.userApiKey,
      'User-Api-Client-Id': this.userApiClientId,
      'Content-Type': contentType
    };
  }

  public toRcpRequestHeaders(contentType: string | null = null): rcp.RequestHeaders {
    if (this.userApiKey === null || this.userApiClientId === null) {
      if (contentType === null) {
        return {
          'User-Agent': this.userAgent,
          Accept: this.accept
        };
      }
      return {
        'User-Agent': this.userAgent,
        Accept: this.accept,
        'Content-Type': contentType
      };
    }
    if (contentType === null) {
      return {
        'User-Agent': this.userAgent,
        Accept: this.accept,
        'User-Api-Key': this.userApiKey,
        'User-Api-Client-Id': this.userApiClientId
      };
    }
    return {
      'User-Agent': this.userAgent,
      Accept: this.accept,
      'User-Api-Key': this.userApiKey,
      'User-Api-Client-Id': this.userApiClientId,
      'Content-Type': contentType
    };
  }
}

export interface AuthenticatedSessionProvider {
  currentSession(): AuthenticatedSession | null;
}

export class DiscourseRequestHeadersFactory {
  private readonly sessionProvider: AuthenticatedSessionProvider | null;

  public constructor(sessionProvider: AuthenticatedSessionProvider | null) {
    this.sessionProvider = sessionProvider;
  }

  public create(): DiscourseHeaders {
    const session: AuthenticatedSession | null = this.sessionProvider?.currentSession() ?? null;
    if (session === null) {
      return new DiscourseHeaders(null, null);
    }
    return new DiscourseHeaders(session.key, session.clientId);
  }
}

export interface PresenceHttpClient {
  postForm(path: string, body: string): Promise<HttpTextResult>;
}

export interface ForumHttpClient extends PresenceHttpClient {
  get(path: string): Promise<HttpTextResult>;

  postReply(request: ReplyRequest): Promise<HttpTextResult>;

  put(path: string): Promise<HttpTextResult>;

  postJson(path: string, body: string): Promise<HttpTextResult>;

  putForm(path: string, body: string): Promise<HttpTextResult>;

  deleteForm(path: string, body: string): Promise<HttpTextResult>;

  delete(path: string): Promise<HttpTextResult>;
}

export class DiscourseHttpClient implements ForumHttpClient {
  private readonly baseUrl: string;
  private readonly headersFactory: DiscourseRequestHeadersFactory;
  private readonly requestPolicy: DiscourseRequestPolicy;
  private readonly networkAvailability: NetworkAvailabilityProvider;

  public constructor(
    baseUrl: string = RIVERSIDE_ORIGIN,
    sessionProvider: AuthenticatedSessionProvider | null = null,
    networkAvailability: NetworkAvailabilityProvider = new AlwaysAvailableNetworkProvider()
  ) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    this.headersFactory = new DiscourseRequestHeadersFactory(sessionProvider);
    this.requestPolicy = new DiscourseRequestPolicy();
    this.networkAvailability = networkAvailability;
  }

  public async get(path: string): Promise<HttpTextResult> {
    const operation: HttpTextRequestAttempt = new HttpTextRequestAttempt(
      (): Promise<HttpTextResult> => this.requestText(path, 'GET', null, null)
    );
    return await executeTopicGetWithRetry(path, operation, this.requestPolicy);
  }

  public async postReply(reply: ReplyRequest): Promise<HttpTextResult> {
    const payload: DiscourseReplyPayload = new DiscourseReplyPayload(reply);
    return await this.requestText(
      '/posts.json',
      'POST',
      JSON.stringify(payload.toHttpExtraData()),
      'application/json'
    );
  }

  public async put(path: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'PUT', null, null);
  }

  public async postForm(path: string, body: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'POST', body, 'application/x-www-form-urlencoded');
  }

  public async postJson(path: string, body: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'POST', body, 'application/json');
  }

  public async putForm(path: string, body: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'PUT', body, 'application/x-www-form-urlencoded');
  }

  public async deleteForm(path: string, body: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'DELETE', body, 'application/x-www-form-urlencoded');
  }

  public async delete(path: string): Promise<HttpTextResult> {
    return await this.requestText(path, 'DELETE', null, null);
  }

  private async requestText(
    path: string,
    method: rcp.HttpMethod,
    requestBody: string | null,
    contentType: string | null
  ): Promise<HttpTextResult> {
    if (!path.startsWith('/')) {
      AppLogger.warning('Network', `${method} rejected an invalid request path`);
      return HttpTextResult.invalidInput('请求路径无效');
    }
    if (!this.networkAvailability.isNetworkAvailable()) {
      AppLogger.info('Network', `${method} ${this.diagnosticPath(path)} skipped while offline`);
      return HttpTextResult.failure(0, '当前没有可用网络');
    }

    const requestHeaders: rcp.RequestHeaders =
      this.headersFactory.create().toRcpRequestHeaders(contentType);
    const configuration: rcp.Configuration = {
      transfer: {
        autoRedirect: true,
        timeout: {
          connectMs: this.requestPolicy.connectTimeoutMs,
          transferMs: this.requestPolicy.transferTimeoutMs
        }
      }
    };
    const request: rcp.Request = new rcp.Request(`${this.baseUrl}${path}`, method);
    request.headers = requestHeaders;
    request.configuration = configuration;
    if (requestBody !== null) {
      request.content = requestBody;
    }

    try {
      const session: rcp.DefaultSession = rcp.getDefaultSession();
      const response: rcp.Response = await session.fetch(request);
      const statusCode: number = response.statusCode;
      if (statusCode === 401) {
        AppLogger.warning('Network', `${method} ${this.diagnosticPath(path)} returned 401`);
        return HttpTextResult.unauthorized();
      }
      if (statusCode < 200 || statusCode >= 300) {
        AppLogger.warning(
          'Network',
          `${method} ${this.diagnosticPath(path)} returned ${statusCode}`
        );
        return HttpTextResult.failure(statusCode, `服务器返回 ${statusCode}`);
      }
      return httpTextResultForSuccessfulResponse(
        statusCode,
        response.body,
        response.toString()
      );
    } catch (error) {
      const errorCode: number | null = caughtHttpErrorCode(error);
      hilog.warn(
        HTTP_LOG_DOMAIN,
        HTTP_LOG_TAG,
        'HTTP request failed with code %{public}d',
        errorCode ?? 0
      );
      AppLogger.warning(
        'Network',
        `${method} ${this.diagnosticPath(path)} failed with code ${errorCode ?? 0}`
      );
      return httpFailureForErrorCode(errorCode);
    }
  }

  private diagnosticPath(path: string): string {
    const queryStart: number = path.indexOf('?');
    return queryStart >= 0 ? path.slice(0, queryStart) : path;
  }
}
