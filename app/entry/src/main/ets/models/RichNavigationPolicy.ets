import {
  RIVERSIDE_FOOD_HOST,
  RIVERSIDE_HOST,
  RIVERSIDE_MAP_HOST,
  RIVERSIDE_REVIEW_HOST,
  RIVERSIDE_RSDATE_HOST,
  RIVERSIDE_URL_RESOLVER,
  RIVERSIDE_WHISPER_HOST
} from '../core/RiversideEnvironment';

export const BILIBILI_URL_TRUST_LIST: string = '{"UrlPermissionList":[' +
  `{"scheme":"https","host":"${RIVERSIDE_HOST}"},` +
  '{"scheme":"https","host":"player.bilibili.com"},' +
  '{"scheme":"https","host":"www.bilibili.com","path":"blackboard/webplayer"}' +
  ']}';

export const YOUTUBE_URL_TRUST_LIST: string = '{"UrlPermissionList":[' +
  `{"scheme":"https","host":"${RIVERSIDE_HOST}"},` +
  '{"scheme":"https","host":"www.youtube.com","path":"embed"},' +
  '{"scheme":"https","host":"www.youtube-nocookie.com","path":"embed"}' +
  ']}';

export enum RichEmbedProvider {
  NONE = 'none',
  BILIBILI = 'bilibili',
  YOUTUBE = 'youtube',
  WHISPER = 'whisper',
  REVIEW = 'review',
  MAP = 'map',
  FOOD = 'food',
  RSDATE = 'rsdate'
}

export enum RichNavigationKind {
  TOPIC = 'topic',
  PROFILE = 'profile',
  EXTERNAL = 'external',
  BLOCKED = 'blocked'
}

export class RichNavigationTarget {
  public readonly kind: RichNavigationKind;
  public readonly url: string;
  public readonly topicId: number;
  public readonly postNumber: number | null;
  public readonly username: string;

  private constructor(
    kind: RichNavigationKind,
    url: string,
    topicId: number = 0,
    postNumber: number | null = null,
    username: string = ''
  ) {
    this.kind = kind;
    this.url = url;
    this.topicId = topicId;
    this.postNumber = postNumber;
    this.username = username;
  }

  public static topic(url: string, topicId: number, postNumber: number | null): RichNavigationTarget {
    return new RichNavigationTarget(RichNavigationKind.TOPIC, url, topicId, postNumber);
  }

  public static profile(url: string, username: string): RichNavigationTarget {
    return new RichNavigationTarget(RichNavigationKind.PROFILE, url, 0, null, username);
  }

  public static external(url: string): RichNavigationTarget {
    return new RichNavigationTarget(RichNavigationKind.EXTERNAL, url);
  }

  public static blocked(url: string): RichNavigationTarget {
    return new RichNavigationTarget(RichNavigationKind.BLOCKED, url);
  }
}

function firstCapture(text: string, pattern: RegExp, group: number = 1): string {
  const match: RegExpExecArray | null = pattern.exec(text);
  return match === null || match[group] === undefined ? '' : match[group];
}

function absoluteUrl(raw: string): string {
  return RIVERSIDE_URL_RESOLVER.richContent(raw.trim());
}

