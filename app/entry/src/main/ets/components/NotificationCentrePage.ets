import {
  NotificationCentreState,
  NotificationCentreStateKind
} from '../app/NotificationCentreModel';
import {
  NotificationBucket,
  NotificationItem,
  notificationActionText,
  notificationBucketLabel,
  notificationTimeText
} from '../models/NotificationModels';

const NOTIFICATION_BUCKETS: Array<NotificationBucket> = [
  NotificationBucket.PRIVATE_MESSAGES,
  NotificationBucket.REPLIES,
  NotificationBucket.REACTIONS,
  NotificationBucket.MENTIONS
];

@Component
export struct NotificationCentrePage {
  @Prop authenticated: boolean = false;
  @Prop unreadCount: number = 0;
  @Prop state: NotificationCentreState = new NotificationCentreState();
  onLogin: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onSelectBucket: (bucket: NotificationBucket) => void = (_bucket: NotificationBucket): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenItem: (item: NotificationItem) => void = (_item: NotificationItem): void => {};

  private bucketIcon(bucket: NotificationBucket): Resource {
    if (bucket === NotificationBucket.PRIVATE_MESSAGES) return $r('sys.symbol.envelope');
    if (bucket === NotificationBucket.REPLIES) return $r('sys.symbol.message');
    if (bucket === NotificationBucket.REACTIONS) return $r('sys.symbol.heart');
    return $r('sys.symbol.at');
  }

  @Builder
  private Header(): void {
    Row({ space: 8 }) {
      Text($r('app.string.notification_title'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      Button() {
        SymbolGlyph($r('sys.symbol.arrow_clockwise'))
          .fontSize(20)
          .fontColor([$r('sys.color.font_primary')])
          .hitTestBehavior(HitTestMode.None)
      }
      .width(40)
      .height(40)
      .backgroundColor(Color.Transparent)
      .enabled(!this.state.refreshing && this.state.kind !== NotificationCentreStateKind.LOADING)
      .onClick(this.onRefresh)
      .accessibilityText($r('app.string.notification_refresh_accessibility'))
    }
    .width('100%')
    .height($r('app.float.page_header_height'))
    .padding({ left: 12, right: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { bottom: 1 }, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private FilterButton(bucket: NotificationBucket): void {
    Button() {
      Row({ space: 5 }) {
        SymbolGlyph(this.bucketIcon(bucket))
          .fontSize(16)
          .fontColor([this.state.bucket === bucket ? $r('app.color.brand_selected_text') : $r('sys.color.font_secondary')])
        Text(notificationBucketLabel(bucket))
          .fontSize(12)
          .fontColor(this.state.bucket === bucket ? $r('app.color.brand_selected_text') : $r('sys.color.font_primary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(40)
    .layoutWeight(1)
    .backgroundColor(this.state.bucket === bucket ? $r('app.color.brand_selected_surface') : $r('sys.color.comp_background_primary'))
    .borderRadius(10)
    .onClick((): void => this.onSelectBucket(bucket))
    .accessibilityText(
      `${notificationBucketLabel(bucket)}${this.state.bucket === bucket ? '，已选择' : ''}`
    )
  }

  @Builder
  private Filters(): void {
    Row({ space: 6 }) {
      ForEach(NOTIFICATION_BUCKETS, (bucket: NotificationBucket): void => {
        this.FilterButton(bucket)
      }, (bucket: NotificationBucket): string => bucket)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 12, bottom: 8 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private AuthenticationState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.bell')).fontSize(46).fontColor([$r('sys.color.font_tertiary')])
      Text($r('app.string.notification_login_title')).fontSize(18).fontWeight(FontWeight.Bold)
      Text($r('app.string.notification_login_message'))
        .fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      Button($r('app.string.notification_login_action')).onClick(this.onLogin)
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ItemCard(item: NotificationItem): void {
    Row({ space: 10 }) {
      Stack() {
        Text(item.actorDisplayName().substring(0, 1))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(18)
        if (item.avatarUrl.length > 0) {
          Image(item.avatarUrl)
            .width(36)
            .height(36)
            .objectFit(ImageFit.Cover)
            .borderRadius(18)
        }
      }
      .width(36)
      .height(36)
      Column({ space: 5 }) {
        Row({ space: 8 }) {
          Text(notificationActionText(this.state.bucket, item))
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (item.createdAt.length > 0) {
            Text(notificationTimeText(item.createdAt))
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
        }
        .width('100%')
        if (item.title.length > 0) {
          Text(item.title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        if (item.excerpt.length > 0) {
          Text(item.excerpt)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .enabled(item.topicId > 0)
    .onClick((): void => this.onOpenItem(item))
    .accessibilityText(
      `${notificationActionText(this.state.bucket, item)}，${item.title}${item.postNumber > 0
        ? `，第 ${item.postNumber} 楼`
        : ''}`
    )
  }

  @Builder
  private PaginationFooter(): void {
    Column({ space: 8 }) {
      if (this.state.loadingMore) {
        LoadingProgress().width(28).height(28)
        Text($r('app.string.common_loading_more')).fontSize(12).fontColor($r('sys.color.font_secondary'))
      } else if (this.state.message.length > 0 && this.state.items.length > 0) {
        Text(this.state.message).fontSize(12).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
        Button($r('app.string.common_retry_load_more')).height(34).onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text($r('app.string.notification_all_shown')).fontSize(12).fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%').height(82).justifyContent(FlexAlign.Center)
  }

  @Builder
  private MessageList(): void {
    if (this.state.kind === NotificationCentreStateKind.LOADING && this.state.items.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.notification_loading')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.ERROR && this.state.items.length === 0) {
      Column({ space: 12 }) {
        Text($r('app.string.notification_load_failed')).fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.state.message).fontSize(13).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
        Button($r('app.string.common_retry')).onClick(this.onRefresh)
      }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.EMPTY) {
      Column({ space: 8 }) {
        Text(`暂无${notificationBucketLabel(this.state.bucket)}消息`)
          .fontSize(17).fontWeight(FontWeight.Bold)
        Text($r('app.string.notification_empty_message'))
          .fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.INITIAL) {
      Column() {
        Text($r('app.string.notification_initial_message')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.state.items, (item: NotificationItem): void => {
          ListItem() { this.ItemCard(item) }
        }, (item: NotificationItem): string => `${item.kind}-${item.id}-${item.topicId}-${item.postNumber}`)
        ListItem() { this.PaginationFooter() }
      }
      .width('100%').height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 124 })
      .backgroundColor($r('sys.color.background_secondary')).edgeEffect(EdgeEffect.Spring)
      .onReachEnd(this.onLoadMore)
    }
  }

  build() {
    if (!this.authenticated) {
      this.AuthenticationState()
    } else {
      Column() {
        this.Header()
        this.Filters()
        this.MessageList()
      }
      .width('100%').height('100%').backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
