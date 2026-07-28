import { motion } from '@kit.MultimodalAwarenessKit';
import { ForumPost } from '../models/ForumModels';
import {
  topicProgressPreview,
  TopicProgressPreview,
  TopicProgressRailSide,
  topicProgressRailSideForHoldingStatus,
  topicProgressRatio,
  topicProgressTargetPostNumber
} from './TopicReadingPresentation';

const PROGRESS_RAIL_WIDTH: number = 44;
const PROGRESS_RAIL_HEIGHT: number = 196;
const PROGRESS_TRACK_HEIGHT: number = 148;
const PROGRESS_TRACK_WIDTH: number = 4;
const PROGRESS_THUMB_SIZE: number = 14;
const PROGRESS_PREVIEW_WIDTH: number = 190;
const PROGRESS_PREVIEW_HEIGHT: number = 154;
const PROGRESS_PANEL_WIDTH: number = 242;
const PROGRESS_PANEL_HEIGHT: number = 220;
const PROGRESS_PANEL_GAP: number = 8;
const COMPACT_TAB_WIDTH: number = 20;
const COMPACT_TAB_HEIGHT: number = 70;
const COMPACT_TRACK_HEIGHT: number = 38;
const COMPACT_TRACK_WIDTH: number = 4;
const PROGRESS_LONG_PRESS_DURATION: number = 500;
const PROGRESS_PREVIEW_DISMISS_DELAY: number = 1000;
const HANDEDNESS_ANIMATION_DURATION: number = 300;

@Component
export struct TopicReadingProgressRail {
  @Prop posts: Array<ForumPost> = [];
  @Prop currentPostNumber: number = 1;
  @Prop highestPostNumber: number = 1;
  @Prop jumpBusy: boolean = false;
  @Prop jumpMessage: string = '';
  @Prop jumpTargetPostNumber: number = 1;
  onJump: (postNumber: number) => void = (_postNumber: number): void => {};
  onRetry: () => void = (): void => {};

  @State private expanded: boolean = false;
  @State private previewVisible: boolean = false;
  @State private previewPostNumber: number = 1;
  @State private railSide: TopicProgressRailSide = TopicProgressRailSide.RIGHT;
  private gestureActive: boolean = false;
  private dragActive: boolean = false;
  private dragStartTrackPosition: number = 0;
  private pendingRailSide: TopicProgressRailSide | null = null;
  private dismissTimer: number = -1;
  private holdingHandSubscribed: boolean = false;
  private readonly holdingHandCallback: Callback<motion.HoldingHandStatus> = (
    status: motion.HoldingHandStatus
  ): void => {
    this.handleHoldingHandChange(status);
  };

  aboutToAppear(): void {
    this.subscribeToHoldingHand();
  }

  aboutToDisappear(): void {
    this.clearDismissTimer();
    this.unsubscribeFromHoldingHand();
  }

  private subscribeToHoldingHand(): void {
    if (this.holdingHandSubscribed || !canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      return;
    }
    try {
      motion.on('holdingHandChanged', this.holdingHandCallback);
      this.holdingHandSubscribed = true;
    } catch (_error) {
      this.holdingHandSubscribed = false;
    }
  }

  private unsubscribeFromHoldingHand(): void {
    if (!this.holdingHandSubscribed || !canIUse('SystemCapability.MultimodalAwareness.Motion')) {
      return;
    }
    try {
      motion.off('holdingHandChanged', this.holdingHandCallback);
    } catch (_error) {
    }
    this.holdingHandSubscribed = false;
  }

  private handleHoldingHandChange(status: motion.HoldingHandStatus): void {
    if (status !== motion.HoldingHandStatus.LEFT_HAND_HELD &&
      status !== motion.HoldingHandStatus.RIGHT_HAND_HELD) {
      return;
    }
    const nextSide: TopicProgressRailSide = topicProgressRailSideForHoldingStatus(
      status,
      this.railSide
    );
    if (this.gestureActive) {
      this.pendingRailSide = nextSide;
      return;
    }
    this.applyRailSide(nextSide);
  }

  private applyRailSide(side: TopicProgressRailSide): void {
    if (side === this.railSide) {
      return;
    }
    this.getUIContext().animateTo({
      duration: HANDEDNESS_ANIMATION_DURATION,
      curve: Curve.EaseInOut
    }, (): void => {
      this.railSide = side;
    });
  }

  private applyPendingRailSide(): void {
    const pendingSide: TopicProgressRailSide | null = this.pendingRailSide;
    this.pendingRailSide = null;
    if (pendingSide !== null) {
      this.applyRailSide(pendingSide);
    }
  }

  private clearDismissTimer(): void {
    if (this.dismissTimer >= 0) {
      clearTimeout(this.dismissTimer);
      this.dismissTimer = -1;
    }
  }

  private normalizedCurrentPostNumber(): number {
    return Math.max(1, Math.min(this.highestPostNumber, this.currentPostNumber));
  }

