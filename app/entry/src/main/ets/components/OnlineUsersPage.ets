import { OnlineUser } from '../models/DiscoveryModels';

@Component
export struct OnlineUsersPage {
  @Prop count: number = 0;
  @Prop users: Array<OnlineUser> = [];
  onOpenUser: (user: OnlineUser) => void = (_user: OnlineUser): void => {};

  @Builder
  private Avatar(user: OnlineUser, size: number): void {
    Stack() {
      Text(user.username.slice(0, 1).toUpperCase())
        .width(size)
        .height(size)
        .textAlign(TextAlign.Center)
        .fontSize(Math.max(10, size * 0.36))
        .fontWeight(FontWeight.Bold)
        .fontColor('#317AF7')
        .backgroundColor('#EAF2FF')
        .borderRadius(size / 2)
      if (user.avatarUrl.length > 0) {
        Image(user.avatarUrl)
          .width(size)
          .height(size)
          .borderRadius(size / 2)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(size)
    .height(size)
  }

  build() {
    List() {
      ForEach(this.users, (user: OnlineUser) => {
        ListItem() {
          Row({ space: 12 }) {
            this.Avatar(user, 42)
            Column({ space: 3 }) {
              Text(user.displayName)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor('#24262B')
              if (user.name.length > 0) {
                Text(`@${user.username}`)
                  .fontSize(12)
                  .fontColor($r('sys.color.font_secondary'))
              }
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            SymbolGlyph($r('sys.symbol.chevron_right'))
              .fontSize(15)
              .fontColor([$r('sys.color.font_tertiary')])
          }
          .width('100%')
          .height(64)
          .padding({ left: 16, right: 16 })
          .backgroundColor('#FFFFFF')
          .onClick((): void => this.onOpenUser(user))
          .accessibilityText(`在线用户 ${user.displayName}`)
        }
      }, (user: OnlineUser): string => `${user.id}-${user.username}`)
      if (this.count > this.users.length) {
        ListItem() {
          Text(`还有 ${this.count - this.users.length} 位在线用户未公开资料`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .width('100%')
            .padding(16)
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .divider({ strokeWidth: 1, color: '#ECEEF2', startMargin: 70 })
  }
}
