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
  private ProgressState(message: ResourceStr): void {
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
      Text($r('app.string.login_not_completed'))
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.login_retry'))
        .onClick(this.onRetry)
        .accessibilityText($r('app.string.login_retry_accessibility'))
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
          const requestUrl: string = event.data.getRequestUrl();
          const isMainFrame: boolean = event.data.isMainFrame();
          const handled: boolean = this.onNavigation(requestUrl, isMainFrame);
          return handled;
        })
        .width('100%')
        .height('100%')
    } else if (this.state.kind === AuthStateKind.GENERATING_REQUEST) {
      this.ProgressState($r('app.string.login_generating_request'))
    } else if (
      this.state.kind === AuthStateKind.VALIDATING ||
      this.state.kind === AuthStateKind.PERSISTING
    ) {
      this.ProgressState($r('app.string.login_validating_session'))
    } else if (this.state.kind === AuthStateKind.ERROR) {
      this.ErrorState()
    } else {
      this.ProgressState($r('app.string.login_finishing'))
    }
  }
}
