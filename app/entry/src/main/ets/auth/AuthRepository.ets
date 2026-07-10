import { RepositoryResult } from '../core/RepositoryResult';
import {
  AuthenticatedSession,
  AuthorizationCallbackValidator
} from './AuthModels';
import {
  AuthenticatedSessionStore,
  SessionLoadKind,
  SessionLoadResult
} from './HuksAuthenticatedSessionStore';
import {
  AuthorizationCryptoFactory,
  AuthorizationCryptoSession
} from './RsaAuthorizationCrypto';

export enum AuthStateKind {
  IDLE = 'idle',
  RESTORING = 'restoring',
  GENERATING_REQUEST = 'generating-request',
  AUTHORIZING = 'authorizing',
  VALIDATING = 'validating',
  PERSISTING = 'persisting',
  AUTHENTICATED = 'authenticated',
  SIGNING_OUT = 'signing-out',
  ERROR = 'error'
}

export class AuthState {
  public readonly kind: AuthStateKind;
  public readonly session: AuthenticatedSession | null;
  public readonly authorizationUrl: string;
  public readonly message: string;

  private constructor(
    kind: AuthStateKind,
    session: AuthenticatedSession | null,
    authorizationUrl: string,
    message: string
  ) {
    this.kind = kind;
    this.session = session;
    this.authorizationUrl = authorizationUrl;
    this.message = message;
  }

  public static idle(): AuthState {
    return new AuthState(AuthStateKind.IDLE, null, '', '');
  }

  public static restoring(): AuthState {
    return new AuthState(AuthStateKind.RESTORING, null, '', '');
  }

  public static generatingRequest(): AuthState {
    return new AuthState(AuthStateKind.GENERATING_REQUEST, null, '', '');
  }

  public static authorizing(authorizationUrl: string): AuthState {
    return new AuthState(AuthStateKind.AUTHORIZING, null, authorizationUrl, '');
  }

  public static validating(authorizationUrl: string): AuthState {
    return new AuthState(AuthStateKind.VALIDATING, null, authorizationUrl, '');
  }

  public static persisting(): AuthState {
    return new AuthState(AuthStateKind.PERSISTING, null, '', '');
  }

  public static authenticated(session: AuthenticatedSession): AuthState {
    return new AuthState(AuthStateKind.AUTHENTICATED, session, '', '');
  }

  public static signingOut(): AuthState {
    return new AuthState(AuthStateKind.SIGNING_OUT, null, '', '');
  }

  public static error(message: string): AuthState {
    return new AuthState(AuthStateKind.ERROR, null, '', message);
  }
}

export class AuthRepository {
  public state: AuthState = AuthState.idle();

  private readonly store: AuthenticatedSessionStore;
  private readonly cryptoFactory: AuthorizationCryptoFactory;
  private readonly callbackValidator: AuthorizationCallbackValidator = new AuthorizationCallbackValidator();
  private pendingCrypto: AuthorizationCryptoSession | null = null;

  public constructor(store: AuthenticatedSessionStore, cryptoFactory: AuthorizationCryptoFactory) {
    this.store = store;
    this.cryptoFactory = cryptoFactory;
  }

  public async restore(): Promise<void> {
    this.clearAuthorizationMaterial();
    this.state = AuthState.restoring();
    const result: SessionLoadResult = await this.store.load();
    if (result.kind === SessionLoadKind.EMPTY) {
      this.state = AuthState.idle();
      return;
    }
    if (result.kind === SessionLoadKind.SESSION) {
      if (result.session === null) {
        this.state = AuthState.error('本地认证会话内容无效');
        return;
      }
      this.state = AuthState.authenticated(result.session);
      return;
    }
    this.state = AuthState.error(result.message);
  }

  public async logout(): Promise<void> {
    this.clearAuthorizationMaterial();
    this.state = AuthState.signingOut();
    const result: RepositoryResult<boolean> = await this.store.clear();
    this.state = result.isSuccess()
      ? AuthState.idle()
      : AuthState.error(result.message);
  }

  public currentSession(): AuthenticatedSession | null {
    return this.state.session;
  }

  public async beginAuthorization(): Promise<void> {
    this.clearAuthorizationMaterial();
    this.state = AuthState.generatingRequest();
    const result: RepositoryResult<AuthorizationCryptoSession> = await this.cryptoFactory.create();
    if (!result.isSuccess() || result.data === null) {
      this.state = AuthState.error(result.message);
      return;
    }
    this.pendingCrypto = result.data;
    this.state = AuthState.authorizing(result.data.request.authorizationUrl);
  }

  public async handleNavigation(url: string, isMainFrame: boolean): Promise<boolean> {
    if (!this.callbackValidator.isCallbackUrl(url)) {
      return false;
    }
    const crypto: AuthorizationCryptoSession | null = this.pendingCrypto;
    if (crypto === null) {
      this.state = AuthState.error('没有待处理的授权请求');
      return true;
    }
    const payload: RepositoryResult<string> = this.callbackValidator.extractPayload(url, isMainFrame);
    if (!payload.isSuccess() || payload.data === null) {
      this.finishAuthorizationWithError(payload.message);
      return true;
    }

    this.state = AuthState.validating(crypto.request.authorizationUrl);
    const decrypted: RepositoryResult<AuthenticatedSession> = await crypto.decryptAndValidate(payload.data);
    if (!decrypted.isSuccess() || decrypted.data === null) {
      this.finishAuthorizationWithError(decrypted.message);
      return true;
    }

    this.state = AuthState.persisting();
    const saved: RepositoryResult<boolean> = await this.store.save(decrypted.data);
    this.clearAuthorizationMaterial();
    this.state = saved.isSuccess()
      ? AuthState.authenticated(decrypted.data)
      : AuthState.error(saved.message);
    return true;
  }

  public cancelAuthorization(): void {
    this.clearAuthorizationMaterial();
    this.state = AuthState.idle();
  }

  private finishAuthorizationWithError(message: string): void {
    this.clearAuthorizationMaterial();
    this.state = AuthState.error(message);
  }

  private clearAuthorizationMaterial(): void {
    const crypto: AuthorizationCryptoSession | null = this.pendingCrypto;
    this.pendingCrypto = null;
    if (crypto === null) {
      return;
    }
    try {
      crypto.clear();
    } catch (_) {
    }
  }
}
