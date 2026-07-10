import { BrowseState, BrowseStateKind } from '../app/AppShellModel';
import { Topic } from '../models/ForumModels';

@Component
export struct HomeBrowsePage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  onRefresh: () => void = (): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text('正在加载最新 Topic')
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
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
        .accessibilityText('重新加载')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 14 }) {
      Text('还没有 Topic')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('稍后再来看看，或手动刷新。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('刷新')
        .onClick(this.onRefresh)
        .accessibilityText('刷新首页')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ListHeader(): void {
    Row() {
      Text('最新 Topic')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      Button('刷新', { type: ButtonType.Normal })
        .onClick(this.onRefresh)
        .accessibilityText('刷新最新 Topic')
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private TopicRow(topic: Topic): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        if (topic.pinned) {
          Text('置顶')
            .fontSize(12)
            .fontColor($r('sys.color.font_emphasize'))
        }
        Text(topic.title)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .layoutWeight(1)
      }
      if (topic.excerpt.length > 0) {
        Text(topic.excerpt)
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      Text(`${topic.username.length > 0 ? topic.username : '匿名'}  ·  ${Math.max(topic.postCount - 1, 0)} Reply  ·  ${topic.viewCount} 浏览`)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(16)
    .accessibilityText(`${topic.title}，${Math.max(topic.postCount - 1, 0)} 条 Reply`)
  }

  build() {
    if (this.state.kind === BrowseStateKind.LOADING || this.state.kind === BrowseStateKind.INITIAL) {
      this.LoadingState()
    } else if (this.state.kind === BrowseStateKind.ERROR) {
      this.RetryableState()
    } else if (this.state.kind === BrowseStateKind.EMPTY) {
      this.EmptyState()
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.ListHeader()
        }
        ForEach(this.state.items, (topic: Topic) => {
          ListItem() {
            this.TopicRow(topic)
          }
        }, (topic: Topic): string => topic.id.toString())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}
