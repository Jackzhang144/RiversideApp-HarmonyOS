export const RIVERSIDE_HOST: string = 'river-side.cc';
export const RIVERSIDE_ORIGIN: string = `https://${RIVERSIDE_HOST}`;
export const RIVERSIDE_AUTHORIZATION_ENDPOINT: string = `${RIVERSIDE_ORIGIN}/user-api-key/new`;
export const RIVERSIDE_ABOUT_URL: string = `${RIVERSIDE_ORIGIN}/about`;
export const RIVERSIDE_REACTION_EMOJI_BASE_URL: string = `${RIVERSIDE_ORIGIN}/images/emoji/twitter`;

export const RIVERSIDE_WHISPER_HOST: string = `whisper.${RIVERSIDE_HOST}`;
export const RIVERSIDE_REVIEW_HOST: string = `review.${RIVERSIDE_HOST}`;
export const RIVERSIDE_MAP_HOST: string = `map.${RIVERSIDE_HOST}`;
export const RIVERSIDE_FOOD_HOST: string = `food.${RIVERSIDE_HOST}`;
export const RIVERSIDE_RSDATE_HOST: string = `rsdate.${RIVERSIDE_HOST}`;

export const RIVERSIDE_WHISPER_HOME_URL: string = `https://${RIVERSIDE_WHISPER_HOST}/`;
export const RIVERSIDE_WHISPER_ENTRY_URL: string = `${RIVERSIDE_WHISPER_HOME_URL}auth/start?mode=interactive`;
export const RIVERSIDE_REVIEW_HOME_URL: string = `https://${RIVERSIDE_REVIEW_HOST}/`;
export const RIVERSIDE_REVIEW_ENTRY_URL: string = `${RIVERSIDE_REVIEW_HOME_URL}auth/start?mode=interactive`;
export const RIVERSIDE_MAP_HOME_URL: string = `https://${RIVERSIDE_MAP_HOST}/`;
export const RIVERSIDE_MAP_ENTRY_URL: string = `${RIVERSIDE_MAP_HOME_URL}auth/start?mode=interactive`;
export const RIVERSIDE_FOOD_HOME_URL: string = `https://${RIVERSIDE_FOOD_HOST}/`;
export const RIVERSIDE_FOOD_ENTRY_URL: string = `${RIVERSIDE_FOOD_HOME_URL}auth/discourse`;
export const RIVERSIDE_RSDATE_HOME_URL: string = `https://${RIVERSIDE_RSDATE_HOST}/`;
export const RIVERSIDE_RSDATE_ENTRY_URL: string = `${RIVERSIDE_RSDATE_HOME_URL}auth/start?mode=interactive`;

export class RiversideUrlResolver {
  private readonly origin: string;

  public constructor(origin: string = RIVERSIDE_ORIGIN) {
    const normalizedOrigin: string = origin.trim();
    this.origin = normalizedOrigin.endsWith('/')
      ? normalizedOrigin.substring(0, normalizedOrigin.length - 1)
      : normalizedOrigin;
  }

  public absolute(value: string): string {
    const normalized: string = value.trim();
    if (normalized.length === 0) {
      return '';
    }
    if (normalized.startsWith('https://') || normalized.startsWith('http://')) {
      return normalized;
    }
    return normalized.startsWith('/')
      ? `${this.origin}${normalized}`
      : `${this.origin}/${normalized}`;
  }

  public richContent(value: string): string {
    const normalized: string = value.trim();
    if (normalized.startsWith('//')) {
      return `https:${normalized}`;
    }
    if (normalized.startsWith('/')) {
      return `${this.origin}${normalized}`;
    }
    if (/^https:\/\//i.test(normalized)) {
      return `https://${normalized.slice(8)}`;
    }
    return normalized;
  }

  public chat(value: string): string {
    const normalized: string = value.trim();
    if (normalized.startsWith('upload://')) {
      const shortPath: string = normalized.substring('upload://'.length).replace(/\s/g, '');
      return shortPath.length === 0 ? '' : `${this.origin}/uploads/short-url/${shortPath}`;
    }
    if (normalized.startsWith('//')) {
      return `https:${normalized}`;
    }
    if (normalized.startsWith('/')) {
      return `${this.origin}${normalized}`;
    }
    return normalized;
  }

  public avatar(value: string, size: number, allowHttp: boolean = true, requireRootPath: boolean = false): string {
    const normalized: string = value.trim().replace('{size}', size.toString());
    if (normalized.length === 0 || normalized.startsWith('https://')) {
      return normalized;
    }
    if (allowHttp && normalized.startsWith('http://')) {
      return normalized;
    }
    if (requireRootPath && !normalized.startsWith('/')) {
      return '';
    }
    return normalized.startsWith('/')
      ? `${this.origin}${normalized}`
      : `${this.origin}/${normalized}`;
  }

  public topicPost(topicId: number, postNumber: number): string {
    if (!Number.isInteger(topicId) || topicId <= 0 ||
      !Number.isInteger(postNumber) || postNumber <= 0) {
      return '';
    }
    return `${this.origin}/t/${topicId}/${postNumber}`;
  }

  public chatMessage(channelId: number, channelSlug: string, messageId: number): string {
    if (!Number.isSafeInteger(channelId) || channelId <= 0 ||
      !Number.isSafeInteger(messageId) || messageId <= 0) {
      return '';
    }
    const normalizedSlug: string = channelSlug.trim();
    const routeSlug: string = normalizedSlug.length > 0 ? normalizedSlug : channelId.toString();
    return `${this.origin}/chat/c/${routeSlug}/${channelId}/${messageId}`;
  }

  public reactionEmoji(name: string): string {
    return `${this.origin}/images/emoji/twitter/${name}.png?v=15`;
  }
}

export const RIVERSIDE_URL_RESOLVER: RiversideUrlResolver = new RiversideUrlResolver();
