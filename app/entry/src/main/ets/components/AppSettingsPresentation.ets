import { HomeChannel, homeChannelLabel } from '../models/DiscoveryModels';
import { AppThemeMode } from '../settings/AppThemeSettings';

export class AppThemePreferenceOption {
  public readonly mode: AppThemeMode;
  public readonly label: string;
  public readonly description: string;
  public readonly selected: boolean;

  public constructor(mode: AppThemeMode, selectedMode: AppThemeMode) {
    this.mode = mode;
    this.label = mode === AppThemeMode.SYSTEM ? '跟随系统' : mode === AppThemeMode.LIGHT ? '浅色' : '深色';
    this.description = mode === AppThemeMode.SYSTEM
      ? '随系统外观自动切换'
      : mode === AppThemeMode.LIGHT ? '始终使用浅色外观' : '始终使用深色外观';
    this.selected = mode === selectedMode;
  }
}

export function appThemePreferenceOptions(selectedMode: AppThemeMode): Array<AppThemePreferenceOption> {
  return [
    new AppThemePreferenceOption(AppThemeMode.SYSTEM, selectedMode),
    new AppThemePreferenceOption(AppThemeMode.LIGHT, selectedMode),
    new AppThemePreferenceOption(AppThemeMode.DARK, selectedMode)
  ];
}

export class HomeChannelPreferenceOption {
  public readonly channel: HomeChannel;
  public readonly label: string;
  public readonly description: string;
  public readonly selected: boolean;

  public constructor(channel: HomeChannel, selectedChannel: HomeChannel) {
    this.channel = channel;
    this.label = homeChannelLabel(channel);
    this.description = channel === HomeChannel.LATEST_CREATED
      ? '按发帖时间倒序'
      : '按最后回复时间倒序';
    this.selected = channel === selectedChannel;
  }
}

export function appSettingsHomeChannelOptions(
  selectedChannel: HomeChannel
): Array<HomeChannelPreferenceOption> {
  return [
    new HomeChannelPreferenceOption(HomeChannel.LATEST_CREATED, selectedChannel),
    new HomeChannelPreferenceOption(HomeChannel.LATEST_REPLIES, selectedChannel)
  ];
}
