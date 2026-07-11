import { ForumPost } from './ForumModels';

export class CurrentUser {
  public readonly id: number;
  public readonly username: string;

  private constructor(id: number, username: string) {
    this.id = id;
    this.username = username;
  }

  public static create(id: number, username: string): CurrentUser | null {
    const normalizedUsername: string = username.trim();
    if (!Number.isInteger(id) || id <= 0 || normalizedUsername.length === 0) {
      return null;
    }
    return new CurrentUser(id, normalizedUsername);
  }
}

export class ReplyRequest {
  public readonly topicId: number;
  public readonly raw: string;
  public readonly replyToPostNumber: number | null;

  private constructor(topicId: number, raw: string, replyToPostNumber: number | null) {
    this.topicId = topicId;
    this.raw = raw;
    this.replyToPostNumber = replyToPostNumber;
  }

  public static create(topicId: number, raw: string, replyToPostNumber: number | null): ReplyRequest | null {
    if (!Number.isInteger(topicId) || topicId <= 0) {
      return null;
    }
    const normalizedRaw: string = raw.trim();
    if (normalizedRaw.length === 0) {
      return null;
    }
    if (
      replyToPostNumber !== null &&
      (!Number.isInteger(replyToPostNumber) || replyToPostNumber <= 0)
    ) {
      return null;
    }
    return new ReplyRequest(topicId, normalizedRaw, replyToPostNumber);
  }
}

export enum ReplySubmitKind {
  CREATED = 'created',
  UNAUTHORIZED = 'unauthorized',
  REJECTED = 'rejected',
  UNCERTAIN = 'uncertain'
}

export class ReplySubmitResult {
  public readonly kind: ReplySubmitKind;
  public readonly post: ForumPost | null;
  public readonly message: string;

  private constructor(kind: ReplySubmitKind, post: ForumPost | null, message: string) {
    this.kind = kind;
    this.post = post;
    this.message = message;
  }

  public static created(post: ForumPost): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.CREATED, post, '');
  }

  public static unauthorized(): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.UNAUTHORIZED, null, '登录已失效');
  }

  public static rejected(message: string): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.REJECTED, null, message);
  }

  public static uncertain(message: string): ReplySubmitResult {
    return new ReplySubmitResult(ReplySubmitKind.UNCERTAIN, null, message);
  }
}
