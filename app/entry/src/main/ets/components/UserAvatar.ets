import {
  avatarFlairSize,
  avatarCornerRadius,
  avatarInitial,
  normalizedAvatarSize
} from './UserAvatarPresentation';
import {
  absoluteDiscourseFlairUrl,
  isDiscourseFlairImage,
  normalizedDiscourseFlairColor
} from '../core/DiscourseFlair';

@Component
export struct UserAvatar {
  @Prop avatarUrl: string = '';
  @Prop displayName: string = '';
  @Prop avatarSize: number = 36;
  @Prop interactive: boolean = false;
  @Prop avatarAccessibilityText: string = '';
  @Prop flairUrl: string = '';
  @Prop flairName: string = '';
  @Prop flairBackgroundColor: string = '';
  @Prop flairColor: string = '';
  @Prop showFlair: boolean = true;
  onActivate: () => void = (): void => {};

  private resolvedAccessibilityDescription(): string {
    const explicitDescription: string = this.avatarAccessibilityText.trim();
    if (explicitDescription.length > 0) {
      return explicitDescription;
    }
    const normalizedName: string = this.displayName.trim();
    return normalizedName.length > 0 ? `${normalizedName} 的头像` : '用户头像';
  }

  private shouldShowFlair(): boolean {
    return this.showFlair &&
      (this.flairUrl.trim().length > 0 || normalizedDiscourseFlairColor(this.flairBackgroundColor).length > 0);
  }

  private resolvedFlairAccessibilityDescription(): string {
    const normalizedName: string = this.flairName.trim();
    return normalizedName.length > 0 ? `徽标：${normalizedName}` : '用户徽标';
  }

  @Builder
  private AvatarImage(): void {
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
  }

  @Builder
  private AvatarFlair(): void {
    Stack() {
      if (isDiscourseFlairImage(this.flairUrl)) {
        Image(absoluteDiscourseFlairUrl(this.flairUrl))
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
      } else {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(avatarFlairSize(this.avatarSize) * 0.68)
          .fontColor([
            normalizedDiscourseFlairColor(this.flairColor).length > 0
              ? normalizedDiscourseFlairColor(this.flairColor)
              : Color.White
          ])
      }
    }
    .width(avatarFlairSize(this.avatarSize))
    .height(avatarFlairSize(this.avatarSize))
    .backgroundColor(
      normalizedDiscourseFlairColor(this.flairBackgroundColor).length > 0
        ? normalizedDiscourseFlairColor(this.flairBackgroundColor)
        : isDiscourseFlairImage(this.flairUrl)
          ? $r('sys.color.comp_background_primary')
          : $r('app.color.brand_primary')
    )
    .borderRadius(avatarFlairSize(this.avatarSize) / 2)
    .border({ width: 2, color: $r('sys.color.comp_background_primary') })
    .translate({ x: 2, y: 2 })
    .accessibilityText(this.resolvedFlairAccessibilityDescription())
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      this.AvatarImage()
      if (this.shouldShowFlair()) {
        this.AvatarFlair()
      }
    }
    .width(normalizedAvatarSize(this.avatarSize))
    .height(normalizedAvatarSize(this.avatarSize))
    .clip(false)
    .hitTestBehavior(this.interactive ? HitTestMode.Default : HitTestMode.None)
    .onClick((): void => {
      if (this.interactive) {
        this.onActivate();
      }
    })
    .accessibilityText(this.resolvedAccessibilityDescription())
  }
}
