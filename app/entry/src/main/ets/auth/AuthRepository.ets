import { RepositoryResult } from '../core/RepositoryResult';
import { AuthenticatedSession } from './AuthModels';
import {
  AuthenticatedSessionStore,
  SessionLoadKind,
  SessionLoadResult
} from './HuksAuthenticatedSessionStore';
import { AuthorizationCryptoFactory } from './RsaAuthorizationCrypto';

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

  public constructor(store: AuthenticatedSessionStore, cryptoFactory: AuthorizationCryptoFactory) {
    this.store = store;
    this.cryptoFactory = cryptoFactory;
  }

  public async restore(): Promise<void> {
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
    this.state = AuthState.signingOut();
    const result: RepositoryResult<boolean> = await this.store.clear();
    this.state = result.isSuccess()
      ? AuthState.idle()
      : AuthState.error(result.message);
  }
}
