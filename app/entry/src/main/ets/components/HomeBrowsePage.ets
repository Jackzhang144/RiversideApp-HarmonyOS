import { HdsTabs } from '@kit.UIDesignKit';
import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { HomeChannel, homeChannelLabel, OnlineUser } from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';
import {
  FeatureSitePresentation,
  HomeHeaderActionPresentation,
  featureSitePresentations
} from './HomePresentation';
import { RichEmbedProvider } from '../models/RichContentModels';

@Component
export struct HomeBrowsePage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  @Prop selectedChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @Prop worldCupEntryEnabled: boolean = true;
  @Prop newTopicAvailable: boolean = true;
  @Prop onlineUsersState: BrowseState<OnlineUser> = BrowseState.initial<OnlineUser>();
  @Prop onlineUserCount: number = 0;
  onRetry: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onOpenSearch: () => void = (): void => {};
  onOpenNewTopic: () => void = (): void => {};
  onSelectChannel: (index: number) => void = (_index: number): void => {};
  onWorldCupEntryChange: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onOpenOnlineUsers: () => void = (): void => {};
  onRetryOnlineUsers: () => void = (): void => {};
  onOpenFeatureSite: (site: FeatureSitePresentation) => void = (_site: FeatureSitePresentation): void => {};

  private featureIcon(provider: RichEmbedProvider): Resource {
    if (provider === RichEmbedProvider.WHISPER) {
      return $r('sys.symbol.message');
    }
    if (provider === RichEmbedProvider.REVIEW) {
      return $r('sys.symbol.book');
    }
    if (provider === RichEmbedProvider.MAP) {
      return $r('sys.symbol.pin');
    }
    if (provider === RichEmbedProvider.FOOD) {
      return $r('sys.symbol.fork_knife');
    }
    return $r('sys.symbol.heart');
  }

  @Builder
  private featureSites(): void {
    Scroll() {
      Row({ space: 9 }) {
        ForEach(featureSitePresentations(), (site: FeatureSitePresentation) => {
          Column({ space: 5 }) {
            SymbolGlyph(this.featureIcon(site.provider))
              .fontSize(22)
              .fontColor([$r('app.color.brand_primary')])
            Text(site.title)
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('sys.color.font_primary'))
              .maxLines(1)
          }
          .width(72)
          .height(62)
          .justifyContent(FlexAlign.Center)
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(10)
          .border({ width: 1, color: $r('sys.color.comp_divider') })
          .onClick((): void => this.onOpenFeatureSite(site))
          .accessibilityText(`打开 ${site.title}`)
        }, (site: FeatureSitePresentation): string => site.provider)
      }
      .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    }
    .width('100%')
    .height(78)
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .edgeEffect(EdgeEffect.Spring)
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  private onlineAvatar(user: OnlineUser): void {
    Stack() {
      Text(user.username.slice(0, 1).toUpperCase())
        .width(28)
        .height(28)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(14)
      if (user.avatarUrl.length > 0) {
        Image(user.avatarUrl)
          .width(28)
          .height(28)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(28)
    .height(28)
  }

  @Builder
  private onlineUsersStrip(): void {
    if (this.onlineUsersState.kind === BrowseStateKind.LOADING) {
      Row({ space: 8 }) {
        LoadingProgress().width(18).height(18)
        Text('正在读取在线用户').fontSize(12).fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height(42)
      .padding({ left: 16, right: 16 })
      .backgroundColor($r('sys.color.comp_background_primary'))
    } else if (this.onlineUsersState.kind === BrowseStateKind.CONTENT) {
      Row({ space: 7 }) {
        Text(`在线（${this.onlineUserCount}）`)
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
        ForEach(this.onlineUsersState.items.slice(0, 7), (user: OnlineUser) => {
          this.onlineAvatar(user)
        }, (user: OnlineUser): string => `${user.id}-${user.username}`)
        if (this.onlineUserCount > 7) {
          Text(`+${this.onlineUserCount - 7}`)
            .width(28)
            .height(28)
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_secondary'))
            .textAlign(TextAlign.Center)
            .backgroundColor($r('sys.color.background_secondary'))
            .borderRadius(14)
        }
        Blank()
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
      .height(44)
      .padding({ left: 16, right: 12 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .onClick(this.onOpenOnlineUsers)
      .accessibilityText(`查看 ${this.onlineUserCount} 位在线用户`)
    } else if (this.onlineUsersState.kind === BrowseStateKind.ERROR) {
      Row({ space: 8 }) {
        Text('在线用户加载失败')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .layoutWeight(1)
        Button('重试').height(30).fontSize(12).onClick(this.onRetryOnlineUsers)
      }
      .width('100%')
      .height(42)
      .padding({ left: 16, right: 12 })
      .backgroundColor($r('sys.color.comp_background_primary'))
    }
  }

  @Builder
  private headerAction(
    icon: Resource,
    action: HomeHeaderActionPresentation,
    onClick: () => void
  ): void {
    Button() {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([$r('sys.color.font_tertiary')])
        .hitTestBehavior(HitTestMode.None)
    }
    .width(40)
    .height(40)
    .backgroundColor(Color.Transparent)
    .enabled(action.available)
    .onClick(onClick)
    .accessibilityText(action.accessibilityText)
  }

  @Builder
  private header(): void {
    Row({ space: 4 }) {
      Text('Riverside')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      this.headerAction(
        $r('sys.symbol.magnifyingglass'),
        HomeHeaderActionPresentation.search(),
        this.onOpenSearch
      )
      this.headerAction(
        $r('sys.symbol.plus'),
        HomeHeaderActionPresentation.newTopic(this.newTopicAvailable),
        this.onOpenNewTopic
      )
    }
    .width('100%')
    .height($r('app.float.page_header_height'))
    .padding({ left: 16, right: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })
  }

  private sortTabStyle(channel: HomeChannel): SubTabBarStyle {
    return SubTabBarStyle.of(homeChannelLabel(channel))
      .labelStyle({
        maxLines: 1,
        overflow: TextOverflow.Clip,
        unselectedColor: $r('sys.color.font_primary'),
        selectedColor: $r('app.color.brand_primary'),
        font: { size: 14 }
      })
      .padding({ left: 8, right: 8, top: 0, bottom: 0 });
  }

  @Builder
  private loadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text(`正在加载${homeChannelLabel(this.selectedChannel)}`)
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private retryableState(): void {
    Column({ space: 16 }) {
      Text('加载失败')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(this.onRetry)
        .accessibilityText(`重新加载${homeChannelLabel(this.selectedChannel)}`)
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private emptyState(): void {
    Column({ space: 14 }) {
      Text('还没有 Topic')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message.length > 0 ? this.state.message : '当前频道暂时没有可查看的内容。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('刷新')
        .onClick(this.onRefresh)
        .accessibilityText(`刷新${homeChannelLabel(this.selectedChannel)}`)
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private worldCupPreference(): void {
    Column({ space: 10 }) {
      Row({ space: 10 }) {
        SymbolGlyph($r('sys.symbol.calendar'))
          .fontSize(22)
          .fontColor([$r('app.color.brand_primary')])
        Column({ space: 2 }) {
          Text('世界杯赛程入口')
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
          Text(this.worldCupEntryEnabled ? '入口已显示，赛程内容将在后续切片接入' : '入口已关闭')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Toggle({ type: ToggleType.Switch, isOn: this.worldCupEntryEnabled })
          .onChange(this.onWorldCupEntryChange)
          .accessibilityText('显示世界杯赛程入口')
      }
      if (this.worldCupEntryEnabled) {
        Button('查看世界杯赛程')
          .width('100%')
          .enabled(false)
          .accessibilityText('查看世界杯赛程，赛程内容将在后续实现')
      }
    }
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private paginationFooter(): void {
    Column({ space: 8 }) {
      if (this.state.isLoadingMore) {
        LoadingProgress()
          .width(28)
          .height(28)
        Text('正在加载更多')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .textAlign(TextAlign.Center)
        Button('重试加载更多')
          .height(34)
          .onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text('已经到底了')
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .height(86)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private topicList(): void {
    Refresh({ refreshing: this.state.isRefreshing }) {
      List({ space: 10 }) {
        // ListItem() {
        //   this.worldCupPreference()
        // }
        ForEach(this.state.items, (topic: Topic) => {
          ListItem() {
            ForumContentCard({
              presentation: ForumCardPresentation.topicPreview(topic, this.categories),
              onOpenTopic: (): void => this.onOpenTopic(topic)
            })
          }
        }, (topic: Topic): string => topic.id.toString())
        ListItem() {
          this.paginationFooter()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 10 })
      .backgroundColor($r('sys.color.background_secondary'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onReachEnd(this.onLoadMore)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
    .refreshOffset(64)
    .pullToRefresh(true)
    .pullUpToCancelRefresh(false)
    .onRefreshing(this.onRefresh)
  }

  @Builder
  private channelContent(): void {
    if (this.state.kind === BrowseStateKind.LOADING || this.state.kind === BrowseStateKind.INITIAL) {
      this.loadingState()
    } else if (this.state.kind === BrowseStateKind.ERROR) {
      this.retryableState()
    } else if (this.state.kind === BrowseStateKind.EMPTY) {
      this.emptyState()
    } else {
      this.topicList()
    }
  }

  build() {
    Column() {
      this.header()
      this.featureSites()
      this.onlineUsersStrip()
      HdsTabs({ index: this.selectedChannel }) {
        TabContent() {
          this.channelContent()
        }
        .tabBar(this.sortTabStyle(HomeChannel.LATEST_REPLIES))
        TabContent() {
          this.channelContent()
        }
        .tabBar(this.sortTabStyle(HomeChannel.LATEST_CREATED))
        TabContent() {
          this.channelContent()
        }
        .tabBar(this.sortTabStyle(HomeChannel.UNREAD))
        TabContent() {
          this.channelContent()
        }
        .tabBar(this.sortTabStyle(HomeChannel.HOT))
        TabContent() {
          this.channelContent()
        }
        .tabBar(this.sortTabStyle(HomeChannel.FEATURED))
      }
      .barPosition(BarPosition.Start)
      .vertical(false)
      .scrollable(false)
      .barMode(BarMode.Scrollable, {
        margin: 8,
        nonScrollableLayoutStyle: LayoutStyle.ALWAYS_CENTER
      })
      .barHeight(44)
      .onChange(this.onSelectChannel)
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
  }
}
