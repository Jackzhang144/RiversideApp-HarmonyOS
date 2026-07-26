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
  EMOJI = 'emoji',
  LINK = 'link'
}

export class RichContentInlineFragment {
  public readonly kind: RichContentInlineFragmentKind;
  public readonly text: string;
  public readonly imageUrl: string;
  public readonly url: string;

  private constructor(
    kind: RichContentInlineFragmentKind,
    text: string,
    imageUrl: string,
    url: string
  ) {
    this.kind = kind;
    this.text = text;
    this.imageUrl = imageUrl;
    this.url = url;
  }

  public static textFragment(text: string): RichContentInlineFragment {
    return new RichContentInlineFragment(RichContentInlineFragmentKind.TEXT, text, '', '');
  }

  public static emoji(token: string, imageUrl: string): RichContentInlineFragment {
    return new RichContentInlineFragment(RichContentInlineFragmentKind.EMOJI, token, imageUrl, '');
  }

  public static link(label: string, url: string): RichContentInlineFragment {
    return new RichContentInlineFragment(RichContentInlineFragmentKind.LINK, label, '', url);
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
  public readonly inlineFragments: Array<RichContentInlineFragment>;

  public constructor(
    text: string,
    inlineFragments: Array<RichContentInlineFragment> = []
  ) {
    this.text = text;
    this.inlineFragments = inlineFragments;
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
  public readonly embedProvider: RichEmbedProvider;
  public readonly inlineFragments: Array<RichContentInlineFragment>;
  public readonly sourceWidth: number;
  public readonly sourceHeight: number;

  private constructor(
    kind: RichContentBlockKind,
    text: string = '',
    title: string = '',
    url: string = '',
    level: number = 0,
    ordered: boolean = false,
    listItems: Array<RichContentListItem> = [],
    rows: Array<Array<string>> = [],
    embedProvider: RichEmbedProvider = RichEmbedProvider.NONE,
    inlineFragments: Array<RichContentInlineFragment> = [],
    sourceWidth: number = 0,
    sourceHeight: number = 0
  ) {
    this.kind = kind;
    this.text = text;
    this.title = title;
    this.url = url;
    this.level = level;
    this.ordered = ordered;
    this.listItems = listItems;
    this.rows = rows;
    this.embedProvider = embedProvider;
    this.inlineFragments = inlineFragments;
    this.sourceWidth = sourceWidth;
    this.sourceHeight = sourceHeight;
  }

  public static textBlock(
    text: string,
    inlineFragments: Array<RichContentInlineFragment> = []
  ): RichContentBlock {
    return new RichContentBlock(
      RichContentBlockKind.TEXT,
      text,
      '',
      '',
      0,
      false,
      [],
      [],
      RichEmbedProvider.NONE,
      inlineFragments
    );
  }

  public static heading(
    text: string,
    level: number,
    inlineFragments: Array<RichContentInlineFragment> = []
  ): RichContentBlock {
    return new RichContentBlock(
      RichContentBlockKind.HEADING,
      text,
      '',
      '',
      level,
      false,
      [],
      [],
      RichEmbedProvider.NONE,
      inlineFragments
    );
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

  public static image(
    url: string,
    description: string,
    sourceWidth: number = 0,
    sourceHeight: number = 0
  ): RichContentBlock {
    return new RichContentBlock(
      RichContentBlockKind.IMAGE,
      '',
      description,
      url,
      0,
      false,
      [],
      [],
      RichEmbedProvider.NONE,
      [],
      sourceWidth,
      sourceHeight
    );
  }

  public static onebox(url: string, title: string, domain: string): RichContentBlock {
    return new RichContentBlock(RichContentBlockKind.ONEBOX, domain, title, url);
  }

  public static video(url: string, title: string, provider: RichEmbedProvider): RichContentBlock {
    return new RichContentBlock(
      RichContentBlockKind.VIDEO,
      '',
      title,
      url,
      0,
      false,
      [],
      [],
      provider
    );
  }
}
