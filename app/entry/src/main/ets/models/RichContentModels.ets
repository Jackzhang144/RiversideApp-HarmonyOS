const RIVERSIDE_ORIGIN: string = 'https://river-side.cc';

export const BILIBILI_URL_TRUST_LIST: string = '{"UrlPermissionList":[' +
  '{"scheme":"https","host":"river-side.cc"},' +
  '{"scheme":"https","host":"player.bilibili.com"},' +
  '{"scheme":"https","host":"www.bilibili.com","path":"blackboard/webplayer"}' +
  ']}';

export const YOUTUBE_URL_TRUST_LIST: string = '{"UrlPermissionList":[' +
  '{"scheme":"https","host":"river-side.cc"},' +
  '{"scheme":"https","host":"www.youtube.com","path":"embed"},' +
  '{"scheme":"https","host":"www.youtube-nocookie.com","path":"embed"}' +
  ']}';

export enum RichContentBlockKind {
  TEXT = 'text',
  HEADING = 'heading',
  QUOTE = 'quote',
  CODE = 'code',
  FORMULA = 'formula',
  SPOILER = 'spoiler',
  LIST = 'list',
  TABLE = 'table',
  IMAGE = 'image',
  ONEBOX = 'onebox',
  VIDEO = 'video'
}

export enum RichEmbedProvider {
  NONE = 'none',
  BILIBILI = 'bilibili',
  YOUTUBE = 'youtube'
}

export enum RichNavigationKind {
  TOPIC = 'topic',
  PROFILE = 'profile',
  EXTERNAL = 'external',
  BLOCKED = 'blocked'
}

export class RichContentLink {
  public readonly label: string;
  public readonly url: string;

  public constructor(label: string, url: string) {
    this.label = label;
    this.url = url;
  }
}

export class RichContentListItem {
  public readonly text: string;
  public readonly links: Array<RichContentLink>;

  public constructor(text: string, links: Array<RichContentLink> = []) {
    this.text = text;
    this.links = links;
  }
}

export class RichContentBlock {
  public readonly kind: RichContentBlockKind;
  public readonly text: string;
  public readonly title: string;
  public readonly url: string;
  public readonly level: number;
  public readonly ordered: boolean;
  public readonly listItems: Array<RichContentListItem>;
  public readonly rows: Array<Array<string>>;
  public readonly links: Array<RichContentLink>;
  public readonly embedProvider: RichEmbedProvider;

  private constructor(
    kind: RichContentBlockKind,
    text: string = '',
    title: string = '',
    url: string = '',
    level: number = 0,
    ordered: boolean = false,
    listItems: Array<RichContentListItem> = [],
    rows: Array<Array<string>> = [],
    links: Array<RichContentLink> = [],
    embedProvider: RichEmbedProvider = RichEmbedProvider.NONE
  ) {
    this.kind = kind;
    this.text = text;
    this.title = title;
    this.url = url;
    this.level = level;
    this.ordered = ordered;
    this.listItems = listItems;
    this.rows = rows;
    this.links = links;
    this.embedProvider = embedProvider;
  }

  public static textBlock(text: string, links: Array<RichContentLink> = []): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.TEXT, text, '', '', 0, false, [], [], links);
  }

  public static heading(text: string, level: number): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.HEADING, text, '', '', level);
  }

  public static quote(text: string, username: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.QUOTE, text, username);
  }

  public static code(text: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.CODE, text);
  }

  public static formula(text: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.FORMULA, text);
  }

  public static spoiler(text: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.SPOILER, text);
  }

  public static list(items: Array<RichContentListItem>, ordered: boolean): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.LIST, '', '', '', 0, ordered, items);
  }

  public static table(rows: Array<Array<string>>): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.TABLE, '', '', '', 0, false, [], rows);
  }

  public static image(url: string, description: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.IMAGE, '', description, url);
  }

  public static onebox(url: string, title: string, domain: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.ONEBOX, domain, title, url);
  }

  public static video(url: string, title: string, provider: RichEmbedProvider): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.VIDEO, '', title, url, 0, false, [], [], [], provider);
  }
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

