import { TopicPostActionKind, TopicPostActionState } from '../app/TopicReadingModels';
import { ForumPost, PostReaction } from '../models/ForumModels';
import {
  displayedReactions,
  reactionAccessibilityLabel,
  reactionCount,
  reactionEmojiKey,
  reactionEmojiUrl
} from './TopicReadingPresentation';

@Component
export struct TopicPostActionBar {
  @Prop post: ForumPost;
  @Prop topicId: number = 0;
  @Prop validReactions: Array<string> = [];
  @Prop actionState: TopicPostActionState = TopicPostActionState.idle();
  @Prop bookmarked: boolean = false;
  @Prop editable: boolean = false;
  @Prop replyAvailable: boolean = false;
  @State private moreActionsExpanded: boolean = false;
  onToggleReaction: (postId: number, reaction: string) => void = (
    _postId: number,
    _reaction: string
  ): void => {};
  onOpenReactionUsers: (postId: number) => void = (_postId: number): void => {};
  onToggleBookmark: (postId: number) => void = (_postId: number): void => {};
  onToggleAcceptedAnswer: (postId: number) => void = (_postId: number): void => {};
  onCopyPostLink: (topicId: number, postNumber: number) => void = (
    _topicId: number,
    _postNumber: number
  ): void => {};
  onReport: (post: ForumPost) => void = (_post: ForumPost): void => {};
  onEdit: (postId: number) => void = (_postId: number): void => {};
  onDelete: (postId: number) => void = (_postId: number): void => {};
  onReply: () => void = (): void => {};

  @Builder
  private ReactionSummary(reaction: PostReaction): void {
    Row({ space: 5 }) {
      Image(reactionEmojiUrl(reaction.id))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
      Text(reaction.count.toString())
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.text_link'))
    }
    .height(34)
    .padding({ left: 10, right: 10 })
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(17)
    .margin({ right: 6 })
    .onClick((): void => this.onOpenReactionUsers(this.post.id))
    .accessibilityText(`${reactionAccessibilityLabel(reaction.id)}回应，${reaction.count} 次`)
  }

  @Builder
  private ReactionPicker(): void {
    Menu() {
      ForEach(this.validReactions, (reaction: string) => {
        MenuItem({
          startIcon: reactionEmojiUrl(reaction),
          content: reactionAccessibilityLabel(reaction)
        })
          .enabled(!this.actionState.busy)
          .onClick((): void => this.onToggleReaction(this.post.id, reaction))
      }, (reaction: string): string => reaction)
    }
  }

  private currentReactionId(): string | null {
    const currentReaction: string = this.post.currentUserReaction?.trim() ?? '';
    return currentReaction.length > 0 ? currentReaction : null;
  }

  private triggerReactionId(): string {
    return this.currentReactionId() ?? '+1';
  }

  private hasCustomCurrentReaction(): boolean {
    const currentReaction: string | null = this.currentReactionId();
    return currentReaction !== null && reactionEmojiKey(currentReaction) !== '+1';
  }

  private hasPositiveCurrentReaction(): boolean {
    const currentReaction: string | null = this.currentReactionId();
    return currentReaction !== null && reactionEmojiKey(currentReaction) === '+1';
  }

  private reactionTriggerAccessibilityText(): string {
    const currentReaction: string | null = this.currentReactionId();
    if (currentReaction !== null && reactionEmojiKey(currentReaction) !== '+1') {
      return `已选择${reactionAccessibilityLabel(currentReaction)}回应；点击取消，长按选择其他回应`;
    }
    const positiveCount: number = reactionCount('+1', this.post.reactions);
    if (this.hasPositiveCurrentReaction()) {
      return `已赞同，当前 ${positiveCount} 个赞同；点击取消，长按选择其他回应`;
    }
    return positiveCount > 0
      ? `当前 ${positiveCount} 个赞同；点击赞同，长按选择其他回应`
      : '添加赞同回应，长按选择其他回应';
  }

