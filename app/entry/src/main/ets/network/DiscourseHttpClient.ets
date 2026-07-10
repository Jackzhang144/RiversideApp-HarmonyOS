import { http } from '@kit.NetworkKit';
import { AuthenticatedSession } from '../auth/AuthModels';

const DEFAULT_BASE_URL: string = 'https://river-side.cc';
const USER_AGENT: string = 'RiversideApp/0.1';
const CONNECT_TIMEOUT_MS: number = 8000;
const READ_TIMEOUT_MS: number = 10000;

export enum HttpTextResultKind {
  SUCCESS = 'success',
  UNAUTHORIZED = 'unauthorized',
  FAILURE = 'failure'
}

export class HttpTextResult {
  public readonly kind: HttpTextResultKind;
  public readonly statusCode: number;
  public readonly body: string;
  public readonly message: string;

  private constructor(kind: HttpTextResultKind, statusCode: number, body: string, message: string) {
    this.kind = kind;
    this.statusCode = statusCode;
    this.body = body;
    this.message = message;
  }

  public static success(statusCode: number, body: string): HttpTextResult {
    return new HttpTextResult(HttpTextResultKind.SUCCESS, statusCode, body, '');
  }

  public static unauthorized(): HttpTextResult {
    return new HttpTextResult(HttpTextResultKind.UNAUTHORIZED, 401, '', '登录已失效');
  }

  public static failure(statusCode: number, message: string): HttpTextResult {
    return new HttpTextResult(HttpTextResultKind.FAILURE, statusCode, '', message);
  }

  public isSuccess(): boolean {
    return this.kind === HttpTextResultKind.SUCCESS;
  }
}

interface HttpHeaderValues {
  'User-Agent': string;
  Accept: string;
  'User-Api-Key'?: string;
  'User-Api-Client-Id'?: string;
}

export class DiscourseHeaders {
  public readonly userAgent: string;
  public readonly accept: string;
  public readonly userApiKey: string | null;
  public readonly userApiClientId: string | null;

  public constructor(userApiKey: string | null, userApiClientId: string | null) {
    this.userAgent = USER_AGENT;
    this.accept = 'application/json';
    this.userApiKey = userApiKey;
    this.userApiClientId = userApiClientId;
  }

  public toHttpHeaderValues(): HttpHeaderValues {
    if (this.userApiKey === null || this.userApiClientId === null) {
      return {
        'User-Agent': this.userAgent,
        Accept: this.accept
      };
    }
    return {
      'User-Agent': this.userAgent,
      Accept: this.accept,
      'User-Api-Key': this.userApiKey,
      'User-Api-Client-Id': this.userApiClientId
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

export interface ForumHttpClient {
  get(path: string): Promise<HttpTextResult>;
}

export class DiscourseHttpClient implements ForumHttpClient {
  private readonly baseUrl: string;
  private readonly headersFactory: DiscourseRequestHeadersFactory;

  public constructor(
    baseUrl: string = DEFAULT_BASE_URL,
    sessionProvider: AuthenticatedSessionProvider | null = null
  ) {
    this.baseUrl = baseUrl.endsWith('/') ? baseUrl.slice(0, -1) : baseUrl;
    this.headersFactory = new DiscourseRequestHeadersFactory(sessionProvider);
  }

  public async get(path: string): Promise<HttpTextResult> {
    if (!path.startsWith('/')) {
      return HttpTextResult.failure(0, '请求路径无效');
    }

    const request: http.HttpRequest = http.createHttp();
    const headers: DiscourseHeaders = this.headersFactory.create();
    const options: http.HttpRequestOptions = {
      method: http.RequestMethod.GET,
      header: headers.toHttpHeaderValues(),
      expectDataType: http.HttpDataType.STRING,
      connectTimeout: CONNECT_TIMEOUT_MS,
      readTimeout: READ_TIMEOUT_MS,
      usingCache: false
    };

    try {
      const response: http.HttpResponse = await request.request(`${this.baseUrl}${path}`, options);
      const statusCode: number = response.responseCode;
      if (statusCode === 401) {
        return HttpTextResult.unauthorized();
      }
      if (statusCode < 200 || statusCode >= 300) {
        return HttpTextResult.failure(statusCode, `服务器返回 ${statusCode}`);
      }
      if (typeof response.result !== 'string') {
        return HttpTextResult.failure(statusCode, '服务器响应格式无效');
      }
      return HttpTextResult.success(statusCode, response.result);
    } catch (_) {
      return HttpTextResult.failure(0, '网络连接失败');
    } finally {
      request.destroy();
    }
  }
}