function decodeEntities(text: string): string {
  return text
    .replace(/&nbsp;/gi, ' ')
    .replace(/&ndash;/gi, '–')
    .replace(/&mdash;/gi, '—')
    .replace(/&hellip;/gi, '...')
    .replace(/&quot;/gi, '"')
    .replace(/&apos;/gi, "'")
    .replace(/&#39;/gi, "'")
    .replace(/&lt;/gi, '<')
    .replace(/&gt;/gi, '>')
    .replace(/&amp;/gi, '&');
}

function stripHtml(text: string): string {
  return decodeEntities(text
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<br\s*\/?>/gi, '\n')
    .replace(/<\/p>/gi, '\n')
    .replace(/<\/div>/gi, '\n')
    .replace(/<[^>]+>/g, ''))
    .replace(/[ \t]+\n/g, '\n')
    .replace(/\n{3,}/g, '\n\n')
    .trim();
}

function absoluteUrl(raw: string): string {
  const value: string = decodeEntities(raw.trim());
  if (value.startsWith('//')) {
    return `https:${value}`;
  }
  if (value.startsWith('/')) {
    return `${RIVERSIDE_ORIGIN}${value}`;
  }
  if (/^https:\/\//i.test(value)) {
    return `https://${value.slice(8)}`;
  }
  return value;
}

