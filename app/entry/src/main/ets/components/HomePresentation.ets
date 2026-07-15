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
