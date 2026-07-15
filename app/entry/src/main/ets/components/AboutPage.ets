import { bundleManager } from '@kit.AbilityKit';

export class AppVersionInfo {
  public readonly versionName: string;
  public readonly versionCode: number;

  public constructor(versionName: string, versionCode: number) {
    this.versionName = versionName.trim().length > 0 ? versionName.trim() : '未知';
    this.versionCode = Number.isInteger(versionCode) && versionCode >= 0 ? versionCode : 0;
  }

  public static current(): AppVersionInfo {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      return new AppVersionInfo(info.versionName, info.versionCode);
    } catch (_) {
      return new AppVersionInfo('未知', 0);
    }
  }
}

@Component
export struct AboutPage {
  @Prop version: AppVersionInfo = new AppVersionInfo('未知', 0);
  onOpenWebsite: () => void = (): void => {};

  build() {
    Column({ space: 16 }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(54)
        .fontColor(['#317AF7'])
      Text('RiverSide')
        .fontSize(26)
        .fontWeight(FontWeight.Bold)
        .fontColor('#24262B')
      Text(`版本 ${this.version.versionName}（${this.version.versionCode}）`)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
      Text('RiverSide HarmonyOS 客户端')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
      Button('查看 RiverSide 关于页面')
        .width('100%')
        .height(44)
        .margin({ top: 12 })
        .onClick(this.onOpenWebsite)
        .accessibilityText('在应用内打开 RiverSide 关于页面')
    }
    .width('100%')
    .height('100%')
    .padding(28)
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }
}
