import { common } from '@kit.AbilityKit';
import { AuthenticatedSession } from '../auth/AuthModels';
import { AuthRepository } from '../auth/AuthRepository';
import { HuksAuthenticatedSessionStore } from '../auth/HuksAuthenticatedSessionStore';
import { RepositoryAuthenticationLifecycle } from '../auth/RepositoryAuthenticationLifecycle';
import { RsaAuthorizationCryptoFactory } from '../auth/RsaAuthorizationCrypto';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { AbilityContextRegistry } from '../core/AbilityContextRegistry';
import { MediaGalleryService } from '../media/MediaGalleryService';
import { AppLogger, DiagnosticLogStore } from '../logging/DiagnosticLogStore';
import { AuthenticatedSessionProvider, DiscourseHttpClient } from '../network/DiscourseHttpClient';
import {
  BilibiliShortLinkResolver,
  RcpBilibiliRedirectReader
} from '../network/BilibiliShortLinkResolver';
import { NetworkStatusMonitor, SystemNetworkStatusMonitor } from '../network/NetworkStatusMonitor';
import { DiscourseMediaTransport } from '../network/ForumMediaTransport';
import { DiscourseChatRepository } from '../repositories/DiscourseChatRepository';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';
import { DiscourseNotificationRepository } from '../repositories/DiscourseNotificationRepository';
import { DiscourseProfileRepository } from '../repositories/DiscourseProfileRepository';
import { DiscourseMediaRepository } from '../repositories/MediaRepository';
import { PreferencesAppThemeSettingsStore } from '../settings/PreferencesAppThemeSettingsStore';
import { PreferencesAppBehaviorSettingsStore } from '../settings/PreferencesAppBehaviorSettingsStore';
import { PreferencesDiscoverySettingsStore } from '../settings/PreferencesDiscoverySettingsStore';
import { RIVERSIDE_ORIGIN } from '../core/RiversideEnvironment';
import { AppCacheManager } from '../storage/AppCacheManager';
import { DiscoursePresenceUpdater, PresenceHeartbeat } from './PresenceHeartbeat';

class RepositorySessionProvider implements AuthenticatedSessionProvider {
  private readonly repository: AuthRepository;

  public constructor(repository: AuthRepository) {
    this.repository = repository;
  }

  public currentSession(): AuthenticatedSession | null {
    return this.repository.currentSession();
  }
}

export class AppDependencyGraph {
  public readonly authRepository: AuthRepository;
  public readonly authenticationLifecycle: RepositoryAuthenticationLifecycle;
  public readonly forumRepository: DiscourseForumRepository;
  public readonly chatRepository: DiscourseChatRepository;
  public readonly notificationRepository: DiscourseNotificationRepository;
  public readonly profileRepository: DiscourseProfileRepository;
  public readonly mediaRepository: DiscourseMediaRepository;
  public readonly categoryCache: PreferencesCategoryCache;
  public readonly discoverySettingsStore: PreferencesDiscoverySettingsStore;
  public readonly appThemeSettingsStore: PreferencesAppThemeSettingsStore;
  public readonly appBehaviorSettingsStore: PreferencesAppBehaviorSettingsStore;
  public readonly mediaGalleryService: MediaGalleryService | null;
  public readonly cacheManager: AppCacheManager;
  public readonly presenceHeartbeat: PresenceHeartbeat;
  public readonly networkStatusMonitor: NetworkStatusMonitor;
  public readonly bilibiliShortLinkResolver: BilibiliShortLinkResolver;

  public constructor(context: common.Context, onAuthenticationChanged: () => void) {
    const diagnosticLogStore: DiagnosticLogStore = AppLogger.initialize(context);
    this.appThemeSettingsStore = new PreferencesAppThemeSettingsStore(context);
    this.appBehaviorSettingsStore = new PreferencesAppBehaviorSettingsStore(context);
    this.authRepository = new AuthRepository(
      HuksAuthenticatedSessionStore.create(context),
      new RsaAuthorizationCryptoFactory()
    );
    const sessionProvider: RepositorySessionProvider = new RepositorySessionProvider(this.authRepository);
    this.authenticationLifecycle = new RepositoryAuthenticationLifecycle(
      this.authRepository,
      onAuthenticationChanged
    );
    this.networkStatusMonitor = new SystemNetworkStatusMonitor();
    const httpClient: DiscourseHttpClient = new DiscourseHttpClient(
      RIVERSIDE_ORIGIN,
      sessionProvider,
      this.networkStatusMonitor
    );
    this.bilibiliShortLinkResolver = new BilibiliShortLinkResolver(
      new RcpBilibiliRedirectReader()
    );
    this.forumRepository = new DiscourseForumRepository(httpClient);
    this.chatRepository = new DiscourseChatRepository(httpClient);
    this.notificationRepository = new DiscourseNotificationRepository(httpClient);
    this.profileRepository = new DiscourseProfileRepository(httpClient);
    this.mediaRepository = new DiscourseMediaRepository(
      new DiscourseMediaTransport(RIVERSIDE_ORIGIN, sessionProvider)
    );
    this.categoryCache = new PreferencesCategoryCache(context);
    this.cacheManager = new AppCacheManager(context, this.categoryCache, diagnosticLogStore);
    this.discoverySettingsStore = new PreferencesDiscoverySettingsStore(context);
    const abilityContext: common.UIAbilityContext | null = AbilityContextRegistry.current();
    this.mediaGalleryService = abilityContext === null
      ? null
      : new MediaGalleryService(abilityContext, sessionProvider);
    this.presenceHeartbeat = new PresenceHeartbeat(
      new DiscoursePresenceUpdater(
        httpClient,
        (): string | null => sessionProvider.currentSession()?.clientId ?? null
      ),
      this.authenticationLifecycle
    );
  }
}
