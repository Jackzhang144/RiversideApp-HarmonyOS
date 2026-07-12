export enum HomeHeaderActionKind {
  SEARCH = 'search',
  NEW_TOPIC = 'new-topic'
}

export class HomeHeaderActionPresentation {
  public readonly kind: HomeHeaderActionKind;
  public readonly label: string;
  public readonly available: boolean = false;
  public readonly accessibilityText: string;

  private constructor(kind: HomeHeaderActionKind, label: string) {
    this.kind = kind;
    this.label = label;
    this.accessibilityText = `${label}，未实现`;
  }

  public static search(): HomeHeaderActionPresentation {
    return new HomeHeaderActionPresentation(HomeHeaderActionKind.SEARCH, '搜索');
  }

  public static newTopic(): HomeHeaderActionPresentation {
    return new HomeHeaderActionPresentation(HomeHeaderActionKind.NEW_TOPIC, '发布新 Topic');
  }
}
