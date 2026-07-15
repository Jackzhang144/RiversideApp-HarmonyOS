import { common } from '@kit.AbilityKit';
import { AuthenticatedSession } from '../auth/AuthModels';
import { AuthRepository } from '../auth/AuthRepository';
import { HuksAuthenticatedSessionStore } from '../auth/HuksAuthenticatedSessionStore';
import { RepositoryAuthenticationLifecycle } from '../auth/RepositoryAuthenticationLifecycle';
import { RsaAuthorizationCryptoFactory } from '../auth/RsaAuthorizationCrypto';
import { PreferencesCategoryCache } from '../cache/PreferencesCategoryCache';
import { AbilityContextRegistry } from '../core/AbilityContextRegistry';
import { MediaGalleryService } from '../media/MediaGalleryService';
import { AuthenticatedSessionProvider, DiscourseHttpClient } from '../network/DiscourseHttpClient';
import { DiscourseMediaTransport } from '../network/ForumMediaTransport';
import { DiscourseChatRepository } from '../repositories/DiscourseChatRepository';
import { DiscourseForumRepository } from '../repositories/DiscourseForumRepository';
import { DiscourseNotificationRepository } from '../repositories/DiscourseNotificationRepository';
import { DiscourseProfileRepository } from '../repositories/DiscourseProfileRepository';
import { DiscourseMediaRepository } from '../repositories/MediaRepository';
import { PreferencesAppThemeSettingsStore } from '../settings/PreferencesAppThemeSettingsStore';
import { PreferencesDiscoverySettingsStore } from '../settings/PreferencesDiscoverySettingsStore';
import { RIVERSIDE_ORIGIN } from '../core/RiversideEnvironment';
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
  public readonly mediaGalleryService: MediaGalleryService | null;
  public readonly presenceHeartbeat: PresenceHeartbeat;

  public constructor(context: common.Context, onAuthenticationChanged: () => void) {
    this.appThemeSettingsStore = new PreferencesAppThemeSettingsStore(context);
    this.authRepository = new AuthRepository(
      HuksAuthenticatedSessionStore.create(context),
      new RsaAuthorizationCryptoFactory()
    );
    const sessionProvider: RepositorySessionProvider = new RepositorySessionProvider(this.authRepository);
    this.authenticationLifecycle = new RepositoryAuthenticationLifecycle(
      this.authRepository,
      onAuthenticationChanged
    );
    const httpClient: DiscourseHttpClient = new DiscourseHttpClient(RIVERSIDE_ORIGIN, sessionProvider);
    this.forumRepository = new DiscourseForumRepository(httpClient);
    this.chatRepository = new DiscourseChatRepository(httpClient);
    this.notificationRepository = new DiscourseNotificationRepository(httpClient);
    this.profileRepository = new DiscourseProfileRepository(httpClient);
    this.mediaRepository = new DiscourseMediaRepository(
      new DiscourseMediaTransport(RIVERSIDE_ORIGIN, sessionProvider)
    );
    this.categoryCache = new PreferencesCategoryCache(context);
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
