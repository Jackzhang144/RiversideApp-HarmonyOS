import { common } from '@kit.AbilityKit';
import {
  hdsMaterial,
  HdsNavDestination,
  HdsNavigation,
  HdsSnackBar,
  HdsTabs,
  HdsTabsController,
  SnackBarOperationType
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier, window } from '@kit.ArkUI';
import {
  AppShellModel,
  BrowseState,
  BrowseStateKind,
  isHomeSortTabAvailable,
  ReplyComposerState,
  ReplyComposerStateKind,
  rootDestinationForTabIndex,
  RootDestination,
  TopicReadState
} from '../app/AppShellModel';
import { AuthenticatedSession } from '../auth/AuthModels';
import { AuthRepository, AuthState, AuthStateKind } from '../auth/AuthRepository';
import { HuksAuthenticatedSessionStore } from '../auth/HuksAuthenticatedSessionStore';
import { RepositoryAuthenticationLifecycle } from '../auth/RepositoryAuthenticationLifecycle';
import { RsaAuthorizationCryptoFactory } from '../auth/RsaAuthorizationCrypto';
import { CategoryCacheScope } from '../cache/CategoryCache';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { AccountPage } from '../components/AccountPage';
import { CategoryBrowsePage } from '../components/CategoryBrowsePage';
import { CategoryTopicsPage } from '../components/CategoryTopicsPage';
import { HomeBrowsePage } from '../components/HomeBrowsePage';
import { LoginPage } from '../components/LoginPage';
import { TopicDetailPage } from '../components/TopicDetailPage';
import { UiPrototypePage } from '../components/prototype/UiPrototypePage';
import { Category, Topic } from '../models/ForumModels';
import {
  AuthenticatedSessionProvider,
  DiscourseHttpClient
} from '../network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';

const CATEGORY_TOPICS_ROUTE: string = 'category-topics';
const TOPIC_ROUTE: string = 'topic';
const LOGIN_ROUTE: string = 'login';
const UI_PROTOTYPE_ROUTE: string = 'ui-prototype';
const RIVERSIDE_BASE_URL: string = 'https://river-side.cc';
const ROOT_TAB_SELECTED_COLOR: string = '#317AF7';

class RepositorySessionProvider implements AuthenticatedSessionProvider {
  private readonly repository: AuthRepository;

  public constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  public currentSession(): AuthenticatedSession | null {
    return this.repository.currentSession();
  }
}

@Entry
@Component
struct Index {
  private readonly pathStack: NavPathStack = new NavPathStack();
  private readonly tabsController: HdsTabsController = new HdsTabsController();
  private model: AppShellModel | null = null;
  private authRepository: AuthRepository | null = null;
  private snackBar: HdsSnackBar | null = null;

  @Env(SystemProperties.WINDOW_AVOID_AREA) avoidAreasVp: window.UIEnvWindowAvoidAreaInfoVP;
  @State selectedRoot: RootDestination = RootDestination.HOME;
  @State homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  @State categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryTitle: string = 'Category';
  @State topicState: TopicReadState = TopicReadState.initial();
  @State replyState: ReplyComposerState = ReplyComposerState.closed();
  @State authState: AuthState = AuthState.idle();

  private topAvoidHeight(): number {
    const statusBarBottom: number =
      this.avoidAreasVp.statusBar.topRect.top + this.avoidAreasVp.statusBar.topRect.height;
    const cutoutBottom: number =
      this.avoidAreasVp.cutout.topRect.top + this.avoidAreasVp.cutout.topRect.height;
    return Math.max(statusBarBottom, cutoutBottom);
  }

  aboutToAppear(): void {
    const context: common.Context | undefined = this.getUIContext().getHostContext();
    if (context === undefined) {
      this.homeState = BrowseState.error<Topic>('无法获取应用运行环境');
      this.categoryState = BrowseState.error<Category>('无法获取应用运行环境');
      return;
    }
    this.snackBar = new HdsSnackBar(this.getUIContext());
    this.initialize(context);
  }

