import { CurrentUser } from '../models/ReplyModels';

@Component
export struct UserProfileSummaryPage {
  @Prop username: string = '';
  @Prop profile: CurrentUser | null = null;
  @Prop loading: boolean = false;
  @Prop errorMessage: string = '';
  onRetry: () => void = (): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 14 }) {
      LoadingProgress()
        .width(36)
        .height(36)
      Text(`正在加载 @${this.username} 的 Profile`)
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ErrorState(): void {
    Column({ space: 14 }) {
      Text('Profile 加载失败')
        .fontSize(21)
        .fontWeight(FontWeight.Bold)
      Text(this.errorMessage)
        .fontSize(13)
        .fontColor('#C62828')
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(this.onRetry)
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ProfileContent(profile: CurrentUser): void {
    Scroll() {
      Column({ space: 14 }) {
        Column({ space: 12 }) {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
            .fontSize(60)
            .fontColor(['#317AF7'])
          Text(profile.displayName)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
          Text(`@${profile.username}`)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          if (profile.title.length > 0) {
            Text(profile.title)
              .fontSize(13)
              .fontColor('#52606D')
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
        Row({ space: 8 }) {
          Text(profile.roleLabel)
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#2068C9')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#EAF2FF')
            .borderRadius(14)
          if (profile.isVerified) {
            Text('认证校友')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2E7D32')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#E8F5E9')
              .borderRadius(14)
          }
          Text(`信任等级 ${profile.trustLevel}`)
            .fontSize(12)
            .fontColor('#52606D')
        }
        .width('100%')
        .padding(16)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  build() {
    if (this.loading) {
      this.LoadingState()
    } else if (this.profile !== null) {
      this.ProfileContent(this.profile)
    } else {
      this.ErrorState()
    }
  }
}
