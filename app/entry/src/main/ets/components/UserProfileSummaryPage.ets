import { ProfileViewState, ProfileViewStateKind } from '../app/ProfileManagementModel';
import {
  ProfileGroup,
  ProfileNotificationLevel,
  UserProfile,
  UserProfileSummary
} from '../models/ProfileModels';

@Component
export struct UserProfileSummaryPage {
  @Prop state: ProfileViewState = ProfileViewState.initial();
  @Prop ownProfile: boolean = false;
  onRetry: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onFollowingChange: (following: boolean) => void = (): void => {};
  onNotificationLevelChange: (level: ProfileNotificationLevel) => void = (): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 14 }) {
      LoadingProgress().width(36).height(36)
      Text('正在加载完整 Profile')
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
      Text('Profile 加载失败').fontSize(21).fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(13)
        .fontColor('#C62828')
        .textAlign(TextAlign.Center)
      Button('重试').onClick(this.onRetry)
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SummaryCard(summary: UserProfileSummary): void {
    Column({ space: 12 }) {
      Text('活跃概览').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
      if (summary.available) {
        Row() {
          this.SummaryMetric('Topic', summary.topicCount)
          this.SummaryMetric('Post', summary.postCount)
          this.SummaryMetric('获赞', summary.likesReceived)
          this.SummaryMetric('访问', summary.daysVisited)
        }
        .width('100%')
      } else {
        Text('该用户活跃数据较少，暂时没有可展示的摘要。')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(14)
  }

  @Builder
  private SummaryMetric(label: string, value: number): void {
    Column({ space: 4 }) {
      Text(value.toString()).fontSize(17).fontWeight(FontWeight.Bold)
      Text(label).fontSize(11).fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
  }

  @Builder
  private ProfileContent(profile: UserProfile): void {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 10 }) {
          if (profile.avatarUrl.length > 0) {
            Image(profile.avatarUrl)
              .width(76)
              .height(76)
              .borderRadius(38)
              .objectFit(ImageFit.Cover)
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(68)
              .fontColor(['#317AF7'])
          }
          Text(profile.displayName).fontSize(22).fontWeight(FontWeight.Bold)
          Text(`@${profile.username}`).fontSize(13).fontColor($r('sys.color.font_secondary'))
          if (profile.title.length > 0) {
            Text(profile.title).fontSize(13).fontColor('#52606D')
          }
          Row({ space: 8 }) {
            Text(profile.roleLabel)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor('#2068C9')
            if (profile.isVerified) {
              Text('认证校友').fontSize(12).fontWeight(FontWeight.Bold).fontColor('#2E7D32')
            }
            Text(`TL ${profile.trustLevel}`).fontSize(12).fontColor('#52606D')
          }
          if (this.ownProfile) {
            Button('编辑个人资料', { type: ButtonType.Normal })
              .width('100%')
              .onClick(this.onEdit)
          } else {
            Row({ space: 8 }) {
              if (profile.canFollow) {
                Button(profile.following ? '取消关注' : '关注', { type: ButtonType.Normal })
                  .layoutWeight(1)
                  .enabled(!this.state.busy)
                  .onClick((): void => this.onFollowingChange(!profile.following))
              }
              if (profile.canMute) {
                Button(profile.notificationLevel === ProfileNotificationLevel.MUTED ? '取消静音' : '静音',
                  { type: ButtonType.Normal })
                  .layoutWeight(1)
                  .enabled(!this.state.busy)
                  .onClick((): void => this.onNotificationLevelChange(
                    profile.notificationLevel === ProfileNotificationLevel.MUTED
                      ? ProfileNotificationLevel.NORMAL
                      : ProfileNotificationLevel.MUTED
                  ))
              }
              if (profile.canIgnore) {
                Button(profile.notificationLevel === ProfileNotificationLevel.IGNORED ? '取消忽略' : '忽略',
                  { type: ButtonType.Normal })
                  .layoutWeight(1)
                  .enabled(!this.state.busy)
                  .onClick((): void => this.onNotificationLevelChange(
                    profile.notificationLevel === ProfileNotificationLevel.IGNORED
                      ? ProfileNotificationLevel.NORMAL
                      : ProfileNotificationLevel.IGNORED
                  ))
              }
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FFFFFF')
        .borderRadius(14)

        if (profile.bioExcerpt.length > 0 || profile.location.length > 0 || profile.website.length > 0) {
          Column({ space: 9 }) {
            if (profile.bioExcerpt.length > 0) {
              Text(profile.bioExcerpt).fontSize(14).lineHeight(21).width('100%')
            }
            if (profile.location.length > 0) {
              Text(`所在地：${profile.location}`).fontSize(13).fontColor('#52606D').width('100%')
            }
            if (profile.website.length > 0) {
              Text(profile.website).fontSize(13).fontColor('#317AF7').width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
        }
        this.SummaryCard(this.state.summary)
        if (profile.groups.length > 0) {
          Column({ space: 8 }) {
            Text('群组').fontSize(16).fontWeight(FontWeight.Bold).width('100%')
            ForEach(profile.groups, (group: ProfileGroup): void => {
              Text(group.displayName.length > 0 ? group.displayName : group.name)
                .fontSize(13)
                .width('100%')
            }, (group: ProfileGroup): string => group.id.toString())
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
        }
        if (this.state.message.length > 0) {
          Text(this.state.message).fontSize(12).fontColor('#C62828').width('100%')
        }
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  build() {
    if (this.state.kind === ProfileViewStateKind.LOADING) {
      this.LoadingState()
    } else if (this.state.profile !== null) {
      this.ProfileContent(this.state.profile)
    } else {
      this.ErrorState()
    }
  }
}