  private async initialize(context: common.Context): Promise<void> {
    const authRepository: AuthRepository = new AuthRepository(
      HuksAuthenticatedSessionStore.create(context),
      new RsaAuthorizationCryptoFactory()
    );
    this.authRepository = authRepository;
    const restoring: Promise<void> = authRepository.restore();
    this.authState = authRepository.state;
    await restoring;
    this.authState = authRepository.state;

    const sessionProvider: RepositorySessionProvider = new RepositorySessionProvider(authRepository);
    const authenticationLifecycle: RepositoryAuthenticationLifecycle = new RepositoryAuthenticationLifecycle(
      authRepository,
      (): void => {
        this.synchronizeAuthentication(true);
      }
    );
    const model: AppShellModel = new AppShellModel(
      new DiscourseForumRepository(new DiscourseHttpClient(RIVERSIDE_BASE_URL, sessionProvider)),
      new PreferencesCategoryCache(context),
      this.categoryCacheScope(authRepository),
      authenticationLifecycle
    );
    model.selectRoot(this.selectedRoot);
    this.model = model;
    this.loadHome();
    this.loadCategories();
  }

  private categoryCacheScope(repository: AuthRepository): CategoryCacheScope {
    const session: AuthenticatedSession | null = repository.currentSession();
    if (session === null) {
      return CategoryCacheScope.anonymous();
    }
    const authenticated: CategoryCacheScope | null = CategoryCacheScope.authenticated(session.clientId);
    return authenticated ?? CategoryCacheScope.anonymous();
  }

  private synchronizeAuthentication(reloadCategories: boolean): void {
    const repository: AuthRepository | null = this.authRepository;
    if (repository === null) {
      return;
    }
    this.authState = repository.state;
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.updateCategoryCacheScope(this.categoryCacheScope(repository));
    if (repository.state.kind === AuthStateKind.AUTHENTICATED) {
      model.resumeReplyAfterAuthentication();
      this.replyState = model.replyState;
    }
    this.categoryState = model.categoryState;
    if (reloadCategories) {
      this.loadCategories();
    }
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

  private async refreshHome(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.refreshHome();
    this.homeState = model.homeState;
    await task;
    this.homeState = model.homeState;
    this.showHomeRefreshMessage();
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
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      if (!model.selectRootTab(index)) {
        return;
      }
      this.selectedRoot = model.selectedRoot;
      return;
    }
    const destination: RootDestination | null = rootDestinationForTabIndex(index);
    if (destination === null) {
      return;
    }
    this.selectedRoot = destination;
  }

  private rootTabStyle(label: string, icon: Resource, available: boolean = true): BottomTabBarStyle {
    const normalColor: ResourceColor = available
      ? $r('sys.color.font_secondary')
      : $r('sys.color.font_tertiary');
    const selectedColor: ResourceColor = available ? ROOT_TAB_SELECTED_COLOR : normalColor;
    const normal: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .fontSize(21)
      .fontColor([normalColor]);
    const selected: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .fontSize(21)
      .fontColor([selectedColor]);
    return BottomTabBarStyle.of({ normal: normal, selected: selected }, label)
      .labelStyle({
        maxLines: 1,
        unselectedColor: normalColor,
        selectedColor: selectedColor,
        font: { size: 11 }
      })
      .padding({ left: 4, right: 4, top: 4, bottom: 4 });
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

  private async openTopic(topic: Topic): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.openTopic(topic);
    this.topicState = model.topicState;
    this.replyState = model.replyState;
    this.pathStack.pushPath({ name: TOPIC_ROUTE });
    await task;
    this.topicState = model.topicState;
    this.replyState = model.replyState;
  }

  private async retryTopic(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.retryTopic();
    this.topicState = model.topicState;
    await task;
    this.topicState = model.topicState;
    this.replyState = model.replyState;
  }

  private async loadMorePosts(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadMorePosts();
    this.topicState = model.topicState;
    await task;
    this.topicState = model.topicState;
  }

