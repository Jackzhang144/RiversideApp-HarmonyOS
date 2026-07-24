import { ProfileViewState, ProfileViewStateKind } from '../app/ProfileManagementModel';
import {
  ProfileBadge,
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
  scroller: Scroller = new Scroller();
  @Prop state: ProfileViewState = ProfileViewState.initial();
  @Prop ownProfile: boolean = false;
  onRetry: () => void = (): void => {};
  onEdit: () => void = (): void => {};
  onFollowingChange: (following: boolean) => void = (): void => {};
  onNotificationLevelChange: (level: ProfileNotificationLevel) => void = (): void => {};
  onOpenDirectChat: (username: string) => void = (_username: string): void => {};
  onOpenTopics: (username: string) => void = (_username: string): void => {};
  onOpenReplies: (username: string) => void = (_username: string): void => {};

  private visibleGroups(groups: Array<ProfileGroup>): Array<ProfileGroup> {
    return groups.filter((group: ProfileGroup): boolean => {
      const name: string = group.name.toLowerCase();
      return !name.startsWith('trust_level_') && name !== 'everyone';
    });
  }

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
    Column({ space: 14 }) {
      Text($r('app.string.profile_activity_summary'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (presentation.available) {
        this.SummaryMetricRow(presentation.metrics.slice(0, 3))
        this.SummaryMetricRow(presentation.metrics.slice(3, 6))
        if (presentation.badges.length > 0) {
          Divider()
            .color($r('sys.color.comp_divider'))
          Row({ space: 7 }) {
            SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
              .fontSize(18)
              .fontColor([$r('app.color.brand_primary')])
            Text($r('app.string.profile_badges'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('sys.color.font_primary'))
          }
          .width('100%')
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            ForEach(presentation.badges.slice(0, 12), (badge: ProfileBadge): void => {
              this.BadgePill(badge)
            }, (badge: ProfileBadge, index: number): string => `${index}-${badge.name}`)
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
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private SummaryMetricRow(metrics: Array<ProfileSummaryMetric>): void {
    Row({ space: 8 }) {
      ForEach(metrics, (metric: ProfileSummaryMetric): void => {
        this.SummaryMetricTile(metric)
      }, (metric: ProfileSummaryMetric): string => metric.label)
    }
    .width('100%')
  }

  @Builder
  private SummaryMetricTile(metric: ProfileSummaryMetric): void {
    Column({ space: 4 }) {
      Text(metric.value.toString())
        .fontSize(19)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
      Text(metric.label)
        .fontSize(11)
        .fontColor($r('sys.color.font_secondary'))
    }
    .layoutWeight(1)
    .height(66)
    .justifyContent(FlexAlign.Center)
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(12)
  }

  @Builder
  private BadgePill(badge: ProfileBadge): void {
    Row({ space: 6 }) {
      if (badge.imageUrl.length > 0) {
        Image(badge.imageUrl)
          .width(18)
          .height(18)
          .objectFit(ImageFit.Contain)
      } else {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(16)
          .fontColor([$r('app.color.brand_primary')])
      }
      Text(badge.name)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .maxLines(1)
    }
    .height(34)
    .padding({ left: 10, right: 11 })
    .margin({ right: 8, bottom: 8 })
    .backgroundColor($r('app.color.brand_tint_surface'))
    .borderRadius(17)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(`徽章：${badge.name}`)
  }

  @Builder
  private IdentityPills(profile: UserProfile): void {
    Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
      Text(profile.roleLabel)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_link'))
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .margin({ right: 7, bottom: 6 })
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(14)
      if (profile.isVerified) {
        Text($r('app.string.profile_verified_alumnus'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.verified_identity'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .margin({ right: 7, bottom: 6 })
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(14)
      }
      Text(`TL ${profile.trustLevel}`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .margin({ right: 7, bottom: 6 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(14)
    }
    .width('100%')
  }

  @Builder
  private ProfileHeaderCard(profile: UserProfile): void {
    Column({ space: 14 }) {
      if (profile.profileBackgroundUrl.length > 0) {
        Image(profile.profileBackgroundUrl)
          .width('100%')
          .height(112)
          .borderRadius(14)
          .objectFit(ImageFit.Cover)
          .accessibilityText(`${profile.displayName} 的个人页背景`)
      }
      Row({ space: 14 }) {
        Stack() {
          SymbolGlyph($r('sys.symbol.person_crop_circle_fill_1'))
            .fontSize(64)
            .fontColor([$r('app.color.brand_primary')])
          if (profile.avatarUrl.length > 0) {
            Image(profile.avatarUrl)
              .width(76)
              .height(76)
              .borderRadius(38)
              .objectFit(ImageFit.Cover)
          }
        }
        .width(76)
        .height(76)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(38)

        Column({ space: 5 }) {
          Text(profile.displayName)
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('sys.color.font_primary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`@${profile.username}`)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
          if (profile.title.length > 0) {
            Text(profile.title)
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      this.IdentityPills(profile)
      this.ProfileActions(profile)
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private ProfileActions(profile: UserProfile): void {
    if (this.ownProfile) {
      Button($r('app.string.profile_edit_action'), { type: ButtonType.Normal })
        .width('100%')
        .height(44)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('sys.color.comp_background_primary'))
        .border({ width: 1, color: $r('app.color.brand_primary') })
        .borderRadius(14)
        .onClick(this.onEdit)
    } else {
      if (profile.canStartDirectChat()) {
        Button($r('app.string.profile_direct_chat'), { type: ButtonType.Normal })
          .width('100%')
          .height(42)
          .borderRadius(14)
          .enabled(!this.state.busy)
          .onClick((): void => this.onOpenDirectChat(profile.username))
      }
      Row({ space: 8 }) {
        if (profile.canFollow) {
          Button(profile.following ? '取消关注' : '关注', { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
            .enabled(!this.state.busy)
            .onClick((): void => this.onFollowingChange(!profile.following))
        }
        if (profile.canMute) {
          Button(profile.notificationLevel === ProfileNotificationLevel.MUTED ? '取消静音' : '静音',
            { type: ButtonType.Normal })
            .layoutWeight(1)
            .height(40)
            .borderRadius(12)
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
            .height(40)
            .borderRadius(12)
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

  @Builder
  private AboutCard(profile: UserProfile): void {
    Column({ space: 10 }) {
      Text('个人简介')
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (profile.bioExcerpt.length > 0) {
        Text(profile.bioExcerpt)
          .fontSize(14)
          .lineHeight(21)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
      }
      if (profile.location.length > 0) {
        Text(`所在地  ·  ${profile.location}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
      if (profile.website.length > 0) {
        Text(profile.website)
          .fontSize(13)
          .fontColor($r('app.color.brand_primary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private ProfileNavigationRow(
    label: string,
    icon: Resource,
    action: () => void
  ): void {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([$r('app.color.brand_primary')])
      Text(label)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(16)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .onClick(action)
    .accessibilityText(label)
  }

  @Builder
  private ActivityNavigationCard(profile: UserProfile): void {
    Column() {
      this.ProfileNavigationRow(
        this.ownProfile ? '我的 Topic' : 'TA 的 Topic',
        $r('sys.symbol.folder'),
        (): void => this.onOpenTopics(profile.username)
      )
      Divider()
        .margin({ left: 49 })
        .color($r('sys.color.comp_divider'))
      this.ProfileNavigationRow(
        this.ownProfile ? '我的 Reply' : 'TA 的 Reply',
        $r('sys.symbol.message'),
        (): void => this.onOpenReplies(profile.username)
      )
    }
    .width('100%')
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private GroupsCard(groups: Array<ProfileGroup>): void {
    Column({ space: 10 }) {
      Text($r('app.string.profile_groups'))
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(groups, (group: ProfileGroup): void => {
          Row({ space: 6 }) {
            if (group.flairUrl.length > 0) {
              Image(group.flairUrl)
                .width(18)
                .height(18)
                .objectFit(ImageFit.Contain)
            }
            Text(group.displayName.length > 0 ? group.displayName : group.name)
              .fontSize(12)
              .fontColor($r('sys.color.font_primary'))
          }
          .height(34)
          .padding({ left: 10, right: 10 })
          .margin({ right: 8, bottom: 8 })
          .backgroundColor($r('sys.color.background_secondary'))
          .borderRadius(17)
        }, (group: ProfileGroup): string => group.id.toString())
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius(18)
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private ProfileContent(profile: UserProfile): void {
    Scroll(this.scroller) {
      Column({ space: 12 }) {
        this.ProfileHeaderCard(profile)
        if (profile.bioExcerpt.length > 0 || profile.location.length > 0 || profile.website.length > 0) {
          this.AboutCard(profile)
        }
        this.SummaryCard(profileSummaryPresentationFor(this.state.summary))
        this.ActivityNavigationCard(profile)
        if (this.visibleGroups(profile.groups).length > 0) {
          this.GroupsCard(this.visibleGroups(profile.groups))
        }
        if (this.state.message.length > 0) {
          Text(this.state.message).fontSize(12).fontColor($r('app.color.status_error')).width('100%')
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .edgeEffect(EdgeEffect.Spring)
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
