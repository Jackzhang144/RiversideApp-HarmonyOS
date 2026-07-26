import { TopicPostActionKind, TopicPostActionState } from '../app/TopicReadingModels';
import {
  ForumPoll,
  ForumPollOption,
  ForumPollType,
  ForumPollVote
} from '../models/PollModels';
import {
  pollTypeLabel,
  rankedPollVote,
  savedRankedOptionIds,
  toggledPollOptionIds,
  toggledRankedOptionIds
} from './PollPresentation';

@Component
export struct PostPollCard {
  @Prop postId: number = 0;
  @Prop @Watch('synchronizeFromPoll') poll: ForumPoll;
  @Prop actionState: TopicPostActionState = TopicPostActionState.idle();
  @Prop authenticated: boolean = false;
  @State private selectedOptionIds: Array<string> = [];
  @State private rankedOptionIds: Array<string> = [];
  @State private showResults: boolean = false;
  onVote: (postId: number, pollName: string, vote: ForumPollVote) => void = (
    _postId: number,
    _pollName: string,
    _vote: ForumPollVote
  ): void => {};
  onRemoveVote: (postId: number, pollName: string) => void = (
    _postId: number,
    _pollName: string
  ): void => {};
  onLogin: () => void = (): void => {};

  aboutToAppear(): void {
    this.synchronizeFromPoll();
  }

  private synchronizeFromPoll(): void {
    this.selectedOptionIds = Array.from(this.poll.vote.optionIds);
    this.rankedOptionIds = savedRankedOptionIds(this.poll);
    this.showResults = this.poll.isClosed() ||
      (this.poll.hasSavedVote() && this.poll.hasResults());
  }

  private isBusy(): boolean {
    return this.actionState.kind === TopicPostActionKind.POLL &&
      this.actionState.postId === this.postId &&
      this.actionState.busy;
  }

  private errorMessage(): string {
    if (
      this.actionState.kind !== TopicPostActionKind.POLL ||
      this.actionState.postId !== this.postId
    ) {
      return '';
    }
    return this.actionState.message;
  }

  private canInteract(): boolean {
    return !this.poll.isClosed() && !this.isBusy();
  }

  private ensureAuthenticated(): boolean {
    if (this.authenticated) {
      return true;
    }
    this.onLogin();
    return false;
  }

  private selectImmediateOption(option: ForumPollOption): void {
    if (!this.canInteract() || !this.ensureAuthenticated()) {
      return;
    }
    if (this.poll.vote.includes(option.id)) {
      this.onRemoveVote(this.postId, this.poll.name);
      return;
    }
    this.onVote(this.postId, this.poll.name, ForumPollVote.options([option.id]));
  }

  private toggleMultipleOption(option: ForumPollOption): void {
    if (!this.canInteract() || !this.ensureAuthenticated()) {
      return;
    }
    this.selectedOptionIds = toggledPollOptionIds(this.selectedOptionIds, option.id);
  }

  private toggleRankedOption(option: ForumPollOption): void {
    if (!this.canInteract() || !this.ensureAuthenticated()) {
      return;
    }
    this.rankedOptionIds = toggledRankedOptionIds(this.rankedOptionIds, option.id);
  }

  private submitSelection(): void {
    if (!this.canInteract() || !this.ensureAuthenticated()) {
      return;
    }
    const vote: ForumPollVote = this.poll.type === ForumPollType.RANKED_CHOICE
      ? rankedPollVote(this.poll.options, this.rankedOptionIds)
      : ForumPollVote.options(this.selectedOptionIds);
    if (this.poll.canSubmit(vote)) {
      this.onVote(this.postId, this.poll.name, vote);
    }
  }

  private selectionIsValid(): boolean {
    const vote: ForumPollVote = this.poll.type === ForumPollType.RANKED_CHOICE
      ? rankedPollVote(this.poll.options, this.rankedOptionIds)
      : ForumPollVote.options(this.selectedOptionIds);
    return this.poll.canSubmit(vote);
  }

  private rankFor(option: ForumPollOption): number {
    const index: number = this.rankedOptionIds.indexOf(option.id);
    return index < 0 ? 0 : index + 1;
  }

  private toggleResults(): void {
    this.getUIContext().animateTo({
      duration: 180,
      curve: Curve.EaseOut
    }, (): void => {
      this.showResults = !this.showResults;
    });
  }

