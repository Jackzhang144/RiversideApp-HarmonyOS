import {
  ForumCardBadge,
  ForumCardBadgeKind,
  ForumCardAuthor,
  ForumCardMode,
  ForumCardPresentation,
  ForumCardReplyAction,
  ForumCardStatistic,
  ForumCardStatisticKind
} from './ForumCardPresentation';
import { RichEmbedProvider } from '../models/RichNavigationPolicy';
import { RichPostContent } from './RichPostContent';

@Component
export struct ForumContentCard {
  @Require @Prop presentation: ForumCardPresentation;
  @Prop richCooked: string = '';
  @Prop richRaw: string = '';
  @Prop authorActionAvailable: boolean = false;
  onOpenTopic: () => void = (): void => {};
  onReply: (postNumber: number | null) => void = (_postNumber: number | null): void => {};
  onOpenRichLink: (url: string) => void = (_url: string): void => {};
  onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string) => void = (
    _url: string,
    _provider: RichEmbedProvider,
    _title: string
  ): void => {};
  onOpenImage: (url: string, title: string) => void = (_url: string, _title: string): void => {};
  onOpenAuthor: (username: string) => void = (_username: string): void => {};

  @Builder
  private Badge(badge: ForumCardBadge): void {
    Text(badge.label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(badge.kind === ForumCardBadgeKind.PINNED ? $r('app.color.status_error') : $r('app.color.text_link'))
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius(10)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private AuthorRow(author: ForumCardAuthor): void {
    Row({ space: 9 }) {
      Text(author.initial)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(18)
      Column({ space: 2 }) {
        Text(author.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        Text(author.timestamp)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.presentation.headerBadge !== null) {
        this.Badge(this.presentation.headerBadge)
      }
    }
    .width('100%')
    .enabled(this.authorActionAvailable && author.username.length > 0)
    .onClick((): void => {
      if (this.authorActionAvailable && author.username.length > 0) {
        this.onOpenAuthor(author.username);
      }
    })
    .accessibilityText(
      this.authorActionAvailable && author.username.length > 0 ? `查看用户 ${author.username}` : author.name
    )
  }

  @Builder
  private Content(): void {
    if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
      if (this.presentation.title.length > 0) {
        Text(this.presentation.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (this.presentation.body.length > 0) {
        Text(this.presentation.body)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    } else {
      if (this.presentation.title.length > 0) {
        Text(this.presentation.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .lineHeight(25)
          .width('100%')
      }
      if (this.richCooked.length > 0 || this.richRaw.length > 0) {
        RichPostContent({
          cooked: this.richCooked,
          raw: this.richRaw,
          onOpenLink: (url: string): void => this.onOpenRichLink(url),
          onOpenEmbed: (url: string, provider: RichEmbedProvider, title: string): void =>
            this.onOpenRichEmbed(url, provider, title),
          onOpenImage: (url: string, title: string): void => this.onOpenImage(url, title)
        })
      } else if (this.presentation.body.length > 0) {
        Text(this.presentation.body)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
      }
    }
  }

  @Builder
  private Statistic(statistic: ForumCardStatistic): void {
    if (statistic.kind === ForumCardStatisticKind.REPLIES) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    } else if (statistic.kind === ForumCardStatisticKind.VIEWS) {
      SymbolGlyph($r('sys.symbol.eye'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    } else {
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    Text(statistic.value.toString())
      .fontSize(11)
      .fontColor($r('sys.color.font_tertiary'))
  }

  @Builder
  private ReplyAction(action: ForumCardReplyAction): void {
    Button() {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([$r('app.color.brand_primary')])
        Text(action.label)
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
      }
    }
    .height(36)
    .backgroundColor(Color.Transparent)
    .onClick((): void => this.onReply(action.targetPostNumber))
    .accessibilityText(action.accessibilityText)
  }

  @Builder
  private Footer(): void {
    Row({ space: 5 }) {
      if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
        if (this.presentation.footerBadge !== null) {
          this.Badge(this.presentation.footerBadge)
        }
        Blank()
        ForEach(this.presentation.statistics, (statistic: ForumCardStatistic) => {
          this.Statistic(statistic)
        }, (statistic: ForumCardStatistic): string => statistic.kind)
      } else {
        ForEach(this.presentation.statistics, (statistic: ForumCardStatistic) => {
          this.Statistic(statistic)
        }, (statistic: ForumCardStatistic): string => statistic.kind)
        Blank()
      }
      if (this.presentation.replyAction !== null) {
        this.ReplyAction(this.presentation.replyAction)
      }
    }
    .width('100%')
  }

  @Builder
  private Restriction(): void {
    if (this.presentation.restrictionText.length > 0) {
      Text(this.presentation.restrictionText)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_error'))
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(8)
        .width('100%')
    }
  }

  build() {
    Column({ space: 10 }) {
      if (this.presentation.author !== null) {
        this.AuthorRow(this.presentation.author)
      }
      this.Content()
      if (this.presentation.footerBadge !== null || this.presentation.statistics.length > 0 ||
        this.presentation.replyAction !== null) {
        this.Footer()
      }
      this.Restriction()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .onClick((): void => {
      if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
        this.onOpenTopic();
      }
    })
    .accessibilityText(this.presentation.accessibilityText)
  }
}
