import { BrowseState, BrowseStateKind } from '../app/AppShellModel';
import { Category, Topic } from '../models/ForumModels';
import { TopicCard } from './TopicCard';

@Component
export struct CategoryTopicsPage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  onRefresh: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text('正在加载 Topic')
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private RetryableState(): void {
    Column({ space: 16 }) {
      Text('加载失败')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(this.onRefresh)
        .accessibilityText('重新加载 Category Topic')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 14 }) {
      Text('这个 Category 还没有 Topic')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('稍后再来看看，或手动刷新。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('刷新')
        .onClick(this.onRefresh)
        .accessibilityText('刷新 Category Topic')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private ListHeader(): void {
    Row() {
      Text(`${this.state.items.length} 个 Topic`)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      Button('刷新', { type: ButtonType.Normal })
        .height(40)
        .backgroundColor(Color.Transparent)
        .fontColor('#317AF7')
        .onClick(this.onRefresh)
        .accessibilityText('刷新 Category Topic')
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private TopicList(): void {
    Refresh({ refreshing: this.state.isRefreshing }) {
      List({ space: 10 }) {
        ListItem() {
          this.ListHeader()
        }
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
            .height(32)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
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

  build() {
    if (this.state.kind === BrowseStateKind.LOADING || this.state.kind === BrowseStateKind.INITIAL) {
      this.LoadingState()
    } else if (this.state.kind === BrowseStateKind.ERROR) {
      this.RetryableState()
    } else if (this.state.kind === BrowseStateKind.EMPTY) {
      this.EmptyState()
    } else {
      this.TopicList()
    }
  }
}
