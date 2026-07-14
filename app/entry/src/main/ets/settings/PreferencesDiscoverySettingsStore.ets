import { common } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { HomeChannel, homeChannelFromIndex } from '../models/DiscoveryModels';
import { DiscoverySettings, DiscoverySettingsStore } from './DiscoverySettingsStore';

const PREFERENCES_NAME: string = 'riverside_discovery_settings';
const HOME_CHANNEL_KEY: string = 'home_channel';
const WORLD_CUP_ENTRY_KEY: string = 'world_cup_entry_enabled';

export class PreferencesDiscoverySettingsStore implements DiscoverySettingsStore {
  private readonly context: common.Context;

  public constructor(context: common.Context) {
    this.context = context;
  }

  public async read(): Promise<DiscoverySettings | null> {
    try {
      const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
      const channelValue: preferences.ValueType = await store.get(HOME_CHANNEL_KEY, HomeChannel.LATEST_REPLIES);
      const worldCupValue: preferences.ValueType = await store.get(WORLD_CUP_ENTRY_KEY, true);
      if (typeof channelValue !== 'number' || typeof worldCupValue !== 'boolean') {
        return null;
      }
      const channel: HomeChannel | null = homeChannelFromIndex(channelValue);
      return channel === null ? null : new DiscoverySettings(channel, worldCupValue);
    } catch (_) {
      return null;
    }
  }

  public async write(settings: DiscoverySettings): Promise<void> {
    const store: preferences.Preferences = await preferences.getPreferences(this.context, PREFERENCES_NAME);
    await store.put(HOME_CHANNEL_KEY, settings.homeChannel);
    await store.put(WORLD_CUP_ENTRY_KEY, settings.worldCupEntryEnabled);
    await store.flush();
  }
}
