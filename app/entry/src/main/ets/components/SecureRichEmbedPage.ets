import { webview } from '@kit.ArkWeb';
import {
  embedTrustList,
  isAllowedEmbedNavigation,
  RichEmbedProvider
} from '../models/RichContentModels';

@Component
export struct SecureRichEmbedPage {
  @Prop url: string = '';
  @Prop title: string = '嵌入内容';
  @Prop provider: RichEmbedProvider = RichEmbedProvider.NONE;
  @State message: string = '正在准备安全播放器';
  @State failed: boolean = false;
  controller: webview.WebviewController = new webview.WebviewController();
  onRequestExternalOpen: (url: string) => void = (_url: string): void => {};

  private applyTrustList(): void {
    try {
      this.controller.setUrlTrustList(embedTrustList(this.provider));
      this.message = '安全白名单已应用';
      this.failed = false;
    } catch (_) {
      this.message = '播放器安全白名单应用失败';
      this.failed = true;
    }
  }

  @Builder
  private FailureState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(36)
        .fontColor([$r('app.color.status_error')])
      Text($r('app.string.embed_load_failed'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
      Text(this.message)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.embed_open_external'))
        .onClick((): void => this.onRequestExternalOpen(this.url))
        .accessibilityText($r('app.string.embed_open_external_accessibility'))
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.info_circle'))
          .fontSize(15)
          .fontColor([$r('app.color.text_link')])
        Text(`${this.title} · 隔离 ArkWeb`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Text($r('app.string.embed_no_native_bridge'))
          .fontSize(10)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })
      if (this.failed) {
        this.FailureState()
      } else {
        Web({ src: this.url, controller: this.controller })
          .javaScriptAccess(true)
          .domStorageAccess(true)
          .fileAccess(false)
          .mixedMode(MixedMode.None)
          .onControllerAttached((): void => this.applyTrustList())
          .onLoadIntercept((event: OnLoadInterceptEvent): boolean => {
            const requestedUrl: string = event.data.getRequestUrl();
            if (isAllowedEmbedNavigation(this.provider, requestedUrl)) {
              return false;
            }
            this.message = `已阻止播放器离开白名单：${requestedUrl}`;
            if (event.data.isMainFrame()) {
              this.failed = true;
            }
            return true;
          })
          .onSslErrorEvent((event: SslErrorEvent): void => {
            event.handler.handleCancel(true);
            this.message = 'SSL 校验失败，已取消加载';
            this.failed = true;
          })
          .onErrorReceive((event: OnErrorReceiveEvent): void => {
            if (event.request.isMainFrame()) {
              this.message = '播放器网络加载失败';
              this.failed = true;
            }
          })
          .width('100%')
          .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
