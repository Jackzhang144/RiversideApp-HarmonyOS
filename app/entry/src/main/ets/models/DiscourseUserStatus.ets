import { RIVERSIDE_URL_RESOLVER } from '../core/RiversideEnvironment';

const USER_STATUS_EMOJI_PATTERN: RegExp = /^[A-Za-z0-9_+\-]+$/;

export class DiscourseUserStatus {
  public readonly description: string;
  public readonly emoji: string;
  public readonly endsAt: string | null;

  private constructor(description: string, emoji: string, endsAt: string | null) {
    this.description = description;
    this.emoji = emoji;
    this.endsAt = endsAt;
  }

  public static create(
    description: string,
    emoji: string,
    endsAt: string | null,
    nowMs: number = Date.now()
  ): DiscourseUserStatus | null {
    const normalizedDescription: string = description.trim();
    if (normalizedDescription.length === 0) {
      return null;
    }
    const normalizedEndsAt: string = endsAt?.trim() ?? '';
    if (normalizedEndsAt.length > 0) {
      const expiryMs: number = Date.parse(normalizedEndsAt);
      if (!Number.isFinite(expiryMs) || expiryMs <= nowMs) {
        return null;
      }
    }
    const normalizedEmoji: string = emoji.trim().replace(/^:+|:+$/g, '');
    return new DiscourseUserStatus(
      normalizedDescription,
      USER_STATUS_EMOJI_PATTERN.test(normalizedEmoji) ? normalizedEmoji : '',
      normalizedEndsAt.length > 0 ? normalizedEndsAt : null
    );
  }

  public emojiUrl(): string {
    return this.emoji.length > 0
      ? RIVERSIDE_URL_RESOLVER.reactionEmoji(this.emoji)
      : '';
  }
}
