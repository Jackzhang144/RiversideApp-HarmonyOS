import { RichEmbedProvider } from './RichNavigationPolicy';

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

export enum RichContentInlineFragmentKind {
  TEXT = 'text',
  EMOJI = 'emoji'
}

export class RichContentInlineFragment {
  public readonly kind: RichContentInlineFragmentKind;
  public readonly text: string;
  public readonly imageUrl: string;

  private constructor(kind: RichContentInlineFragmentKind, text: string, imageUrl: string) {
    this.kind = kind;
    this.text = text;
    this.imageUrl = imageUrl;
  }

  public static textFragment(text: string): RichContentInlineFragment {
    return new RichContentInlineFragment(RichContentInlineFragmentKind.TEXT, text, '');
  }

  public static emoji(token: string, imageUrl: string): RichContentInlineFragment {
    return new RichContentInlineFragment(RichContentInlineFragmentKind.EMOJI, token, imageUrl);
  }
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
  public readonly inlineFragments: Array<RichContentInlineFragment>;

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
    embedProvider: RichEmbedProvider = RichEmbedProvider.NONE,
    inlineFragments: Array<RichContentInlineFragment> = []
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
    this.inlineFragments = inlineFragments;
  }

  public static textBlock(
    text: string,
    links: Array<RichContentLink> = [],
    inlineFragments: Array<RichContentInlineFragment> = []
  ): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.TEXT, text, '', '', 0, false, [], [], links,
      RichEmbedProvider.NONE, inlineFragments);
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