function urlHost(url: string): string {
  return firstCapture(url, /^https:\/\/([^\/?#]+)(?:[\/?#]|$)/i).toLowerCase();
}

function urlPath(url: string): string {
  const path: string = firstCapture(url, /^https:\/\/[^\/?#]+([^?#]*)/i);
  return path.length > 0 ? path : '/';
}

export function classifyRichNavigation(rawUrl: string): RichNavigationTarget {
  const url: string = absoluteUrl(rawUrl);
  if (/^mailto:[^\s@]+@[^\s@]+$/i.test(url) || /^tel:\+?[0-9 ()-]+$/i.test(url)) {
    return RichNavigationTarget.external(url);
  }
  if (!/^https:\/\//i.test(url)) {
    return RichNavigationTarget.blocked(url);
  }
  if (urlHost(url) !== RIVERSIDE_HOST) {
    return RichNavigationTarget.external(url);
  }
  const path: string = urlPath(url);
  const profileSegment: string = firstCapture(path, /^\/u\/([^\/?#]+)/i);
  if (profileSegment.length > 0) {
    try {
      const username: string = decodeURIComponent(profileSegment).trim();
      return username.length > 0
        ? RichNavigationTarget.profile(url, username)
        : RichNavigationTarget.blocked(url);
    } catch (_) {
      return RichNavigationTarget.blocked(url);
    }
  }
  const topicMatch: RegExpExecArray | null = /^\/t\/(?:[^/]*[^\d/][^/]*\/)?(\d+)(?:\/(\d+))?(?:\/|$)/i.exec(path);
  if (topicMatch !== null) {
    const topicId: number = Number.parseInt(topicMatch[1], 10);
    const postNumber: number | null = topicMatch[2] === undefined ? null : Number.parseInt(topicMatch[2], 10);
    if (Number.isInteger(topicId) && topicId > 0 &&
      (postNumber === null || (Number.isInteger(postNumber) && postNumber > 0))) {
      return RichNavigationTarget.topic(url, topicId, postNumber);
    }
  }
  return RichNavigationTarget.external(url);
}

export function isAllowedEmbedNavigation(provider: RichEmbedProvider, rawUrl: string): boolean {
  const url: string = absoluteUrl(rawUrl);
  if (!/^https:\/\//i.test(url)) {
    return false;
  }
  const host: string = urlHost(url);
  const path: string = urlPath(url);
  if (host === RIVERSIDE_HOST) {
    return true;
  }
  if (provider === RichEmbedProvider.BILIBILI) {
    return host === 'player.bilibili.com' && path === '/player.html' ||
      host === 'www.bilibili.com' && path.startsWith('/blackboard/webplayer/');
  }
  if (provider === RichEmbedProvider.YOUTUBE) {
    return (host === 'www.youtube.com' || host === 'www.youtube-nocookie.com') && path.startsWith('/embed/');
  }
  if (provider === RichEmbedProvider.WHISPER) {
    return host === RIVERSIDE_WHISPER_HOST;
  }
  if (provider === RichEmbedProvider.REVIEW) {
    return host === RIVERSIDE_REVIEW_HOST;
  }
  if (provider === RichEmbedProvider.MAP) {
    return host === RIVERSIDE_MAP_HOST;
  }
  if (provider === RichEmbedProvider.FOOD) {
    return host === RIVERSIDE_FOOD_HOST;
  }
  if (provider === RichEmbedProvider.RSDATE) {
    return host === RIVERSIDE_RSDATE_HOST;
  }
  return false;
}

export function embedTrustList(provider: RichEmbedProvider): string {
  if (provider === RichEmbedProvider.BILIBILI) {
    return BILIBILI_URL_TRUST_LIST;
  }
  if (provider === RichEmbedProvider.YOUTUBE) {
    return YOUTUBE_URL_TRUST_LIST;
  }
  let host: string = RIVERSIDE_HOST;
  if (provider === RichEmbedProvider.WHISPER) {
    host = RIVERSIDE_WHISPER_HOST;
  } else if (provider === RichEmbedProvider.REVIEW) {
    host = RIVERSIDE_REVIEW_HOST;
  } else if (provider === RichEmbedProvider.MAP) {
    host = RIVERSIDE_MAP_HOST;
  } else if (provider === RichEmbedProvider.FOOD) {
    host = RIVERSIDE_FOOD_HOST;
  } else if (provider === RichEmbedProvider.RSDATE) {
    host = RIVERSIDE_RSDATE_HOST;
  }
  return '{"UrlPermissionList":[' +
    `{"scheme":"https","host":"${RIVERSIDE_HOST}"},` +
    `{"scheme":"https","host":"${host}"}` +
    ']}';
}
