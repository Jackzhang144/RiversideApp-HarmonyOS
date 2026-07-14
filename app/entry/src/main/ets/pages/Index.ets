import { common } from '@kit.AbilityKit';
import { webview } from '@kit.ArkWeb';
import { BusinessError, pasteboard } from '@kit.BasicServicesKit';
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
  ComposerMediaTarget,
  ReplyComposerState,
  ReplyComposerStateKind,
  rootDestinationForTabIndex,
  RootDestination,
  SearchState,
  TopicComposerState,
  TopicComposerStateKind,
  TopicReadState
} from '../app/AppShellModel';
import { AuthenticatedSession } from '../auth/AuthModels';
import { AuthRepository, AuthState, AuthStateKind } from '../auth/AuthRepository';
import { HuksAuthenticatedSessionStore } from '../auth/HuksAuthenticatedSessionStore';
import { RepositoryAuthenticationLifecycle } from '../auth/RepositoryAuthenticationLifecycle';
import { RsaAuthorizationCryptoFactory } from '../auth/RsaAuthorizationCrypto';
import { CategoryCacheScope } from '../cache/CategoryCache';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { AbilityContextRegistry } from '../core/AbilityContextRegistry';
import { RepositoryResult } from '../core/RepositoryResult';
import { AccountPage } from '../components/AccountPage';
import { CategoryBrowsePage } from '../components/CategoryBrowsePage';
import { CategoryTopicsPage } from '../components/CategoryTopicsPage';
import { HomeBrowsePage } from '../components/HomeBrowsePage';
import { ForumComposer } from '../components/ForumComposer';
import {
  ForumComposerPresentation,
  ForumComposerStatus
} from '../components/ForumComposerPresentation';
import { LoginPage } from '../components/LoginPage';
import { SearchPage } from '../components/SearchPage';
import { SecureRichEmbedPage } from '../components/SecureRichEmbedPage';
import { TopicDetailPage } from '../components/TopicDetailPage';
import { UserProfileSummaryPage } from '../components/UserProfileSummaryPage';
import { ImageViewerPage } from '../components/ImageViewerPage';
import { selectedBookmarkPostIds } from '../components/TopicReadingPresentation';
import { UiPrototypePage } from '../components/prototype/UiPrototypePage';
import { Category, Topic } from '../models/ForumModels';
import { HomeChannel, SearchPost } from '../models/DiscoveryModels';
import { CurrentUser } from '../models/ReplyModels';
import { AUTHORING_CATEGORY_ID } from '../models/AuthoringModels';
import {
  classifyRichNavigation,
  isAllowedEmbedNavigation,
  RichEmbedProvider,
  RichNavigationKind,
  RichNavigationTarget
} from '../models/RichContentModels';
import {
  AuthenticatedSessionProvider,
  DiscourseHttpClient
} from '../network/DiscourseHttpClient';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';
import { DiscourseMediaRepository } from '../repositories/MediaRepository';
import { DiscourseMediaTransport } from '../network/ForumMediaTransport';
import {
  MediaSelectionResult,
  MediaSelectionResultKind,
  MediaSelectionService
} from '../media/MediaSelectionService';
import { CachedMedia, MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import {
  ImageViewerState,
  normalizeRemoteImageUrl
} from '../models/ImageViewerModels';
import { MediaGalleryService } from '../media/MediaGalleryService';
import { PreferencesDiscoverySettingsStore } from '../settings/PreferencesDiscoverySettingsStore';

const CATEGORY_TOPICS_ROUTE: string = 'category-topics';
const TOPIC_ROUTE: string = 'topic';
const LOGIN_ROUTE: string = 'login';
const SEARCH_ROUTE: string = 'search';
const TOPIC_COMPOSER_ROUTE: string = 'topic-composer';
const USER_PROFILE_ROUTE: string = 'user-profile';
const RICH_EMBED_ROUTE: string = 'rich-embed';
const IMAGE_VIEWER_ROUTE: string = 'image-viewer';
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
  private authenticationLifecycle: RepositoryAuthenticationLifecycle | null = null;
  private snackBar: HdsSnackBar | null = null;
  private richEmbedController: webview.WebviewController = new webview.WebviewController();
  private mediaGalleryService: MediaGalleryService | null = null;

  @Env(SystemProperties.WINDOW_AVOID_AREA) avoidAreasVp: window.UIEnvWindowAvoidAreaInfoVP;
  @State selectedRoot: RootDestination = RootDestination.HOME;
  @State homeState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State selectedHomeChannel: HomeChannel = HomeChannel.LATEST_REPLIES;
  @State worldCupEntryEnabled: boolean = true;
  @State categoryState: BrowseState<Category> = BrowseState.initial<Category>();
  @State categoryTopicsState: BrowseState<Topic> = BrowseState.initial<Topic>();
  @State categoryTitle: string = 'Category';
  @State topicState: TopicReadState = TopicReadState.initial();
  @State bookmarkedPostIds: Array<number> = [];
  @State lastReadPostNumber: number = 0;
  @State readProgressBusy: boolean = false;
  @State readProgressMessage: string = '';
  @State replyState: ReplyComposerState = ReplyComposerState.closed();
  @State replySheetVisible: boolean = false;
  @State topicComposerState: TopicComposerState = TopicComposerState.closed();
  @State composerMediaState: MediaUploadState | null = null;
  @State authState: AuthState = AuthState.idle();
  @State accountIdentity: CurrentUser | null = null;
  @State accountIdentityLoading: boolean = false;
  @State accountIdentityError: string = '';
  @State searchState: SearchState = SearchState.initial();
  @State profileUsername: string = '';
  @State profileUser: CurrentUser | null = null;
  @State profileLoading: boolean = false;
  @State profileError: string = '';
  @State richEmbedUrl: string = '';
  @State richEmbedTitle: string = '';
  @State richEmbedProvider: RichEmbedProvider = RichEmbedProvider.NONE;
  @State imageViewerState: ImageViewerState = ImageViewerState.preparing('', '');
  private accountIdentityRequestVersion: number = 0;
  private profileRequestVersion: number = 0;

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
    const abilityContext: common.UIAbilityContext | null = AbilityContextRegistry.current();
    if (abilityContext !== null) {
      this.mediaGalleryService = new MediaGalleryService(abilityContext, sessionProvider);
    }
    const authenticationLifecycle: RepositoryAuthenticationLifecycle = new RepositoryAuthenticationLifecycle(
      authRepository,
      (): void => {
        this.synchronizeAuthentication(true);
      }
    );
    this.authenticationLifecycle = authenticationLifecycle;
    const model: AppShellModel = new AppShellModel(
      new DiscourseForumRepository(new DiscourseHttpClient(RIVERSIDE_BASE_URL, sessionProvider)),
      new PreferencesCategoryCache(context),
      this.categoryCacheScope(authRepository),
      authenticationLifecycle,
      new PreferencesDiscoverySettingsStore(context),
      new DiscourseMediaRepository(new DiscourseMediaTransport(RIVERSIDE_BASE_URL, sessionProvider))
    );
    await model.restoreDiscoverySettings();
    this.selectedHomeChannel = model.selectedHomeChannel;
    this.worldCupEntryEnabled = model.worldCupEntryEnabled;
    model.selectRoot(this.selectedRoot);
    this.model = model;
    this.refreshAccountIdentity();
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
      this.synchronizeReplyState(model, model.replyState.kind === ReplyComposerStateKind.EDITING);
      model.resumeTopicAfterAuthentication();
      this.topicComposerState = model.topicComposerState;
      this.refreshAccountIdentity();
    } else {
      this.accountIdentityRequestVersion += 1;
      this.accountIdentity = null;
      this.accountIdentityLoading = false;
      this.accountIdentityError = '';
    }
    this.categoryState = model.categoryState;
    if (reloadCategories) {
      this.loadCategories();
    }
  }

  private refreshAccountIdentity(): void {
    const model: AppShellModel | null = this.model;
    if (model === null || this.authState.kind !== AuthStateKind.AUTHENTICATED) {
      return;
    }
    const requestVersion: number = this.accountIdentityRequestVersion + 1;
    this.accountIdentityRequestVersion = requestVersion;
    this.accountIdentity = null;
    this.accountIdentityLoading = true;
    this.accountIdentityError = '';
    this.loadAccountIdentity(model, requestVersion);
  }

  private async loadAccountIdentity(model: AppShellModel, requestVersion: number): Promise<void> {
    const result: RepositoryResult<CurrentUser> = await model.loadCurrentUser();
    if (
      requestVersion !== this.accountIdentityRequestVersion ||
      this.authState.kind !== AuthStateKind.AUTHENTICATED
    ) {
      return;
    }
    this.accountIdentityLoading = false;
    if (!result.isSuccess() || result.data === null) {
      this.accountIdentityError = result.message;
      return;
    }
    this.accountIdentity = result.data;
    const channelChanged: boolean = model.selectedHomeChannel !== result.data.defaultHomeChannel &&
      result.data.defaultHomeChannel !== null;
    if (result.data.defaultHomeChannel !== null) {
      await model.applyServerHomeChannel(result.data.defaultHomeChannel);
      this.selectedHomeChannel = model.selectedHomeChannel;
      if (channelChanged) {
        await this.loadHome();
      }
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

  private async selectHomeChannel(index: number): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null || !await model.selectHomeChannel(index)) {
      return;
    }
    this.selectedHomeChannel = model.selectedHomeChannel;
    await this.loadHome();
  }

  private async loadMoreHome(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadMoreHome();
    this.homeState = model.homeState;
    await task;
    this.homeState = model.homeState;
  }

  private async setWorldCupEntryEnabled(enabled: boolean): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    this.worldCupEntryEnabled = enabled;
    await model.setWorldCupEntryEnabled(enabled);
    this.worldCupEntryEnabled = model.worldCupEntryEnabled;
  }

  private openSearch(): void {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.searchState = SearchState.initial();
      this.searchState = model.searchState;
    }
    this.pathStack.pushPath({ name: SEARCH_ROUTE });
  }

  private async searchForum(query: string): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.searchForum(query);
    this.searchState = model.searchState;
    await task;
    this.searchState = model.searchState;
  }

  private async retrySearch(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.retrySearch();
    this.searchState = model.searchState;
    await task;
    this.searchState = model.searchState;
  }

  private async loadMoreSearch(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadMoreSearch();
    this.searchState = model.searchState;
    await task;
    this.searchState = model.searchState;
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

  private async loadMoreCategoryTopics(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadMoreCategoryTopics();
    this.categoryTopicsState = model.categoryTopicsState;
    await task;
    this.categoryTopicsState = model.categoryTopicsState;
  }

  private async openTopic(topic: Topic, initialPostNumber: number | null = null): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.openTopic(topic, initialPostNumber);
    this.synchronizeTopicState(model);
    this.synchronizeReplyState(model, false);
    this.pathStack.pushPath({ name: TOPIC_ROUTE });
    await task;
    this.synchronizeTopicState(model);
    this.synchronizeReplyState(model);
  }

  private handleRichLink(url: string): void {
    const target: RichNavigationTarget = classifyRichNavigation(url);
    if (target.kind === RichNavigationKind.TOPIC) {
      const topic: Topic = new Topic(target.topicId, 'Topic', 0, 0, 0, 0, '', '', false, '');
      this.openTopic(topic, target.postNumber);
      return;
    }
    if (target.kind === RichNavigationKind.PROFILE) {
      this.openUserProfile(target.username);
      return;
    }
    if (target.kind === RichNavigationKind.EXTERNAL) {
      this.confirmExternalNavigation(target.url);
      return;
    }
    this.showAuthenticationMessage('链接已拦截', '仅允许安全 HTTPS、邮件或电话链接');
  }

  private openUserProfile(username: string): void {
    this.profileUsername = username;
    this.profileUser = null;
    this.profileError = '';
    this.pathStack.pushPath({ name: USER_PROFILE_ROUTE });
    this.loadSelectedUserProfile();
  }

  private async loadSelectedUserProfile(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null || this.profileUsername.length === 0) {
      return;
    }
    const requestVersion: number = this.profileRequestVersion + 1;
    this.profileRequestVersion = requestVersion;
    this.profileLoading = true;
    this.profileError = '';
    const result: RepositoryResult<CurrentUser> = await model.loadUserProfile(this.profileUsername);
    if (requestVersion !== this.profileRequestVersion) {
      return;
    }
    this.profileLoading = false;
    if (!result.isSuccess() || result.data === null) {
      this.profileUser = null;
      this.profileError = result.message;
      return;
    }
    this.profileUser = result.data;
  }

  private openRichEmbed(url: string, provider: RichEmbedProvider, title: string): void {
    if (!isAllowedEmbedNavigation(provider, url)) {
      this.showAuthenticationMessage('嵌入已拦截', '播放器 URL 不在已验证白名单中');
      return;
    }
    this.richEmbedUrl = url;
    this.richEmbedProvider = provider;
    this.richEmbedTitle = title;
    this.richEmbedController = new webview.WebviewController();
    this.pathStack.pushPath({ name: RICH_EMBED_ROUTE });
  }

  private handleRichEmbedBack(): boolean {
    try {
      if (this.richEmbedController.accessBackward()) {
        this.richEmbedController.backward();
        return true;
      }
    } catch (_) {
      return false;
    }
    return false;
  }

  private confirmExternalNavigation(url: string): void {
    this.getUIContext().showAlertDialog({
      title: '打开外部链接？',
      message: url,
      primaryButton: {
        value: '取消',
        action: (): void => {}
      },
      secondaryButton: {
        value: '继续打开',
        action: (): void => this.openExternalLink(url)
      },
      cancel: (): void => {}
    });
  }

  private openExternalLink(url: string): void {
    const abilityContext: common.UIAbilityContext | null = AbilityContextRegistry.current();
    if (abilityContext === null) {
      this.showAuthenticationMessage('链接未打开', '无法获取应用运行环境');
      return;
    }
    abilityContext.openLink(url).catch((error: BusinessError): void => {
      this.showAuthenticationMessage('链接未打开', error.message);
    });
  }

  private async openImageViewer(url: string, title: string): Promise<void> {
    const normalizedUrl: string = normalizeRemoteImageUrl(url, RIVERSIDE_BASE_URL);
    if (normalizedUrl.length === 0) {
      this.showAuthenticationMessage('无法查看图片', '图片地址无效');
      return;
    }
    this.imageViewerState = ImageViewerState.preparing(normalizedUrl, title);
    this.pathStack.pushPath({ name: IMAGE_VIEWER_ROUTE });
    const service: MediaGalleryService | null = this.mediaGalleryService;
    if (service === null) {
      this.imageViewerState = this.imageViewerState.failed('图片保存服务不可用');
      return;
    }
    const result: RepositoryResult<CachedMedia> = await service.prepareOriginal(normalizedUrl);
    if (this.imageViewerState.remoteUrl !== normalizedUrl) {
      return;
    }
    if (result.isUnauthorized()) {
      await this.authenticationLifecycle?.handleUnauthorized();
      this.imageViewerState = this.imageViewerState.failed('登录已失效，请重新登录后保存图片');
      return;
    }
    this.imageViewerState = result.isSuccess() && result.data !== null
      ? this.imageViewerState.ready(result.data)
      : this.imageViewerState.failed(result.message);
  }

  private async saveViewerImage(): Promise<void> {
    const service: MediaGalleryService | null = this.mediaGalleryService;
    const media: CachedMedia | null = this.imageViewerState.cachedMedia;
    if (service === null || media === null) {
      this.imageViewerState = this.imageViewerState.failed('原图尚未准备完成');
      return;
    }
    this.imageViewerState = this.imageViewerState.saving();
    const result: RepositoryResult<boolean> = await service.saveToGallery(media);
    this.imageViewerState = result.isSuccess()
      ? this.imageViewerState.saved()
      : this.imageViewerState.failed(result.message);
  }

  private async copyViewerImageUrl(): Promise<void> {
    try {
      await pasteboard.getSystemPasteboard().setData(
        pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, this.imageViewerState.remoteUrl)
      );
      this.showAuthenticationMessage('链接已复制', '图片原始地址已复制到剪贴板');
    } catch (_) {
      this.showAuthenticationMessage('复制失败', '无法写入系统剪贴板');
    }
  }

  private async retryTopic(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.retryTopic();
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
    this.synchronizeReplyState(model);
  }

  private async loadMorePosts(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadMorePosts();
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
  }

  private async loadPreviousPosts(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.loadPreviousPosts();
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
  }

  private async togglePostReaction(postId: number, reaction: string): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.togglePostReaction(postId, reaction);
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
  }

  private async togglePostBookmark(postId: number): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.togglePostBookmark(postId);
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
  }

  private async reportTopicReadProgress(postNumber: number): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.reportTopicReadProgress(postNumber);
    this.synchronizeTopicState(model);
    await task;
    this.synchronizeTopicState(model);
  }

  private synchronizeTopicState(model: AppShellModel): void {
    this.topicState = model.topicState;
    this.bookmarkedPostIds = selectedBookmarkPostIds(model.topicState.posts);
    this.lastReadPostNumber = model.topicState.readProgressState.lastReadPostNumber;
    this.readProgressBusy = model.topicState.readProgressState.busy;
    this.readProgressMessage = model.topicState.readProgressState.message;
  }

  private synchronizeReplyState(model: AppShellModel, sheetVisible: boolean | null = null): void {
    this.replyState = model.replyState;
    if (sheetVisible !== null) {
      this.replySheetVisible = sheetVisible;
    }
  }

  private openReply(postNumber: number | null): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.openReply(postNumber);
    this.composerMediaState = null;
    this.synchronizeReplyState(
      model,
      model.replyState.kind !== ReplyComposerStateKind.CLOSED &&
        model.replyState.kind !== ReplyComposerStateKind.SUCCESS
    );
    this.restoreReplyDraft(model);
  }

  private async restoreReplyDraft(model: AppShellModel): Promise<void> {
    await model.restoreReplyDraft();
    this.synchronizeReplyState(model,
      model.replyState.kind !== ReplyComposerStateKind.CLOSED &&
        model.replyState.kind !== ReplyComposerStateKind.SUCCESS
    );
  }

  private updateReplyDraft(draft: string): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.updateReplyDraft(draft);
    this.synchronizeReplyState(model);
  }

  private dismissReply(): void {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    model.dismissReply();
    this.composerMediaState = null;
    this.synchronizeReplyState(model, false);
  }

  private async submitReply(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const task: Promise<void> = model.submitReply((state: ReplyComposerState): void => {
      this.replyState = state;
    });
    this.synchronizeReplyState(model);
    await task;
    this.synchronizeReplyState(
      model,
      model.replyState.kind === ReplyComposerStateKind.SUCCESS ? false : null
    );
    this.synchronizeTopicState(model);
    this.showReplyMessage();
  }

  private async saveReplyDraft(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const saved: boolean = await model.saveReplyDraft();
    this.synchronizeReplyState(model);
    if (saved) {
      this.showAuthenticationMessage('草稿已保存', 'Reply 草稿已同步到服务端');
    }
  }

  private async discardReplyDraft(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const discarded: boolean = await model.discardReplyDraft();
    this.synchronizeReplyState(model, discarded ? false : null);
  }

  private async openNewTopic(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null || !this.canCreateAuthoringTopic()) {
      return;
    }
    model.openNewTopic();
    this.composerMediaState = null;
    this.topicComposerState = model.topicComposerState;
    this.pathStack.pushPath({ name: TOPIC_COMPOSER_ROUTE });
    await model.restoreTopicDraft();
    this.topicComposerState = model.topicComposerState;
  }

  private canCreateAuthoringTopic(): boolean {
    if (this.authState.kind !== AuthStateKind.AUTHENTICATED) {
      return true;
    }
    return this.accountIdentity?.canCreatePost === true && this.categoryState.items.some(
      (category: Category): boolean => category.id === AUTHORING_CATEGORY_ID
    );
  }

  private openPostEditor(postId: number): void {
    const model: AppShellModel | null = this.model;
    if (model === null || !model.openPostEditor(postId)) {
      return;
    }
    this.synchronizeTopicState(model);
    if (model.topicEditingTopicId !== null) {
      this.composerMediaState = null;
      this.topicComposerState = model.topicComposerState;
      this.pathStack.pushPath({ name: TOPIC_COMPOSER_ROUTE });
      return;
    }
    this.synchronizeReplyState(model, true);
  }

  private topicComposerStatus(): ForumComposerStatus {
    if (
      this.topicComposerState.kind === TopicComposerStateKind.SUBMITTING ||
      this.topicComposerState.kind === TopicComposerStateKind.SAVING_DRAFT
    ) {
      return ForumComposerStatus.SUBMITTING;
    }
    if (this.topicComposerState.kind === TopicComposerStateKind.ERROR) {
      return ForumComposerStatus.ERROR;
    }
    if (this.topicComposerState.kind === TopicComposerStateKind.REAUTHENTICATE) {
      return ForumComposerStatus.REAUTHENTICATE;
    }
    return ForumComposerStatus.EDITING;
  }

  private topicComposerPresentation(): ForumComposerPresentation {
    const model: AppShellModel | null = this.model;
    if (model?.topicEditingTopicId !== null && model?.topicEditingTopicId !== undefined) {
      return ForumComposerPresentation.editTopic(
        this.topicComposerState.title,
        this.topicComposerState.raw,
        this.topicComposerStatus(),
        this.topicComposerState.message,
        this.composerMediaState
      );
    }
    return ForumComposerPresentation.topic(
      'Category #111',
      this.topicComposerState.title,
      this.topicComposerState.raw,
      this.topicComposerStatus(),
      this.topicComposerState.message,
      this.composerMediaState
    );
  }

  private synchronizeComposerDrafts(model: AppShellModel): void {
    this.replyState = model.replyState;
    this.topicComposerState = model.topicComposerState;
  }

  private async selectComposerImages(): Promise<void> {
    const context: common.UIAbilityContext | null = AbilityContextRegistry.current();
    if (context === null) {
      this.showAuthenticationMessage('无法选择图片', '无法获取应用运行环境');
      return;
    }
    const result: MediaSelectionResult = await new MediaSelectionService(context).selectImages(5);
    if (result.kind === MediaSelectionResultKind.CANCELLED) {
      return;
    }
    if (result.kind === MediaSelectionResultKind.FAILURE) {
      this.showAuthenticationMessage('无法选择图片', result.message);
      return;
    }
    for (const media of result.media) {
      const state: MediaUploadState = await this.uploadComposerImage(media);
      if (state.kind !== MediaUploadStateKind.SUCCEEDED) {
        return;
      }
    }
  }

  private async uploadComposerImage(media: CachedMedia): Promise<MediaUploadState> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      const unavailable: MediaUploadState = MediaUploadState.selected(media).failed('图片上传服务不可用');
      this.composerMediaState = unavailable;
      return unavailable;
    }
    const state: MediaUploadState = await model.uploadComposerMedia(
      media,
      this.replySheetVisible ? ComposerMediaTarget.REPLY : ComposerMediaTarget.TOPIC,
      (nextState: MediaUploadState): void => {
        this.composerMediaState = nextState;
        this.synchronizeComposerDrafts(model);
      }
    );
    this.synchronizeComposerDrafts(model);
    return state;
  }

  private cancelComposerImageUpload(): void {
    this.model?.cancelComposerMediaUpload();
  }

  private retryComposerImageUpload(): void {
    const media: CachedMedia | undefined = this.composerMediaState?.media;
    if (media !== undefined) {
      this.uploadComposerImage(media);
    }
  }

  private removeComposerImageState(): void {
    this.composerMediaState = null;
  }

  private updateTopicTitle(title: string): void {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.updateTopicComposerTitle(title);
      this.topicComposerState = model.topicComposerState;
    }
  }

  private updateTopicRaw(raw: string): void {
    const model: AppShellModel | null = this.model;
    if (model !== null) {
      model.updateTopicComposerRaw(raw);
      this.topicComposerState = model.topicComposerState;
    }
  }

  private async saveTopicDraft(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const saved: boolean = await model.saveTopicDraft();
    this.topicComposerState = model.topicComposerState;
    if (saved) {
      this.showAuthenticationMessage('草稿已保存', 'Topic 草稿已同步到服务端');
    }
  }

  private async discardTopicDraft(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const discarded: boolean = await model.discardTopicDraft();
    this.topicComposerState = model.topicComposerState;
    if (discarded) {
      this.pathStack.pop();
    }
  }

  private async submitTopicComposer(): Promise<void> {
    const model: AppShellModel | null = this.model;
    if (model === null) {
      return;
    }
    const editing: boolean = model.topicEditingTopicId !== null;
    const task: Promise<void> = model.submitTopicComposer();
    this.topicComposerState = model.topicComposerState;
    await task;
    this.topicComposerState = model.topicComposerState;
    this.synchronizeTopicState(model);
    if (model.topicComposerState.kind === TopicComposerStateKind.SUCCESS) {
      this.pathStack.pop();
      this.showAuthenticationMessage(
        editing ? 'Topic 已保存' : 'Topic 已发布',
        editing
          ? '标题和首个 Post 已更新'
          : (model.topicComposerState.message === 'Topic 已发布'
            ? '已发布到 Category #111'
            : model.topicComposerState.message)
      );
      if (!editing) {
        this.refreshHome();
      }
    }
  }

  private async loginForTopicComposer(): Promise<void> {
    await this.openLogin();
  }

  private handleTopicComposerBack(): boolean {
    const model: AppShellModel | null = this.model;
    if (model !== null && !model.topicComposerState.isBusy()) {
      model.dismissTopicComposer();
      this.topicComposerState = model.topicComposerState;
    }
    return false;
  }

  private async loginForReply(): Promise<void> {
    this.replySheetVisible = false;
    await this.openLogin();
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
    if (this.replyState.kind === ReplyComposerStateKind.REAUTHENTICATE) {
      this.replySheetVisible = true;
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
          onLoadMore: (): void => {
            this.loadMoreCategoryTopics();
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
    } else if (name === SEARCH_ROUTE) {
      HdsNavDestination() {
        SearchPage({
          state: this.searchState,
          knownCategories: this.categoryState.items,
          onSearch: (query: string): void => {
            this.searchForum(query);
          },
          onRetry: (): void => {
            this.retrySearch();
          },
          onLoadMore: (): void => {
            this.loadMoreSearch();
          },
          onOpenTopic: (topic: Topic): void => {
            this.openTopic(topic);
          },
          onOpenPost: (post: SearchPost): void => {
            this.openTopic(post.topic, post.postNumber);
          },
          onOpenCategory: (category: Category): void => {
            this.openCategory(category);
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: '搜索论坛' },
          backIcon: { label: '返回首页' }
        }
      })
      .onBackPressed((): boolean => this.handleSecondaryBack())
    } else if (name === TOPIC_ROUTE) {
      HdsNavDestination() {
        TopicDetailPage({
          state: this.topicState,
          bookmarkedPostIds: $bookmarkedPostIds,
          lastReadPostNumber: $lastReadPostNumber,
          readProgressBusy: $readProgressBusy,
          readProgressMessage: $readProgressMessage,
          replyState: this.replyState,
          mediaState: this.composerMediaState,
          categories: this.categoryState.items,
          replySheetVisible: this.replySheetVisible,
          onRetry: (): void => {
            this.retryTopic();
          },
          onLoadMore: (): void => {
            this.loadMorePosts();
          },
          onLoadPrevious: (): void => {
            this.loadPreviousPosts();
          },
          onToggleReaction: (postId: number, reaction: string): void => {
            this.togglePostReaction(postId, reaction);
          },
          onToggleBookmark: (postId: number): void => {
            this.togglePostBookmark(postId);
          },
          onOpenSuggestedTopic: (topic: Topic): void => {
            this.openTopic(topic);
          },
          onOpenRichLink: (url: string): void => {
            this.handleRichLink(url);
          },
          onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string): void => {
            this.openRichEmbed(url, provider, title);
          },
          onOpenImage: (url: string, title: string): void => {
            this.openImageViewer(url, title);
          },
          onReadProgress: (postNumber: number): void => {
            this.reportTopicReadProgress(postNumber);
          },
          onOpenReply: (postNumber: number | null): void => {
            this.openReply(postNumber);
          },
          onOpenEdit: (postId: number): void => {
            this.openPostEditor(postId);
          },
          onReplyDraftChange: (draft: string): void => {
            this.updateReplyDraft(draft);
          },
          onSubmitReply: (): void => {
            this.submitReply();
          },
          onSaveReplyDraft: (): void => {
            this.saveReplyDraft();
          },
          onDiscardReplyDraft: (): void => {
            this.discardReplyDraft();
          },
          onDismissReply: (): void => {
            this.dismissReply();
          },
          onLoginForReply: (): void => {
            this.loginForReply();
          },
          onSelectMedia: (): void => {
            this.selectComposerImages();
          },
          onCancelMedia: (): void => {
            this.cancelComposerImageUpload();
          },
          onRetryMedia: (): void => {
            this.retryComposerImageUpload();
          },
          onRemoveMedia: (): void => {
            this.removeComposerImageState();
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
    } else if (name === USER_PROFILE_ROUTE) {
      HdsNavDestination() {
        UserProfileSummaryPage({
          username: this.profileUsername,
          profile: this.profileUser,
          loading: this.profileLoading,
          errorMessage: this.profileError,
          onRetry: (): void => {
            this.loadSelectedUserProfile();
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: 'Profile' },
          backIcon: { label: '返回 Topic' }
        }
      })
      .onBackPressed((): boolean => false)
    } else if (name === RICH_EMBED_ROUTE) {
      HdsNavDestination() {
        SecureRichEmbedPage({
          url: this.richEmbedUrl,
          title: this.richEmbedTitle,
          provider: this.richEmbedProvider,
          controller: this.richEmbedController,
          onRequestExternalOpen: (url: string): void => this.confirmExternalNavigation(url)
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: this.richEmbedTitle },
          backIcon: { label: '返回 Topic' }
        }
      })
      .onBackPressed((): boolean => this.handleRichEmbedBack())
    } else if (name === IMAGE_VIEWER_ROUTE) {
      HdsNavDestination() {
        ImageViewerPage({
          state: this.imageViewerState,
          onCopyUrl: (): void => {
            this.copyViewerImageUrl();
          },
          onOpenExternally: (): void => {
            this.openExternalLink(this.imageViewerState.remoteUrl);
          },
          onSaveAuthorized: (): void => {
            this.saveViewerImage();
          },
          onSaveAuthorizationFailure: (): void => {
            this.showAuthenticationMessage('未保存图片', '系统未授予本次保存授权');
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: { mainTitle: this.imageViewerState.title.length > 0 ? this.imageViewerState.title : '查看原图' },
          backIcon: { label: '返回 Topic' }
        }
      })
      .onBackPressed((): boolean => false)
    } else if (name === TOPIC_COMPOSER_ROUTE) {
      HdsNavDestination() {
        ForumComposer({
          presentation: this.topicComposerPresentation(),
          onTitleChange: (title: string): void => {
            this.updateTopicTitle(title);
          },
          onBodyChange: (raw: string): void => {
            this.updateTopicRaw(raw);
          },
          onSubmit: (): void => {
            this.submitTopicComposer();
          },
          onSaveDraft: (): void => {
            this.saveTopicDraft();
          },
          onDiscard: (): void => {
            this.discardTopicDraft();
          },
          onReauthenticate: (): void => {
            this.loginForTopicComposer();
          },
          onSelectMedia: (): void => {
            this.selectComposerImages();
          },
          onCancelMedia: (): void => {
            this.cancelComposerImageUpload();
          },
          onRetryMedia: (): void => {
            this.retryComposerImageUpload();
          },
          onRemoveMedia: (): void => {
            this.removeComposerImageState();
          }
        })
      }
      .titleBar({
        enableComponentSafeArea: true,
        content: {
          title: {
            mainTitle: this.model?.topicEditingTopicId === null ? '发布新 Topic' : '编辑 Topic'
          },
          backIcon: { label: '返回' }
        }
      })
      .onBackPressed((): boolean => this.handleTopicComposerBack())
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
        this.replyState.kind !== ReplyComposerStateKind.ERROR &&
        this.replyState.kind !== ReplyComposerStateKind.REAUTHENTICATE)
    ) {
      return;
    }
    this.snackBar.show(
      { icon: this.replyState.kind === ReplyComposerStateKind.SUCCESS
        ? $r('sys.symbol.checkmark_circle')
        : $r('sys.symbol.exclamationmark_circle') },
      {
        title: this.replyState.kind === ReplyComposerStateKind.SUCCESS
          ? 'Reply 已发布'
          : this.replyState.kind === ReplyComposerStateKind.REAUTHENTICATE
            ? '需要重新登录'
            : 'Reply 未发布',
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
            selectedChannel: this.selectedHomeChannel,
            worldCupEntryEnabled: this.worldCupEntryEnabled,
            newTopicAvailable: this.canCreateAuthoringTopic(),
            onRetry: (): void => {
              this.loadHome();
            },
            onRefresh: (): void => {
              this.refreshHome();
            },
            onLoadMore: (): void => {
              this.loadMoreHome();
            },
            onOpenTopic: (topic: Topic): void => {
              this.openTopic(topic);
            },
            onOpenSearch: (): void => {
              this.openSearch();
            },
            onOpenNewTopic: (): void => {
              this.openNewTopic();
            },
            onSelectChannel: (index: number): void => {
              this.selectHomeChannel(index);
            },
            onWorldCupEntryChange: (enabled: boolean): void => {
              this.setWorldCupEntryEnabled(enabled);
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
            identity: this.accountIdentity,
            identityLoading: this.accountIdentityLoading,
            identityError: this.accountIdentityError,
            onLogin: (): void => {
              this.openLogin();
            },
            onLogout: (): void => {
              this.logout();
            },
            onRetryIdentity: (): void => {
              this.refreshAccountIdentity();
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
