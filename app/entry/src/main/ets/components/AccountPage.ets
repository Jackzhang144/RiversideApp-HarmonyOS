import { AuthState, AuthStateKind } from '../auth/AuthRepository';

@Component
export struct AccountPage {
  @Prop state: AuthState = AuthState.idle();
  onLogin: () => void = (): void => {};
  onLogout: () => void = (): void => {};
  onOpenUiPrototype: () => void = (): void => {};

  @Builder
  private PrototypeEntry(): void {
    Column({ space: 8 }) {
      Text('原生 UI/UX 设计原型')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
      Text('使用静态数据在 API 23 设备上评审页面密度、状态和 Reply 键盘体验。')
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('查看 UI 原型', { type: ButtonType.Normal })
        .onClick(this.onOpenUiPrototype)
        .accessibilityText('打开原生 UI UX 设计原型')
    }
    .width('100%')
    .padding({ left: 24, right: 24, top: 18, bottom: 18 })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(12)
  }

  @Builder
  private LoadingState(message: string): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text(message)
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SignedOutState(): void {
    Column({ space: 18 }) {
      Text('RiverSide 账户')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
      Text('登录后可使用 RiverSide User API Key 访问需要身份的功能。授权过程会在应用内完成。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (this.state.kind === AuthStateKind.ERROR && this.state.message.length > 0) {
        Text(this.state.message)
          .fontSize(14)
          .fontColor($r('sys.color.font_emphasize'))
          .textAlign(TextAlign.Center)
      }
      Button('登录 RiverSide')
        .onClick(this.onLogin)
        .accessibilityText('登录 RiverSide 账户')
      this.PrototypeEntry()
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SignedInState(): void {
    Column({ space: 18 }) {
      Text('已登录')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
      Text('Authenticated Session 已通过 HUKS 加密保存在本机。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('退出登录')
        .onClick(this.onLogout)
        .accessibilityText('退出 RiverSide 账户')
      this.PrototypeEntry()
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    if (this.state.kind === AuthStateKind.RESTORING) {
      this.LoadingState('正在恢复认证会话')
    } else if (this.state.kind === AuthStateKind.SIGNING_OUT) {
      this.LoadingState('正在退出登录')
    } else if (this.state.kind === AuthStateKind.AUTHENTICATED) {
      this.SignedInState()
    } else {
      this.SignedOutState()
    }
  }
}
