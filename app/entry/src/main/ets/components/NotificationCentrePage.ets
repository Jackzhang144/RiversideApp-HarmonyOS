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
import { UserAvatar } from './UserAvatar';

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
  scroller: Scroller = new Scroller();
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
  private FilterButton(bucket: NotificationBucket): void {
    Button() {
      Row({ space: 6 }) {
        SymbolGlyph(this.bucketIcon(bucket))
          .fontSize(17)
          .fontColor([this.state.bucket === bucket ? $r('app.color.brand_selected_text') : $r('sys.color.font_secondary')])
        Text(notificationBucketLabel(bucket))
          .fontSize(13)
          .fontColor(this.state.bucket === bucket ? $r('app.color.brand_selected_text') : $r('sys.color.font_primary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(34)
    .layoutWeight(1)
    .backgroundColor(this.state.bucket === bucket ? $r('app.color.brand_selected_surface') : Color.Transparent)
    .borderRadius(14)
    .animation({ duration: 180, curve: Curve.EaseOut })
    .onClick((): void => this.onSelectBucket(bucket))
    .accessibilityText(
      `${notificationBucketLabel(bucket)}${this.state.bucket === bucket ? '，已选择' : ''}`
    )
  }

  @Builder
  private Filters(): void {
    Column() {
      Row({ space: 4 }) {
        ForEach(NOTIFICATION_BUCKETS, (bucket: NotificationBucket): void => {
          this.FilterButton(bucket)
        }, (bucket: NotificationBucket): string => bucket)
      }
      .width('100%')
      .height(40)
      .padding(3)
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .clip(true)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 8 })
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
  private ItemRow(item: NotificationItem): void {
    Row({ space: 12 }) {
      UserAvatar({
        avatarUrl: item.avatarUrl,
        displayName: item.actorDisplayName(),
        avatarSize: 36,
        avatarAccessibilityText: `${item.actorDisplayName()} 的头像`,
        flairUrl: item.flairUrl
      })
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(notificationActionText(this.state.bucket, item))
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
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
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
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
      if (item.topicId > 0) {
        SymbolGlyph($r('sys.symbol.chevron_right'))
          .fontSize(15)
          .fontColor([$r('sys.color.font_tertiary')])
      }
    }
    .width('100%')
    .constraintSize({ minHeight: 76 })
    .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    .enabled(item.topicId > 0)
    .onClick((): void => this.onOpenItem(item))
    .accessibilityText(
      `${notificationActionText(this.state.bucket, item)}，${item.title}${item.postNumber > 0
        ? `，第 ${item.postNumber} 楼`
        : ''}`
    )
  }

  @Builder
  private NotificationGroup(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(`${notificationBucketLabel(this.state.bucket)}动态`)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.state.items.length.toString())
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .height(20)
          .constraintSize({ minWidth: 20 })
          .padding({ left: 6, right: 6 })
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(10)
        Blank()
        if (this.unreadCount > 0) {
          Text(`${this.unreadCount > 99 ? '99+' : this.unreadCount.toString()} 条未读`)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_selected_text'))
            .height(22)
            .padding({ left: 8, right: 8 })
            .textAlign(TextAlign.Center)
            .backgroundColor($r('app.color.brand_selected_surface'))
            .borderRadius(11)
        }
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Column() {
        ForEach(this.state.items, (item: NotificationItem, index: number): void => {
          this.ItemRow(item)
          if (index < this.state.items.length - 1) {
            Divider()
              .margin({ left: 62, right: 14 })
              .color($r('sys.color.comp_divider'))
          }
        }, (item: NotificationItem): string => `${item.kind}-${item.id}-${item.topicId}-${item.postNumber}`)
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .clip(true)
    }
    .width('100%')
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
      Refresh({ refreshing: this.state.refreshing }) {
        List({ scroller: this.scroller }) {
          ListItem() {
            this.NotificationGroup()
          }
          ListItem() {
            this.PaginationFooter()
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 124 })
        .clip(true)
        .cachedCount(3, true)
        .backgroundColor($r('sys.color.background_secondary'))
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
        .onReachEnd(this.onLoadMore)
      }
      .width('100%')
      .height('100%')
      .refreshOffset(64)
      .pullToRefresh(true)
      .pullUpToCancelRefresh(false)
      .onRefreshing((): void => {
        this.onRefresh();
      })
    }
  }

  build() {
    if (!this.authenticated) {
      this.AuthenticationState()
    } else {
      Column() {
        this.Filters()
        this.MessageList()
      }
      .width('100%').height('100%').clip(false)
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
