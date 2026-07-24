import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { Category } from '../models/ForumModels';
import { CategorySection, categorySections } from './CategoryBrowsePresentation';

@Component
export struct CategoryBrowsePage {
  @Prop state: BrowseState<Category> = BrowseState.initial<Category>();
  scroller: Scroller = new Scroller();
  onRefresh: () => void = (): void => {};
  onOpenCategory: (category: Category) => void = (_category: Category): void => {};

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
  private ParentCategoryHeader(category: Category): void {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.square_grid_2x2'))
        .fontSize(22)
        .fontColor([this.categoryAccent(category)])
      Text(category.name)
        .fontSize(17)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(52)
    .padding({ left: 8, right: 8 })
    .onClick((): void => {
      this.onOpenCategory(category);
    })
    .accessibilityText(`父版块：${category.name}，查看全部主题`)
  }

  @Builder
  private ChildCategoryRow(category: Category): void {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.folder'))
        .fontSize(22)
        .fontColor([this.categoryAccent(category)])
      Column({ space: 3 }) {
        Text(category.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
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
    .constraintSize({ minHeight: 68 })
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .onClick((): void => {
      this.onOpenCategory(category);
    })
    .accessibilityText(`子版块：${category.name}`)
  }

  @Builder
  private CategoryGroup(section: CategorySection): void {
    Column({ space: 8 }) {
      this.ParentCategoryHeader(section.parent)
      if (section.children.length > 0) {
        Column() {
          ForEach(section.children, (category: Category, index: number) => {
            this.ChildCategoryRow(category)
            if (index < section.children.length - 1) {
              Divider()
                .margin({ left: 50, right: 16 })
                .color($r('sys.color.comp_divider'))
            }
          }, (category: Category): string => category.id.toString())
        }
        .width('100%')
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(18)
        .border({ width: 1, color: $r('sys.color.comp_divider') })
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, bottom: 12 })
  }

  @Builder
  private CategoryList(): void {
    Refresh({ refreshing: this.state.isRefreshing }) {
      List({ scroller: this.scroller }) {
        ForEach(categorySections(this.state.items), (section: CategorySection) => {
          ListItem() {
            this.CategoryGroup(section)
          }
        }, (section: CategorySection): string => section.parent.id.toString())
        ListItem() {
          Column()
            .width('100%')
            .height(92)
        }
      }
      .width('100%')
      .height('100%')
      .contentStartOffset(6)
      .clip(false)
      .cachedCount(3, true)
      .backgroundColor(Color.Transparent)
      .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    }
    .width('100%')
    .layoutWeight(1)
    .clip(false)
    .backgroundColor(Color.Transparent)
    .refreshOffset(64)
    .pullToRefresh(true)
    .pullUpToCancelRefresh(false)
    .onRefreshing((): void => {
      this.onRefresh();
    })
  }

  build() {
    Column() {
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
    .clip(false)
    .backgroundColor(Color.Transparent)
  }
}
