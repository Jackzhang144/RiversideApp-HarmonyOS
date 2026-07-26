import { hilog } from '@kit.PerformanceAnalysisKit';

const CHAT_CONVERSATION_POLL_INTERVAL_MILLISECONDS: number = 30000;
const CHAT_POLLING_LOG_DOMAIN: number = 0x0000;
const CHAT_POLLING_LOG_TAG: string = 'ChatPolling';

export interface ChatPollingTimer {
  setInterval(callback: () => Promise<void>, delayMilliseconds: number): number;
  clearInterval(handle: number): void;
}

export class SystemChatPollingTimer implements ChatPollingTimer {
  public setInterval(callback: () => Promise<void>, delayMilliseconds: number): number {
    return setInterval((): void => {
      callback().catch((error: Error): void => {
        hilog.error(
          CHAT_POLLING_LOG_DOMAIN,
          CHAT_POLLING_LOG_TAG,
          'Unexpected Chat polling failure: %{public}s',
          JSON.stringify(error)
        );
      });
    }, delayMilliseconds);
  }

  public clearInterval(handle: number): void {
    clearInterval(handle);
  }
}

export class ChatConversationPollingController {
  private readonly timer: ChatPollingTimer;
  private readonly refresh: () => Promise<void>;
  private foreground: boolean = false;
  private authenticated: boolean = false;
  private activeConversation: boolean = false;
  private networkAvailable: boolean = true;
  private destroyed: boolean = false;
  private refreshing: boolean = false;
  private intervalHandle: number | null = null;

  public constructor(timer: ChatPollingTimer, refresh: () => Promise<void>) {
    this.timer = timer;
    this.refresh = refresh;
  }

  public setForeground(foreground: boolean): void {
    this.foreground = foreground;
    this.reconcileTimer();
  }

  public setAuthenticated(authenticated: boolean): void {
    this.authenticated = authenticated;
    this.reconcileTimer();
  }

  public setActiveConversation(activeConversation: boolean): void {
    this.activeConversation = activeConversation;
    this.reconcileTimer();
  }

  public setNetworkAvailable(networkAvailable: boolean): void {
    this.networkAvailable = networkAvailable;
    this.reconcileTimer();
  }

  public destroy(): void {
    this.destroyed = true;
    this.stopTimer();
  }

  private reconcileTimer(): void {
    const shouldPoll: boolean = this.canPoll();
    if (shouldPoll && this.intervalHandle === null) {
      this.intervalHandle = this.timer.setInterval(async (): Promise<void> => {
        await this.poll();
      }, CHAT_CONVERSATION_POLL_INTERVAL_MILLISECONDS);
    } else if (!shouldPoll) {
      this.stopTimer();
    }
  }

  private canPoll(): boolean {
    return !this.destroyed &&
      this.foreground &&
      this.authenticated &&
      this.activeConversation &&
      this.networkAvailable;
  }

  private async poll(): Promise<void> {
    if (!this.canPoll() || this.refreshing) {
      return;
    }
    this.refreshing = true;
    try {
      await this.refresh();
    } catch (_) {
      hilog.error(
        CHAT_POLLING_LOG_DOMAIN,
        CHAT_POLLING_LOG_TAG,
        'Chat polling refresh failed unexpectedly'
      );
    } finally {
      this.refreshing = false;
    }
  }

  private stopTimer(): void {
    if (this.intervalHandle !== null) {
      this.timer.clearInterval(this.intervalHandle);
      this.intervalHandle = null;
    }
  }
}
