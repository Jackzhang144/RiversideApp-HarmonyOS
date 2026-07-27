import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { ChatEmoji } from '../models/ChatModels';
import { HomeChannel, homeChannelLabel } from '../models/DiscoveryModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';

@Component
export struct HomeBrowsePage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop selectedChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @Prop worldCupEntryEnabled: boolean = true;
  scroller: Scroller = new Scroller();
  onRetry: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onWorldCupEntryChange: (enabled: boolean) => void = (_enabled: boolean): void => {};
  onBrowseScroll: (scrollOffset: number, scrollState: ScrollState) => void =
    (_scrollOffset: number, _scrollState: ScrollState): void => {};

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
      Text($r('app.string.common_load_failed'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_retry'))
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
      Text($r('app.string.home_empty_title'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message.length > 0 ? this.state.message : $r('app.string.home_empty_message'))
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_refresh'))
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
        Text($r('app.string.common_loading_more'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.common_retry_load_more'))
          .height(34)
          .onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text($r('app.string.common_end_of_list'))
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
      List({ space: 10, scroller: this.scroller }) {
        // ListItem() {
        //   this.worldCupPreference()
        // }
        ForEach(this.state.items, (topic: Topic) => {
          ListItem() {
            ForumContentCard({
              presentation: ForumCardPresentation.topicPreview(topic, this.categories, null, this.emojis),
              onOpenTopic: (): void => this.onOpenTopic(topic)
            })
          }
        }, (topic: Topic): string => `${topic.id}-emoji-${this.emojis.length}`)
        ListItem() {
          this.paginationFooter()
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
      .contentStartOffset(10)
      .backgroundColor($r('sys.color.background_secondary'))
      .clip(false)
      .cachedCount(3, true)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      .onDidScroll(this.onBrowseScroll)
      .onReachEnd(this.onLoadMore)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .clip(false)
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
    Stack() {
      Column() {
        this.channelContent()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor(Color.Transparent)
    .clip(false)
  }
}
