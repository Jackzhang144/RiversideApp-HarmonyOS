import { describe, expect, it } from '@ohos/hypium';
import { AuthenticatedSession } from '../../../main/ets/auth/AuthModels';
import { AuthState } from '../../../main/ets/auth/AuthRepository';
import { ProfileGroup, UserProfile } from '../../../main/ets/models/ProfileModels';
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

function assertPersistentContent(presentation: AccountPresentation, actionsAvailable: boolean = false): void {
  expect(presentation.prototypeEntryVisible).assertTrue();
  expect(presentation.placeholderSections.length).assertEqual(2);
  let placeholderIndex: number = 0;
  for (const section of presentation.placeholderSections) {
    for (const placeholder of section.placeholders) {
      expect(placeholder.label).assertEqual(PLACEHOLDER_LABELS[placeholderIndex]);
      const expectedAvailable: boolean = actionsAvailable && [0, 2, 3, 4, 5].includes(placeholderIndex);
      expect(placeholder.accessibilityText).assertEqual(expectedAvailable
        ? PLACEHOLDER_LABELS[placeholderIndex]
        : `${PLACEHOLDER_LABELS[placeholderIndex]}，未实现`);
      expect(placeholder.available).assertEqual(expectedAvailable);
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
      expect(signedOut.avatarUrl).assertEqual('');
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

    it('presents server-proven identity, role, verification, and capabilities', 0, () => {
      const session: AuthenticatedSession | null = AuthenticatedSession.create(
        'user-api-key',
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef'
      );
      const user: UserProfile | null = UserProfile.create(
        24,
        'co-admin',
        {
          name: '协管员',
          avatarUrl: '/user_avatar/river-side.cc/co-admin/192/1.png',
          title: '社区维护',
          moderator: true,
          trustLevel: 3,
          canCreatePost: true,
          canChatWithUser: true,
          groups: [
            new ProfileGroup(45, 'scuer'),
            new ProfileGroup(50, 'rs_developer')
          ],
          primaryGroupId: 45,
          flairGroupId: 50
        }
      );
      expect(session === null || user === null).assertFalse();
      if (session === null || user === null) {
        return;
      }

      const presentation: AccountPresentation = accountPresentationFor(
        AuthState.authenticated(session),
        user,
        false,
        ''
      );

      expect(presentation.title).assertEqual('协管员');
      expect(presentation.detail).assertEqual('版主 · 已认证 · 信任等级 3');
      expect(presentation.capabilityDetail).assertEqual('可发帖 · 可发起私聊');
      expect(presentation.avatarUrl).assertEqual(
        'https://river-side.cc/user_avatar/river-side.cc/co-admin/192/1.png'
      );
      assertPersistentContent(presentation, true);
    });
  });
}