function urlHost(url: string): string {
  return firstCapture(url, /^https:\/\/([^\/?#]+)(?:[\/?#]|$)/i).toLowerCase();
}

function urlPath(url: string): string {
  const path: string = firstCapture(url, /^https:\/\/[^\/?#]+([^?#]*)/i);
  return path.length > 0 ? path : '/';
}

function queryValue(url: string, name: string): string {
  const queryStart: number = url.indexOf('?');
  if (queryStart < 0) {
    return '';
  }
  const fragmentStart: number = url.indexOf('#', queryStart);
  const query: string = fragmentStart < 0
    ? url.slice(queryStart + 1)
    : url.slice(queryStart + 1, fragmentStart);
  const pairs: Array<string> = query.split('&');
  for (const pair of pairs) {
    const separator: number = pair.indexOf('=');
    const key: string = separator < 0 ? pair : pair.slice(0, separator);
    if (key === name) {
      const rawValue: string = separator < 0 ? '' : pair.slice(separator + 1);
      try {
        return decodeURIComponent(rawValue.replace(/\+/g, ' '));
      } catch (_) {
        return '';
      }
    }
  }
  return '';
}

function videoStartSeconds(url: string): number {
  const raw: string = queryValue(url, 'start').length > 0
    ? queryValue(url, 'start')
    : queryValue(url, 't');
  if (/^\d+$/.test(raw)) {
    return Number.parseInt(raw, 10);
  }
  const hours: string = firstCapture(raw, /(\d+)h/i);
  const minutes: string = firstCapture(raw, /(\d+)m/i);
  const seconds: string = firstCapture(raw, /(\d+)s/i);
  const total: number = (hours.length > 0 ? Number.parseInt(hours, 10) * 3600 : 0) +
    (minutes.length > 0 ? Number.parseInt(minutes, 10) * 60 : 0) +
    (seconds.length > 0 ? Number.parseInt(seconds, 10) : 0);
  return Number.isFinite(total) ? total : 0;
}

function bilibiliPlayerUrl(raw: string): string {
  const url: string = absoluteUrl(raw);
  const host: string = urlHost(url);
  const path: string = urlPath(url);
  if (host === 'player.bilibili.com' && path === '/player.html') {
    const hasId: boolean = ['bvid', 'aid', 'cid', 'ep_id']
      .some((name: string): boolean => queryValue(url, name).length > 0);
    return hasId ? url : '';
  }
  if (host !== 'bilibili.com' && !host.endsWith('.bilibili.com')) {
    return '';
  }
  const identifier: string = firstCapture(path, /\/(BV[0-9A-Za-z]{10}|av\d+)(?:\/|$)/i);
  if (identifier.length === 0) {
    return '';
  }
  const key: string = identifier.toLowerCase().startsWith('av') ? 'aid' : 'bvid';
  const value: string = key === 'aid' ? identifier.slice(2) : identifier;
  const page: string = queryValue(url, 'p');
  const pageParameter: string = /^\d+$/.test(page) ? `&page=${page}` : '';
  return `https://player.bilibili.com/player.html?${key}=${value}&high_quality=1&autoplay=0${pageParameter}`;
}

function youtubePlayerUrl(raw: string): string {
  const url: string = absoluteUrl(raw);
  const host: string = urlHost(url);
  const path: string = urlPath(url);
  const youtubeHost: boolean = host === 'youtube.com' || host.endsWith('.youtube.com') ||
    host === 'youtube-nocookie.com' || host.endsWith('.youtube-nocookie.com') ||
    host === 'youtu.be' || host.endsWith('.youtu.be');
  if (!youtubeHost) {
    return '';
  }
  let videoId: string = '';
  let playlistId: string = '';
  if (host === 'youtu.be' || host.endsWith('.youtu.be')) {
    videoId = firstCapture(path, /^\/([A-Za-z0-9_-]{6,})(?:\/|$)/);
  } else if (path === '/watch') {
    videoId = queryValue(url, 'v');
    playlistId = queryValue(url, 'list');
  } else if (path === '/playlist') {
    playlistId = queryValue(url, 'list');
  } else {
    videoId = firstCapture(path, /^\/(?:embed|v|shorts|live)\/([A-Za-z0-9_-]{6,})(?:\/|$)/i);
    if (videoId === 'videoseries') {
      videoId = '';
      playlistId = queryValue(url, 'list');
    }
  }
  const playerPath: string = videoId.length >= 6
    ? `/embed/${videoId}`
    : (playlistId.length > 0 ? '/embed/videoseries' : '');
  if (playerPath.length === 0) {
    return '';
  }
  const start: number = videoStartSeconds(url);
  const listParameter: string = playlistId.length > 0 ? `&list=${encodeURIComponent(playlistId)}` : '';
  const startParameter: string = start > 0 ? `&start=${start}` : '';
  return `https://www.youtube.com${playerPath}?autoplay=0&playsinline=1&rel=0&iv_load_policy=3` +
    `&origin=${encodeURIComponent(RIVERSIDE_ORIGIN)}${listParameter}${startParameter}`;
}

function videoBlock(rawUrl: string, title: string = ''): RichContentBlock | null {
  const bilibili: string = bilibiliPlayerUrl(rawUrl);
  if (bilibili.length > 0) {
    return RichContentBlock.video(bilibili, title.length > 0 ? title : 'Bilibili 视频', RichEmbedProvider.BILIBILI);
  }
  const youtube: string = youtubePlayerUrl(rawUrl);
  if (youtube.length > 0) {
    return RichContentBlock.video(youtube, title.length > 0 ? title : 'YouTube 视频', RichEmbedProvider.YOUTUBE);
  }
  return null;
}

function extractLinks(html: string): Array<RichContentLink> {
  const tags: Array<string> = html.match(/<a\b[^>]*href=["'][^"']+["'][^>]*>[\s\S]*?<\/a>/gi) ?? [];
  const links: Array<RichContentLink> = [];
  for (const tag of tags) {
    const href: string = absoluteUrl(firstCapture(tag, /href=["']([^"']+)["']/i));
    const label: string = stripHtml(tag);
    if (href.length > 0 && label.length > 0 && classifyRichNavigation(href).kind !== RichNavigationKind.BLOCKED) {
      links.push(new RichContentLink(label, href));
    }
  }
  return links;
}

function extractImages(html: string): Array<RichContentBlock> {
  const tags: Array<string> = html.match(/<img\b[^>]*>/gi) ?? [];
  const blocks: Array<RichContentBlock> = [];
  for (const tag of tags) {
    if (/youtube-thumbnail/i.test(tag)) {
      continue;
    }
    const url: string = absoluteUrl(firstCapture(tag, /src=["']([^"']+)["']/i));
    const description: string = decodeEntities(firstCapture(tag, /alt=["']([^"']*)["']/i));
    if (/^https:\/\//i.test(url)) {
      blocks.push(RichContentBlock.image(url, description.length > 0 ? description : 'Post 图片'));
    }
  }
  return blocks;
}

function directListItemTags(html: string): Array<string> {
  const tags: Array<string> = [];
  const pattern: RegExp = /<(\/?)li\b[^>]*>/gi;
  let depth: number = 0;
  let start: number = -1;
  let match: RegExpExecArray | null = pattern.exec(html);
  while (match !== null) {
    const closing: boolean = match[1] === '/';
    if (!closing) {
      if (depth === 0) {
        start = match.index;
      }
      depth += 1;
    } else if (depth > 0) {
      depth -= 1;
      if (depth === 0 && start >= 0) {
        tags.push(html.slice(start, pattern.lastIndex));
        start = -1;
      }
    }
    match = pattern.exec(html);
  }
  return tags;
}

class BalancedListExtraction {
  public readonly html: string;
  public readonly lists: Array<string>;

  public constructor(html: string, lists: Array<string>) {
    this.html = html;
    this.lists = lists;
  }
}

function encodePlaceholderText(text: string): string {
  return text.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
}

function extractBalancedLists(html: string): BalancedListExtraction {
  const pattern: RegExp = /<(\/?)\s*(?:ul|ol)\b[^>]*>/gi;
  const lists: Array<string> = [];
  let output: string = '';
  let cursor: number = 0;
  let depth: number = 0;
  let start: number = -1;
  let match: RegExpExecArray | null = pattern.exec(html);
  while (match !== null) {
    const closing: boolean = match[1] === '/';
    if (!closing) {
      if (depth === 0) {
        start = match.index;
      }
      depth += 1;
    } else if (depth > 0) {
      depth -= 1;
      if (depth === 0 && start >= 0) {
        const list: string = html.slice(start, pattern.lastIndex);
        const listIndex: number = lists.length;
        lists.push(list);
        output += html.slice(cursor, start) +
          `<rich-list data-index="${listIndex}">${encodePlaceholderText(stripHtml(list))}</rich-list>`;
        cursor = pattern.lastIndex;
        start = -1;
      }
    }
    match = pattern.exec(html);
  }
  output += html.slice(cursor);
  return new BalancedListExtraction(output, lists);
}

function appendInlineBlocks(html: string, blocks: Array<RichContentBlock>): void {
  const iframeUrl: string = firstCapture(html, /<iframe\b[^>]*src=["']([^"']+)["']/i);
  if (iframeUrl.length > 0) {
    const iframeVideo: RichContentBlock | null = videoBlock(iframeUrl);
    if (iframeVideo !== null) {
      blocks.push(iframeVideo);
    }
  }
  const spoilerTags: Array<string> = html.match(
    /<(?:span|div)\b[^>]*class=["'][^"']*\b(?:spoiler|spoiled)\b[^"']*["'][^>]*>[\s\S]*?<\/(?:span|div)>/gi
  ) ?? [];
  let visibleHtml: string = html;
  for (const spoilerTag of spoilerTags) {
    visibleHtml = visibleHtml.replace(spoilerTag, '');
  }
  visibleHtml = visibleHtml.replace(/<iframe\b[^>]*>[\s\S]*?<\/iframe>/gi, '');
  visibleHtml = visibleHtml.replace(/<img\b[^>]*>/gi, '');
  const text: string = stripHtml(visibleHtml);
  const bareVideo: RichContentBlock | null = /^https?:\/\/\S+$/i.test(text) ? videoBlock(text) : null;
  if (bareVideo !== null) {
    blocks.push(bareVideo);
  } else if (text.length > 0) {
    blocks.push(RichContentBlock.textBlock(text, extractLinks(visibleHtml)));
  }
  for (const spoilerTag of spoilerTags) {
    const spoilerText: string = stripHtml(spoilerTag);
    if (spoilerText.length > 0) {
      blocks.push(RichContentBlock.spoiler(spoilerText));
    }
  }
  blocks.push(...extractImages(html));
}

function parseHtmlToken(token: string, blocks: Array<RichContentBlock>): void {
  const lower: string = token.toLowerCase();
  if (lower.startsWith('<pre')) {
    const code: string = stripHtml(token);
    if (code.length > 0) {
      blocks.push(RichContentBlock.code(code));
    }
    return;
  }
  if (lower.startsWith('<h')) {
    const levelText: string = firstCapture(token, /^<h([1-6])\b/i);
    const heading: string = stripHtml(token);
    if (heading.length > 0) {
      blocks.push(RichContentBlock.heading(heading, Number.parseInt(levelText, 10)));
    }
    return;
  }
  if (lower.startsWith('<aside') && lower.includes('onebox') && !lower.includes('quote')) {
    const link: RichContentLink | null = extractLinks(token)[0] ?? null;
    if (link !== null) {
      const heading: string = stripHtml(firstCapture(token, /<h3\b[^>]*>([\s\S]*?)<\/h3>/i));
      const title: string = heading.length > 0 ? heading : link.label;
      blocks.push(RichContentBlock.onebox(link.url, title, urlHost(link.url).replace(/^www\./, '')));
    }
    return;
  }
  if (lower.startsWith('<aside') || lower.startsWith('<blockquote')) {
    const username: string = decodeEntities(firstCapture(token, /data-username=["']([^"']+)["']/i));
    const quoteBody: string = firstCapture(token, /<blockquote\b[^>]*>([\s\S]*?)<\/blockquote>/i);
    const quote: string = stripHtml(quoteBody.length > 0 ? quoteBody : token);
    if (quote.length > 0) {
      blocks.push(RichContentBlock.quote(quote, username));
    }
    return;
  }
  if ((lower.startsWith('<ul') || lower.startsWith('<ol'))) {
    const itemTags: Array<string> = directListItemTags(token);
    const items: Array<RichContentListItem> = itemTags
      .map((item: string): RichContentListItem =>
        new RichContentListItem(stripHtml(item), extractLinks(item)))
      .filter((item: RichContentListItem): boolean => item.text.length > 0);
    if (items.length > 0) {
      blocks.push(RichContentBlock.list(items, lower.startsWith('<ol')));
    }
    return;
  }
  if (lower.startsWith('<table')) {
    const rowTags: Array<string> = token.match(/<tr\b[^>]*>[\s\S]*?<\/tr>/gi) ?? [];
    const rows: Array<Array<string>> = [];
    for (const rowTag of rowTags) {
      const cellTags: Array<string> = rowTag.match(/<t[hd]\b[^>]*>[\s\S]*?<\/t[hd]>/gi) ?? [];
      const cells: Array<string> = cellTags.map((cell: string): string => stripHtml(cell));
      if (cells.length > 0) {
        rows.push(cells);
      }
    }
    if (rows.length > 0) {
      blocks.push(RichContentBlock.table(rows));
    }
    return;
  }
  if (lower.startsWith('<div') && /class=["'][^"']*\bmath\b/i.test(token)) {
    const formula: string = stripHtml(token);
    if (formula.length > 0) {
      blocks.push(RichContentBlock.formula(formula));
    }
    return;
  }
  appendInlineBlocks(token, blocks);
}

function parseCookedHtml(cooked: string): Array<RichContentBlock> {
  const sanitized: string = cooked
    .replace(/<script[\s\S]*?<\/script>/gi, '')
    .replace(/<style[\s\S]*?<\/style>/gi, '')
    .replace(/<(?:object|embed|form)\b[\s\S]*?<\/(?:object|embed|form)>/gi, '');
  const listExtraction: BalancedListExtraction = extractBalancedLists(sanitized);
  const tokens: Array<string> = listExtraction.html.match(
    /<pre\b[^>]*>[\s\S]*?<\/pre>|<aside\b[^>]*>[\s\S]*?<\/aside>|<blockquote\b[^>]*>[\s\S]*?<\/blockquote>|<h[1-6]\b[^>]*>[\s\S]*?<\/h[1-6]>|<rich-list\b[^>]*>[\s\S]*?<\/rich-list>|<table\b[^>]*>[\s\S]*?<\/table>|<div\b[^>]*class=["'][^"']*\bmath\b[^"']*["'][^>]*>[\s\S]*?<\/div>|<p\b[^>]*>[\s\S]*?<\/p>|<iframe\b[^>]*>[\s\S]*?<\/iframe>|<img\b[^>]*>/gi
  ) ?? [];
  const blocks: Array<RichContentBlock> = [];
  for (const token of tokens) {
    if (token.toLowerCase().startsWith('<rich-list')) {
      const indexText: string = firstCapture(token, /data-index=["'](\d+)["']/i);
      const index: number = Number.parseInt(indexText, 10);
      if (Number.isInteger(index) && index >= 0 && index < listExtraction.lists.length) {
        parseHtmlToken(listExtraction.lists[index], blocks);
      }
    } else {
      parseHtmlToken(token, blocks);
    }
  }
  if (blocks.length === 0) {
    appendInlineBlocks(sanitized, blocks);
  }
  return blocks;
}

function markdownLinks(text: string): Array<RichContentLink> {
  const tags: Array<string> = text.match(/\[[^\]]+\]\([^)]+\)/g) ?? [];
  const links: Array<RichContentLink> = [];
  for (const tag of tags) {
    const label: string = firstCapture(tag, /^\[([^\]]+)\]/);
    const url: string = absoluteUrl(firstCapture(tag, /\]\(([^)]+)\)$/));
    if (label.length > 0 && classifyRichNavigation(url).kind !== RichNavigationKind.BLOCKED) {
      links.push(new RichContentLink(label, url));
    }
  }
  return links;
}

function markdownText(text: string): string {
  return text
    .replace(/!\[[^\]]*\]\([^)]+\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/`([^`]+)`/g, '$1')
    .trim();
}

function parseMarkdown(raw: string): Array<RichContentBlock> {
  const lines: Array<string> = raw.replace(/\r\n/g, '\n').split('\n');
  const blocks: Array<RichContentBlock> = [];
  let index: number = 0;
  while (index < lines.length) {
    const line: string = lines[index].trim();
    if (line.length === 0) {
      index += 1;
      continue;
    }
    if (line.startsWith('```')) {
      const codeLines: Array<string> = [];
      index += 1;
      while (index < lines.length && !lines[index].trim().startsWith('```')) {
        codeLines.push(lines[index]);
        index += 1;
      }
      blocks.push(RichContentBlock.code(codeLines.join('\n').trim()));
      index += 1;
      continue;
    }
    const headingLevel: string = firstCapture(line, /^(#{1,6})\s+/);
    if (headingLevel.length > 0) {
      blocks.push(RichContentBlock.heading(line.slice(headingLevel.length).trim(), headingLevel.length));
      index += 1;
      continue;
    }
    if (line.startsWith('>')) {
      blocks.push(RichContentBlock.quote(markdownText(line.replace(/^>\s?/, '')), ''));
      index += 1;
      continue;
    }
    if (/^[-*+]\s+/.test(line) || /^\d+\.\s+/.test(line)) {
      const ordered: boolean = /^\d+\.\s+/.test(line);
      const items: Array<RichContentListItem> = [];
      while (index < lines.length) {
        const candidate: string = lines[index].trim();
        if ((ordered && !/^\d+\.\s+/.test(candidate)) || (!ordered && !/^[-*+]\s+/.test(candidate))) {
          break;
        }
        const itemSource: string = candidate.replace(ordered ? /^\d+\.\s+/ : /^[-*+]\s+/, '');
        items.push(new RichContentListItem(markdownText(itemSource), markdownLinks(itemSource)));
        index += 1;
      }
      blocks.push(RichContentBlock.list(items, ordered));
      continue;
    }
    if (line.startsWith('$$') && line.endsWith('$$') && line.length > 4) {
      blocks.push(RichContentBlock.formula(line.slice(2, line.length - 2).trim()));
      index += 1;
      continue;
    }
    const imageTags: Array<string> = line.match(/!\[[^\]]*\]\([^)]+\)/g) ?? [];
    for (const imageTag of imageTags) {
      const description: string = firstCapture(imageTag, /^!\[([^\]]*)\]/);
      const url: string = absoluteUrl(firstCapture(imageTag, /\]\(([^)]+)\)$/));
      if (/^https:\/\//i.test(url)) {
        blocks.push(RichContentBlock.image(url, description.length > 0 ? description : 'Post 图片'));
      }
    }
    const links: Array<RichContentLink> = markdownLinks(line);
    const text: string = markdownText(line);
    const video: RichContentBlock | null = /^https?:\/\/\S+$/i.test(text) ? videoBlock(text) : null;
    if (video !== null) {
      blocks.push(video);
    } else if (text.length > 0) {
      blocks.push(RichContentBlock.textBlock(text, links));
    }
    index += 1;
  }
  return blocks;
}

