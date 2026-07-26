import { HomeChannel } from '../models/DiscoveryModels';
import { AppThemeMode } from '../settings/AppThemeSettings';
import { AppMaterialPreference } from '../settings/AppBehaviorSettings';
import {
  appMaterialPreferenceDescription,
  appMaterialPreferenceFromIndex,
  appMaterialPreferenceIndex,
  appMaterialPreferenceLabel,
  appMaterialPreferenceOptions,
  AppMaterialPreferenceOption,
  appThemePreferenceOptions,
  AppThemePreferenceOption,
  appSettingsHomeChannelOptions,
  HomeChannelPreferenceOption
} from './AppSettingsPresentation';

const MATERIAL_PREFERENCE_COUNT: number = 5;
const MATERIAL_SELECTOR_HEIGHT: number = 44;
const MATERIAL_SELECTOR_INSET: number = 3;

@Component
struct AppMaterialLevelPicker {
  @Prop preference: AppMaterialPreference = AppMaterialPreference.SYSTEM;
  onSelect: (preference: AppMaterialPreference) => void =
    (_preference: AppMaterialPreference): void => {};

  @State selectorWidth: number = 0;
  @State dragPreviewIndex: number = -1;
  private dragOriginIndex: number = 0;

  private activeIndex(): number {
    return this.dragPreviewIndex >= 0
      ? this.dragPreviewIndex
      : appMaterialPreferenceIndex(this.preference);
  }

  private activePreference(): AppMaterialPreference {
    return appMaterialPreferenceFromIndex(this.activeIndex());
  }

  private indicatorWidth(): number {
    if (this.selectorWidth <= 0) {
      return 0;
    }
    return this.selectorWidth / MATERIAL_PREFERENCE_COUNT - MATERIAL_SELECTOR_INSET * 2;
  }

  private indicatorOffset(): number {
    if (this.selectorWidth <= 0) {
      return MATERIAL_SELECTOR_INSET;
    }
    return this.selectorWidth / MATERIAL_PREFERENCE_COUNT * this.activeIndex() +
      MATERIAL_SELECTOR_INSET;
  }

  private beginMaterialDrag(): void {
    this.dragOriginIndex = appMaterialPreferenceIndex(this.preference);
    this.dragPreviewIndex = this.dragOriginIndex;
  }

  private updateMaterialDrag(offsetX: number): void {
    if (this.selectorWidth <= 0) {
      return;
    }
    const segmentWidth: number = this.selectorWidth / MATERIAL_PREFERENCE_COUNT;
    const targetIndex: number = Math.max(
      0,
      Math.min(
        MATERIAL_PREFERENCE_COUNT - 1,
        Math.round(this.dragOriginIndex + offsetX / segmentWidth)
      )
    );
    this.dragPreviewIndex = targetIndex;
  }

  private finishMaterialDrag(): void {
    if (this.dragPreviewIndex < 0) {
      return;
    }
    const preference: AppMaterialPreference =
      appMaterialPreferenceFromIndex(this.dragPreviewIndex);
    this.onSelect(preference);
    this.dragPreviewIndex = -1;
  }

  private cancelMaterialDrag(): void {
    this.dragPreviewIndex = -1;
  }

  private materialLevelDotOpacity(preference: AppMaterialPreference): number {
    if (preference === AppMaterialPreference.EXQUISITE) {
      return 1;
    }
    if (preference === AppMaterialPreference.GENTLE) {
      return 0.64;
    }
    return 0.3;
  }

