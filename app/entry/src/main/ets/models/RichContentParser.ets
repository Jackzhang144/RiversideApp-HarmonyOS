import {
  RIVERSIDE_ORIGIN,
  RIVERSIDE_URL_RESOLVER
} from '../core/RiversideEnvironment';
import {
  classifyRichNavigation,
  RichEmbedProvider,
  RichNavigationKind
} from './RichNavigationPolicy';
import {
  RichContentBlock,
  RichContentInlineFragment,
  RichContentInlineFragmentKind,
  RichContentLink,
  RichContentListItem
} from './RichContentBlocks';

const EMOJI_TOKEN_PATTERN: RegExp = /^:[A-Za-z0-9_+\-]+:$/;
const INLINE_BREAK_MARKER: string = '\uE000';

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
  return RIVERSIDE_URL_RESOLVER.richContent(decodeEntities(raw.trim()));
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

function inlineEmoji(tag: string): RichContentInlineFragment | null {
  const className: string = decodeEntities(firstCapture(tag, /class=["']([^"']*)["']/i));
  const token: string = decodeEntities(firstCapture(tag, /alt=["']([^"']*)["']/i));
  const url: string = absoluteUrl(firstCapture(tag, /src=["']([^"']+)["']/i));
  if (!/(^|\s)emoji(?:\s|$)/i.test(className) || !EMOJI_TOKEN_PATTERN.test(token) || !/^https:\/\//i.test(url)) {
    return null;
  }
  return RichContentInlineFragment.emoji(token, url);
}

export function parsePlainTextInlineEmojis(
  text: string,
  resolveEmojiUrl: (name: string) => string =
    (name: string): string => RIVERSIDE_URL_RESOLVER.reactionEmoji(name)
): Array<RichContentInlineFragment> {
  if (!text.includes(':')) {
    return [];
  }
  const fragments: Array<RichContentInlineFragment> = [];
  let textStart: number = 0;
  let cursor: number = 0;
  while (cursor < text.length) {
    const tokenStart: number = text.indexOf(':', cursor);
    if (tokenStart < 0) {
      break;
    }
    const tokenEnd: number = text.indexOf(':', tokenStart + 1);
    if (tokenEnd < 0) {
      break;
    }
    const token: string = text.substring(tokenStart, tokenEnd + 1);
    if (!EMOJI_TOKEN_PATTERN.test(token)) {
      cursor = tokenStart + 1;
      continue;
    }
    if (tokenStart > textStart) {
      fragments.push(RichContentInlineFragment.textFragment(text.substring(textStart, tokenStart)));
    }
    const name: string = token.substring(1, token.length - 1);
    const resolvedUrl: string = resolveEmojiUrl(name).trim();
    fragments.push(RichContentInlineFragment.emoji(
      token,
      resolvedUrl.length > 0 ? resolvedUrl : RIVERSIDE_URL_RESOLVER.reactionEmoji(name)
    ));
    cursor = tokenEnd + 1;
    textStart = cursor;
  }
  if (fragments.length === 0) {
    return [];
  }
  if (textStart < text.length) {
    fragments.push(RichContentInlineFragment.textFragment(text.substring(textStart)));
  }
  return fragments;
}

function inlineText(html: string): string {
  return decodeEntities(
    html
      .replace(/<br\s*\/?>/gi, INLINE_BREAK_MARKER)
      .replace(/<[^>]+>/g, '')
  )
    .replace(/\s+/g, ' ')
    .replace(new RegExp(INLINE_BREAK_MARKER, 'g'), '\n');
}