export function parseRichPostContent(cooked: string, raw: string): Array<RichContentBlock> {
  const normalizedCooked: string = cooked.trim();
  if (normalizedCooked.length > 0) {
    const htmlBlocks: Array<RichContentBlock> = parseCookedHtml(normalizedCooked);
    if (htmlBlocks.length > 0) {
      return htmlBlocks;
    }
  }
  return parseMarkdown(raw.trim());
}

export function classifyRichNavigation(rawUrl: string): RichNavigationTarget {
  const url: string = absoluteUrl(rawUrl);
  if (/^mailto:[^\s@]+@[^\s@]+$/i.test(url) || /^tel:\+?[0-9 ()-]+$/i.test(url)) {
    return RichNavigationTarget.external(url);
  }
  if (!/^https:\/\//i.test(url)) {
    return RichNavigationTarget.blocked(url);
  }
  if (urlHost(url) !== 'river-side.cc') {
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
  if (host === 'river-side.cc') {
    return true;
  }
  if (provider === RichEmbedProvider.BILIBILI) {
    return host === 'player.bilibili.com' && path === '/player.html' ||
      host === 'www.bilibili.com' && path.startsWith('/blackboard/webplayer/');
  }
  if (provider === RichEmbedProvider.YOUTUBE) {
    return (host === 'www.youtube.com' || host === 'www.youtube-nocookie.com') && path.startsWith('/embed/');
  }
  return false;
}

export function embedTrustList(provider: RichEmbedProvider): string {
  return provider === RichEmbedProvider.BILIBILI
    ? BILIBILI_URL_TRUST_LIST
    : YOUTUBE_URL_TRUST_LIST;
}