  @Builder
  private MaterialTab(option: AppMaterialPreferenceOption): void {
    Button() {
      if (option.preference === AppMaterialPreference.SYSTEM) {
        SymbolGlyph($r('sys.symbol.gearshape'))
          .fontSize(18)
          .fontColor([option.index === this.activeIndex()
            ? $r('app.color.brand_primary')
            : $r('sys.color.font_secondary')])
          .hitTestBehavior(HitTestMode.None)
      } else if (option.preference === AppMaterialPreference.OFF) {
        SymbolGlyph($r('sys.symbol.xmark_circle_fill'))
          .fontSize(18)
          .fontColor([option.index === this.activeIndex()
            ? $r('app.color.brand_primary')
            : $r('sys.color.font_tertiary')])
          .hitTestBehavior(HitTestMode.None)
      } else {
        Stack() {
          if (option.index === this.activeIndex()) {
            Circle()
              .width(22)
              .height(22)
              .fill($r('app.color.brand_primary'))
              .opacity(0.12)
              .hitTestBehavior(HitTestMode.None)
          }
          Circle()
            .width(11)
            .height(11)
            .fill($r('app.color.brand_primary'))
            .opacity(this.materialLevelDotOpacity(option.preference))
            .hitTestBehavior(HitTestMode.None)
        }
        .width(24)
        .height(24)
      }
    }
      .layoutWeight(1)
      .height(MATERIAL_SELECTOR_HEIGHT - MATERIAL_SELECTOR_INSET * 2)
      .padding(0)
      .backgroundColor(Color.Transparent)
      .borderRadius((MATERIAL_SELECTOR_HEIGHT - MATERIAL_SELECTOR_INSET * 2) / 2)
      .stateEffect(false)
      .onClick((): void => {
        this.onSelect(option.preference);
      })
      .accessibilityText(`${option.label}${option.index === this.activeIndex() ? '，已选择' : ''}`)
  }

  build() {
    Column({ space: 12 }) {
      Text(appMaterialPreferenceDescription(this.activePreference()))
        .fontSize(13)
        .lineHeight(19)
        .fontColor($r('sys.color.font_secondary'))
        .height(38)
        .textAlign(TextAlign.Start)
      .width('100%')

      Stack({ alignContent: Alignment.Start }) {
        Row()
          .width(this.indicatorWidth())
          .height(MATERIAL_SELECTOR_HEIGHT - MATERIAL_SELECTOR_INSET * 2)
          .position({ x: this.indicatorOffset(), y: MATERIAL_SELECTOR_INSET })
          .borderRadius((MATERIAL_SELECTOR_HEIGHT - MATERIAL_SELECTOR_INSET * 2) / 2)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .border({ width: 1, color: $r('app.color.brand_primary') })
          .shadow(ShadowStyle.OUTER_DEFAULT_XS)
          .animation({ duration: 160, curve: Curve.EaseOut })

        Row() {
          ForEach(
            appMaterialPreferenceOptions(this.activePreference()),
            (option: AppMaterialPreferenceOption) => {
              this.MaterialTab(option)
            },
            (option: AppMaterialPreferenceOption): string => option.preference
          )
        }
        .width('100%')
        .height(MATERIAL_SELECTOR_HEIGHT)
      }
      .width('100%')
      .height(MATERIAL_SELECTOR_HEIGHT)
      .borderRadius(MATERIAL_SELECTOR_HEIGHT / 2)
      .backgroundColor($r('sys.color.comp_background_secondary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .clip(true)
      .onAreaChange((_oldValue: Area, newValue: Area): void => {
        if (typeof newValue.width === 'number') {
          this.selectorWidth = newValue.width;
        }
      })
      .gesture(
        PanGesture({ fingers: 1, direction: PanDirection.Horizontal, distance: 1 })
          .onActionStart((): void => {
            this.beginMaterialDrag();
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.updateMaterialDrag(event.offsetX);
          })
          .onActionEnd((): void => {
            this.finishMaterialDrag();
          })
          .onActionCancel((): void => {
            this.cancelMaterialDrag();
          })
      )

    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 14, bottom: 14 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }
}

@Component
export struct AppSettingsPage {
  scroller: Scroller = new Scroller();
  @Prop selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @StorageLink('riverside_theme_mode')
  selectedThemeMode: AppThemeMode = AppThemeMode.SYSTEM;
  @Prop immersiveBrowsingEnabled: boolean = true;
  @Prop confirmExternalLinks: boolean = true;
  @Prop materialPreference: AppMaterialPreference = AppMaterialPreference.SYSTEM;
  @Prop immersiveMaterialSupported: boolean = false;
  @Prop hidePresence: boolean = false;
  @Prop presenceAvailable: boolean = false;
  @Prop presenceBusy: boolean = false;
  onSelectHomeChannel: (channel: HomeChannel) => void = (_channel: HomeChannel): void => {};
  onSelectThemeMode: (mode: AppThemeMode) => void = (_mode: AppThemeMode): void => {};
  onImmersiveBrowsingChange: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onConfirmExternalLinksChange: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onSelectMaterialPreference: (preference: AppMaterialPreference) => void =
    (_preference: AppMaterialPreference): void => {};
  onHidePresenceChange: (hidden: boolean) => void = (_hidden: boolean): void => {};

  @Builder
  private SectionLabel(icon: Resource, label: ResourceStr, topMargin: number = 0): void {
    Row({ space: 9 }) {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(28)
      .height(28)
      .borderRadius(9)
      .backgroundColor($r('app.color.brand_tint_surface'))

      Text(label)
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ top: topMargin })
  }

  @Builder
  private ToggleSettingRow(
    icon: Resource,
    title: ResourceStr,
    description: ResourceStr,
    isOn: boolean,
    enabled: boolean,
    onChange: (value: boolean) => void
  ): void {
    Row({ space: 12 }) {
      Stack() {
        SymbolGlyph(icon)
          .fontSize(20)
          .fontColor([$r('app.color.brand_primary')])
      }
      .width(36)
      .height(36)
      .borderRadius(11)
      .backgroundColor($r('app.color.brand_tint_surface'))

      Column({ space: 4 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(description)
          .fontSize(12)
          .lineHeight(17)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Toggle({ type: ToggleType.Switch, isOn })
        .enabled(enabled)
        .onChange(onChange)
        .accessibilityText(`${title.toString()}，${isOn ? '已开启' : '已关闭'}`)
    }
    .width('100%')
    .height(82)
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
  }

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
        this.selectedThemeMode = option.mode;
        this.onSelectThemeMode(option.mode);
      }
    })
    .accessibilityText(`${option.label}${option.selected ? '，已选择' : ''}`)
  }