function imageDimension(tag: string, width: boolean): number {
  const raw: string = width
    ? firstCapture(tag, /\swidth=["']?(\d+(?:\.\d+)?)/i)
    : firstCapture(tag, /\sheight=["']?(\d+(?:\.\d+)?)/i);
  const value: number = Number(raw);
  return Number.isFinite(value) && value > 0 ? value : 0;
}

function imageBlock(tag: string): RichContentBlock | null {
  if (/youtube-thumbnail/i.test(tag) || inlineEmoji(tag) !== null) {
    return null;
  }
  const url: string = absoluteUrl(firstCapture(tag, /src=["']([^"']+)["']/i));
  if (!/^https:\/\//i.test(url)) {
    return null;
  }
  const description: string = decodeEntities(firstCapture(tag, /alt=["']([^"']*)["']/i));
  return RichContentBlock.image(
    url,
    description.length > 0 ? description : 'Post 图片',
    imageDimension(tag, true),
    imageDimension(tag, false)
  );
}

function appendTextFragments(
  fragments: Array<RichContentInlineFragment>,
  text: string
): void {
  if (text.length === 0) {
    return;
  }
  const emojiFragments: Array<RichContentInlineFragment> = parsePlainTextInlineEmojis(text);
  if (emojiFragments.length > 0) {
    fragments.push(...emojiFragments);
    return;
  }
  fragments.push(RichContentInlineFragment.textFragment(text));
}

function normalizeInlineFragments(
  fragments: Array<RichContentInlineFragment>
): Array<RichContentInlineFragment> {
  const merged: Array<RichContentInlineFragment> = [];
  for (const fragment of fragments) {
    if (fragment.kind === RichContentInlineFragmentKind.TEXT) {
      const previous: RichContentInlineFragment | null = merged[merged.length - 1] ?? null;
      if (previous !== null && previous.kind === RichContentInlineFragmentKind.TEXT) {
        merged[merged.length - 1] =
          RichContentInlineFragment.textFragment(previous.text + fragment.text);
      } else {
        merged.push(fragment);
      }
    } else {
      merged.push(fragment);
    }
  }
  if (merged.length > 0 && merged[0].kind === RichContentInlineFragmentKind.TEXT) {
    merged[0] = RichContentInlineFragment.textFragment(merged[0].text.trimStart());
  }
  const lastIndex: number = merged.length - 1;
  if (lastIndex >= 0 && merged[lastIndex].kind === RichContentInlineFragmentKind.TEXT) {
    merged[lastIndex] = RichContentInlineFragment.textFragment(merged[lastIndex].text.trimEnd());
  }
  return merged.filter((fragment: RichContentInlineFragment): boolean => {
    return fragment.kind !== RichContentInlineFragmentKind.TEXT || fragment.text.length > 0;
  });
}

function inlineFragmentsText(fragments: Array<RichContentInlineFragment>): string {
  return fragments.map((fragment: RichContentInlineFragment): string => fragment.text).join('');
}

function inlineFragmentsFromHtml(html: string): Array<RichContentInlineFragment> {
  const fragments: Array<RichContentInlineFragment> = [];
  const pattern: RegExp = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>/gi;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(html);
  while (match !== null) {
    appendTextFragments(fragments, inlineText(html.slice(cursor, match.index)));
    const tag: string = match[0];
    if (/^<img\b/i.test(tag)) {
      const emoji: RichContentInlineFragment | null = inlineEmoji(tag);
      if (emoji !== null) {
        fragments.push(emoji);
      }
    } else {
      const nestedImageTag: string = firstCapture(tag, /(<img\b[^>]*>)/i);
      const nestedEmoji: RichContentInlineFragment | null =
        nestedImageTag.length > 0 ? inlineEmoji(nestedImageTag) : null;
      if (nestedEmoji !== null) {
        fragments.push(nestedEmoji);
      } else if (nestedImageTag.length === 0) {
        const href: string = absoluteUrl(firstCapture(tag, /href=["']([^"']+)["']/i));
        const label: string = stripHtml(tag);
        if (
          href.length > 0 &&
          label.length > 0 &&
          classifyRichNavigation(href).kind !== RichNavigationKind.BLOCKED
        ) {
          fragments.push(RichContentInlineFragment.link(label, href));
        } else {
          appendTextFragments(fragments, label);
        }
      }
    }
    cursor = pattern.lastIndex;
    match = pattern.exec(html);
  }
  appendTextFragments(fragments, inlineText(html.slice(cursor)));
  return normalizeInlineFragments(fragments);
}

function appendHtmlInlineBlocks(html: string, blocks: Array<RichContentBlock>): void {
  const pattern: RegExp = /<a\b[^>]*>[\s\S]*?<\/a>|<img\b[^>]*>/gi;
  let fragments: Array<RichContentInlineFragment> = [];
  let cursor: number = 0;

  const flushText = (): void => {
    const normalized: Array<RichContentInlineFragment> = normalizeInlineFragments(fragments);
    const text: string = inlineFragmentsText(normalized);
    if (text.length > 0) {
      blocks.push(RichContentBlock.textBlock(text, normalized));
    }
    fragments = [];
  };

  let match: RegExpExecArray | null = pattern.exec(html);
  while (match !== null) {
    appendTextFragments(fragments, inlineText(html.slice(cursor, match.index)));
    const tag: string = match[0];
    const imageTag: string = /^<img\b/i.test(tag)
      ? tag
      : firstCapture(tag, /(<img\b[^>]*>)/i);
    if (imageTag.length > 0) {
      const emoji: RichContentInlineFragment | null = inlineEmoji(imageTag);
      if (emoji !== null) {
        fragments.push(emoji);
      } else {
        const image: RichContentBlock | null = imageBlock(imageTag);
        if (image !== null) {
          flushText();
          blocks.push(image);
        }
      }
    } else {
      const href: string = absoluteUrl(firstCapture(tag, /href=["']([^"']+)["']/i));
      const label: string = stripHtml(tag);
      if (
        href.length > 0 &&
        label.length > 0 &&
        classifyRichNavigation(href).kind !== RichNavigationKind.BLOCKED
      ) {
        fragments.push(RichContentInlineFragment.link(label, href));
      } else {
        appendTextFragments(fragments, label);
      }
    }
    cursor = pattern.lastIndex;
    match = pattern.exec(html);
  }
  appendTextFragments(fragments, inlineText(html.slice(cursor)));
  flushText();
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
  const text: string = stripHtml(visibleHtml);
  const bareVideo: RichContentBlock | null = /^https?:\/\/\S+$/i.test(text) ? videoBlock(text) : null;
  if (bareVideo !== null) {
    blocks.push(bareVideo);
  } else {
    appendHtmlInlineBlocks(visibleHtml, blocks);
  }
  for (const spoilerTag of spoilerTags) {
    const spoilerText: string = stripHtml(spoilerTag);
    if (spoilerText.length > 0) {
      blocks.push(RichContentBlock.spoiler(spoilerText));
    }
  }
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
    const fragments: Array<RichContentInlineFragment> = inlineFragmentsFromHtml(token);
    const heading: string = inlineFragmentsText(fragments);
    if (heading.length > 0) {
      blocks.push(RichContentBlock.heading(
        heading,
        Number.parseInt(levelText, 10),
        fragments
      ));
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
      .map((item: string): RichContentListItem => {
        const fragments: Array<RichContentInlineFragment> = inlineFragmentsFromHtml(item);
        return new RichContentListItem(inlineFragmentsText(fragments), fragments);
      })
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

function markdownInlineText(text: string): string {
  return text
    .replace(/!\[[^\]]*\]\([^)]+\)/g, '')
    .replace(/\[([^\]]+)\]\([^)]+\)/g, '$1')
    .replace(/\*\*([^*]+)\*\*/g, '$1')
    .replace(/\*([^*]+)\*/g, '$1')
    .replace(/`([^`]+)`/g, '$1');
}

function markdownText(text: string): string {
  return markdownInlineText(text).trim();
}

function markdownInlineFragments(source: string): Array<RichContentInlineFragment> {
  const fragments: Array<RichContentInlineFragment> = [];
  const pattern: RegExp = /(!?)\[([^\]]*)\]\(([^)]+)\)/g;
  let cursor: number = 0;
  let match: RegExpExecArray | null = pattern.exec(source);
  while (match !== null) {
    appendTextFragments(fragments, markdownInlineText(source.slice(cursor, match.index)));
    if (match[1] !== '!') {
      const label: string = markdownInlineText(match[2]).trim();
      const url: string = absoluteUrl(match[3]);
      if (
        label.length > 0 &&
        classifyRichNavigation(url).kind !== RichNavigationKind.BLOCKED
      ) {
        fragments.push(RichContentInlineFragment.link(label, url));
      } else {
        appendTextFragments(fragments, label);
      }
    }
    cursor = pattern.lastIndex;
    match = pattern.exec(source);
  }
  appendTextFragments(fragments, markdownInlineText(source.slice(cursor)));
  return normalizeInlineFragments(fragments);
}

function appendMarkdownInlineBlocks(
  source: string,
  blocks: Array<RichContentBlock>
): void {
  const pattern: RegExp = /(!?)\[([^\]]*)\]\(([^)]+)\)/g;
  let fragments: Array<RichContentInlineFragment> = [];
  let cursor: number = 0;

  const flushText = (): void => {
    const normalized: Array<RichContentInlineFragment> = normalizeInlineFragments(fragments);
    const text: string = inlineFragmentsText(normalized);
    if (text.length > 0) {
      blocks.push(RichContentBlock.textBlock(text, normalized));
    }
    fragments = [];
  };

  let match: RegExpExecArray | null = pattern.exec(source);
  while (match !== null) {
    appendTextFragments(fragments, markdownInlineText(source.slice(cursor, match.index)));
    const label: string = markdownInlineText(match[2]).trim();
    const url: string = absoluteUrl(match[3]);
    if (match[1] === '!') {
      flushText();
      if (/^https:\/\//i.test(url)) {
        blocks.push(RichContentBlock.image(
          url,
          label.length > 0 ? label : 'Post 图片'
        ));
      }
    } else if (
      label.length > 0 &&
      classifyRichNavigation(url).kind !== RichNavigationKind.BLOCKED
    ) {
      fragments.push(RichContentInlineFragment.link(label, url));
    } else {
      appendTextFragments(fragments, label);
    }
    cursor = pattern.lastIndex;
    match = pattern.exec(source);
  }
  appendTextFragments(fragments, markdownInlineText(source.slice(cursor)));
  flushText();
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
        const fragments: Array<RichContentInlineFragment> = markdownInlineFragments(itemSource);
        items.push(new RichContentListItem(inlineFragmentsText(fragments), fragments));
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
    const text: string = markdownText(line);
    const video: RichContentBlock | null = /^https?:\/\/\S+$/i.test(text) ? videoBlock(text) : null;
    if (video !== null) {
      blocks.push(video);
    } else {
      appendMarkdownInlineBlocks(line, blocks);
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
