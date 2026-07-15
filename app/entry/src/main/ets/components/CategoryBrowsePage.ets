import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { Category } from '../models/ForumModels';

@Component
export struct CategoryBrowsePage {
  @Prop state: BrowseState<Category> = BrowseState.initial<Category>();
  onRefresh: () => void = (): void => {};
  onOpenCategory: (category: Category) => void = (_category: Category): void => {};

  private categoryDepth(category: Category): number {
    let depth: number = 0;
    let current: Category = category;
    const visited: Set<number> = new Set<number>();
    visited.add(category.id);
    while (current.parentCategoryId !== null && depth < 3) {
      depth += 1;
      const parentId: number = current.parentCategoryId;
      if (visited.has(parentId)) {
        break;
      }
      visited.add(parentId);
      let parent: Category | null = null;
      for (const candidate of this.state.items) {
        if (candidate.id === parentId) {
          parent = candidate;
          break;
        }
      }
      if (parent === null) {
        break;
      }
      current = parent;
    }
    return depth;
  }

  private categoryLeftPadding(category: Category): number {
    return 16 + this.categoryDepth(category) * 20;
  }

  private categoryAccent(category: Category): ResourceColor {
    const color: string = category.color.trim();
    if (color.length === 6) {
      return `#${color}`;
    }
    if (color.length === 7 && color.startsWith('#')) {
      return color;
    }
    return $r('app.color.brand_primary');
  }

  @Builder
  private Header(): void {
    Row({ space: 8 }) {
      Text($r('app.string.category_all'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
    }
    .width('100%')
    .height($r('app.float.page_header_height'))
    .padding({ left: 16, right: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text($r('app.string.category_loading'))
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
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
        .accessibilityText($r('app.string.category_reload_accessibility'))
    }
    .padding(32)
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 14 }) {
      Text($r('app.string.category_empty_title'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message.length > 0 ? this.state.message : $r('app.string.category_empty_message'))
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      if (this.state.isRefreshing) {
        LoadingProgress()
          .width(36)
          .height(36)
      } else {
        Button($r('app.string.common_refresh'))
          .onClick(this.onRefresh)
          .accessibilityText($r('app.string.category_refresh_accessibility'))
      }
    }
    .padding(32)
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private CategoryIcon(category: Category): void {
    if (this.categoryDepth(category) === 0) {
      SymbolGlyph($r('sys.symbol.square_grid_2x2'))
        .fontSize(22)
        .fontColor([this.categoryAccent(category)])
    } else {
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(21)
        .fontColor([this.categoryAccent(category)])
    }
  }

  @Builder
  private CategoryRow(category: Category): void {
    Column() {
      Row({ space: 12 }) {
        this.CategoryIcon(category)
        Column({ space: 3 }) {
          Text(category.name)
            .fontSize(15)
            .fontWeight(this.categoryDepth(category) === 0 ? FontWeight.Bold : FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (category.description.length > 0) {
            Text(category.description)
              .fontSize(12)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(16)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      .width('100%')
      .constraintSize({ minHeight: 64 })
      .padding({
        left: this.categoryLeftPadding(category),
        right: 16,
        top: 10,
        bottom: 10
      })
      .backgroundColor(this.categoryDepth(category) === 0
        ? $r('sys.color.background_secondary')
        : $r('sys.color.comp_background_primary'))
      .onClick((): void => {
        this.onOpenCategory(category);
      })
      .accessibilityText(
        `${this.categoryDepth(category) === 0 ? '一级分类' : '子分类'}：${category.name}`
      )
      Divider()
        .margin({ left: this.categoryLeftPadding(category) + 34 })
        .color($r('sys.color.comp_divider'))
    }
    .width('100%')
  }

  @Builder
  private CategoryList(): void {
    Refresh({ refreshing: this.state.isRefreshing }) {
      List() {
        ForEach(this.state.items, (category: Category) => {
          ListItem() {
            this.CategoryRow(category)
          }
        }, (category: Category): string => category.id.toString())
        ListItem() {
          Column()
            .width('100%')
            .height(92)
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .refreshOffset(64)
    .pullToRefresh(true)
    .pullUpToCancelRefresh(false)
    .onRefreshing((): void => {
      this.onRefresh();
    })
  }

  build() {
    Column() {
      this.Header()
      if (this.state.kind === BrowseStateKind.LOADING || this.state.kind === BrowseStateKind.INITIAL) {
        this.LoadingState()
      } else if (this.state.kind === BrowseStateKind.ERROR) {
        this.RetryableState()
      } else if (this.state.kind === BrowseStateKind.EMPTY) {
        this.EmptyState()
      } else {
        this.CategoryList()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
  }
}
