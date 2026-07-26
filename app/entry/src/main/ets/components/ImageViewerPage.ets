import {
  ImageViewerPresentation,
  ImageViewerState,
  ImageViewerStateKind
} from '../models/ImageViewerModels';

const IMAGE_VIEWER_MIN_SCALE: number = 1;
const IMAGE_VIEWER_MAX_SCALE: number = 4;
const IMAGE_VIEWER_DOUBLE_TAP_SCALE: number = 2;

enum ImageViewerActionKind {
  SAVE = 'save',
  COPY = 'copy',
  OPEN = 'open'
}

@Component
export struct ImageViewerPage {
  @Require @Prop state: ImageViewerState;
  @State imageScale: number = IMAGE_VIEWER_MIN_SCALE;
  @State imageOffsetX: number = 0;
  @State imageOffsetY: number = 0;
  @State viewportWidth: number = 0;
  @State viewportHeight: number = 0;
  onCopyUrl: () => void = (): void => {};
  onOpenExternally: () => void = (): void => {};
  onSave: () => void = (): void => {};
  private pinchStartScale: number = IMAGE_VIEWER_MIN_SCALE;
  private panStartOffsetX: number = 0;
  private panStartOffsetY: number = 0;

  private presentation(): ImageViewerPresentation {
    return new ImageViewerPresentation(this.state);
  }

  private clamp(value: number, minimum: number, maximum: number): number {
    return Math.min(maximum, Math.max(minimum, value));
  }

  private maxOffsetX(): number {
    return Math.max(0, this.viewportWidth * (this.imageScale - 1) / 2);
  }

  private maxOffsetY(): number {
    return Math.max(0, this.viewportHeight * (this.imageScale - 1) / 2);
  }

  private constrainOffsets(): void {
    this.imageOffsetX = this.clamp(this.imageOffsetX, -this.maxOffsetX(), this.maxOffsetX());
    this.imageOffsetY = this.clamp(this.imageOffsetY, -this.maxOffsetY(), this.maxOffsetY());
  }

  private resetTransform(animated: boolean): void {
    const reset: () => void = (): void => {
      this.imageScale = IMAGE_VIEWER_MIN_SCALE;
      this.imageOffsetX = 0;
      this.imageOffsetY = 0;
    };
    if (!animated) {
      reset();
      return;
    }
    this.getUIContext().animateTo({
      duration: 220,
      curve: Curve.EaseOut
    }, reset);
  }

  private toggleDoubleTapZoom(): void {
    if (this.imageScale > IMAGE_VIEWER_MIN_SCALE + 0.05) {
      this.resetTransform(true);
      return;
    }
    this.getUIContext().animateTo({
      duration: 220,
      curve: Curve.EaseOut
    }, (): void => {
      this.imageScale = IMAGE_VIEWER_DOUBLE_TAP_SCALE;
      this.imageOffsetX = 0;
      this.imageOffsetY = 0;
    });
  }

  private viewerStatusText(): string {
    const status: string = this.presentation().statusText();
    if (status.length > 0) {
      return status;
    }
    if (this.imageScale > IMAGE_VIEWER_MIN_SCALE + 0.05) {
      return `${Math.round(this.imageScale * 100)}%`;
    }
    return '';
  }

  private canPerformAction(kind: ImageViewerActionKind): boolean {
    if (kind === ImageViewerActionKind.SAVE) {
      return this.presentation().canSave();
    }
    if (kind === ImageViewerActionKind.COPY) {
      return this.presentation().canCopyUrl();
    }
    return this.presentation().canOpenExternally();
  }

  private performAction(kind: ImageViewerActionKind): void {
    if (!this.canPerformAction(kind)) {
      return;
    }
    if (kind === ImageViewerActionKind.SAVE) {
      this.onSave();
    } else if (kind === ImageViewerActionKind.COPY) {
      this.onCopyUrl();
    } else {
      this.onOpenExternally();
    }
  }

  @Builder
  private ViewerAction(
    icon: Resource,
    accessibilityText: Resource,
    kind: ImageViewerActionKind
  ): void {
    Button({ type: ButtonType.Normal }) {
      SymbolGlyph(icon)
        .fontSize(21)
        .fontColor([$r('app.color.on_accent')])
        .hitTestBehavior(HitTestMode.None)
    }
    .width(46)
    .height(42)
    .borderRadius(21)
    .backgroundColor(Color.Transparent)
    .enabled(this.canPerformAction(kind))
    .opacity(this.canPerformAction(kind) ? 1 : 0.38)
    .onClick((): void => this.performAction(kind))
    .accessibilityText(accessibilityText)
  }