  private displayedPostNumber(): number {
    if (this.previewVisible) {
      return this.previewPostNumber;
    }
    if (this.jumpBusy || this.jumpMessage.length > 0) {
      return Math.max(1, Math.min(this.highestPostNumber, this.jumpTargetPostNumber));
    }
    return this.normalizedCurrentPostNumber();
  }

  private displayedPreview(): TopicProgressPreview {
    return topicProgressPreview(this.posts, this.displayedPostNumber());
  }

  private railPositionPostNumber(): number {
    return this.previewVisible ? this.previewPostNumber : this.normalizedCurrentPostNumber();
  }

  private railPositionRatio(): number {
    return topicProgressRatio(this.railPositionPostNumber(), this.highestPostNumber);
  }

  private progressFillHeight(): number {
    return PROGRESS_TRACK_HEIGHT * this.railPositionRatio();
  }

  private thumbOffset(): number {
    return (PROGRESS_TRACK_HEIGHT - PROGRESS_THUMB_SIZE) * this.railPositionRatio();
  }

  private compactFillHeight(): number {
    return COMPACT_TRACK_HEIGHT *
      topicProgressRatio(this.normalizedCurrentPostNumber(), this.highestPostNumber);
  }

  private updatePreview(positionY: number): void {
    this.clearDismissTimer();
    this.previewPostNumber = topicProgressTargetPostNumber(
      positionY,
      PROGRESS_TRACK_HEIGHT,
      this.highestPostNumber
    );
    this.previewVisible = true;
  }

  private beginLongPress(): void {
    this.clearDismissTimer();
    this.gestureActive = true;
    this.dragActive = false;
    this.previewPostNumber = this.normalizedCurrentPostNumber();
    this.previewVisible = true;
    this.expanded = true;
    this.dragStartTrackPosition = PROGRESS_TRACK_HEIGHT *
      topicProgressRatio(this.previewPostNumber, this.highestPostNumber);
  }

  private beginDrag(): void {
    if (!this.gestureActive) {
      return;
    }
    this.dragActive = true;
    this.dragStartTrackPosition = PROGRESS_TRACK_HEIGHT *
      topicProgressRatio(this.previewPostNumber, this.highestPostNumber);
  }

  private updateDrag(offsetY: number): void {
    if (!this.gestureActive || !this.dragActive) {
      return;
    }
    this.updatePreview(this.dragStartTrackPosition + offsetY);
  }

  private finishGesture(commitJump: boolean): void {
    if (!this.gestureActive) {
      return;
    }
    const shouldJump: boolean = commitJump && this.dragActive;
    this.gestureActive = false;
    this.dragActive = false;
    if (shouldJump) {
      this.onJump(this.previewPostNumber);
    }
    this.applyPendingRailSide();
    this.scheduleCollapse();
  }

  private scheduleCollapse(): void {
    this.clearDismissTimer();
    this.dismissTimer = setTimeout((): void => {
      this.dismissTimer = -1;
      if (this.gestureActive) {
        return;
      }
      this.previewVisible = false;
      this.expanded = false;
    }, PROGRESS_PREVIEW_DISMISS_DELAY);
  }

  private compactBorderRadius(): BorderRadiuses {
    return this.railSide === TopicProgressRailSide.LEFT
      ? { topRight: COMPACT_TAB_WIDTH / 2, bottomRight: COMPACT_TAB_WIDTH / 2 }
      : { topLeft: COMPACT_TAB_WIDTH / 2, bottomLeft: COMPACT_TAB_WIDTH / 2 };
  }