  private choiceSelected(option: ForumPollOption): boolean {
    return this.poll.type === ForumPollType.MULTIPLE
      ? this.selectedOptionIds.includes(option.id)
      : this.poll.vote.includes(option.id);
  }

  private hasRankedWinner(): boolean {
    return (this.poll.rankedChoiceOutcome?.winnerText.length ?? 0) > 0;
  }

  @Builder
  private PollHeader(): void {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text(this.poll.title.length > 0 ? this.poll.title : '投票')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('sys.color.font_primary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(`${pollTypeLabel(this.poll)} · ${this.poll.voters} 人参与`)
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 5 }) {
        Circle({ width: 6, height: 6 })
          .fill(this.poll.isClosed()
            ? $r('sys.color.font_tertiary')
            : $r('app.color.status_success'))
        Text(this.poll.isClosed() ? '已结束' : '进行中')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.poll.isClosed()
            ? $r('sys.color.font_secondary')
            : $r('app.color.status_success'))
      }
      .height(26)
      .padding({ left: 9, right: 9 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(13)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private ChoiceIndicator(option: ForumPollOption): void {
    SymbolGlyph(this.choiceSelected(option)
      ? $r('sys.symbol.checkmark_circle_fill')
      : $r('sys.symbol.circle'))
      .fontSize(21)
      .fontColor([this.choiceSelected(option)
        ? $r('app.color.brand_primary')
        : $r('sys.color.font_tertiary')])
  }

  @Builder
  private ChoiceRow(option: ForumPollOption): void {
    Button() {
      Row({ space: 10 }) {
        this.ChoiceIndicator(option)
        Text(option.text)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Start)
          .layoutWeight(1)
          .maxLines(3)
        if (this.choiceSelected(option)) {
          Text('已选')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_primary'))
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .constraintSize({ minHeight: 48 })
    .backgroundColor(
      this.choiceSelected(option)
        ? $r('app.color.brand_tint_surface')
        : $r('sys.color.comp_background_primary')
    )
    .border({
      width: 1,
      color: this.choiceSelected(option)
        ? $r('app.color.brand_primary')
        : $r('sys.color.comp_divider')
    })
    .borderRadius(12)
    .animation({ duration: 160, curve: Curve.EaseOut })
    .enabled(this.canInteract())
    .onClick((): void => {
      if (this.poll.type === ForumPollType.MULTIPLE) {
        this.toggleMultipleOption(option);
      } else {
        this.selectImmediateOption(option);
      }
    })
    .accessibilityText(
      `${option.text}${this.choiceSelected(option) ? '，已选择' : '，未选择'}`
    )
  }

  @Builder
  private RankedChoiceRow(option: ForumPollOption): void {
    Button() {
      Row({ space: 10 }) {
        Stack() {
          if (this.rankFor(option) > 0) {
            Text(this.rankFor(option).toString())
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(Color.White)
          } else {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(14)
              .fontColor([$r('sys.color.font_secondary')])
          }
        }
        .width(28)
        .height(28)
        .borderRadius(14)
        .backgroundColor(this.rankFor(option) > 0
          ? $r('app.color.brand_primary')
          : $r('sys.color.background_secondary'))
        Text(option.text)
          .fontSize(14)
          .fontColor($r('sys.color.font_primary'))
          .textAlign(TextAlign.Start)
          .layoutWeight(1)
          .maxLines(3)
        if (this.rankFor(option) > 0) {
          Text('再次点击移除')
            .fontSize(10)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .width('100%')
      .padding({ left: 12, right: 12 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .constraintSize({ minHeight: 50 })
    .backgroundColor(this.rankFor(option) > 0
      ? $r('app.color.brand_tint_surface')
      : $r('sys.color.comp_background_primary'))
    .border({
      width: 1,
      color: this.rankFor(option) > 0
        ? $r('app.color.brand_primary')
        : $r('sys.color.comp_divider')
    })
    .borderRadius(12)
    .animation({ duration: 160, curve: Curve.EaseOut })
    .enabled(this.canInteract())
    .onClick((): void => this.toggleRankedOption(option))
    .accessibilityText(
      this.rankFor(option) > 0
        ? `${option.text}，当前第 ${this.rankFor(option)} 位；点击移除`
        : `${option.text}；点击加入排序`
    )
  }

  @Builder
  private ResultRow(option: ForumPollOption): void {
    Column({ space: 6 }) {
      Row({ space: 8 }) {
        if (this.poll.vote.includes(option.id) || this.poll.vote.rankFor(option.id) > 0) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(17)
            .fontColor([$r('app.color.brand_primary')])
        }
        Text(option.text)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
          .maxLines(2)
        Text(`${option.votes ?? 0} · ${this.poll.resultPercentage(option)}%`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')

      Progress({ value: this.poll.resultPercentage(option), total: 100, type: ProgressType.Linear })
        .width('100%')
        .height(6)
        .color($r('app.color.brand_primary'))
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(3)
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY)
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(12)
    .accessibilityText(
      `${option.text}，${option.votes ?? 0} 票，${this.poll.resultPercentage(option)}%`
    )
  }

  @Builder
  private RankedOutcome(): void {
    if (this.poll.rankedChoiceOutcome?.isAvailable() ?? false) {
      Row({ space: 7 }) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(18)
          .fontColor([$r('app.color.status_warning')])
        Text(this.hasRankedWinner()
          ? `胜出：${this.poll.rankedChoiceOutcome?.winnerText ?? ''}`
          : `并列：${this.poll.rankedChoiceOutcome?.tiedOptionTexts.join('、') ?? ''}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
          .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor($r('app.color.brand_tint_surface'))
      .borderRadius(12)
    }
  }

  @Builder
  private PollResults(): void {
    Column({ space: 8 }) {
      this.RankedOutcome()
      if (this.poll.options.some((option: ForumPollOption): boolean => option.votes !== null)) {
        ForEach(this.poll.resultOptions(), (option: ForumPollOption) => {
          this.ResultRow(option)
        }, (option: ForumPollOption): string => option.id)
      } else if (!(this.poll.rankedChoiceOutcome?.isAvailable() ?? false)) {
        Text('结果将在满足投票设置后显示')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 10, bottom: 10 })
      }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY)
  }

  @Builder
  private PollChoices(): void {
    Column({ space: 8 }) {
      ForEach(this.poll.options, (option: ForumPollOption) => {
        if (this.poll.type === ForumPollType.RANKED_CHOICE) {
          this.RankedChoiceRow(option)
        } else {
          this.ChoiceRow(option)
        }
      }, (option: ForumPollOption): string => option.id)
      if (
        this.poll.type === ForumPollType.MULTIPLE ||
        this.poll.type === ForumPollType.RANKED_CHOICE
      ) {
        Button(this.poll.hasSavedVote() ? '更新投票' : '提交投票')
          .height(38)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.brand_primary'))
          .borderRadius(19)
          .enabled(this.canInteract() && this.selectionIsValid())
          .onClick((): void => this.submitSelection())
          .accessibilityText(this.poll.hasSavedVote() ? '更新投票选择' : '提交投票选择')
      }
    }
    .width('100%')
    .transition(TransitionEffect.OPACITY)
  }

  @Builder
  private PollFooter(): void {
    Row({ space: 6 }) {
      if (this.poll.hasResults() && !this.poll.isClosed()) {
        Button(this.showResults ? '返回投票' : '查看结果')
          .height(34)
          .fontSize(12)
          .fontColor($r('app.color.text_link'))
          .backgroundColor(Color.Transparent)
          .onClick((): void => this.toggleResults())
      }
      Blank()
      if (this.poll.hasSavedVote() && !this.poll.isClosed()) {
        Button('撤销投票')
          .height(34)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .backgroundColor(Color.Transparent)
          .enabled(!this.isBusy())
          .onClick((): void => {
            if (this.ensureAuthenticated()) {
              this.onRemoveVote(this.postId, this.poll.name);
            }
          })
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 10 }) {
      this.PollHeader()
      if (this.showResults) {
        this.PollResults()
      } else {
        this.PollChoices()
      }
      this.PollFooter()
      if (this.isBusy()) {
        Row({ space: 7 }) {
          LoadingProgress()
            .width(17)
            .height(17)
            .color($r('app.color.brand_primary'))
          Text('正在提交投票')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
        .width('100%')
      } else if (this.errorMessage().length > 0) {
        Text(this.errorMessage())
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_secondary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(14)
    .accessibilityText(`${this.poll.title.length > 0 ? this.poll.title : '投票'}，${pollTypeLabel(this.poll)}`)
  }
}
