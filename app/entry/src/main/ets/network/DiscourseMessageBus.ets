import { JsonObjectReader } from '../core/JsonObjectReader';
import { HttpTextResult, MessageBusHttpClient } from './DiscourseHttpClient';

export class MessageBusSubscription {
  public readonly channel: string;
  public readonly lastMessageId: number;

  public constructor(channel: string, lastMessageId: number = -1) {
    this.channel = channel;
    this.lastMessageId = Number.isSafeInteger(lastMessageId) ? lastMessageId : -1;
  }
}

export class MessageBusEvent {
  public readonly channel: string;
  public readonly messageId: number;
  public readonly globalId: number;
  public readonly data: JsonObjectReader;

  public constructor(channel: string, messageId: number, globalId: number, data: JsonObjectReader) {
    this.channel = channel;
    this.messageId = messageId;
    this.globalId = globalId;
    this.data = data;
  }
}

export class MessageBusPollResult {
  public readonly events: Array<MessageBusEvent>;
  public readonly failureMessage: string;

  private constructor(events: Array<MessageBusEvent>, failureMessage: string) {
    this.events = events;
    this.failureMessage = failureMessage;
  }

  public static success(events: Array<MessageBusEvent>): MessageBusPollResult {
    return new MessageBusPollResult(events, '');
  }

  public static failure(message: string): MessageBusPollResult {
    return new MessageBusPollResult([], message);
  }

  public isSuccess(): boolean {
    return this.failureMessage.length === 0;
  }
}

export class MessageBusResponseParser {
  public parse(text: string): MessageBusPollResult {
    const values: Array<Object | null> | null = JsonObjectReader.parseArray(text);
    if (values === null) {
      return MessageBusPollResult.failure('MessageBus 响应格式无效');
    }
    const events: Array<MessageBusEvent> = [];
    for (const value of values) {
      const event: JsonObjectReader | null = JsonObjectReader.fromValue(value);
      const data: JsonObjectReader | null = event?.object('data') ?? null;
      const channel: string | null = event?.string('channel') ?? null;
      const messageId: number | null = event?.number('message_id') ?? null;
      const globalId: number | null = event?.number('global_id') ?? null;
      if (
        data === null ||
        channel === null ||
        messageId === null ||
        globalId === null ||
        !Number.isSafeInteger(messageId) ||
        !Number.isSafeInteger(globalId)
      ) {
        return MessageBusPollResult.failure('MessageBus 响应缺少事件字段');
      }
      events.push(new MessageBusEvent(channel, messageId, globalId, data));
    }
    return MessageBusPollResult.success(events);
  }
}

export class DiscourseMessageBusClient {
  private readonly httpClient: MessageBusHttpClient;
  private readonly parser: MessageBusResponseParser;

  public constructor(
    httpClient: MessageBusHttpClient,
    parser: MessageBusResponseParser = new MessageBusResponseParser()
  ) {
    this.httpClient = httpClient;
    this.parser = parser;
  }

  public async poll(
    clientId: string,
    sequence: number,
    subscriptions: Array<MessageBusSubscription>
  ): Promise<MessageBusPollResult> {
    if (clientId.trim().length === 0 || !Number.isSafeInteger(sequence) || sequence < 0) {
      return MessageBusPollResult.failure('MessageBus 请求参数无效');
    }
    const fields: Array<string> = [];
    for (const subscription of subscriptions) {
      fields.push(`${encodeURIComponent(subscription.channel)}=${subscription.lastMessageId}`);
    }
    fields.push(`__seq=${sequence}`);
    const response: HttpTextResult = await this.httpClient.postMessageBus(
      `/message-bus/${encodeURIComponent(clientId)}/poll`,
      fields.join('&')
    );
    if (!response.isSuccess()) {
      return MessageBusPollResult.failure(response.message);
    }
    return this.parser.parse(response.body);
  }
}
