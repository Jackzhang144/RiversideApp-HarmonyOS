import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  DiscourseMessageBusClient,
  MessageBusEvent,
  MessageBusPollResult,
  MessageBusSubscription
} from '../network/DiscourseMessageBus';

const LIVE_UPDATE_LOG_DOMAIN: number = 0x0000;
const LIVE_UPDATE_LOG_TAG: string = 'ForumLiveUpdate';
const MINIMUM_RETRY_DELAY_MILLISECONDS: number = 1000;
const MAXIMUM_RETRY_DELAY_MILLISECONDS: number = 30000;
const EMPTY_RESPONSE_DELAY_MILLISECONDS: number = 100;

export interface ForumLiveUpdateTimer {
  setTimeout(callback: () => Promise<void>, delayMilliseconds: number): number;
  clearTimeout(handle: number): void;
}

export class SystemForumLiveUpdateTimer implements ForumLiveUpdateTimer {
  public setTimeout(callback: () => Promise<void>, delayMilliseconds: number): number {
    return setTimeout((): void => {
      callback().catch((error: Error): void => {
        hilog.error(
          LIVE_UPDATE_LOG_DOMAIN,
          LIVE_UPDATE_LOG_TAG,
          'Unexpected MessageBus failure: %{public}s',
          JSON.stringify(error)
        );
      });
    }, delayMilliseconds);
  }

  public clearTimeout(handle: number): void {
    clearTimeout(handle);
  }
}

export type MessageBusClientIdProvider = () => string;
export type MessageBusSubscriptionsProvider = () => Array<MessageBusSubscription>;
export type MessageBusEventsHandler = (events: Array<MessageBusEvent>) => Promise<void>;

export class ForumLiveUpdateController {
  private readonly client: DiscourseMessageBusClient;
  private readonly timer: ForumLiveUpdateTimer;
  private readonly clientIdProvider: MessageBusClientIdProvider;
  private readonly subscriptionsProvider: MessageBusSubscriptionsProvider;
  private readonly handleEvents: MessageBusEventsHandler;
  private readonly channelCursors: Map<string, number> = new Map<string, number>();
  private foreground: boolean = false;
  private networkAvailable: boolean = true;
  private destroyed: boolean = false;
  private polling: boolean = false;
  private sequence: number = 0;
  private retryDelayMilliseconds: number = MINIMUM_RETRY_DELAY_MILLISECONDS;
  private timeoutHandle: number | null = null;

  public constructor(
    client: DiscourseMessageBusClient,
    timer: ForumLiveUpdateTimer,
    clientIdProvider: MessageBusClientIdProvider,
    subscriptionsProvider: MessageBusSubscriptionsProvider,
    handleEvents: MessageBusEventsHandler
  ) {
    this.client = client;
    this.timer = timer;
    this.clientIdProvider = clientIdProvider;
    this.subscriptionsProvider = subscriptionsProvider;
    this.handleEvents = handleEvents;
  }

  public setForeground(foreground: boolean): void {
    this.foreground = foreground;
    this.reconcilePolling();
  }

  public setNetworkAvailable(networkAvailable: boolean): void {
    this.networkAvailable = networkAvailable;
    this.reconcilePolling();
  }

  public subscriptionsChanged(): void {
    if (this.canPoll() && !this.polling && this.timeoutHandle === null) {
      this.schedulePoll(0);
    }
  }

  public destroy(): void {
    this.destroyed = true;
    this.stopScheduledPoll();
  }

  private canPoll(): boolean {
    return !this.destroyed && this.foreground && this.networkAvailable;
  }

  private reconcilePolling(): void {
    if (!this.canPoll()) {
      this.stopScheduledPoll();
      return;
    }
    if (!this.polling && this.timeoutHandle === null) {
      this.schedulePoll(0);
    }
  }

  private schedulePoll(delayMilliseconds: number): void {
    if (!this.canPoll() || this.timeoutHandle !== null) {
      return;
    }
    this.timeoutHandle = this.timer.setTimeout(async (): Promise<void> => {
      this.timeoutHandle = null;
      await this.poll();
    }, Math.max(0, delayMilliseconds));
  }

  private async poll(): Promise<void> {
    if (!this.canPoll() || this.polling) {
      return;
    }
    const subscriptions: Array<MessageBusSubscription> = this.currentSubscriptions();
    if (subscriptions.length === 0) {
      this.schedulePoll(MINIMUM_RETRY_DELAY_MILLISECONDS);
      return;
    }
    this.polling = true;
    const result: MessageBusPollResult = await this.client.poll(
      this.clientIdProvider(),
      this.sequence,
      subscriptions
    );
    this.sequence += 1;
    this.polling = false;
    if (!this.canPoll()) {
      return;
    }
    if (!result.isSuccess()) {
      this.schedulePoll(this.retryDelayMilliseconds);
      this.retryDelayMilliseconds = Math.min(
        MAXIMUM_RETRY_DELAY_MILLISECONDS,
        this.retryDelayMilliseconds * 2
      );
      return;
    }
    this.retryDelayMilliseconds = MINIMUM_RETRY_DELAY_MILLISECONDS;
    const userEvents: Array<MessageBusEvent> = this.recordCursors(result.events);
    if (userEvents.length > 0) {
      await this.handleEvents(userEvents);
    }
    this.schedulePoll(result.events.length === 0 ? EMPTY_RESPONSE_DELAY_MILLISECONDS : 0);
  }

  private currentSubscriptions(): Array<MessageBusSubscription> {
    const subscriptions: Array<MessageBusSubscription> = [];
    const channelNames: Set<string> = new Set<string>();
    for (const subscription of this.subscriptionsProvider()) {
      const channel: string = subscription.channel.trim();
      if (channel.length === 0 || channelNames.has(channel)) {
        continue;
      }
      channelNames.add(channel);
      const cursor: number = this.channelCursors.get(channel) ?? subscription.lastMessageId;
      subscriptions.push(new MessageBusSubscription(channel, cursor));
    }
    return subscriptions;
  }

  private recordCursors(events: Array<MessageBusEvent>): Array<MessageBusEvent> {
    const userEvents: Array<MessageBusEvent> = [];
    for (const event of events) {
      if (event.channel === '/__status') {
        for (const entry of event.data.entries()) {
          if (typeof entry[1] === 'number' && Number.isSafeInteger(entry[1])) {
            this.updateCursor(entry[0], entry[1]);
          }
        }
        continue;
      }
      this.updateCursor(event.channel, event.messageId);
      userEvents.push(event);
    }
    return userEvents;
  }

  private updateCursor(channel: string, messageId: number): void {
    const current: number = this.channelCursors.get(channel) ?? -1;
    if (messageId > current) {
      this.channelCursors.set(channel, messageId);
    }
  }

  private stopScheduledPoll(): void {
    if (this.timeoutHandle !== null) {
      this.timer.clearTimeout(this.timeoutHandle);
      this.timeoutHandle = null;
    }
  }
}
