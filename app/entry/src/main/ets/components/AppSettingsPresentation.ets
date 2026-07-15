import { HomeChannel, homeChannelLabel } from '../models/DiscoveryModels';

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
