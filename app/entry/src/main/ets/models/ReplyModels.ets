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
