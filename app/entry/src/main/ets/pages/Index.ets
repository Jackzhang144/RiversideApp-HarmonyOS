import { common } from '@kit.AbilityKit';
import {
  HdsNavigation,
  HdsNavigationTitleMode,
  HdsSnackBar,
  HdsTabs,
  HdsTabsController,
  SnackBarOperationType
} from '@kit.UIDesignKit';
import {
  AppShellModel,
  BrowseState,
  BrowseStateKind,
  RootDestination
} from '../app/AppShellModel';
import { CategoryCacheScope } from '../cache/CategoryCache';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { Category, Topic } from '../models/ForumModels';
import { DiscourseHttpClient } from '../network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';

@Entry
@Component
struct Index {
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly tabsController: HdsTabsController = new HdsTabsController();
  private model: AppShellModel | null = null;

  @State selectedRoot: RootDestination = RootDestination.HOME;
  @State homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryState: BrowseState<Category> = BrowseState.initial<Category>();

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.homeState = BrowseState.error<Topic>('无法获取应用运行环境');
      this.categoryState = BrowseState.error<Category>('无法获取应用运行环境');
      return;
    }
    const model: AppShellModel = new AppShellModel(
      new DiscourseForumRepository(new DiscourseHttpClient()),
      new PreferencesCategoryCache(context),
      CategoryCacheScope.anonymous()
    );
    this.model = model;
    this.loadHome();
    this.loadCategories();
  }

  private async loadHome(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadHome();
    this.homeState = model.homeState;
    await task;
    this.homeState = model.homeState;
  }

  private async loadCategories(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    await model.restoreCategories();
    this.categoryState = model.categoryState;
    const task: Promise<void> = model.refreshCategories();
    this.categoryState = model.categoryState;
    await task;
    this.categoryState = model.categoryState;
    this.showCategoryRefreshMessage();
  }

  private async refreshCategories(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.refreshCategories();
    this.categoryState = model.categoryState;
    await task;
    this.categoryState = model.categoryState;
    this.showCategoryRefreshMessage();
  }

  private selectRoot(index: number): void {
    const destination: RootDestination = index === RootDestination.CATEGORY
      ? RootDestination.CATEGORY
      : RootDestination.HOME;
    this.selectedRoot = destination;
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.selectRoot(destination);
    }
  }

  private showCategoryRefreshMessage(): void {
    if (
      this.categoryState.message.length === 0 ||
      this.categoryState.kind === BrowseStateKind.ERROR
    ) {
      return;
    }
    const snackBar: HdsSnackBar = new HdsSnackBar(this.getUIContext());
    snackBar.show(
      { icon: $r('sys.symbol.exclamationmark_circle') },
      { title: '暂时无法刷新', content: this.categoryState.message },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭提示'
      },
      { duration: 5000 }
    );
  }

  @Builder
  private HomePage(): void {
    if (this.homeState.kind === BrowseStateKind.LOADING || this.homeState.kind === BrowseStateKind.INITIAL) {
      this.LoadingState('正在加载最新 Topic')
    } else if (this.homeState.kind === BrowseStateKind.ERROR) {
      this.RetryableState(this.homeState.message, (): void => {
        this.loadHome();
      })
    } else if (this.homeState.kind === BrowseStateKind.EMPTY) {
      this.EmptyState('还没有 Topic', '稍后再来看看，或手动刷新。', (): void => {
        this.loadHome();
      })
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.ListHeader('最新 Topic', (): void => {
            this.loadHome();
          })
        }
        ForEach(this.homeState.items, (topic: Topic) => {
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

  @Builder
  private CategoryPage(): void {
    if (
      this.categoryState.kind === BrowseStateKind.LOADING ||
      this.categoryState.kind === BrowseStateKind.INITIAL
    ) {
      this.LoadingState('正在加载 Category')
    } else if (this.categoryState.kind === BrowseStateKind.ERROR) {
      this.RetryableState(this.categoryState.message, (): void => {
        this.refreshCategories();
      })
    } else if (this.categoryState.kind === BrowseStateKind.EMPTY) {
      this.EmptyState('还没有 Category', '刷新后仍没有可展示的 Category。', (): void => {
        this.refreshCategories();
      })
    } else {
      List({ space: 8 }) {
        ListItem() {
          this.ListHeader(this.categoryState.isRefreshing ? 'Category · 正在刷新' : 'Category', (): void => {
            this.refreshCategories();
          })
        }
        ForEach(this.categoryState.items, (category: Category) => {
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

  @Builder
  private LoadingState(message: string): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text(message)
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private RetryableState(message: string, retry: () => void): void {
    Column({ space: 16 }) {
      Text('加载失败')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(retry)
        .accessibilityText('重新加载')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState(title: string, description: string, retry: () => void): void {
    Column({ space: 14 }) {
      Text(title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(description)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('刷新')
        .onClick(retry)
        .accessibilityText('刷新当前页面')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ListHeader(title: string, refresh: () => void): void {
    Row() {
      Text(title)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .layoutWeight(1)
      Button('刷新', { type: ButtonType.Normal })
        .onClick(refresh)
        .accessibilityText(`刷新${title}`)
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
    HdsNavigation(this.pathStack) {
      HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          this.HomePage()
        }
        .tabBar({ icon: $r('app.media.startIcon'), text: '首页' })

        TabContent() {
          this.CategoryPage()
        }
        .tabBar({ icon: $r('app.media.startIcon'), text: 'Category' })
      }
      .barPosition(BarPosition.End)
      .vertical(false)
      .onChange((index: number): void => {
        this.selectRoot(index);
      })
      .width('100%')
      .height('100%')
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .hideBackButton(true)
    .titleBar({
      content: {
        title: {
          mainTitle: this.selectedRoot === RootDestination.HOME ? '首页' : 'Category'
        }
      }
    })
    .width('100%')
    .height('100%')
  }
}