  build() {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        this.SectionLabel($r('sys.symbol.house'), $r('app.string.settings_home_channel'))
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

        this.SectionLabel($r('sys.symbol.eye'), $r('app.string.settings_appearance'), 8)
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

        if (this.immersiveMaterialSupported) {
          this.SectionLabel($r('sys.symbol.checkmark_circle_fill'), '沉浸光感', 8)
          AppMaterialLevelPicker({
            preference: this.materialPreference,
            onSelect: this.onSelectMaterialPreference
          })
        }

        this.SectionLabel($r('sys.symbol.link'), '浏览', 8)
        Column() {
          this.ToggleSettingRow(
            $r('sys.symbol.eye'),
            '沉浸浏览',
            '向下浏览时自动收起状态栏和页面导航',
            this.immersiveBrowsingEnabled,
            true,
            this.onImmersiveBrowsingChange
          )
          Divider()
            .margin({ left: 62 })
            .color($r('sys.color.comp_divider'))
          this.ToggleSettingRow(
            $r('sys.symbol.link'),
            '打开外部链接前询问',
            '离开 RiverSide 前显示目标地址',
            this.confirmExternalLinks,
            true,
            this.onConfirmExternalLinksChange
          )
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)
        .border({ width: 1, color: $r('sys.color.comp_divider') })

        this.SectionLabel($r('sys.symbol.eye_slash'), $r('app.string.settings_privacy'), 8)
        Row({ space: 12 }) {
          if (this.presenceBusy) {
            LoadingProgress().width(22).height(22)
          } else {
            Stack() {
              SymbolGlyph($r('sys.symbol.eye_slash'))
                .fontSize(20)
                .fontColor([$r('app.color.brand_primary')])
            }
            .width(36)
            .height(36)
            .borderRadius(11)
            .backgroundColor($r('app.color.brand_tint_surface'))
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

        Text('首页频道、外观与浏览偏好保存在本机；隐身模式同步到 RiverSide 账号。')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
          .lineHeight(18)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 0, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
