import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  AuthRepository,
  AuthStateKind
} from '../../../main/ets/auth/AuthRepository';
import {
  AuthenticatedSession,
  AuthorizationRequest
} from '../../../main/ets/auth/AuthModels';
import {
  AuthenticatedSessionStore,
  SessionLoadResult
} from '../../../main/ets/auth/HuksAuthenticatedSessionStore';
import {
  AuthorizationCryptoFactory,
  AuthorizationCryptoSession
} from '../../../main/ets/auth/RsaAuthorizationCrypto';

const CLIENT_ID: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const NONCE: string = '0123456789abcdef0123456789abcdef';
const PUBLIC_KEY_PEM: string =
  '-----BEGIN RSA PUBLIC KEY-----\nAQAB\n-----END RSA PUBLIC KEY-----';

class StubSessionStore implements AuthenticatedSessionStore {
  public loadResult: SessionLoadResult = SessionLoadResult.empty();
  public saveResult: RepositoryResult<boolean> = RepositoryResult.success<boolean>(true);
  public clearResult: RepositoryResult<boolean> = RepositoryResult.success<boolean>(true);
  public clearCallCount: number = 0;
  public saveCallCount: number = 0;
  public savedSession: AuthenticatedSession | null = null;

  public async load(): Promise<SessionLoadResult> {
    return this.loadResult;
  }

  public async save(session: AuthenticatedSession): Promise<RepositoryResult<boolean>> {
    this.saveCallCount += 1;
    this.savedSession = session;
    return this.saveResult;
  }

  public async clear(): Promise<RepositoryResult<boolean>> {
    this.clearCallCount += 1;
    return this.clearResult;
  }
}

class StubCryptoFactory implements AuthorizationCryptoFactory {
  public createResult: RepositoryResult<AuthorizationCryptoSession> =
    RepositoryResult.failure<AuthorizationCryptoSession>('not configured');

  public async create(): Promise<RepositoryResult<AuthorizationCryptoSession>> {
    return this.createResult;
  }
}

class StubCryptoSession implements AuthorizationCryptoSession {
  public readonly request: AuthorizationRequest;
  public decryptResult: RepositoryResult<AuthenticatedSession>;
  public clearCallCount: number = 0;

  public constructor(
    request: AuthorizationRequest,
    decryptResult: RepositoryResult<AuthenticatedSession>
  ) {
    this.request = request;
    this.decryptResult = decryptResult;
  }

  public async decryptAndValidate(_encryptedPayload: string): Promise<RepositoryResult<AuthenticatedSession>> {
    return this.decryptResult;
  }

  public clear(): void {
    this.clearCallCount += 1;
  }
}

class DeferredCryptoFactory implements AuthorizationCryptoFactory {
  private resolver: ((result: RepositoryResult<AuthorizationCryptoSession>) => void) | null = null;

  public create(): Promise<RepositoryResult<AuthorizationCryptoSession>> {
    return new Promise<RepositoryResult<AuthorizationCryptoSession>>(
      (resolve: (result: RepositoryResult<AuthorizationCryptoSession>) => void): void => {
        this.resolver = resolve;
      }
    );
  }

  public complete(result: RepositoryResult<AuthorizationCryptoSession>): void {
    const resolve: ((result: RepositoryResult<AuthorizationCryptoSession>) => void) | null = this.resolver;
    this.resolver = null;
    if (resolve !== null) {
      resolve(result);
    }
  }
}

class DeferredCryptoSession implements AuthorizationCryptoSession {
  public readonly request: AuthorizationRequest;
  public clearCallCount: number = 0;
  private resolver: ((result: RepositoryResult<AuthenticatedSession>) => void) | null = null;

  public constructor(request: AuthorizationRequest) {
    this.request = request;
  }

  public decryptAndValidate(_encryptedPayload: string): Promise<RepositoryResult<AuthenticatedSession>> {
    return new Promise<RepositoryResult<AuthenticatedSession>>(
      (resolve: (result: RepositoryResult<AuthenticatedSession>) => void): void => {
        this.resolver = resolve;
      }
    );
  }

  public complete(result: RepositoryResult<AuthenticatedSession>): void {
    const resolve: ((result: RepositoryResult<AuthenticatedSession>) => void) | null = this.resolver;
    this.resolver = null;
    if (resolve !== null) {
      resolve(result);
    }
  }

