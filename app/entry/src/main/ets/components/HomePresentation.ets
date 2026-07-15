import { RichEmbedProvider } from '../models/RichContentModels';
import {
  RIVERSIDE_FOOD_ENTRY_URL,
  RIVERSIDE_FOOD_HOME_URL,
  RIVERSIDE_MAP_ENTRY_URL,
  RIVERSIDE_MAP_HOME_URL,
  RIVERSIDE_REVIEW_ENTRY_URL,
  RIVERSIDE_REVIEW_HOME_URL,
  RIVERSIDE_RSDATE_ENTRY_URL,
  RIVERSIDE_RSDATE_HOME_URL,
  RIVERSIDE_WHISPER_ENTRY_URL,
  RIVERSIDE_WHISPER_HOME_URL
} from '../core/RiversideEnvironment';

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
      RIVERSIDE_WHISPER_HOME_URL,
      RIVERSIDE_WHISPER_ENTRY_URL,
      RichEmbedProvider.WHISPER
    ),
    new FeatureSitePresentation(
      '选课指南',
      RIVERSIDE_REVIEW_HOME_URL,
      RIVERSIDE_REVIEW_ENTRY_URL,
      RichEmbedProvider.REVIEW
    ),
    new FeatureSitePresentation(
      '校友地图',
      RIVERSIDE_MAP_HOME_URL,
      RIVERSIDE_MAP_ENTRY_URL,
      RichEmbedProvider.MAP
    ),
    new FeatureSitePresentation(
      '觅电',
      RIVERSIDE_FOOD_HOME_URL,
      RIVERSIDE_FOOD_ENTRY_URL,
      RichEmbedProvider.FOOD
    ),
    new FeatureSitePresentation(
      'RS date',
      RIVERSIDE_RSDATE_HOME_URL,
      RIVERSIDE_RSDATE_ENTRY_URL,
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
