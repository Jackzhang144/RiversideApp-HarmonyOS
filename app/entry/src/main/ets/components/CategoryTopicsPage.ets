import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { Category, Topic } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';

@Component
export struct CategoryTopicsPage {
  @Prop state: BrowseState<Topic> = BrowseState.initial<Topic>();
  @Prop categories: Array<Category> = [];
  onRefresh: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenTopic: (topic: Topic) => void = (_topic: Topic): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text($r('app.string.category_topic_loading'))
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private RetryableState(): void {
    Column({ space: 16 }) {
      Text($r('app.string.common_load_failed'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_retry'))
        .onClick(this.onRefresh)
        .accessibilityText($r('app.string.category_topic_reload_accessibility'))
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 14 }) {
      Text($r('app.string.category_topic_empty_title'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text($r('app.string.category_topic_empty_message'))
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_refresh'))
        .onClick(this.onRefresh)
        .accessibilityText($r('app.string.category_topic_refresh_accessibility'))
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private ListHeader(): void {
    Row() {
      Text(`${this.state.items.length} 个 Topic`)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
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
            ForumContentCard({
              presentation: ForumCardPresentation.topicPreview(topic, this.categories),
              onOpenTopic: (): void => {
                this.onOpenTopic(topic);
              }
            })
          }
        }, (topic: Topic): string => topic.id.toString())
        ListItem() {
          Column({ space: 8 }) {
            if (this.state.isLoadingMore) {
              LoadingProgress()
                .width(28)
                .height(28)
              Text($r('app.string.category_topic_loading_more'))
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
          .height(76)
          .justifyContent(FlexAlign.Center)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12 })
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
