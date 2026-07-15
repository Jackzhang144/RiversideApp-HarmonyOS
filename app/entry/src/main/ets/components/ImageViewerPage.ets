import {
  ImageViewerPresentation,
  ImageViewerState,
  ImageViewerStateKind
} from '../models/ImageViewerModels';

@Component
export struct ImageViewerPage {
  @Require @Prop state: ImageViewerState;
  onCopyUrl: () => void = (): void => {};
  onOpenExternally: () => void = (): void => {};
  onSave: () => void = (): void => {};

  private presentation(): ImageViewerPresentation {
    return new ImageViewerPresentation(this.state);
  }

  build() {
    Column({ space: 16 }) {
      Column() {
        Image(this.presentation().imageSource())
          .width('100%')
          .height('100%')
          .objectFit(ImageFit.Contain)
          .interpolation(ImageInterpolation.High)
          .accessibilityText(this.state.title.length > 0 ? this.state.title : '查看原图')
      }
      .layoutWeight(1)
      .width('100%')
      .backgroundColor($r('app.color.image_viewer_surface'))
      .borderRadius($r('app.float.card_corner_radius'))

      if (this.presentation().statusText().length > 0) {
        Row({ space: 8 }) {
          if (
            this.state.kind === ImageViewerStateKind.PREPARING ||
            this.state.kind === ImageViewerStateKind.SAVING
          ) {
            LoadingProgress()
              .width(20)
              .height(20)
          }
          Text(this.presentation().statusText())
            .fontSize(13)
            .fontColor(this.state.kind === ImageViewerStateKind.ERROR
              ? $r('app.color.status_error')
              : $r('sys.color.font_secondary'))
            .layoutWeight(1)
        }
        .width('100%')
      }

      Row({ space: 10 }) {
        Button($r('app.string.image_save'))
          .width('32%')
          .height(46)
          .enabled(this.presentation().canSave())
          .onClick(this.onSave)
        Button($r('app.string.action_copy_link'))
          .layoutWeight(1)
          .height(46)
          .enabled(this.presentation().canCopyUrl())
          .onClick(this.onCopyUrl)
        Button($r('app.string.action_open_external'))
          .layoutWeight(1)
          .height(46)
          .enabled(this.presentation().canOpenExternally())
          .onClick(this.onOpenExternally)
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
  }
}
