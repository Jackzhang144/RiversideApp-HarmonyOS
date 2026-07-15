import {
  NotificationCentreState,
  NotificationCentreStateKind
} from '../app/NotificationCentreModel';
import {
  NotificationBucket,
  NotificationItem,
  notificationActionText,
  notificationBucketLabel
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

  private unreadLabel(): string {
    if (this.unreadCount <= 0) return '';
    return this.unreadCount > 99 ? '99+' : this.unreadCount.toString();
  }

  @Builder
  private Header(): void {
    Column({ space: 12 }) {
      Row({ space: 8 }) {
        Text('消息').fontSize(24).fontWeight(FontWeight.Bold)
        if (this.unreadCount > 0) {
          Text(this.unreadLabel())
            .fontSize(11).fontColor('#FFFFFF').fontWeight(FontWeight.Bold)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor('#D32F2F').borderRadius(10)
            .accessibilityText(`${this.unreadCount} 条未读通知`)
        }
        Blank()
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(20)
        }
        .width(40).height(40).backgroundColor(Color.Transparent)
        .enabled(!this.state.refreshing && this.state.kind !== NotificationCentreStateKind.LOADING)
        .onClick(this.onRefresh)
        .accessibilityText('刷新消息与活动')
      }
      .width('100%')

      Row({ space: 8 }) {
        ForEach(NOTIFICATION_BUCKETS, (bucket: NotificationBucket): void => {
          Button(notificationBucketLabel(bucket), { type: ButtonType.Normal })
            .layoutWeight(1).height(36).fontSize(13)
            .fontColor(this.state.bucket === bucket ? '#FFFFFF' : '#52606D')
            .backgroundColor(this.state.bucket === bucket ? '#317AF7' : '#EEF1F5')
            .onClick((): void => this.onSelectBucket(bucket))
            .accessibilityText(
              `${notificationBucketLabel(bucket)}${this.state.bucket === bucket ? '，已选择' : ''}`
            )
        }, (bucket: NotificationBucket): string => bucket)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 })
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private AuthenticationState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.bell')).fontSize(46).fontColor(['#7B8794'])
      Text('登录后查看消息与活动').fontSize(18).fontWeight(FontWeight.Bold)
      Text('私信、回复、回应和提及都需要 Authenticated Session。')
        .fontSize(13).fontColor('#52606D').textAlign(TextAlign.Center)
      Button('登录并授权').onClick(this.onLogin)
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ItemCard(item: NotificationItem): void {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        Text(notificationActionText(this.state.bucket, item))
          .fontSize(13).fontColor('#52606D').layoutWeight(1).maxLines(1)
        if (item.createdAt.length > 0) {
          Text(item.createdAt.replace('T', ' ').replace('Z', ''))
            .fontSize(10).fontColor('#98A2B3').maxLines(1)
        }
      }
      if (item.title.length > 0) {
        Text(item.title).fontSize(16).fontWeight(FontWeight.Bold).width('100%').maxLines(2)
      }
      if (item.excerpt.length > 0) {
        Text(item.excerpt).fontSize(13).fontColor('#52606D').width('100%').maxLines(3)
      }
    }
    .width('100%').padding(14).backgroundColor('#FFFFFF').borderRadius(12)
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
        Text('正在加载更多').fontSize(12).fontColor('#52606D')
      } else if (this.state.message.length > 0 && this.state.items.length > 0) {
        Text(this.state.message).fontSize(12).fontColor('#C62828').textAlign(TextAlign.Center)
        Button('重试加载更多').height(34).onClick(this.onLoadMore)
      } else if (!this.state.hasMore) {
        Text('已经显示全部消息').fontSize(12).fontColor('#7B8794')
      }
    }
    .width('100%').height(82).justifyContent(FlexAlign.Center)
  }

  @Builder
  private MessageList(): void {
    if (this.state.kind === NotificationCentreStateKind.LOADING && this.state.items.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text('正在读取服务器消息').fontSize(13).fontColor('#52606D')
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.ERROR && this.state.items.length === 0) {
      Column({ space: 12 }) {
        Text('消息加载失败').fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.state.message).fontSize(13).fontColor('#C62828').textAlign(TextAlign.Center)
        Button('重试').onClick(this.onRefresh)
      }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.EMPTY) {
      Column({ space: 8 }) {
        Text(`暂无${notificationBucketLabel(this.state.bucket)}消息`)
          .fontSize(17).fontWeight(FontWeight.Bold)
        Text('下拉或点击刷新可重新检查前台状态。').fontSize(13).fontColor('#52606D')
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === NotificationCentreStateKind.INITIAL) {
      Column() { Text('打开消息页后将从服务器刷新。').fontSize(13).fontColor('#52606D') }
        .width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.state.items, (item: NotificationItem): void => {
          ListItem() { this.ItemCard(item) }
        }, (item: NotificationItem): string => `${item.kind}-${item.id}-${item.topicId}-${item.postNumber}`)
        ListItem() { this.PaginationFooter() }
      }
      .width('100%').height('100%')
      .padding({ left: 12, right: 12, top: 10, bottom: 124 })
      .backgroundColor('#F5F6F8').edgeEffect(EdgeEffect.Spring)
      .onReachEnd(this.onLoadMore)
    }
  }

  build() {
    if (!this.authenticated) {
      this.AuthenticationState()
    } else {
      Column() {
        this.Header()
        this.MessageList()
      }
      .width('100%').height('100%').backgroundColor('#F5F6F8')
    }
  }
}
