import { HomeChannel } from '../models/DiscoveryModels';
import { AppThemeMode } from '../settings/AppThemeSettings';
import {
  appThemePreferenceOptions,
  AppThemePreferenceOption,
  appSettingsHomeChannelOptions,
  HomeChannelPreferenceOption
} from './AppSettingsPresentation';

@Component
export struct AppSettingsPage {
  scroller: Scroller = new Scroller();
  @Prop selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @Prop selectedThemeMode: AppThemeMode = AppThemeMode.SYSTEM;
  @Prop hidePresence: boolean = false;
  @Prop presenceAvailable: boolean = false;
  @Prop presenceBusy: boolean = false;
  onSelectHomeChannel: (channel: HomeChannel) => void = (_channel: HomeChannel): void => {};
  onSelectThemeMode: (mode: AppThemeMode) => void = (_mode: AppThemeMode): void => {};
  onHidePresenceChange: (hidden: boolean) => void = (_hidden: boolean): void => {};

  @Builder
  private HomeChannelOption(option: HomeChannelPreferenceOption): void {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(option.label)
          .fontSize(16)
          .fontWeight(option.selected ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
        Text(option.description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (option.selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.brand_primary')])
      } else {
        SymbolGlyph($r('sys.symbol.circle'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick((): void => {
      if (!option.selected) {
        this.onSelectHomeChannel(option.channel);
      }
    })
    .accessibilityText(`${option.label}${option.selected ? '，已选择' : ''}`)
  }

  @Builder
  private ThemeOption(option: AppThemePreferenceOption): void {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(option.label)
          .fontSize(16)
          .fontWeight(option.selected ? FontWeight.Medium : FontWeight.Regular)
          .fontColor($r('sys.color.font_primary'))
        Text(option.description).fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (option.selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill')).fontSize(22).fontColor([$r('app.color.brand_primary')])
      } else {
        SymbolGlyph($r('sys.symbol.circle')).fontSize(22).fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .height(72)
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick((): void => {
      if (!option.selected) {
        this.onSelectThemeMode(option.mode);
      }
    })
    .accessibilityText(`${option.label}${option.selected ? '，已选择' : ''}`)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        Text($r('app.string.settings_home_channel'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        Column() {
          ForEach(
            appSettingsHomeChannelOptions(this.selectedHomeChannel),
            (option: HomeChannelPreferenceOption, index: number) => {
              this.HomeChannelOption(option)
              if (index === 0) {
                Divider()
                  .margin({ left: 16 })
                  .color($r('sys.color.comp_divider'))
              }
            },
            (option: HomeChannelPreferenceOption): string => option.channel.toString()
          )
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .border({ width: 1, color: $r('sys.color.comp_divider') })

        Text($r('app.string.settings_appearance'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .margin({ top: 8 })
        Column() {
          ForEach(
            appThemePreferenceOptions(this.selectedThemeMode),
            (option: AppThemePreferenceOption, index: number) => {
              this.ThemeOption(option)
              if (index < 2) {
                Divider().margin({ left: 16 }).color($r('sys.color.comp_divider'))
              }
            },
            (option: AppThemePreferenceOption): string => option.mode
          )
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .border({ width: 1, color: $r('sys.color.comp_divider') })

        Text($r('app.string.settings_privacy'))
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .margin({ top: 8 })
        Row({ space: 12 }) {
          if (this.presenceBusy) {
            LoadingProgress().width(22).height(22)
          } else {
            SymbolGlyph($r('sys.symbol.eye_slash'))
              .fontSize(22)
              .fontColor([$r('sys.color.font_secondary')])
          }
          Column({ space: 4 }) {
            Text($r('app.string.settings_presence_hidden'))
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
            Text($r('app.string.settings_presence_hidden_description'))
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.hidePresence })
            .enabled(this.presenceAvailable && !this.presenceBusy)
            .onChange(this.onHidePresenceChange)
            .accessibilityText(`隐身模式，${this.hidePresence ? '已开启' : '已关闭'}`)
        }
        .width('100%')
        .height(76)
        .padding({ left: 16, right: 16, top: 10, bottom: 10 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .border({ width: 1, color: $r('sys.color.comp_divider') })

        Text($r('app.string.settings_storage_description'))
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .lineHeight(18)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 16, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
