import { HdsTabs } from '@kit.UIDesignKit';
import { BrowseState, BrowseStateKind, isHomeSortTabAvailable } from '../app/AppShellModel';
import { Category, Topic } from '../models/ForumModels';
import { TopicCard } from './TopicCard';

@Component
export struct HomeBrowsePage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  onRetry: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  canChangeSortTab: (index: number) => boolean = (index: number): boolean => {
    return isHomeSortTabAvailable(index);
  };

  @Builder
  private headerAction(icon: Resource, label: string): void {
    Button() {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([$r('sys.color.font_tertiary')])
        .hitTestBehavior(HitTestMode.None)
    }
    .width(40)
    .height(40)
    .backgroundColor(Color.Transparent)
    .enabled(false)
    .accessibilityText(`${label}，未实现`)
  }

  @Builder
  private header(): void {
    Row({ space: 4 }) {
      Text('Riverside')
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      this.headerAction($r('sys.symbol.magnifyingglass'), '搜索')
      this.headerAction($r('sys.symbol.plus'), '发布新 Topic')
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#ECEEF2' })
  }

  private sortTabStyle(label: string, available: boolean): SubTabBarStyle {
    const labelColor: ResourceColor = available
      ? $r('sys.color.font_primary')
      : $r('sys.color.font_tertiary');
    const selectedColor: ResourceColor = available ? '#317AF7' : labelColor;
    return SubTabBarStyle.of(label)
      .labelStyle({
        maxLines: 1,
        overflow: TextOverflow.Clip,
        unselectedColor: labelColor,
        selectedColor: selectedColor,
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
      Text('正在加载最新回复')
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
        .accessibilityText('重新加载最新回复')
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
      Text(this.state.message.length > 0 ? this.state.message : '稍后再来看看，或手动刷新。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (this.state.isRefreshing) {
        LoadingProgress()
          .width(36)
          .height(36)
      } else {
        Button('刷新')
          .onClick(this.onRefresh)
          .accessibilityText('刷新最新回复')
      }
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private topicList(): void {
    Refresh({ refreshing: this.state.isRefreshing }) {
      List({ space: 10 }) {
        ForEach(this.state.items, (topic: Topic) => {
          ListItem() {
            TopicCard({
              topic: topic,
              categories: this.categories,
              onOpen: (selected: Topic): void => {
                this.onOpenTopic(selected);
              }
            })
          }
        }, (topic: Topic): string => topic.id.toString())
        ListItem() {
          Column()
            .width('100%')
            .height(92)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 12 })
      .backgroundColor('#F5F6F8')
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .refreshOffset(64)
    .pullToRefresh(true)
    .pullUpToCancelRefresh(false)
    .onRefreshing((): void => {
      this.onRefresh();
    })
  }

  @Builder
  private latestRepliesContent(): void {
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

  @Builder
  private unavailableContent(): void {
    Column()
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F6F8')
  }

  build() {
    Column() {
      this.header()
      HdsTabs() {
        TabContent() {
          this.latestRepliesContent()
        }
        .tabBar(this.sortTabStyle('最新回复', true))
        TabContent() {
          this.unavailableContent()
        }
        .tabBar(this.sortTabStyle('最新发表 · 未实现', false))
        .accessibilityText('最新发表，未实现')
        TabContent() {
          this.unavailableContent()
        }
        .tabBar(this.sortTabStyle('未读 · 未实现', false))
        .accessibilityText('未读，未实现')
        TabContent() {
          this.unavailableContent()
        }
        .tabBar(this.sortTabStyle('热门 · 未实现', false))
        .accessibilityText('热门，未实现')
        TabContent() {
          this.unavailableContent()
        }
        .tabBar(this.sortTabStyle('精华 · 未实现', false))
        .accessibilityText('精华，未实现')
      }
      .barPosition(BarPosition.Start)
      .vertical(false)
      .scrollable(false)
      .barMode(BarMode.Scrollable, {
        margin: 8,
        nonScrollableLayoutStyle: LayoutStyle.ALWAYS_CENTER
      })
      .barHeight(44)
      .onContentWillChange((_currentIndex: number, comingIndex: number): boolean => {
        return this.canChangeSortTab(comingIndex);
      })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
