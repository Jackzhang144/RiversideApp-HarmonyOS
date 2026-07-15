import { ProfileViewState, ProfileViewStateKind } from '../app/ProfileManagementModel';
import {
  ProfileGroup,
  ProfileNotificationLevel,
  UserProfile
} from '../models/ProfileModels';
import {
  ProfileSummaryMetric,
  ProfileSummaryPresentation,
  profileSummaryPresentationFor
} from './ProfileSummaryPresentation';

@Component
export struct UserProfileSummaryPage {
  @Prop state: ProfileViewState = ProfileViewState.initial();
  @Prop ownProfile: boolean = false;
  onRetry: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onFollowingChange: (following: boolean) => void = (): void => {};
  onNotificationLevelChange: (level: ProfileNotificationLevel) => void = (): void => {};
  onOpenDirectChat: (username: string) => void = (_username: string): void => {};
  onOpenTopics: (username: string) => void = (_username: string): void => {};
  onOpenReplies: (username: string) => void = (_username: string): void => {};

  @Builder
  private LoadingState(): void {
    Column({ space: 14 }) {
      LoadingProgress().width(36).height(36)
      Text($r('app.string.profile_loading'))
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
      Text($r('app.string.profile_load_failed')).fontSize(21).fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(13)
        .fontColor($r('app.color.status_error'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_retry')).onClick(this.onRetry)
    }
    .width('100%')
    .height('100%')
    .padding(32)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SummaryCard(presentation: ProfileSummaryPresentation): void {
    Column({ space: 12 }) {
      Text($r('app.string.profile_activity_summary')).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
      if (presentation.available) {
        this.SummaryMetricRow(presentation.metrics.slice(0, 3))
        this.SummaryMetricRow(presentation.metrics.slice(3, 6))
        if (presentation.badges.length > 0) {
          Text($r('app.string.profile_badges')).fontSize(13).fontWeight(FontWeight.Medium).width('100%')
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(presentation.badges, (badge: string): void => {
              Text(badge)
                .fontSize(12)
                .fontColor($r('app.color.text_link'))
                .padding({ left: 10, right: 10, top: 5, bottom: 5 })
                .margin({ right: 8, bottom: 8 })
                .backgroundColor($r('app.color.brand_tint_surface'))
                .borderRadius($r('app.float.card_corner_radius'))
            }, (badge: string, index: number): string => `${index}-${badge}`)
          }
          .width('100%')
        }
      } else {
        Text($r('app.string.profile_summary_empty'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(14)
  }

  @Builder
  private SummaryMetricRow(metrics: Array<ProfileSummaryMetric>): void {
    Row() {
      ForEach(metrics, (metric: ProfileSummaryMetric): void => {
        Column({ space: 4 }) {
          Text(metric.value.toString()).fontSize(17).fontWeight(FontWeight.Bold)
          Text(metric.label).fontSize(11).fontColor($r('sys.color.font_secondary'))
        }
        .layoutWeight(1)
      }, (metric: ProfileSummaryMetric): string => metric.label)
    }
    .width('100%')
  }

  @Builder
  private ProfileContent(profile: UserProfile): void {
    Scroll() {
      Column({ space: 12 }) {
        Column({ space: 10 }) {
          if (profile.profileBackgroundUrl.length > 0) {
            Image(profile.profileBackgroundUrl)
              .width('100%')
              .height(132)
              .borderRadius($r('app.float.card_corner_radius'))
              .objectFit(ImageFit.Cover)
              .accessibilityText(`${profile.displayName} 的个人页背景`)
          }
          if (profile.avatarUrl.length > 0) {
            Image(profile.avatarUrl)
              .width(76)
              .height(76)
              .borderRadius(38)
              .objectFit(ImageFit.Cover)
          } else {
            SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
              .fontSize(68)
              .fontColor([$r('app.color.brand_primary')])
          }
          Text(profile.displayName).fontSize(22).fontWeight(FontWeight.Bold)
          Text(`@${profile.username}`).fontSize(13).fontColor($r('sys.color.font_secondary'))
          if (profile.title.length > 0) {
            Text(profile.title).fontSize(13).fontColor($r('sys.color.font_secondary'))
          }
          Row({ space: 8 }) {
            Text(profile.roleLabel)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_link'))
            if (profile.isVerified) {
              Text($r('app.string.profile_verified_alumnus')).fontSize(12).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.verified_identity'))
            }
            Text(`TL ${profile.trustLevel}`).fontSize(12).fontColor($r('sys.color.font_secondary'))
          }
          if (this.ownProfile) {
            Button($r('app.string.profile_edit_action'), { type: ButtonType.Normal })
              .width('100%')
              .onClick(this.onEdit)
          } else {
            if (profile.canStartDirectChat()) {
              Button($r('app.string.profile_direct_chat'), { type: ButtonType.Normal })
                .width('100%')
                .enabled(!this.state.busy)
                .onClick((): void => this.onOpenDirectChat(profile.username))
            }
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
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(14)

        if (profile.bioExcerpt.length > 0 || profile.location.length > 0 || profile.website.length > 0) {
          Column({ space: 9 }) {
            if (profile.bioExcerpt.length > 0) {
              Text(profile.bioExcerpt).fontSize(14).lineHeight(21).width('100%')
            }
            if (profile.location.length > 0) {
              Text(`所在地：${profile.location}`).fontSize(13)
                .fontColor($r('sys.color.font_secondary')).width('100%')
            }
            if (profile.website.length > 0) {
              Text(profile.website).fontSize(13).fontColor($r('app.color.brand_primary')).width('100%')
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(14)
        }
        this.SummaryCard(profileSummaryPresentationFor(this.state.summary))
        Row({ space: 10 }) {
          Button(this.ownProfile ? '我的 Topic' : 'TA 的 Topic', { type: ButtonType.Normal })
            .layoutWeight(1)
            .onClick((): void => this.onOpenTopics(profile.username))
          Button(this.ownProfile ? '我的 Reply' : 'TA 的 Reply', { type: ButtonType.Normal })
            .layoutWeight(1)
            .onClick((): void => this.onOpenReplies(profile.username))
        }
        .width('100%')
        if (profile.groups.length > 0) {
          Column({ space: 8 }) {
            Text($r('app.string.profile_groups')).fontSize(16).fontWeight(FontWeight.Bold).width('100%')
            ForEach(profile.groups, (group: ProfileGroup): void => {
              Text(group.displayName.length > 0 ? group.displayName : group.name)
                .fontSize(13)
                .width('100%')
            }, (group: ProfileGroup): string => group.id.toString())
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(14)
        }
        if (this.state.message.length > 0) {
          Text(this.state.message).fontSize(12).fontColor($r('app.color.status_error')).width('100%')
        }
      }
      .width('100%')
      .padding(12)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('sys.color.background_secondary'))
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
