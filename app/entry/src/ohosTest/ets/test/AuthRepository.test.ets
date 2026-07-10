import { describe, expect, it } from '@ohos/hypium';
import { RepositoryResult } from '../../../main/ets/core/RepositoryResult';
import {
  AuthRepository,
  AuthStateKind
} from '../../../main/ets/auth/AuthRepository';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import {
  AuthenticatedSessionStore,
  SessionLoadResult
} from '../../../main/ets/auth/HuksAuthenticatedSessionStore';
import {
  AuthorizationCryptoFactory,
  AuthorizationCryptoSession
} from '../../../main/ets/auth/RsaAuthorizationCrypto';

const CLIENT_ID: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

class StubSessionStore implements AuthenticatedSessionStore {
  public loadResult: SessionLoadResult = SessionLoadResult.empty();
  public saveResult: RepositoryResult<boolean> = RepositoryResult.success<boolean>(true);
  public clearResult: RepositoryResult<boolean> = RepositoryResult.success<boolean>(true);
  public clearCallCount: number = 0;

  public async load(): Promise<SessionLoadResult> {
    return this.loadResult;
  }

  public async save(_session: AuthenticatedSession): Promise<RepositoryResult<boolean>> {
    return this.saveResult;
  }

  public async clear(): Promise<RepositoryResult<boolean>> {
    this.clearCallCount += 1;
    return this.clearResult;
  }
}

class StubCryptoFactory implements AuthorizationCryptoFactory {
  public async create(): Promise<RepositoryResult<AuthorizationCryptoSession>> {
    return RepositoryResult.failure<AuthorizationCryptoSession>('not configured');
  }
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
}
