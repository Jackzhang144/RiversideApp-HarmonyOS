import { AuthState, AuthStateKind } from '../auth/AuthRepository';

export enum AccountPrimaryAction {
  NONE = 'none',
  LOGIN = 'login',
  LOGOUT = 'logout'
}

export enum AccountPlaceholderKind {
  PERSONAL_INFORMATION = 'personal-information',
  RSC_WALLET = 'rsc-wallet',
  MY_TOPICS = 'my-topics',
  MY_REPLIES = 'my-replies',
  MY_DRAFTS = 'my-drafts',
  MY_BOOKMARKS = 'my-bookmarks',
  APP_SETTINGS = 'app-settings',
  ABOUT_RIVERSIDE = 'about-riverside'
}

export enum AccountPlaceholderSectionKind {
  ACCOUNT = 'account',
  APPLICATION = 'application'
}

export class AccountPlaceholder {
  public readonly kind: AccountPlaceholderKind;
  public readonly label: string;
  public readonly accessibilityText: string;
  public readonly available: boolean = false;

  public constructor(kind: AccountPlaceholderKind, label: string) {
    this.kind = kind;
    this.label = label;
    this.accessibilityText = `${label}，未实现`;
  }
}

export class AccountPlaceholderSection {
  public readonly kind: AccountPlaceholderSectionKind;
  public readonly placeholders: Array<AccountPlaceholder>;

  public constructor(kind: AccountPlaceholderSectionKind, placeholders: Array<AccountPlaceholder>) {
    this.kind = kind;
    this.placeholders = placeholders;
  }
}

export class AccountPresentation {
  public readonly title: string;
  public readonly detail: string;
  public readonly primaryAction: AccountPrimaryAction;
  public readonly busy: boolean;
  public readonly error: boolean;
  public readonly placeholderSections: Array<AccountPlaceholderSection>;
  public readonly prototypeEntryVisible: boolean = true;

  public constructor(
    title: string,
    detail: string,
    primaryAction: AccountPrimaryAction,
    busy: boolean,
    error: boolean,
    placeholderSections: Array<AccountPlaceholderSection>
  ) {
    this.title = title;
    this.detail = detail;
    this.primaryAction = primaryAction;
    this.busy = busy;
    this.error = error;
    this.placeholderSections = placeholderSections;
  }
}

function accountPlaceholderSections(): Array<AccountPlaceholderSection> {
  return [
    new AccountPlaceholderSection(AccountPlaceholderSectionKind.ACCOUNT, [
      new AccountPlaceholder(AccountPlaceholderKind.PERSONAL_INFORMATION, '个人信息'),
      new AccountPlaceholder(AccountPlaceholderKind.RSC_WALLET, 'RSC 钱包'),
      new AccountPlaceholder(AccountPlaceholderKind.MY_TOPICS, '我的 Topic'),
      new AccountPlaceholder(AccountPlaceholderKind.MY_REPLIES, '我的 Reply'),
      new AccountPlaceholder(AccountPlaceholderKind.MY_DRAFTS, '我的草稿'),
      new AccountPlaceholder(AccountPlaceholderKind.MY_BOOKMARKS, '我的书签')
    ]),
    new AccountPlaceholderSection(AccountPlaceholderSectionKind.APPLICATION, [
      new AccountPlaceholder(AccountPlaceholderKind.APP_SETTINGS, '应用设置'),
      new AccountPlaceholder(AccountPlaceholderKind.ABOUT_RIVERSIDE, '关于 RiverSide')
    ])
  ];
}

export function accountPresentationFor(state: AuthState): AccountPresentation {
  const placeholderSections: Array<AccountPlaceholderSection> = accountPlaceholderSections();
  if (state.kind === AuthStateKind.AUTHENTICATED) {
    return new AccountPresentation(
      '已登录 RiverSide',
      'Authenticated Session 已通过 HUKS 加密保存在本机。',
      AccountPrimaryAction.LOGOUT,
      false,
      false,
      placeholderSections
    );
  }
  if (state.kind === AuthStateKind.RESTORING) {
    return new AccountPresentation(
      '正在恢复 RiverSide 会话',
      '正在读取本机安全保存的认证会话。',
      AccountPrimaryAction.NONE,
      true,
      false,
      placeholderSections
    );
  }
  if (state.kind === AuthStateKind.SIGNING_OUT) {
    return new AccountPresentation(
      '正在退出 RiverSide',
      '正在清除本机保存的认证材料。',
      AccountPrimaryAction.NONE,
      true,
      false,
      placeholderSections
    );
  }
  if (
    state.kind === AuthStateKind.GENERATING_REQUEST ||
    state.kind === AuthStateKind.AUTHORIZING ||
    state.kind === AuthStateKind.VALIDATING ||
    state.kind === AuthStateKind.PERSISTING
  ) {
    return new AccountPresentation(
      '正在登录 RiverSide',
      '请在登录页面完成 RiverSide 账户授权。',
      AccountPrimaryAction.NONE,
      true,
      false,
      placeholderSections
    );
  }
  if (state.kind === AuthStateKind.ERROR) {
    return new AccountPresentation(
      'RiverSide 认证异常',
      state.message.length > 0 ? state.message : '认证状态异常，请重试登录。',
      AccountPrimaryAction.LOGIN,
      false,
      true,
      placeholderSections
    );
  }
  return new AccountPresentation(
    '未登录 RiverSide',
    '登录后可使用 RiverSide User API Key 访问需要身份的功能。',
    AccountPrimaryAction.LOGIN,
    false,
    false,
    placeholderSections
  );
}
