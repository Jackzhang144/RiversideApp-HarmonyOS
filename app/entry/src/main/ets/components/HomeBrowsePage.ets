import { HdsTabs } from '@kit.UIDesignKit';
import { BrowseState, BrowseStateKind } from '../app/AppShellModel';
import { HomeChannel, homeChannelLabel } from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';
import { HomeHeaderActionPresentation } from './HomePresentation';

@Component
export struct HomeBrowsePage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  @Prop selectedChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @Prop worldCupEntryEnabled: boolean = true;
  @Prop newTopicAvailable: boolean = true;
  onRetry: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onOpenSearch: () => void = (): void => {};
  onOpenNewTopic: () => void = (): void => {};
  onSelectChannel: (index: number) => void = (_index: number): void => {};
  onWorldCupEntryChange: (enabled: boolean) => void = (_enabled: boolean): void => {};

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
    .height(56)
    .padding({ left: 16, right: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#ECEEF2' })
  }

  private sortTabStyle(channel: HomeChannel): SubTabBarStyle {
    return SubTabBarStyle.of(homeChannelLabel(channel))
      .labelStyle({
        maxLines: 1,
        overflow: TextOverflow.Clip,
        unselectedColor: $r('sys.color.font_primary'),
        selectedColor: '#317AF7',
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
          .fontColor(['#317AF7'])
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
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
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
          .fontColor('#C62828')
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
      .backgroundColor('#F5F6F8')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onReachEnd(this.onLoadMore)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
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
    .backgroundColor('#FFFFFF')
  }
}
