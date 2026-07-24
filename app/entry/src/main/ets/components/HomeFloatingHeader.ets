import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { HomeChannel, homeChannelLabel, OnlineUser } from '../models/DiscoveryModels';
import {
  FeatureSitePresentation,
  HomeHeaderActionPresentation,
  featureSitePresentations
} from './HomePresentation';

@Component
export struct HomeFloatingHeader {
  @Prop selectedChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @Prop newTopicAvailable: boolean = true;
  @Prop onlineUsersState: BrowseState<OnlineUser> = BrowseState.initial<OnlineUser>();
  @Prop onlineUserCount: number = 0;
  @State private featureMenuVisible: boolean = false;
  @State private channelMenuVisible: boolean = false;
  @State private onlineUsersSheetVisible: boolean = false;
  onOpenSearch: () => void = (): void => {};
  onOpenNewTopic: () => void = (): void => {};
  onSelectChannel: (index: number) => void = (_index: number): void => {};
  onOpenOnlineUser: (user: OnlineUser) => void = (_user: OnlineUser): void => {};
  onRetryOnlineUsers: () => void = (): void => {};
  onOpenFeatureSite: (site: FeatureSitePresentation) => void = (_site: FeatureSitePresentation): void => {};

  @Builder
  private onlineAvatar(user: OnlineUser, size: number): void {
    Stack() {
      Text(user.username.slice(0, 1).toUpperCase())
        .width(size)
        .height(size)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(size / 2)
      if (user.avatarUrl.length > 0) {
        Image(user.avatarUrl)
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(size)
    .height(size)
  }

  @Builder
  private OnlineUsersSheet(): void {
    if (this.onlineUsersState.kind === BrowseStateKind.LOADING) {
      Column({ space: 10 }) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.home_online_loading')).fontSize(14).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
    } else if (this.onlineUsersState.kind === BrowseStateKind.ERROR) {
      Column({ space: 12 }) {
        Text(this.onlineUsersState.message.length > 0
          ? this.onlineUsersState.message : $r('app.string.home_online_load_failed'))
          .fontSize(14)
          .fontColor($r('app.color.status_error'))
        Button($r('app.string.common_retry')).height(34).fontSize(13).onClick(this.onRetryOnlineUsers)
      }
      .width('100%')
      .height(220)
      .justifyContent(FlexAlign.Center)
    } else if (this.onlineUsersState.items.length === 0) {
      Text('当前没有可展示的在线用户')
        .width('100%')
        .height(220)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
    } else {
      List({ space: 12 }) {
        ForEach(this.onlineUsersState.items, (user: OnlineUser) => {
          ListItem() {
            Button() {
              Row({ space: 12 }) {
                this.onlineAvatar(user, 42)
                Column({ space: 3 }) {
                  Text(user.displayName).fontSize(15).fontWeight(FontWeight.Medium).maxLines(1)
                  Text(`@${user.username}`).fontSize(12).fontColor($r('sys.color.font_secondary')).maxLines(1)
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)
                SymbolGlyph($r('sys.symbol.chevron_right'))
                  .fontSize(15)
                  .fontColor([$r('sys.color.font_tertiary')])
              }
              .width('100%')
            }
            .width('100%')
            .height(58)
            .backgroundColor(Color.Transparent)
            .onClick((): void => {
              this.onlineUsersSheetVisible = false;
              this.onOpenOnlineUser(user);
            })
            .accessibilityText(`查看 ${user.username} 的资料`)
          }
        }, (user: OnlineUser): string => `${user.id}-${user.username}`)
      }
      .width('100%')
      .height(320)
    }
  }

  @Builder
  private floatingAction(
    icon: Resource,
    action: HomeHeaderActionPresentation,
    onClick: () => void
  ): void {
    Button() {
      SymbolGlyph(icon)
        .fontSize(19)
        .fontColor([$r('sys.color.font_primary')])
        .hitTestBehavior(HitTestMode.None)
    }
    .width(38)
    .height(38)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .enabled(action.available)
    .onClick(onClick)
    .accessibilityText(action.accessibilityText)
  }

  @Builder
  private FeatureSiteMenu(): void {
    Menu() {
      ForEach(featureSitePresentations(), (site: FeatureSitePresentation) => {
        MenuItem({ content: site.title })
          .onClick((): void => {
            this.featureMenuVisible = false;
            this.onOpenFeatureSite(site);
          })
      }, (site: FeatureSitePresentation): string => site.provider)
    }
    .width(180)
  }

  private homeChannels(): Array<HomeChannel> {
    return [
      HomeChannel.LATEST_REPLIES,
      HomeChannel.LATEST_CREATED,
      HomeChannel.UNREAD,
      HomeChannel.HOT,
      HomeChannel.FEATURED
    ];
  }

  @Builder
  private ChannelMenu(): void {
    Menu() {
      ForEach(this.homeChannels(), (channel: HomeChannel) => {
        MenuItem({
          content: channel === this.selectedChannel
            ? `✓ ${homeChannelLabel(channel)}`
            : homeChannelLabel(channel)
        })
          .onClick((): void => {
            this.channelMenuVisible = false;
            this.onSelectChannel(channel);
          })
      }, (channel: HomeChannel): string => channel.toString())
    }
    .width(160)
  }

  build() {
    Row({ space: 8 }) {
      Button() {
        Image($r('app.media.riverside_harmony_foreground_v2'))
          .width(28)
          .height(28)
          .objectFit(ImageFit.Contain)
      }
      .width(48)
      .height(42)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .onClick((): void => {
        this.featureMenuVisible = !this.featureMenuVisible;
      })
      .bindMenu(this.featureMenuVisible, this.FeatureSiteMenu, {
        onWillDisappear: (): void => {
          this.featureMenuVisible = false;
        }
      })
      .accessibilityText('打开 Riverside 功能入口')
      Button() {
        Row({ space: 4 }) {
          Text(homeChannelLabel(this.selectedChannel))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
          SymbolGlyph($r('sys.symbol.chevron_down'))
            .fontSize(12)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .hitTestBehavior(HitTestMode.None)
      }
      .width(100)
      .height(42)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .onClick((): void => {
        this.channelMenuVisible = !this.channelMenuVisible;
      })
      .bindMenu(this.channelMenuVisible, this.ChannelMenu, {
        onWillDisappear: (): void => {
          this.channelMenuVisible = false;
        }
      })
      .accessibilityText(`当前列表：${homeChannelLabel(this.selectedChannel)}，点击切换`)
      Blank()
      this.floatingAction(
        $r('sys.symbol.magnifyingglass'),
        HomeHeaderActionPresentation.search(),
        this.onOpenSearch
      )
      this.floatingAction(
        $r('sys.symbol.plus'),
        HomeHeaderActionPresentation.newTopic(this.newTopicAvailable),
        this.onOpenNewTopic
      )
      Button() {
        Text(this.onlineUserCount.toString())
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
      }
      .width(46)
      .height(38)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(14)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .onClick((): void => {
        this.onlineUsersSheetVisible = true;
      })
      .accessibilityText(`查看 ${this.onlineUserCount} 位在线用户`)
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, bottom: 6 })
    .backgroundColor($r('sys.color.background_secondary'))
    .bindSheet($$this.onlineUsersSheetVisible, this.OnlineUsersSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      detentSelection: SheetSize.MEDIUM,
      showClose: true,
      dragBar: true,
      title: { title: `在线用户（${this.onlineUserCount}）`, subtitle: '点击头像或用户名查看用户资料' }
    })
  }
}
