import { ConfigurationConstant } from '@kit.AbilityKit';

export enum AppThemeMode {
  SYSTEM = 'system',
  LIGHT = 'light',
  DARK = 'dark'
}

export class AppSystemBarPalette {
  public static readonly transparent: string = '#00000000';
  public static readonly darkContent: string = '#F5F5F5';
  public static readonly lightStatusContent: string = '#1F1F1F';
  public static readonly lightNavigationContent: string = '#606060';
}

export function appThemeModeFromStoredValue(value: string): AppThemeMode {
  if (value === AppThemeMode.LIGHT) {
    return AppThemeMode.LIGHT;
  }
  if (value === AppThemeMode.DARK) {
    return AppThemeMode.DARK;
  }
  return AppThemeMode.SYSTEM;
}

export function appThemePlatformColorMode(mode: AppThemeMode): ConfigurationConstant.ColorMode {
  if (mode === AppThemeMode.LIGHT) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
  }
  if (mode === AppThemeMode.DARK) {
    return ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
  }
  return ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
}

export interface AppThemeSettingsStore {
  read(): Promise<AppThemeMode>;

  write(mode: AppThemeMode): Promise<void>;
}
