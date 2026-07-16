@Component
export struct ImmersiveFloatingHeader {
  @Prop title: ResourceStr = '';
  @Prop leadingInset: number = 0;
  @Prop showAction: boolean = false;
  @Prop actionIcon: Resource = $r('sys.symbol.arrow_clockwise');
  @Prop actionEnabled: boolean = true;
  @Prop actionAccessibilityText: Resource = $r('app.string.common_refresh');
  onAction: () => void = (): void => {};

  build() {
    Row({ space: 8 }) {
      if (this.leadingInset > 0) {
        Blank()
          .width(this.leadingInset)
      }
      Text(this.title)
        .height(38)
        .constraintSize({ maxWidth: '72%' })
        .padding({ left: 16, right: 16 })
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_primary'))
        .textAlign(TextAlign.Center)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(19)
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .hitTestBehavior(HitTestMode.None)
      Blank()
      if (this.showAction) {
        Button() {
          SymbolGlyph(this.actionIcon)
            .fontSize(19)
            .fontColor([$r('sys.color.font_primary')])
            .hitTestBehavior(HitTestMode.None)
        }
        .width(38)
        .height(38)
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius(19)
        .border({ width: 1, color: $r('sys.color.comp_divider') })
        .enabled(this.actionEnabled)
        .onClick(this.onAction)
        .accessibilityText(this.actionAccessibilityText)
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 16, right: 16, bottom: 6 })
    .backgroundColor(Color.Transparent)
  }
}
