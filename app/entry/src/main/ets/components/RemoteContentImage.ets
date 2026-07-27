@Component
export struct RemoteContentImage {
  @Require @Prop url: string;
  @Prop imageAspectRatio: number = 4 / 3;
  @Prop displayWidth: number = 0;
  @Prop cornerRadius: number = 8;
  @Prop transitionId: string = '';
  @Prop failed: boolean = false;
  @Prop failureText: ResourceStr = '';
  onLoaded: (width: number, height: number) => void =
    (_width: number, _height: number): void => {};
  onError: () => void = (): void => {};
  onOpen: () => void = (): void => {};

  private resolvedAspectRatio(): number {
    return Number.isFinite(this.imageAspectRatio) && this.imageAspectRatio > 0
      ? this.imageAspectRatio
      : 4 / 3;
  }

  build() {
    if (this.failed) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.ohos_photo'))
          .fontSize(18)
          .fontColor([$r('sys.color.font_tertiary')])
        Text(this.failureText)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width(this.displayWidth > 0 ? this.displayWidth : '100%')
      .height(72)
      .justifyContent(FlexAlign.Center)
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius(this.cornerRadius)
    } else {
      Image(this.url)
        .width(this.displayWidth > 0 ? this.displayWidth : '100%')
        .aspectRatio(this.resolvedAspectRatio())
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(this.cornerRadius)
        .clip(true)
        .draggable(false)
        .geometryTransition(this.transitionId)
        .transition(TransitionEffect.OPACITY)
        .onComplete((event): void => {
          if (event !== undefined && event.loadingStatus === 1) {
            this.onLoaded(event.width, event.height);
          }
        })
        .onError((): void => this.onError())
        .onClick((): void => this.onOpen(), 8)
    }
  }
}
