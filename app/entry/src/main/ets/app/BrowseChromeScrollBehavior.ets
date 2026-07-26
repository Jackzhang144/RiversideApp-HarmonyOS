const DIRECTION_COMMIT_DISTANCE: number = 8;

export enum BrowseChromeScrollIntent {
  KEEP = 'keep',
  SHOW = 'show',
  HIDE = 'hide'
}

export class BrowseChromeScrollBehavior {
  private accumulatedOffset: number = 0;

  public observe(scrollOffset: number, active: boolean): BrowseChromeScrollIntent {
    if (!active || !Number.isFinite(scrollOffset) || scrollOffset === 0) {
      this.accumulatedOffset = 0;
      return BrowseChromeScrollIntent.KEEP;
    }

    if (
      (this.accumulatedOffset > 0 && scrollOffset < 0) ||
      (this.accumulatedOffset < 0 && scrollOffset > 0)
    ) {
      this.accumulatedOffset = scrollOffset;
    } else {
      this.accumulatedOffset += scrollOffset;
    }

    if (this.accumulatedOffset >= DIRECTION_COMMIT_DISTANCE) {
      this.accumulatedOffset = 0;
      return BrowseChromeScrollIntent.HIDE;
    }
    if (this.accumulatedOffset <= -DIRECTION_COMMIT_DISTANCE) {
      this.accumulatedOffset = 0;
      return BrowseChromeScrollIntent.SHOW;
    }
    return BrowseChromeScrollIntent.KEEP;
  }

  public reset(): void {
    this.accumulatedOffset = 0;
  }
}