  @Builder
  private PreviewCard(): void {
    Column({ space: 8 }) {
      Row({ space: 6 }) {
        Text(`#${this.displayedPreview().postNumber}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.brand_primary'))
        Text(`/ ${this.highestPostNumber}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
        Blank()
        if (this.jumpBusy) {
          LoadingProgress()
            .width(18)
            .height(18)
        }
      }
      .width('100%')

      Text(this.displayedPreview().authorLabel)
        .width('100%')
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.displayedPreview().loaded
          ? $r('sys.color.font_secondary')
          : $r('sys.color.font_tertiary'))
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(this.jumpBusy
        ? `正在定位 #${this.jumpTargetPostNumber}`
        : this.displayedPreview().excerpt)
        .width('100%')
        .fontSize(13)
        .fontColor($r('sys.color.font_primary'))
        .lineHeight(19)
        .maxLines(3)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .layoutWeight(1)

      if (this.jumpMessage.length > 0) {
        Row({ space: 6 }) {
          Text(this.jumpMessage)
            .fontSize(11)
            .fontColor($r('app.color.status_error'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Button() {
            SymbolGlyph($r('sys.symbol.arrow_clockwise'))
              .fontSize(16)
              .fontColor([$r('app.color.brand_primary')])
          }
          .width(30)
          .height(30)
          .padding(0)
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(15)
          .onClick(this.onRetry)
          .accessibilityText(`重试定位 Post #${this.jumpTargetPostNumber}`)
        }
        .width('100%')
      }
    }
    .width(PROGRESS_PREVIEW_WIDTH)
    .height(PROGRESS_PREVIEW_HEIGHT)
    .padding(14)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius($r('app.float.card_corner_radius'))
  }

  @Builder
  private Rail(): void {
    Column({ space: 8 }) {
      Text(`#${this.railPositionPostNumber()}`)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(1)
        .textAlign(TextAlign.Center)

      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width(PROGRESS_TRACK_WIDTH)
          .height(PROGRESS_TRACK_HEIGHT)
          .backgroundColor($r('sys.color.comp_divider'))
          .borderRadius(PROGRESS_TRACK_WIDTH / 2)

        Column()
          .width(PROGRESS_TRACK_WIDTH)
          .height(this.progressFillHeight())
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius(PROGRESS_TRACK_WIDTH / 2)

        Circle()
          .width(PROGRESS_THUMB_SIZE)
          .height(PROGRESS_THUMB_SIZE)
          .fill($r('app.color.brand_primary'))
          .border({ width: 3, color: $r('sys.color.comp_background_primary') })
          .position({
            x: (PROGRESS_RAIL_WIDTH - PROGRESS_THUMB_SIZE) / 2,
            y: this.thumbOffset()
          })
      }
      .width(PROGRESS_RAIL_WIDTH)
      .height(PROGRESS_TRACK_HEIGHT)

      Text(this.highestPostNumber.toString())
        .fontSize(10)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
        .textAlign(TextAlign.Center)
    }
    .width(PROGRESS_RAIL_WIDTH)
    .height(PROGRESS_RAIL_HEIGHT)
    .padding({ top: 8, bottom: 8 })
    .justifyContent(FlexAlign.SpaceBetween)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(PROGRESS_RAIL_WIDTH / 2)
    .accessibilityGroup(true)
    .accessibilityText(
      `Topic 阅读进度，当前 Post ${this.railPositionPostNumber()}，共 ${this.highestPostNumber}`
    )
  }

  @Builder
  private CompactTab(): void {
    Column() {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width(COMPACT_TRACK_WIDTH)
          .height(COMPACT_TRACK_HEIGHT)
          .backgroundColor($r('sys.color.comp_divider'))
          .borderRadius(COMPACT_TRACK_WIDTH / 2)
        Column()
          .width(COMPACT_TRACK_WIDTH)
          .height(this.compactFillHeight())
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius(COMPACT_TRACK_WIDTH / 2)
      }
      .width(COMPACT_TRACK_WIDTH)
      .height(COMPACT_TRACK_HEIGHT)
      Text(`#${this.normalizedCurrentPostNumber()}`)
        .fontSize(8)
        .fontColor($r('sys.color.font_tertiary'))
        .maxLines(1)
    }
    .width(COMPACT_TAB_WIDTH)
    .height(COMPACT_TAB_HEIGHT)
    .padding({ top: 8, bottom: 8 })
    .justifyContent(FlexAlign.SpaceBetween)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(this.compactBorderRadius())
    .shadow(ShadowStyle.OUTER_DEFAULT_SM)
    .accessibilityGroup(true)
    .accessibilityText(
      `Topic 阅读进度，当前 Post ${this.normalizedCurrentPostNumber()}，共 ${this.highestPostNumber}，长按并拖动以跳转`
    )
  }

  @Builder
  private ExpandedPanel(): void {
    Row({ space: PROGRESS_PANEL_GAP }) {
      if (this.railSide === TopicProgressRailSide.LEFT) {
        this.Rail()
        this.PreviewCard()
      } else {
        this.PreviewCard()
        this.Rail()
      }
    }
    .width(PROGRESS_PANEL_WIDTH)
    .height(PROGRESS_PANEL_HEIGHT)
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ProgressControl(): void {
    Column() {
      if (this.expanded) {
        this.ExpandedPanel()
      } else {
        this.CompactTab()
      }
    }
    .width(this.expanded ? PROGRESS_PANEL_WIDTH : COMPACT_TAB_WIDTH)
    .height(this.expanded ? PROGRESS_PANEL_HEIGHT : COMPACT_TAB_HEIGHT)
    .gesture(
      GestureGroup(
        GestureMode.Sequence,
        LongPressGesture({ duration: PROGRESS_LONG_PRESS_DURATION })
          .onAction((): void => {
            this.beginLongPress();
          }),
        PanGesture({ fingers: 1, direction: PanDirection.Vertical, distance: 1 })
          .onActionStart((): void => {
            this.beginDrag();
          })
          .onActionUpdate((event: GestureEvent): void => {
            this.updateDrag(event.offsetY);
          })
          .onActionEnd((): void => {
            this.finishGesture(true);
          })
          .onActionCancel((): void => {
            this.finishGesture(false);
          })
      )
        .onCancel((): void => {
          this.finishGesture(false);
        })
    )
  }

  build() {
    if (this.highestPostNumber > 1 && this.posts.length > 0) {
      Stack({
        alignContent: this.railSide === TopicProgressRailSide.LEFT
          ? Alignment.Start
          : Alignment.End
      }) {
        this.ProgressControl()
      }
      .width('100%')
      .height('100%')
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
