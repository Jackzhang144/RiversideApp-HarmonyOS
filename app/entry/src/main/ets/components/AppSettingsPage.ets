import { HomeChannel } from '../models/DiscoveryModels';
import {
  appSettingsHomeChannelOptions,
  HomeChannelPreferenceOption
} from './AppSettingsPresentation';

@Component
export struct AppSettingsPage {
  @Prop selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  onSelectHomeChannel: (channel: HomeChannel) => void = (_channel: HomeChannel): void => {};

  @Builder
  private HomeChannelOption(option: HomeChannelPreferenceOption): void {
    Row({ space: 12 }) {
      Column({ space: 4 }) {
        Text(option.label)
          .fontSize(16)
          .fontWeight(option.selected ? FontWeight.Medium : FontWeight.Regular)
          .fontColor('#24262B')
        Text(option.description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (option.selected) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor(['#317AF7'])
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

  build() {
    Scroll() {
      Column({ space: 12 }) {
        Text('首页频道')
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
                  .color('#ECEEF2')
              }
            },
            (option: HomeChannelPreferenceOption): string => option.channel.toString()
          )
        }
        .width('100%')
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        .border({ width: 1, color: '#E8EBF0' })

        Text('选择结果会保存在本机，并同步到首页频道。')
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
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor('#F4F5F7')
  }
}
