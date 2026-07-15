import { RichEmbedProvider } from '../models/RichContentModels';

export class FeatureSitePresentation {
  public readonly title: string;
  public readonly homeUrl: string;
  public readonly entryUrl: string;
  public readonly provider: RichEmbedProvider;

  public constructor(title: string, homeUrl: string, entryUrl: string, provider: RichEmbedProvider) {
    this.title = title;
    this.homeUrl = homeUrl;
    this.entryUrl = entryUrl;
    this.provider = provider;
  }
}

export function featureSitePresentations(): Array<FeatureSitePresentation> {
  return [
    new FeatureSitePresentation(
      '树洞',
      'https://whisper.river-side.cc/',
      'https://whisper.river-side.cc/auth/start?mode=interactive',
      RichEmbedProvider.WHISPER
    ),
    new FeatureSitePresentation(
      '选课指南',
      'https://review.river-side.cc/',
      'https://review.river-side.cc/auth/start?mode=interactive',
      RichEmbedProvider.REVIEW
    ),
    new FeatureSitePresentation(
      '校友地图',
      'https://map.river-side.cc/',
      'https://map.river-side.cc/auth/start?mode=interactive',
      RichEmbedProvider.MAP
    ),
    new FeatureSitePresentation(
      '觅电',
      'https://food.river-side.cc/',
      'https://food.river-side.cc/auth/discourse',
      RichEmbedProvider.FOOD
    ),
    new FeatureSitePresentation(
      'RS date',
      'https://rsdate.river-side.cc/',
      'https://rsdate.river-side.cc/auth/start?mode=interactive',
      RichEmbedProvider.RSDATE
    )
  ];
}

export enum HomeHeaderActionKind {
  SEARCH = 'search',
  NEW_TOPIC = 'new-topic'
}

export class HomeHeaderActionPresentation {
  public readonly kind: HomeHeaderActionKind;
  public readonly label: string;
  public readonly available: boolean;
  public readonly accessibilityText: string;

  private constructor(
    kind: HomeHeaderActionKind,
    label: string,
    available: boolean,
    accessibilityText: string | null = null
  ) {
    this.kind = kind;
    this.label = label;
    this.available = available;
    this.accessibilityText = accessibilityText ?? (available ? label : `${label}，未实现`);
  }

  public static search(): HomeHeaderActionPresentation {
    return new HomeHeaderActionPresentation(HomeHeaderActionKind.SEARCH, '搜索', true);
  }

  public static newTopic(available: boolean = true): HomeHeaderActionPresentation {
    return new HomeHeaderActionPresentation(
      HomeHeaderActionKind.NEW_TOPIC,
      '发布新 Topic',
      available,
      available ? null : '发布新 Topic，当前账户无可用 Category 创建权限'
    );
  }
}
