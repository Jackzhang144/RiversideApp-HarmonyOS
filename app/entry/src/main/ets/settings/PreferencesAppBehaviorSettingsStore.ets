import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import {
  AppBehaviorSettings,
  AppBehaviorSettingsStore,
  AppMaterialPreference,
  appMaterialPreferenceFromStoredValue
} from './AppBehaviorSettings';

const PREFERENCES_NAME: string = 'riverside_app_settings';
const IMMERSIVE_BROWSING_KEY: string = 'immersive_browsing_enabled';
const CONFIRM_EXTERNAL_LINKS_KEY: string = 'confirm_external_links';
const MATERIAL_PREFERENCE_KEY: string = 'material_preference';

export class PreferencesAppBehaviorSettingsStore implements AppBehaviorSettingsStore {
  private readonly context: common.Context;

  public constructor(context: common.Context) {
    this.context = context;
  }

  public async read(): Promise<AppBehaviorSettings> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const immersiveValue: preferences.ValueType = await store.get(IMMERSIVE_BROWSING_KEY, true);
      const confirmationValue: preferences.ValueType = await store.get(CONFIRM_EXTERNAL_LINKS_KEY, true);
      const materialValue: preferences.ValueType = await store.get(
        MATERIAL_PREFERENCE_KEY,
        AppMaterialPreference.SYSTEM
      );
      return new AppBehaviorSettings(
        typeof immersiveValue === 'boolean' ? immersiveValue : true,
        typeof confirmationValue === 'boolean' ? confirmationValue : true,
        typeof materialValue === 'string'
          ? appMaterialPreferenceFromStoredValue(materialValue)
          : AppMaterialPreference.SYSTEM
      );
    } catch (_) {
      return new AppBehaviorSettings();
    }
  }

  public async write(settings: AppBehaviorSettings): Promise<void> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      await store.put(IMMERSIVE_BROWSING_KEY, settings.immersiveBrowsingEnabled);
      await store.put(CONFIRM_EXTERNAL_LINKS_KEY, settings.confirmExternalLinks);
      await store.put(MATERIAL_PREFERENCE_KEY, settings.materialPreference);
      await store.flush();
    } catch (_) {
      // Applied in-memory behavior remains authoritative for the current run.
    }
  }
}
