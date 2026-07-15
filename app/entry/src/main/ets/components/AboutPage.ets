import { AppMetadata } from '../core/AppMetadata';

@Component
export struct AboutPage {
  @Prop version: AppMetadata = new AppMetadata('unknown', 0);
  onOpenWebsite: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(54)
        .fontColor([$r('app.color.brand_primary')])
      Text($r('app.string.about_product_name'))
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(`版本 ${this.version.versionName}（${this.version.versionCode}）`)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Text($r('app.string.about_product_description'))
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
      Button($r('app.string.about_open_page'))
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .onClick(this.onOpenWebsite)
        .accessibilityText($r('app.string.about_open_page_accessibility'))
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
