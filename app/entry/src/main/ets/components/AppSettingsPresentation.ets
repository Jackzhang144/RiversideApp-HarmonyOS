import { HomeChannel, homeChannelLabel } from '../models/DiscoveryModels';
import { AppThemeMode } from '../settings/AppThemeSettings';
import { AppMaterialPreference } from '../settings/AppBehaviorSettings';

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

export function appMaterialPreferenceLabel(preference: AppMaterialPreference): string {
  if (preference === AppMaterialPreference.SYSTEM) {
    return '系统自适应';
  }
  if (preference === AppMaterialPreference.EXQUISITE) {
    return '精美';
  }
  if (preference === AppMaterialPreference.GENTLE) {
    return '轻柔';
  }
  if (preference === AppMaterialPreference.SMOOTH) {
    return '流畅';
  }
  return '关闭';
}

export function appMaterialPreferenceDescription(preference: AppMaterialPreference): string {
  if (preference === AppMaterialPreference.SYSTEM) {
    return '推荐：系统根据设备性能自动选择效果';
  }
  if (preference === AppMaterialPreference.EXQUISITE) {
    return '更细腻的光感，性能开销较高';
  }
  if (preference === AppMaterialPreference.GENTLE) {
    return '光感与性能之间取得平衡';
  }
  if (preference === AppMaterialPreference.SMOOTH) {
    return '降低材质开销，保持流畅';
  }
  return '不使用沉浸光感材质';
}

export function appMaterialPreferenceIndex(preference: AppMaterialPreference): number {
  if (preference === AppMaterialPreference.OFF) {
    return 1;
  }
  if (preference === AppMaterialPreference.SMOOTH) {
    return 2;
  }
  if (preference === AppMaterialPreference.GENTLE) {
    return 3;
  }
  if (preference === AppMaterialPreference.EXQUISITE) {
    return 4;
  }
  return 0;
}

export function appMaterialPreferenceFromIndex(value: number): AppMaterialPreference {
  const step: number = Math.round(value);
  if (step === 1) {
    return AppMaterialPreference.OFF;
  }
  if (step === 2) {
    return AppMaterialPreference.SMOOTH;
  }
  if (step === 3) {
    return AppMaterialPreference.GENTLE;
  }
  if (step >= 4) {
    return AppMaterialPreference.EXQUISITE;
  }
  return AppMaterialPreference.SYSTEM;
}

export class AppMaterialPreferenceOption {
  public readonly preference: AppMaterialPreference;
  public readonly label: string;
  public readonly index: number;
  public readonly selected: boolean;

  public constructor(
    preference: AppMaterialPreference,
    selectedPreference: AppMaterialPreference
  ) {
    this.preference = preference;
    this.label = appMaterialPreferenceLabel(preference);
    this.index = appMaterialPreferenceIndex(preference);
    this.selected = preference === selectedPreference;
  }
}

export function appMaterialPreferenceOptions(
  selectedPreference: AppMaterialPreference
): Array<AppMaterialPreferenceOption> {
  return [
    new AppMaterialPreferenceOption(AppMaterialPreference.SYSTEM, selectedPreference),
    new AppMaterialPreferenceOption(AppMaterialPreference.OFF, selectedPreference),
    new AppMaterialPreferenceOption(AppMaterialPreference.SMOOTH, selectedPreference),
    new AppMaterialPreferenceOption(AppMaterialPreference.GENTLE, selectedPreference),
    new AppMaterialPreferenceOption(AppMaterialPreference.EXQUISITE, selectedPreference)
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