  private openReply(postNumber: number | null): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.openReply(postNumber);
    this.replyState = model.replyState;
  }

  private updateReplyDraft(draft: string): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.updateReplyDraft(draft);
    this.replyState = model.replyState;
  }

  private dismissReply(): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.dismissReply();
    this.replyState = model.replyState;
  }

  private async submitReply(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.submitReply();
    this.replyState = model.replyState;
    await task;
    this.replyState = model.replyState;
    this.topicState = model.topicState;
    this.showReplyMessage();
  }

  private handleSecondaryBack(): boolean {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.closeSecondary();
    }
    return false;
  }

  private async openLogin(): Promise<void> {
    const repository: AuthRepository | null = this.authRepository;
    if (
      repository === null ||
      repository.state.kind === AuthStateKind.AUTHENTICATED ||
      repository.state.kind === AuthStateKind.GENERATING_REQUEST ||
      repository.state.kind === AuthStateKind.AUTHORIZING ||
      repository.state.kind === AuthStateKind.VALIDATING ||
      repository.state.kind === AuthStateKind.PERSISTING
    ) {
      return;
    }
    this.pathStack.pushPath({ name: LOGIN_ROUTE });
    await this.beginAuthorization();
  }

  private openUiPrototype(): void {
    this.pathStack.pushPath({ name: UI_PROTOTYPE_ROUTE });
  }

  private closeUiPrototype(): void {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.closeSecondary();
    }
    this.pathStack.pop();
  }

  private async beginAuthorization(): Promise<void> {
    const repository: AuthRepository | null = this.authRepository;
    if (repository === null) {
      return;
    }
    const task: Promise<void> = repository.beginAuthorization();
    this.authState = repository.state;
    await task;
    this.authState = repository.state;
  }

  private handleLoginNavigation(url: string, isMainFrame: boolean): boolean {
    const repository: AuthRepository | null = this.authRepository;
    if (repository === null || !repository.shouldInterceptNavigation(url, isMainFrame)) {
      return false;
    }
    this.completeLoginNavigation(url, isMainFrame);
    return true;
  }

  private async completeLoginNavigation(url: string, isMainFrame: boolean): Promise<void> {
    const repository: AuthRepository | null = this.authRepository;
    if (repository === null) {
      return;
    }
    const task: Promise<boolean> = repository.handleNavigation(url, isMainFrame);
    this.authState = repository.state;
    await task;
    this.authState = repository.state;
    if (repository.state.kind !== AuthStateKind.AUTHENTICATED) {
      return;
    }
    this.pathStack.pop();
    this.synchronizeAuthentication(true);
    this.showAuthenticationMessage('登录成功', 'Authenticated Session 已安全保存');
  }

  private cancelLogin(): boolean {
    const repository: AuthRepository | null = this.authRepository;
    if (repository?.state.kind === AuthStateKind.PERSISTING) {
      return true;
    }
    if (repository !== null && repository.state.kind !== AuthStateKind.AUTHENTICATED) {
      repository.cancelAuthorization();
      this.authState = repository.state;
    }
    return false;
  }

  private async logout(): Promise<void> {
    const repository: AuthRepository | null = this.authRepository;
    if (repository === null) {
      return;
    }
    const task: Promise<void> = repository.logout();
    this.authState = repository.state;
    await task;
    this.synchronizeAuthentication(true);
    if (repository.state.kind === AuthStateKind.IDLE) {
      this.showAuthenticationMessage('已退出登录', '本地认证材料已清除');
    }
  }

  @Builder
  private SecondaryPage(name: string, _param: Object): void {
    if (name === CATEGORY_TOPICS_ROUTE) {
      HdsNavDestination() {
        CategoryTopicsPage({
          state: this.categoryTopicsState,
          categories: this.categoryState.items,
          onRefresh: (): void => {
            this.retryCategoryTopics();
          },
          onOpenTopic: (topic: Topic): void => {
            this.openTopic(topic);
          }
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
    } else if (name === TOPIC_ROUTE) {
      HdsNavDestination() {
        TopicDetailPage({
          state: this.topicState,
          replyState: this.replyState,
          onRetry: (): void => {
            this.retryTopic();
          },
          onLoadMore: (): void => {
            this.loadMorePosts();
          },
          onOpenReply: (postNumber: number | null): void => {
            this.openReply(postNumber);
          },
          onReplyDraftChange: (draft: string): void => {
            this.updateReplyDraft(draft);
          },
          onSubmitReply: (): void => {
            this.submitReply();
          },
          onDismissReply: (): void => {
            this.dismissReply();
          },
          onLoginForReply: (): void => {
            this.openLogin();
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: 'Topic 详情' },
          backIcon: { label: '返回 Topic 列表' }
        }
      })
      .onBackPressed((): boolean => this.handleSecondaryBack())
    } else if (name === LOGIN_ROUTE) {
      HdsNavDestination() {
        LoginPage({
          state: this.authState,
          onRetry: (): void => {
            this.beginAuthorization();
          },
          onNavigation: (url: string, isMainFrame: boolean): boolean => {
            return this.handleLoginNavigation(url, isMainFrame);
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: '登录 RiverSide' },
          backIcon: { label: '取消登录' }
        }
      })
      .onBackPressed((): boolean => this.cancelLogin())
    } else if (name === UI_PROTOTYPE_ROUTE) {
      HdsNavDestination() {
        UiPrototypePage({
          onExit: (): void => {
            this.closeUiPrototype();
          }
        })
      }
      .hideTitleBar(true)
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
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

  private showHomeRefreshMessage(): void {
    if (
      this.homeState.message.length === 0 ||
      this.homeState.kind === BrowseStateKind.ERROR ||
      this.snackBar === null
    ) {
      return;
    }
    this.snackBar.show(
      { icon: $r('sys.symbol.exclamationmark_circle') },
      { title: '暂时无法刷新', content: this.homeState.message },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭提示'
      },
      { duration: 5000 }
    );
  }

  private showAuthenticationMessage(title: string, content: string): void {
    if (this.snackBar === null) {
      return;
    }
    this.snackBar.show(
      { icon: $r('sys.symbol.checkmark_circle') },
      { title: title, content: content },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭提示'
      },
      { duration: 4000 }
    );
  }

  private showReplyMessage(): void {
    if (
      this.snackBar === null ||
      (this.replyState.kind !== ReplyComposerStateKind.SUCCESS &&
        this.replyState.kind !== ReplyComposerStateKind.ERROR)
    ) {
      return;
    }
    this.snackBar.show(
      { icon: this.replyState.kind === ReplyComposerStateKind.SUCCESS
        ? $r('sys.symbol.checkmark_circle')
        : $r('sys.symbol.exclamationmark_circle') },
      {
        title: this.replyState.kind === ReplyComposerStateKind.SUCCESS ? 'Reply 已发布' : 'Reply 未发布',
        content: this.replyState.message
      },
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
            categories: this.categoryState.items,
            onRetry: (): void => {
              this.loadHome();
            },
            onRefresh: (): void => {
              this.refreshHome();
            },
            onOpenTopic: (topic: Topic): void => {
              this.openTopic(topic);
            },
            canChangeSortTab: (index: number): boolean => {
              const model: AppShellModel | null = this.model;
              return model === null
                ? isHomeSortTabAvailable(index)
                : model.selectHomeSortTab(index);
            }
          })
        }
        .tabBar(this.rootTabStyle('首页', $r('sys.symbol.house')))

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
        .tabBar(this.rootTabStyle('Category', $r('sys.symbol.square_grid_2x2')))

        TabContent() {
          Column()
            .width('100%')
            .height('100%')
        }
        .tabBar(this.rootTabStyle('聊天', $r('sys.symbol.message'), false))
        .accessibilityText('聊天，未实现')

        TabContent() {
          Column()
            .width('100%')
            .height('100%')
        }
        .tabBar(this.rootTabStyle('消息', $r('sys.symbol.bell'), false))
        .accessibilityText('消息，未实现')

        TabContent() {
          AccountPage({
            state: this.authState,
            onLogin: (): void => {
              this.openLogin();
            },
            onLogout: (): void => {
              this.logout();
            },
            onOpenUiPrototype: (): void => {
              this.openUiPrototype();
            }
          })
        }
        .tabBar(this.rootTabStyle('我的', $r('sys.symbol.person_crop_circle_fill_1')))
      }
      .scrollable(false)
      .barPosition(BarPosition.End)
      .vertical(false)
      .barOverlap(true)
      .barFloatingStyle({
        barSideMargin: 12,
        barBottomMargin: 28,
        adaptToHandedness: true,
        systemMaterialEffect: {
          materialType: hdsMaterial.MaterialType.ADAPTIVE,
          materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
        }
      })
      .onContentWillChange((_currentIndex: number, comingIndex: number): boolean => {
        return rootDestinationForTabIndex(comingIndex) !== null;
      })
      .onChange((index: number): void => {
        this.selectRoot(index);
      })
      .width('100%')
      .height('100%')
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
    }
    .hideTitleBar(true)
    .hideBackButton(true)
    .navDestination(this.SecondaryPage)
    .width('100%')
    .height('100%')
    .padding({ top: this.topAvoidHeight() })
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
  }
}
