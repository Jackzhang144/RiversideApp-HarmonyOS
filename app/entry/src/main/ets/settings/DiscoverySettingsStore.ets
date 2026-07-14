import { HomeChannel } from '../models/DiscoveryModels';

export class DiscoverySettings {
  public readonly homeChannel: HomeChannel;
  public readonly worldCupEntryEnabled: boolean;

  public constructor(homeChannel: HomeChannel, worldCupEntryEnabled: boolean) {
    this.homeChannel = homeChannel;
    this.worldCupEntryEnabled = worldCupEntryEnabled;
  }
}

export interface DiscoverySettingsStore {
  read(): Promise<DiscoverySettings | null>;

  write(settings: DiscoverySettings): Promise<void>;
}
