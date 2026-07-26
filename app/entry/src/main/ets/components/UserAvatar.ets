import {
  avatarCornerRadius,
  avatarInitial,
  normalizedAvatarSize
} from './UserAvatarPresentation';

@Component
export struct UserAvatar {
  @Prop avatarUrl: string = '';
  @Prop displayName: string = '';
  @Prop avatarSize: number = 36;
  @Prop interactive: boolean = false;
  @Prop avatarAccessibilityText: string = '';
  onActivate: () => void = (): void => {};

  private resolvedAccessibilityDescription(): string {
    const explicitDescription: string = this.avatarAccessibilityText.trim();
    if (explicitDescription.length > 0) {
      return explicitDescription;
    }
    const normalizedName: string = this.displayName.trim();
    return normalizedName.length > 0 ? `${normalizedName} 的头像` : '用户头像';
  }

  build() {
    Stack() {
      Text(avatarInitial(this.displayName))
        .width('100%')
        .height('100%')
        .fontSize(normalizedAvatarSize(this.avatarSize) * 0.36)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_tint_surface'))
      if (this.avatarUrl.trim().length > 0) {
        Image(this.avatarUrl)
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Cover)
      }
    }
    .width(normalizedAvatarSize(this.avatarSize))
    .height(normalizedAvatarSize(this.avatarSize))
    .borderRadius(avatarCornerRadius(this.avatarSize))
    .clip(true)
    .hitTestBehavior(this.interactive ? HitTestMode.Default : HitTestMode.None)
    .onClick((): void => {
      if (this.interactive) {
        this.onActivate();
      }
    })
    .accessibilityText(this.resolvedAccessibilityDescription())
  }
}
