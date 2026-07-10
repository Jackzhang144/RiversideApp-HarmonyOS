import { describe, expect, it } from '@ohos/hypium';
import { abilityDelegatorRegistry } from '@kit.TestKit';
import { common, UIAbility } from '@kit.AbilityKit';
import { RepositoryResult, RepositoryResultKind } from '../../../main/ets/core/RepositoryResult';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import {
  HuksAuthenticatedSessionStore,
  SessionLoadKind,
  SessionLoadResult
} from '../../../main/ets/auth/HuksAuthenticatedSessionStore';

const CLIENT_ID: string = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

export default function sessionStoreTest(): void {
  describe('HUKS Authenticated Session storage', () => {
    it('saves, restores and clears an encrypted Authenticated Session', 0, async (done: Function) => {
      const ability: UIAbility = await abilityDelegatorRegistry.getAbilityDelegator().getCurrentTopAbility();
      const context: common.Context = ability.context;
      const store: HuksAuthenticatedSessionStore = HuksAuthenticatedSessionStore.forTesting(context);
      await store.clear();
      const session: AuthenticatedSession | null = AuthenticatedSession.create('secret-user-api-key', CLIENT_ID);
      expect(session === null).assertFalse();
      if (session === null) {
        done();
        return;
      }

      const empty: SessionLoadResult = await store.load();
      const saved: RepositoryResult<boolean> = await store.save(session);
      const restored: SessionLoadResult = await store.load();
      const cleared: RepositoryResult<boolean> = await store.clear();
      const afterClear: SessionLoadResult = await store.load();

      expect(empty.message).assertEqual('');
      expect(empty.kind).assertEqual(SessionLoadKind.EMPTY);
      expect(saved.message).assertEqual('');
      expect(saved.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(restored.kind).assertEqual(SessionLoadKind.SESSION);
      expect(restored.session?.key).assertEqual('secret-user-api-key');
      expect(restored.session?.clientId).assertEqual(CLIENT_ID);
      expect(cleared.kind).assertEqual(RepositoryResultKind.SUCCESS);
      expect(afterClear.kind).assertEqual(SessionLoadKind.EMPTY);
      done();
    });
  });
}
