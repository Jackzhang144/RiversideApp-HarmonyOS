import { uri } from '@kit.ArkTS';
import { JsonObjectReader } from '../core/JsonObjectReader';
import { RepositoryResult } from '../core/RepositoryResult';
import { RIVERSIDE_AUTHORIZATION_ENDPOINT } from '../core/RiversideEnvironment';

const AUTH_REDIRECT: string = 'riverside://auth_redirect';
const AUTH_SCOPES: string = 'read,write,session_info';
const APPLICATION_NAME: string = 'RiverSide Mobile';
const HEX_CLIENT_ID: RegExp = /^[0-9a-f]{64}$/;
const HEX_NONCE: RegExp = /^[0-9a-f]{32}$/;

export class AuthenticatedSession {
  public readonly key: string;
  public readonly clientId: string;

  private constructor(key: string, clientId: string) {
    this.key = key;
    this.clientId = clientId;
  }

  public static create(key: string, clientId: string): AuthenticatedSession | null {
    const normalizedKey: string = key.trim();
    const normalizedClientId: string = clientId.trim();
    if (normalizedKey.length === 0 || !HEX_CLIENT_ID.test(normalizedClientId)) {
      return null;
    }
    return new AuthenticatedSession(normalizedKey, normalizedClientId);
  }
}

export class AuthorizationRequest {
  public readonly publicKeyPem: string;
  public readonly clientId: string;
  public readonly nonce: string;
  public readonly authorizationUrl: string;

  private constructor(publicKeyPem: string, clientId: string, nonce: string, authorizationUrl: string) {
    this.publicKeyPem = publicKeyPem;
    this.clientId = clientId;
    this.nonce = nonce;
    this.authorizationUrl = authorizationUrl;
  }

  public static create(publicKeyPem: string, clientId: string, nonce: string): AuthorizationRequest | null {
    const normalizedPem: string = publicKeyPem.trim();
    const normalizedClientId: string = clientId.trim();
    const normalizedNonce: string = nonce.trim();
    if (
      !normalizedPem.startsWith('-----BEGIN RSA PUBLIC KEY-----') ||
      !normalizedPem.endsWith('-----END RSA PUBLIC KEY-----') ||
      !HEX_CLIENT_ID.test(normalizedClientId) ||
      !HEX_NONCE.test(normalizedNonce)
    ) {
      return null;
    }

    let authorizationUri: uri.URI = new uri.URI(RIVERSIDE_AUTHORIZATION_ENDPOINT);
    authorizationUri = authorizationUri.addQueryValue('public_key', normalizedPem);
    authorizationUri = authorizationUri.addQueryValue('nonce', normalizedNonce);
    authorizationUri = authorizationUri.addQueryValue('scopes', AUTH_SCOPES);
    authorizationUri = authorizationUri.addQueryValue('client_id', normalizedClientId);
    authorizationUri = authorizationUri.addQueryValue('application_name', APPLICATION_NAME);
    authorizationUri = authorizationUri.addQueryValue('auth_redirect', AUTH_REDIRECT);
    authorizationUri = authorizationUri.addQueryValue('padding', 'pkcs1');
    return new AuthorizationRequest(
      normalizedPem,
      normalizedClientId,
      normalizedNonce,
      authorizationUri.toString()
    );
  }
}

export class AuthorizationCallbackValidator {
  public isCallbackUrl(callbackUrl: string): boolean {
    try {
      new uri.URI(callbackUrl);
      const queryStart: number = callbackUrl.indexOf('?');
      const callbackBase: string = queryStart < 0 ? callbackUrl : callbackUrl.slice(0, queryStart);
      return callbackBase === AUTH_REDIRECT && !callbackUrl.includes('#');
    } catch (_) {
      return false;
    }
  }

  public extractPayload(callbackUrl: string, isMainFrame: boolean): RepositoryResult<string> {
    if (!isMainFrame) {
      return RepositoryResult.invalidInput<string>('登录回调不是主页面导航');
    }
    try {
      const callback: uri.URI = new uri.URI(callbackUrl);
      if (!this.isCallbackUrl(callbackUrl)) {
        return RepositoryResult.invalidInput<string>('登录回调地址无效');
      }
      const payload: string | null = callback.getQueryValue('payload');
      if (payload === null || payload.trim().length === 0) {
        return RepositoryResult.invalidInput<string>('登录回调缺少 payload');
      }
      return RepositoryResult.success<string>(payload);
    } catch (_) {
      return RepositoryResult.invalidInput<string>('登录回调地址无效');
    }
  }

  public validateDecryptedPayload(
    decryptedPayload: string,
    clientId: string,
    expectedNonce: string
  ): RepositoryResult<AuthenticatedSession> {
    const payload: JsonObjectReader | null = JsonObjectReader.parse(decryptedPayload);
    if (payload === null) {
      return RepositoryResult.security<AuthenticatedSession>('授权结果格式无效');
    }
    const nonce: string | null = payload.string('nonce');
    const key: string | null = payload.string('key');
    if (nonce === null || nonce !== expectedNonce) {
      return RepositoryResult.security<AuthenticatedSession>('授权 nonce 校验失败');
    }
    if (key === null) {
      return RepositoryResult.security<AuthenticatedSession>('授权结果缺少 User API Key');
    }
    const session: AuthenticatedSession | null = AuthenticatedSession.create(key, clientId);
    return session === null
      ? RepositoryResult.security<AuthenticatedSession>('授权会话无效')
      : RepositoryResult.success<AuthenticatedSession>(session);
  }
}
