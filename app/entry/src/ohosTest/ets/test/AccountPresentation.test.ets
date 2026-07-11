import { describe, expect, it } from '@ohos/hypium';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import { AuthState } from '../../../main/ets/auth/AuthRepository';
import {
  AccountPrimaryAction,
  AccountPresentation,
  accountPresentationFor
} from '../../../main/ets/components/AccountPresentation';

const PLACEHOLDER_LABELS: Array<string> = [
  '个人信息',
  'RSC 钱包',
  '我的 Topic',
  '我的 Reply',
  '我的草稿',
  '我的书签',
  '应用设置',
  '关于 RiverSide'
];

function assertPersistentContent(presentation: AccountPresentation): void {
  expect(presentation.prototypeEntryVisible).assertTrue();
  expect(presentation.placeholderSections.length).assertEqual(2);
  let placeholderIndex: number = 0;
  for (const section of presentation.placeholderSections) {
    for (const placeholder of section.placeholders) {
      expect(placeholder.label).assertEqual(PLACEHOLDER_LABELS[placeholderIndex]);
      expect(placeholder.accessibilityText).assertEqual(`${PLACEHOLDER_LABELS[placeholderIndex]}，未实现`);
      expect(placeholder.available).assertFalse();
      placeholderIndex += 1;
    }
  }
  expect(placeholderIndex).assertEqual(PLACEHOLDER_LABELS.length);
}

export default function accountPresentationTest(): void {
  describe('Account presentation contract', () => {
    it('keeps placeholders and the prototype entry visible in every required authentication state', 0, () => {
      const session: AuthenticatedSession | null = AuthenticatedSession.create(
        'user-api-key',
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      );
      expect(session === null).assertFalse();
      if (session === null) {
        return;
      }
      const presentations: Array<AccountPresentation> = [
        accountPresentationFor(AuthState.idle()),
        accountPresentationFor(AuthState.restoring()),
        accountPresentationFor(AuthState.error('本地会话读取失败')),
        accountPresentationFor(AuthState.authenticated(session)),
        accountPresentationFor(AuthState.signingOut())
      ];

      presentations.forEach((presentation: AccountPresentation): void => {
        assertPersistentContent(presentation);
      });
    });

    it('exposes only login and logout as real account actions', 0, () => {
      const session: AuthenticatedSession | null = AuthenticatedSession.create(
        'user-api-key',
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      );
      expect(session === null).assertFalse();
      if (session === null) {
        return;
      }

      const signedOut: AccountPresentation = accountPresentationFor(AuthState.idle());
      const restoring: AccountPresentation = accountPresentationFor(AuthState.restoring());
      const failed: AccountPresentation = accountPresentationFor(AuthState.error('认证失败'));
      const signedIn: AccountPresentation = accountPresentationFor(AuthState.authenticated(session));
      const signingOut: AccountPresentation = accountPresentationFor(AuthState.signingOut());

      expect(signedOut.primaryAction).assertEqual(AccountPrimaryAction.LOGIN);
      expect(restoring.primaryAction).assertEqual(AccountPrimaryAction.NONE);
      expect(restoring.busy).assertTrue();
      expect(failed.primaryAction).assertEqual(AccountPrimaryAction.LOGIN);
      expect(failed.detail).assertEqual('认证失败');
      expect(signedIn.primaryAction).assertEqual(AccountPrimaryAction.LOGOUT);
      expect(signedIn.title).assertEqual('已登录 RiverSide');
      expect(signingOut.primaryAction).assertEqual(AccountPrimaryAction.NONE);
      expect(signingOut.busy).assertTrue();
    });

    it('keeps every authorization phase busy without exposing another account action', 0, () => {
      const authorizingStates: Array<AuthState> = [
        AuthState.generatingRequest(),
        AuthState.authorizing('https://river-side.cc/user-api-key/new'),
        AuthState.validating('https://river-side.cc/user-api-key/new'),
        AuthState.persisting()
      ];

      authorizingStates.forEach((state: AuthState): void => {
        const presentation: AccountPresentation = accountPresentationFor(state);
        expect(presentation.primaryAction).assertEqual(AccountPrimaryAction.NONE);
        expect(presentation.busy).assertTrue();
        expect(presentation.title).assertEqual('正在登录 RiverSide');
        assertPersistentContent(presentation);
      });
    });
  });
}
