import { common } from '@kit.AbilityKit';
import {
  HdsNavDestination,
  HdsNavigation,
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
import { CategoryBrowsePage } from '../components/CategoryBrowsePage';
import { CategoryTopicsPage } from '../components/CategoryTopicsPage';
import { HomeBrowsePage } from '../components/HomeBrowsePage';
import { Category, Topic } from '../models/ForumModels';
import { DiscourseHttpClient } from '../network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';

const CATEGORY_TOPICS_ROUTE: string = 'category-topics';

@Entry
@Component
struct Index {
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly tabsController: HdsTabsController = new HdsTabsController();
  private model: AppShellModel | null = null;
  private snackBar: HdsSnackBar | null = null;

  @State selectedRoot: RootDestination = RootDestination.HOME;
  @State homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  @State categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryTitle: string = 'Category';

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.homeState = BrowseState.error<Topic>('无法获取应用运行环境');
      this.categoryState = BrowseState.error<Category>('无法获取应用运行环境');
      return;
    }
    this.snackBar = new HdsSnackBar(this.getUIContext());
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
    await this.refreshCategories();
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

  private async openCategory(category: Category): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.openCategory(category);
    this.categoryTitle = category.name;
    this.categoryTopicsState = model.categoryTopicsState;
    this.pathStack.pushPath({ name: CATEGORY_TOPICS_ROUTE });
    await task;
    this.categoryTopicsState = model.categoryTopicsState;
  }

  private async retryCategoryTopics(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.retryCategoryTopics();
    this.categoryTopicsState = model.categoryTopicsState;
    await task;
    this.categoryTopicsState = model.categoryTopicsState;
  }

  private handleSecondaryBack(): boolean {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.closeSecondary();
    }
    return false;
  }

  @Builder
  private SecondaryPage(name: string, _param: Object): void {
    if (name === CATEGORY_TOPICS_ROUTE) {
      HdsNavDestination() {
        CategoryTopicsPage({
          state: this.categoryTopicsState,
          onRefresh: (): void => {
            this.retryCategoryTopics();
          },
          onOpenTopic: (_topic: Topic): void => {}
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: this.categoryTitle },
          backIcon: { label: '返回 Category' }
        }
      })
      .onBackPressed((): boolean => this.handleSecondaryBack())
    } else {
      HdsNavDestination() {
        Text('页面不可用')
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: { title: { mainTitle: 'Riverside' } }
      })
      .onBackPressed((): boolean => this.handleSecondaryBack())
    }
  }

  private showCategoryRefreshMessage(): void {
    if (
      this.categoryState.message.length === 0 ||
      this.categoryState.kind === BrowseStateKind.ERROR ||
      this.snackBar === null
    ) {
      return;
    }
    this.snackBar.show(
      { icon: $r('sys.symbol.exclamationmark_circle') },
      { title: '暂时无法刷新', content: this.categoryState.message },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭提示'
      },
      { duration: 5000 }
    );
  }

  build() {
    HdsNavigation(this.pathStack) {
      HdsTabs({ controller: this.tabsController }) {
        TabContent() {
          HomeBrowsePage({
            state: this.homeState,
            onRefresh: (): void => {
              this.loadHome();
            }
          })
        }
        .tabBar({ icon: $r('app.media.startIcon'), text: '首页' })

        TabContent() {
          CategoryBrowsePage({
            state: this.categoryState,
            onRefresh: (): void => {
              this.refreshCategories();
            },
            onOpenCategory: (category: Category): void => {
              this.openCategory(category);
            }
          })
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
    .hideTitleBar(true)
    .hideBackButton(true)
    .navDestination(this.SecondaryPage)
    .width('100%')
    .height('100%')
  }
}
