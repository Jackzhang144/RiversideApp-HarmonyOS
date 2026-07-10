import { webview } from '@kit.ArkWeb';
import { AuthState, AuthStateKind } from '../auth/AuthRepository';

@Component
export struct LoginPage {
  @Prop state: AuthState = AuthState.idle();
  onRetry: () => void = (): void => {};
  onNavigation: (url: string, isMainFrame: boolean) => boolean =
    (_url: string, _isMainFrame: boolean): boolean => false;

  private controller: webview.WebviewController = new webview.WebviewController();

  @Builder
  private ProgressState(message: string): void {
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
  private ErrorState(): void {
    Column({ space: 16 }) {
      Text('登录未完成')
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('重新登录')
        .onClick(this.onRetry)
        .accessibilityText('重新开始 RiverSide 登录')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  build() {
    if (this.state.kind === AuthStateKind.AUTHORIZING) {
      Web({ src: this.state.authorizationUrl, controller: this.controller })
        .javaScriptAccess(true)
        .domStorageAccess(true)
        .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
          return this.onNavigation(event.data.getRequestUrl(), event.data.isMainFrame());
        })
        .width('100%')
        .height('100%')
    } else if (this.state.kind === AuthStateKind.GENERATING_REQUEST) {
      this.ProgressState('正在创建安全授权请求')
    } else if (
      this.state.kind === AuthStateKind.VALIDATING ||
      this.state.kind === AuthStateKind.PERSISTING
    ) {
      this.ProgressState('正在校验并保存认证会话')
    } else if (this.state.kind === AuthStateKind.ERROR) {
      this.ErrorState()
    } else {
      this.ProgressState('正在完成登录')
    }
  }
}
