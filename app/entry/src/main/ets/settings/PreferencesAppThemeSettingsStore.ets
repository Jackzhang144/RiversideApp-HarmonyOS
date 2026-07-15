import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppThemeMode,
  appThemeModeFromStoredValue,
  AppThemeSettingsStore
} from './AppThemeSettings';

const PREFERENCES_NAME: string = 'riverside_app_settings';
const THEME_MODE_KEY: string = 'theme_mode';

export class PreferencesAppThemeSettingsStore implements AppThemeSettingsStore {
  private readonly context: common.Context;

  public constructor(context: common.Context) {
    this.context = context;
  }

  public async read(): Promise<AppThemeMode> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const value: preferences.ValueType = await store.get(THEME_MODE_KEY, AppThemeMode.SYSTEM);
      return typeof value === 'string' ? appThemeModeFromStoredValue(value) : AppThemeMode.SYSTEM;
    } catch (_) {
      return AppThemeMode.SYSTEM;
    }
  }

  public async write(mode: AppThemeMode): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      await store.put(THEME_MODE_KEY, mode);
      await store.flush();
    } catch (_) {
      // The applied in-memory theme remains authoritative for this run.
    }
  }
}
