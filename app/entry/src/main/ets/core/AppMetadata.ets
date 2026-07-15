import { bundleManager } from '@kit.AbilityKit';

const PRODUCT_NAME: string = 'RiversideApp';
const UNKNOWN_VERSION_NAME: string = 'unknown';

export class AppMetadata {
  public readonly versionName: string;
  public readonly versionCode: number;

  public constructor(versionName: string, versionCode: number) {
    this.versionName = versionName.trim().length > 0 ? versionName.trim() : UNKNOWN_VERSION_NAME;
    this.versionCode = Number.isInteger(versionCode) && versionCode >= 0 ? versionCode : 0;
  }

  public static current(): AppMetadata {
    try {
      const info: bundleManager.BundleInfo = bundleManager.getBundleInfoForSelfSync(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      return new AppMetadata(info.versionName, info.versionCode);
    } catch (_) {
      return new AppMetadata(UNKNOWN_VERSION_NAME, 0);
    }
  }

  public userAgent(): string {
    return `${PRODUCT_NAME}/${this.versionName}`;
  }
}