  @Builder
  private ReactionTrigger(): void {
    Button() {
      Row({ space: 4 }) {
        if (this.hasCustomCurrentReaction()) {
          Image(reactionEmojiUrl(this.triggerReactionId()))
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
        } else {
          SymbolGlyph(reactionCount('+1', this.post.reactions) > 0
            ? $r('sys.symbol.hand_thumbsup_fill')
            : $r('sys.symbol.hand_thumbsup'))
            .fontSize(18)
            .fontColor([this.hasPositiveCurrentReaction()
              ? $r('app.color.reaction_liked')
              : $r('sys.color.font_secondary')])
          if (reactionCount('+1', this.post.reactions) > 0) {
            Text(reactionCount('+1', this.post.reactions).toString())
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.hasPositiveCurrentReaction()
                ? $r('app.color.reaction_liked')
                : $r('sys.color.font_secondary'))
          }
        }
      }
      .justifyContent(FlexAlign.Center)
      .alignItems(VerticalAlign.Center)
    }
    .constraintSize({ minWidth: 36 })
    .padding({ left: 6, right: 6 })
    .height(34)
    .backgroundColor(Color.Transparent)
    .enabled(!this.actionState.busy)
    .onClick((): void => this.onToggleReaction(this.post.id, this.triggerReactionId()))
    .bindContextMenu(this.ReactionPicker(), ResponseType.LongPress, {
      preview: MenuPreviewMode.NONE,
      enableArrow: true
    })
    .accessibilityText(this.reactionTriggerAccessibilityText())
  }

  @Builder
  private CompactActions(): void {
    Row({ space: 0 }) {
      this.ReactionTrigger()
      this.MoreActionsTrigger()
      this.ReplyTrigger()
    }
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private MoreActionsTrigger(): void {
    Button() {
      SymbolGlyph($r('sys.symbol.line_3_horizontal'))
        .fontSize(20)
        .fontColor([this.moreActionsExpanded
          ? $r('app.color.brand_primary')
          : $r('sys.color.font_secondary')])
    }
    .width(36)
    .height(34)
    .backgroundColor(Color.Transparent)
    .onClick((): void => {
      this.moreActionsExpanded = !this.moreActionsExpanded;
    })
    .accessibilityText(this.moreActionsExpanded ? '收起更多操作' : '显示更多操作')
  }

  @Builder
  private ReplyTrigger(): void {
    if (this.replyAvailable) {
      Button() {
        SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
          .fontSize(19)
          .fontColor([$r('sys.color.font_secondary')])
      }
      .width(36)
      .height(34)
      .backgroundColor(Color.Transparent)
      .onClick(this.onReply)
      .accessibilityText('回复此 Post')
    }
  }

  @Builder
  private MoreActions(): void {
    if (this.moreActionsExpanded) {
      Row({ space: 0 }) {
        Button() {
          if (this.bookmarked) {
            SymbolGlyph($r('sys.symbol.bookmark_fill'))
              .fontSize(19)
              .fontColor([$r('app.color.brand_primary')])
          } else {
            SymbolGlyph($r('sys.symbol.bookmark'))
              .fontSize(19)
              .fontColor([$r('sys.color.font_secondary')])
          }
        }
        .width(36)
        .height(34)
        .backgroundColor(Color.Transparent)
        .enabled(!this.actionState.busy)
        .onClick((): void => this.onToggleBookmark(this.post.id))
        .accessibilityText(this.bookmarked ? '取消收藏' : '收藏')
        Button() {
          SymbolGlyph($r('sys.symbol.paperclip'))
            .fontSize(19)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(36)
        .height(34)
        .backgroundColor(Color.Transparent)
        .onClick((): void => this.onCopyPostLink(this.topicId, this.post.postNumber))
        .accessibilityText(`复制 Post #${this.post.postNumber} 链接`)
        Button() {
          SymbolGlyph($r('sys.symbol.flag'))
            .fontSize(19)
            .fontColor([$r('sys.color.font_secondary')])
        }
        .width(36)
        .height(34)
        .backgroundColor(Color.Transparent)
        .enabled(!this.actionState.busy)
        .onClick((): void => this.onReport(this.post))
        .accessibilityText(`举报 Post #${this.post.postNumber}`)
        if (this.post.canAcceptAnswer || this.post.canUnacceptAnswer) {
          Button() {
            SymbolGlyph(this.post.acceptedAnswer
              ? $r('sys.symbol.checkmark_circle_fill')
              : $r('sys.symbol.checkmark_circle'))
              .fontSize(19)
              .fontColor([this.post.acceptedAnswer
                ? $r('app.color.status_warning')
                : $r('app.color.status_success')])
          }
            .width(36)
            .height(34)
            .backgroundColor(Color.Transparent)
            .enabled(!this.actionState.busy)
            .onClick((): void => this.onToggleAcceptedAnswer(this.post.id))
            .accessibilityText(this.post.acceptedAnswer ? '取消采纳此回答' : '采纳此回答')
        }
        if (this.editable) {
          Button() {
            SymbolGlyph($r('sys.symbol.square_and_pencil'))
              .fontSize(19)
              .fontColor([$r('sys.color.font_secondary')])
          }
            .width(36)
            .height(34)
            .backgroundColor(Color.Transparent)
            .enabled(!this.actionState.busy)
            .onClick((): void => this.onEdit(this.post.id))
            .accessibilityText(this.post.postNumber === 1 ? '编辑 Topic' : `编辑 Post #${this.post.postNumber}`)
        }
        if (this.post.canDelete) {
          Button() {
            SymbolGlyph($r('sys.symbol.trash'))
              .fontSize(19)
              .fontColor([$r('app.color.status_error')])
          }
            .width(36)
            .height(34)
            .backgroundColor(Color.Transparent)
            .enabled(!this.actionState.busy)
            .onClick((): void => this.onDelete(this.post.id))
            .accessibilityText(this.post.postNumber === 1 ? '删除 Topic 首帖' : `删除 Post #${this.post.postNumber}`)
        }
      }
      .width('100%')
      .justifyContent(FlexAlign.End)
      .alignItems(VerticalAlign.Center)
    }
  }

  build() {
    Column({ space: 7 }) {
      Row({ space: 6 }) {
        if (this.post.acceptedAnswer || displayedReactions(this.post.reactions).length > 0) {
          Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
            if (this.post.acceptedAnswer) {
              Text($r('app.string.topic_accepted_answer'))
                .height(34)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.status_success'))
                .padding({ left: 10, right: 10 })
                .backgroundColor($r('sys.color.background_secondary'))
                .borderRadius(17)
                .margin({ right: 6 })
                .accessibilityText($r('app.string.topic_accepted_answer_accessibility'))
            }
            ForEach(displayedReactions(this.post.reactions), (reaction: PostReaction) => {
              this.ReactionSummary(reaction)
            }, (reaction: PostReaction): string => reaction.id)
          }
          .layoutWeight(1)
        } else {
          Blank()
            .layoutWeight(1)
        }
        this.CompactActions()
      }
      .width('100%')
      .alignItems(VerticalAlign.Bottom)
      this.MoreActions()
      if (
        this.actionState.postId === this.post.id &&
        this.actionState.busy &&
        this.actionState.kind !== TopicPostActionKind.REACTION
      ) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(18)
            .height(18)
          Text($r('app.string.topic_server_state_syncing'))
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
      } else if (this.actionState.postId === this.post.id && this.actionState.message.length > 0) {
        Text(this.actionState.message)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 8, right: 8 })
  }
}