  @Builder
  private ViewerStatus(): void {
    if (this.viewerStatusText().length > 0) {
      Row({ space: 7 }) {
        if (
          this.state.kind === ImageViewerStateKind.PREPARING ||
          this.state.kind === ImageViewerStateKind.SAVING
        ) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color($r('app.color.on_accent'))
        }
        Text(this.viewerStatusText())
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.state.kind === ImageViewerStateKind.ERROR
            ? $r('app.color.status_error')
            : $r('app.color.image_viewer_secondary_text'))
      }
      .height(34)
      .padding({ left: 12, right: 12 })
      .backgroundColor($r('app.color.image_viewer_control_surface'))
      .border({
        width: 1,
        color: $r('app.color.image_viewer_control_border')
      })
      .borderRadius(17)
    }
  }

  @Builder
  private ViewerToolbar(): void {
    Row() {
      this.ViewerAction(
        $r('sys.symbol.square_and_arrow_down_1'),
        $r('app.string.image_save'),
        ImageViewerActionKind.SAVE
      )
      this.ViewerAction(
        $r('sys.symbol.link'),
        $r('app.string.action_copy_link'),
        ImageViewerActionKind.COPY
      )
      this.ViewerAction(
        $r('sys.symbol.arrow_right_up_and_square'),
        $r('app.string.action_open_external'),
        ImageViewerActionKind.OPEN
      )
    }
    .height(50)
    .padding({ left: 4, right: 4, top: 4, bottom: 4 })
    .backgroundColor($r('app.color.image_viewer_control_surface'))
    .border({
      width: 1,
      color: $r('app.color.image_viewer_control_border')
    })
    .borderRadius(25)
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Image(this.presentation().imageSource())
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Contain)
        .interpolation(ImageInterpolation.High)
        .draggable(false)
        .scale({ x: this.imageScale, y: this.imageScale })
        .translate({ x: this.imageOffsetX, y: this.imageOffsetY })
        .geometryTransition(this.state.transitionId)
        .transition(TransitionEffect.OPACITY)
        .accessibilityText(this.state.title.length > 0 ? this.state.title : '查看原图')

      Stack({ alignContent: Alignment.Bottom }) {
        Column({ space: 10 }) {
          this.ViewerStatus()
          this.ViewerToolbar()
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
        .padding({ left: 16, right: 16, bottom: 18 })
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .clip(true)
    .backgroundColor($r('app.color.image_viewer_surface'))
    .onAreaChange((_oldValue: Area, newValue: Area): void => {
      const width: number = Number(newValue.width);
      const height: number = Number(newValue.height);
      if (Number.isFinite(width) && width > 0) {
        this.viewportWidth = width;
      }
      if (Number.isFinite(height) && height > 0) {
        this.viewportHeight = height;
      }
    })
    .gesture(
      GestureGroup(
        GestureMode.Parallel,
        PinchGesture({ fingers: 2 })
          .onActionStart((): void => {
            this.pinchStartScale = this.imageScale;
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.imageScale = this.clamp(
              this.pinchStartScale * event.scale,
              IMAGE_VIEWER_MIN_SCALE,
              IMAGE_VIEWER_MAX_SCALE
            );
            this.constrainOffsets();
          })
          .onActionEnd((): void => {
            if (this.imageScale <= IMAGE_VIEWER_MIN_SCALE + 0.05) {
              this.resetTransform(true);
            } else {
              this.constrainOffsets();
            }
          }),
        PanGesture({ fingers: 1, direction: PanDirection.All, distance: 2 })
          .onActionStart((): void => {
            this.panStartOffsetX = this.imageOffsetX;
            this.panStartOffsetY = this.imageOffsetY;
          })
          .onActionUpdate((event: GestureEvent): void => {
            if (this.imageScale <= IMAGE_VIEWER_MIN_SCALE + 0.05) {
              return;
            }
            this.imageOffsetX = this.panStartOffsetX + event.offsetX;
            this.imageOffsetY = this.panStartOffsetY + event.offsetY;
            this.constrainOffsets();
          }),
        TapGesture({ count: 2 })
          .onAction((): void => this.toggleDoubleTapZoom())
      )
    )
  }
}
