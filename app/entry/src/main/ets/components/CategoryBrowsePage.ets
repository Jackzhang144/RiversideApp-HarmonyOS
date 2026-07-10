import { BrowseState, BrowseStateKind } from '../app/AppShellModel';
import { Category } from '../models/ForumModels';

@Component
export struct CategoryBrowsePage {
  @Prop state: BrowseState<Category> = BrowseState.initial<Category>();
  onRefresh: () => void = (): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text('正在加载 Category')
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
        .accessibilityText('重新加载 Category')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 14 }) {
      Text('还没有 Category')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text('刷新后仍没有可展示的 Category。')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('刷新')
        .onClick(this.onRefresh)
        .accessibilityText('刷新 Category')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ListHeader(): void {
    Row() {
      Text(this.state.isRefreshing ? 'Category · 正在刷新' : 'Category')
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      Button('刷新', { type: ButtonType.Normal })
        .onClick(this.onRefresh)
        .accessibilityText('刷新 Category')
    }
    .width('100%')
    .height(48)
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private CategoryRow(category: Category): void {
    Row({ space: 12 }) {
      Blank()
        .width(4)
        .height(44)
        .backgroundColor(`#${category.color}`)
        .borderRadius(2)
      Column({ space: 6 }) {
        Text(category.name)
          .fontSize(17)
          .fontWeight(FontWeight.Medium)
        if (category.description.length > 0) {
          Text(category.description)
            .fontSize(14)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .padding({
      left: category.parentCategoryId === null ? 16 : 32,
      right: 16,
      top: 14,
      bottom: 14
    })
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(16)
    .accessibilityText(`Category：${category.name}`)
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
        ForEach(this.state.items, (category: Category) => {
          ListItem() {
            this.CategoryRow(category)
          }
        }, (category: Category): string => category.id.toString())
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, bottom: 12 })
      .edgeEffect(EdgeEffect.Spring)
    }
  }
}