  public clear(): void {
    this.clearCallCount += 1;
  }
}

function createAuthorizationRequest(): AuthorizationRequest | null {
  return AuthorizationRequest.create(PUBLIC_KEY_PEM, CLIENT_ID, NONCE);
}

export default function authRepositoryTest(): void {
  describe('AuthRepository session lifecycle', () => {
    it('restores an Authenticated Session and clears it on logout', 0, async (done: Function) => {
      const session: AuthenticatedSession | null = AuthenticatedSession.create('user-api-key', CLIENT_ID);
      expect(session === null).assertFalse();
      if (session === null) {
        done();
        return;
      }
      const store: StubSessionStore = new StubSessionStore();
      store.loadResult = SessionLoadResult.session(session);
      const repository: AuthRepository = new AuthRepository(store, new StubCryptoFactory());

      const restoring: Promise<void> = repository.restore();
      expect(repository.state.kind).assertEqual(AuthStateKind.RESTORING);
      await restoring;
      expect(repository.state.kind).assertEqual(AuthStateKind.AUTHENTICATED);
      expect(repository.state.session?.key).assertEqual('user-api-key');

      const loggingOut: Promise<void> = repository.logout();
      expect(repository.state.kind).assertEqual(AuthStateKind.SIGNING_OUT);
      expect(repository.state.session).assertNull();
      await loggingOut;

      expect(repository.state.kind).assertEqual(AuthStateKind.IDLE);
      expect(store.clearCallCount).assertEqual(1);
      done();
    });

    it('surfaces session restoration and logout cleanup failures', 0, async (done: Function) => {
      const store: StubSessionStore = new StubSessionStore();
      store.loadResult = SessionLoadResult.failure('无法解密本地认证会话');
      store.clearResult = RepositoryResult.failure<boolean>('无法清除认证会话');
      const repository: AuthRepository = new AuthRepository(store, new StubCryptoFactory());

      await repository.restore();
      expect(repository.state.kind).assertEqual(AuthStateKind.ERROR);
      expect(repository.state.message).assertEqual('无法解密本地认证会话');

      await repository.logout();
      expect(repository.state.kind).assertEqual(AuthStateKind.ERROR);
      expect(repository.state.session).assertNull();
      done();
    });
  });

  describe('AuthRepository authorization lifecycle', () => {
    it('generates a request and persists a validated callback session', 0, async (done: Function) => {
      const request: AuthorizationRequest | null = createAuthorizationRequest();
      const authenticated: AuthenticatedSession | null = AuthenticatedSession.create('user-api-key', CLIENT_ID);
      expect(request === null).assertFalse();
      expect(authenticated === null).assertFalse();
      if (request === null || authenticated === null) {
        done();
        return;
      }
      const store: StubSessionStore = new StubSessionStore();
      const crypto: StubCryptoSession = new StubCryptoSession(
        request,
        RepositoryResult.success<AuthenticatedSession>(authenticated)
      );
      const factory: StubCryptoFactory = new StubCryptoFactory();
      factory.createResult = RepositoryResult.success<AuthorizationCryptoSession>(crypto);
      const repository: AuthRepository = new AuthRepository(store, factory);

      const beginning: Promise<void> = repository.beginAuthorization();
      expect(repository.state.kind).assertEqual(AuthStateKind.GENERATING_REQUEST);
      await beginning;
      expect(repository.state.kind).assertEqual(AuthStateKind.AUTHORIZING);
      expect(repository.state.authorizationUrl).assertEqual(request.authorizationUrl);
      expect(repository.shouldInterceptNavigation('https://river-side.cc/latest', true)).assertFalse();
      expect(repository.shouldInterceptNavigation('riverside://auth_redirect?payload=value', true)).assertTrue();
      expect(repository.shouldInterceptNavigation('riverside://auth_redirect?payload=value', false)).assertFalse();

      const ordinaryNavigationHandled: boolean = await repository.handleNavigation(
        'https://river-side.cc/latest',
        true
      );
      expect(ordinaryNavigationHandled).assertFalse();
      expect(repository.state.kind).assertEqual(AuthStateKind.AUTHORIZING);

      const callbackHandled: Promise<boolean> = repository.handleNavigation(
        'riverside://auth_redirect?payload=encrypted-value',
        true
      );
      expect(repository.state.kind).assertEqual(AuthStateKind.VALIDATING);
      expect(await callbackHandled).assertTrue();
      expect(repository.state.kind).assertEqual(AuthStateKind.AUTHENTICATED);
      expect(repository.state.session?.key).assertEqual('user-api-key');
      expect(store.saveCallCount).assertEqual(1);
      expect(store.savedSession?.clientId).assertEqual(CLIENT_ID);
      expect(crypto.clearCallCount).assertEqual(1);
      done();
    });

    it('rejects invalid callback results without persisting a session', 0, async (done: Function) => {
      const request: AuthorizationRequest | null = createAuthorizationRequest();
      expect(request === null).assertFalse();
      if (request === null) {
        done();
        return;
      }
      const store: StubSessionStore = new StubSessionStore();
      const crypto: StubCryptoSession = new StubCryptoSession(
        request,
        RepositoryResult.failure<AuthenticatedSession>('授权 nonce 校验失败')
      );
      const factory: StubCryptoFactory = new StubCryptoFactory();
      factory.createResult = RepositoryResult.success<AuthorizationCryptoSession>(crypto);
      const repository: AuthRepository = new AuthRepository(store, factory);

      await repository.beginAuthorization();
      const callbackHandled: boolean = await repository.handleNavigation(
        'riverside://auth_redirect?payload=encrypted-value',
        true
      );

      expect(callbackHandled).assertTrue();
      expect(repository.state.kind).assertEqual(AuthStateKind.ERROR);
      expect(repository.state.message).assertEqual('授权 nonce 校验失败');
      expect(store.saveCallCount).assertEqual(0);
      expect(crypto.clearCallCount).assertEqual(1);
      done();
    });

    it('discards RSA material generated after the user cancels', 0, async (done: Function) => {
      const request: AuthorizationRequest | null = createAuthorizationRequest();
      expect(request === null).assertFalse();
      if (request === null) {
        done();
        return;
      }
      const crypto: StubCryptoSession = new StubCryptoSession(
        request,
        RepositoryResult.failure<AuthenticatedSession>('not used')
      );
      const factory: DeferredCryptoFactory = new DeferredCryptoFactory();
      const repository: AuthRepository = new AuthRepository(new StubSessionStore(), factory);

      const beginning: Promise<void> = repository.beginAuthorization();
      repository.cancelAuthorization();
      factory.complete(RepositoryResult.success<AuthorizationCryptoSession>(crypto));
      await beginning;

      expect(repository.state.kind).assertEqual(AuthStateKind.IDLE);
      expect(crypto.clearCallCount).assertEqual(1);
      done();
    });

    it('does not persist a callback decrypted after the user cancels', 0, async (done: Function) => {
      const request: AuthorizationRequest | null = createAuthorizationRequest();
      const authenticated: AuthenticatedSession | null = AuthenticatedSession.create('user-api-key', CLIENT_ID);
      expect(request === null).assertFalse();
      expect(authenticated === null).assertFalse();
      if (request === null || authenticated === null) {
        done();
        return;
      }
      const store: StubSessionStore = new StubSessionStore();
      const crypto: DeferredCryptoSession = new DeferredCryptoSession(request);
      const factory: StubCryptoFactory = new StubCryptoFactory();
      factory.createResult = RepositoryResult.success<AuthorizationCryptoSession>(crypto);
      const repository: AuthRepository = new AuthRepository(store, factory);
      await repository.beginAuthorization();

      const handling: Promise<boolean> = repository.handleNavigation(
        'riverside://auth_redirect?payload=encrypted-value',
        true
      );
      expect(repository.state.kind).assertEqual(AuthStateKind.VALIDATING);
      repository.cancelAuthorization();
      crypto.complete(RepositoryResult.success<AuthenticatedSession>(authenticated));
      expect(await handling).assertTrue();

      expect(repository.state.kind).assertEqual(AuthStateKind.IDLE);
      expect(store.saveCallCount).assertEqual(0);
      expect(crypto.clearCallCount).assertEqual(1);
      done();
    });
  });
}
