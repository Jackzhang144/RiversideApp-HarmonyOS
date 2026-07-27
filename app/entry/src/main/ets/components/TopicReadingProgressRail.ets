import { ForumPost } from '../models/ForumModels';
import {
  topicProgressPreview,
  TopicProgressPreview,
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
const PROGRESS_PREVIEW_DISMISS_DELAY: number = 1400;

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

  @State private previewVisible: boolean = false;
  @State private previewPostNumber: number = 1;
  private dismissTimer: number = -1;

  aboutToDisappear(): void {
    this.clearDismissTimer();
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

  private previewCardVisible(): boolean {
    return this.previewVisible || this.jumpBusy || this.jumpMessage.length > 0;
  }

  private progressFillHeight(): number {
    return PROGRESS_TRACK_HEIGHT *
      topicProgressRatio(this.normalizedCurrentPostNumber(), this.highestPostNumber);
  }

  private thumbOffset(): number {
    return (PROGRESS_TRACK_HEIGHT - PROGRESS_THUMB_SIZE) *
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

  private schedulePreviewDismiss(): void {
    this.clearDismissTimer();
    this.dismissTimer = setTimeout((): void => {
      this.dismissTimer = -1;
      this.previewVisible = false;
    }, PROGRESS_PREVIEW_DISMISS_DELAY);
  }

  private handleTrackTouch(event: TouchEvent): void {
    event.stopPropagation();
    const touch = event.touches[0] ?? event.changedTouches[0];
    if (touch === undefined) {
      return;
    }
    if (event.type === TouchType.Down || event.type === TouchType.Move) {
      this.updatePreview(touch.y);
      return;
    }
    if (event.type === TouchType.Up) {
      this.updatePreview(touch.y);
      this.onJump(this.previewPostNumber);
      this.schedulePreviewDismiss();
      return;
    }
    if (event.type === TouchType.Cancel) {
      this.schedulePreviewDismiss();
    }
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
    .opacity(this.previewCardVisible() ? 1 : 0)
    .translate({
      x: this.previewCardVisible() ? 0 : 12
    })
    .animation({ duration: 180, curve: Curve.EaseOut })
    .hitTestBehavior(this.previewCardVisible() ? HitTestMode.Default : HitTestMode.None)
    .accessibilityLevel(this.previewCardVisible() ? 'auto' : 'no-hide-descendants')
  }

  @Builder
  private Rail(): void {
    Column({ space: 8 }) {
      Text(`#${this.normalizedCurrentPostNumber()}`)
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
      .onTouch((event: TouchEvent): void => {
        this.handleTrackTouch(event);
      })

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
      `Topic 阅读进度，当前 Post ${this.normalizedCurrentPostNumber()}，共 ${this.highestPostNumber}`
    )
  }

  build() {
    if (this.highestPostNumber > 1 && this.posts.length > 0) {
      Stack() {
        Column() {
          this.PreviewCard()
        }
        .width(PROGRESS_PREVIEW_WIDTH)
        .height(PROGRESS_PREVIEW_HEIGHT)
        .position({ x: 0, y: (220 - PROGRESS_PREVIEW_HEIGHT) / 2 })
        Column() {
          this.Rail()
        }
        .width(PROGRESS_RAIL_WIDTH)
        .height(PROGRESS_RAIL_HEIGHT)
          .position({ x: 198, y: (220 - PROGRESS_RAIL_HEIGHT) / 2 })
      }
      .width(246)
      .height(220)
      .responseRegion({
        x: this.previewCardVisible() ? 0 : 198,
        y: this.previewCardVisible() ? 0 : (220 - PROGRESS_RAIL_HEIGHT) / 2,
        width: this.previewCardVisible() ? 246 : PROGRESS_RAIL_WIDTH,
        height: this.previewCardVisible() ? 220 : PROGRESS_RAIL_HEIGHT
      })
      .hitTestBehavior(HitTestMode.Transparent)
    }
  }
}
