export enum AppMaterialPreference {
  SYSTEM = 'system',
  EXQUISITE = 'exquisite',
  GENTLE = 'gentle',
  SMOOTH = 'smooth',
  OFF = 'off'
}

export function appMaterialPreferenceFromStoredValue(value: string): AppMaterialPreference {
  if (value === AppMaterialPreference.EXQUISITE) {
    return AppMaterialPreference.EXQUISITE;
  }
  if (value === AppMaterialPreference.GENTLE) {
    return AppMaterialPreference.GENTLE;
  }
  if (value === AppMaterialPreference.SMOOTH) {
    return AppMaterialPreference.SMOOTH;
  }
  if (value === AppMaterialPreference.OFF) {
    return AppMaterialPreference.OFF;
  }
  return AppMaterialPreference.SYSTEM;
}

export class AppBehaviorSettings {
  public readonly immersiveBrowsingEnabled: boolean;
  public readonly confirmExternalLinks: boolean;
  public readonly materialPreference: AppMaterialPreference;

  public constructor(
    immersiveBrowsingEnabled: boolean = true,
    confirmExternalLinks: boolean = true,
    materialPreference: AppMaterialPreference = AppMaterialPreference.SYSTEM
  ) {
    this.immersiveBrowsingEnabled = immersiveBrowsingEnabled;
    this.confirmExternalLinks = confirmExternalLinks;
    this.materialPreference = materialPreference;
  }

  public withImmersiveBrowsing(enabled: boolean): AppBehaviorSettings {
    return new AppBehaviorSettings(enabled, this.confirmExternalLinks, this.materialPreference);
  }

  public withExternalLinkConfirmation(enabled: boolean): AppBehaviorSettings {
    return new AppBehaviorSettings(this.immersiveBrowsingEnabled, enabled, this.materialPreference);
  }

  public withMaterialPreference(preference: AppMaterialPreference): AppBehaviorSettings {
    return new AppBehaviorSettings(
      this.immersiveBrowsingEnabled,
      this.confirmExternalLinks,
      preference
    );
  }
}

export interface AppBehaviorSettingsStore {
  read(): Promise<AppBehaviorSettings>;

  write(settings: AppBehaviorSettings): Promise<void>;
}
