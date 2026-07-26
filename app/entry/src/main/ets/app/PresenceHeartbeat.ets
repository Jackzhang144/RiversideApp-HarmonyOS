import {
  HttpTextResult,
  HttpTextResultKind,
  PresenceHttpClient
} from '../network/DiscourseHttpClient';
import { AuthenticationLifecycle } from './AuthenticationLifecycle';

const PRESENCE_INTERVAL_MS: number = 28000;
const PRESENCE_UPDATE_PATH: string = '/presence/update.json';
const PRESENCE_CHANNEL: string = '/whos-online/online';

export function shouldRunPresenceHeartbeat(
  foreground: boolean,
  authenticated: boolean,
  networkAvailable: boolean
): boolean {
  return foreground && authenticated && networkAvailable;
}

export interface PresenceUpdater {
  updatePresence(): Promise<HttpTextResult>;
}

export interface PresenceScheduler {
  scheduleRepeating(callback: () => void, intervalMs: number): number;

  cancel(handle: number): void;
}

export class DiscoursePresenceUpdater implements PresenceUpdater {
  private readonly client: PresenceHttpClient;
  private readonly currentClientId: () => string | null;

  public constructor(client: PresenceHttpClient, currentClientId: () => string | null) {
    this.client = client;
    this.currentClientId = currentClientId;
  }

  public updatePresence(): Promise<HttpTextResult> {
    const clientId: string | null = this.currentClientId();
    if (clientId === null || clientId.length === 0) {
      return Promise.resolve(HttpTextResult.success(204, ''));
    }
    const body: string = `present_channels[]=${PRESENCE_CHANNEL}&client_id=${encodeURIComponent(clientId)}`;
    return this.client.postForm(PRESENCE_UPDATE_PATH, body);
  }
}

export class SystemPresenceScheduler implements PresenceScheduler {
  public scheduleRepeating(callback: () => void, intervalMs: number): number {
    return setInterval(callback, intervalMs);
  }

  public cancel(handle: number): void {
    clearInterval(handle);
  }
}

export class PresenceHeartbeat {
  private readonly updater: PresenceUpdater;
  private readonly authenticationLifecycle: AuthenticationLifecycle;
  private readonly scheduler: PresenceScheduler;
  private active: boolean = false;
  private requestInFlight: boolean = false;
  private generation: number = 0;
  private pendingGeneration: number | null = null;
  private timerHandle: number | null = null;

  public constructor(
    updater: PresenceUpdater,
    authenticationLifecycle: AuthenticationLifecycle,
    scheduler: PresenceScheduler = new SystemPresenceScheduler()
  ) {
    this.updater = updater;
    this.authenticationLifecycle = authenticationLifecycle;
    this.scheduler = scheduler;
  }

  public start(): void {
    if (this.active) {
      return;
    }
    this.active = true;
    this.generation += 1;
    const generation: number = this.generation;
    this.timerHandle = this.scheduler.scheduleRepeating((): void => {
      this.requestUpdate(generation);
    }, PRESENCE_INTERVAL_MS);
    this.requestUpdate(generation);
  }

  public stop(): void {
    this.active = false;
    this.generation += 1;
    this.pendingGeneration = null;
    const handle: number | null = this.timerHandle;
    this.timerHandle = null;
    if (handle !== null) {
      this.scheduler.cancel(handle);
    }
  }

  public dispose(): void {
    this.stop();
  }

  public isActive(): boolean {
    return this.active;
  }

  private requestUpdate(generation: number): void {
    if (!this.active || generation !== this.generation) {
      return;
    }
    if (this.requestInFlight) {
      this.pendingGeneration = generation;
      return;
    }
    this.requestInFlight = true;
    this.performUpdate(generation);
  }

  private async performUpdate(generation: number): Promise<void> {
    try {
      const result: HttpTextResult = await this.updater.updatePresence();
      if (!this.active || generation !== this.generation) {
        return;
      }
      if (result.kind === HttpTextResultKind.UNAUTHORIZED) {
        this.stop();
        await this.authenticationLifecycle.handleUnauthorized();
      }
    } catch (_) {
    } finally {
      this.requestInFlight = false;
      const pendingGeneration: number | null = this.pendingGeneration;
      this.pendingGeneration = null;
      if (pendingGeneration !== null) {
        this.requestUpdate(pendingGeneration);
      }
    }
  }
}
