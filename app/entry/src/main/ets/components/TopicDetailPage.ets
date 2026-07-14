import {
  ReplyComposerState,
  ReplyComposerStateKind,
  TopicReadState,
  TopicReadStateKind
} from '../app/AppShellModel';
import { ForumComposer } from './ForumComposer';
import {
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';
import { Category, ForumPost, PostReaction, Topic, TopicDetail } from '../models/ForumModels';
import {
  categoryLabel,
  displayedReactions,
  reactionAccessibilityLabel,
  reactionEmojiUrl,
  systemActionLabel
} from './TopicReadingPresentation';

@Component
export struct TopicDetailPage {
  @Prop state: TopicReadState = TopicReadState.initial();
  @Prop replyState: ReplyComposerState = ReplyComposerState.closed();
  @Prop categories: Array<Category> = [];
  @Link replySheetVisible: boolean;
  onRetry: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onLoadPrevious: () => void = (): void => {};
  onOpenReply: (postNumber: number | null) => void = (_postNumber: number | null): void => {};
  onToggleReaction: (postId: number, reaction: string) => void = (
    _postId: number,
    _reaction: string
  ): void => {};
  onToggleBookmark: (postId: number) => void = (_postId: number): void => {};
  onOpenSuggestedTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onReadProgress: (postNumber: number) => void = (_postNumber: number): void => {};
  onReplyDraftChange: (draft: string) => void = (_draft: string): void => {};
  onSubmitReply: () => void = (): void => {};
  onDismissReply: () => void = (): void => {};
  onLoginForReply: () => void = (): void => {};
  private readProgressTimer: number = -1;
  private pendingReadPostNumber: number = 0;

  aboutToDisappear(): void {
    if (this.readProgressTimer >= 0) {
      clearTimeout(this.readProgressTimer);
      this.readProgressTimer = -1;
    }
  }

  private scheduleReadProgress(postNumber: number): void {
    this.pendingReadPostNumber = Math.max(this.pendingReadPostNumber, postNumber);
    if (this.readProgressTimer >= 0) {
      clearTimeout(this.readProgressTimer);
    }
    this.readProgressTimer = setTimeout((): void => {
      const targetPostNumber: number = this.pendingReadPostNumber;
      this.pendingReadPostNumber = 0;
      this.readProgressTimer = -1;
      this.onReadProgress(targetPostNumber);
    }, 2000);
  }

  private hasStarterPost(): boolean {
    return this.state.posts.length > 0 && this.state.posts[0].postNumber === 1;
  }

  private visiblePosts(): Array<ForumPost> {
    return this.hasStarterPost() ? this.state.posts.slice(1) : this.state.posts;
  }

  private composerStatus(): ForumComposerStatus {
    if (this.replyState.kind === ReplyComposerStateKind.SUBMITTING) {
      return ForumComposerStatus.SUBMITTING;
    }
    if (this.replyState.kind === ReplyComposerStateKind.CHECKING) {
      return ForumComposerStatus.CHECKING;
    }
    if (this.replyState.kind === ReplyComposerStateKind.ERROR) {
      return ForumComposerStatus.ERROR;
    }
    if (this.replyState.kind === ReplyComposerStateKind.REAUTHENTICATE) {
      return ForumComposerStatus.REAUTHENTICATE;
    }
    return ForumComposerStatus.EDITING;
  }

  private composerPresentation(): ForumComposerPresentation {
    return ForumComposerPresentation.reply(
      this.state.topicId,
      this.state.title,
      this.replyState.replyToPostNumber,
      this.replyState.draft,
      this.composerStatus(),
      this.replyState.message
    );
  }

  @Builder
  private LoadingState(): void {
    Column({ space: 16 }) {
      LoadingProgress()
        .width(40)
        .height(40)
      Text('正在加载 Topic 与首屏 Post')
        .fontSize(16)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private RetryableState(): void {
    Column({ space: 16 }) {
      Text('Topic 加载失败')
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .onClick(this.onRetry)
        .accessibilityText('重新加载 Topic')
    }
    .padding(32)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private TopicStarter(detail: TopicDetail, post: ForumPost | null): void {
    Column({ space: 8 }) {
      ForumContentCard({
        presentation: ForumCardPresentation.topicStarter(detail, post, this.replyState.draft),
        onReply: (postNumber: number | null): void => this.onOpenReply(postNumber)
      })
      if (post !== null) {
        this.PostActions(post)
      }
    }
    .width('100%')
  }

  @Builder
  private TopicMetadata(detail: TopicDetail): void {
    Row({ space: 8 }) {
      Text(categoryLabel(detail.categoryId, this.categories))
        .fontSize(12)
        .fontColor('#2068C9')
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor('#EAF2FF')
        .borderRadius(12)
      if (detail.authorUsername.length > 0) {
        Text(`作者 ${detail.authorUsername}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      Blank()
      Text(`已读 #${this.state.readProgressState.lastReadPostNumber}`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private ReadProgressFeedback(): void {
    if (this.state.readProgressState.busy) {
      Text('正在同步阅读进度')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    } else if (this.state.readProgressState.message.length > 0) {
      Text(this.state.readProgressState.message)
        .fontSize(12)
        .fontColor('#C62828')
        .width('100%')
        .textAlign(TextAlign.Center)
    }
  }

  @Builder
  private Reply(post: ForumPost): void {
    Column({ space: 8 }) {
      if (post.replyToPostNumber !== null) {
        Text(post.replyToUsername === null
          ? `回复 #${post.replyToPostNumber}`
          : `回复 @${post.replyToUsername} · #${post.replyToPostNumber}`)
          .fontSize(12)
          .fontColor('#2068C9')
          .width('100%')
          .padding({ left: 8 })
      }
      ForumContentCard({
        presentation: ForumCardPresentation.reply(post, this.state.canReply),
        onReply: (postNumber: number | null): void => this.onOpenReply(postNumber)
      })
      this.PostActions(post)
    }
    .width('100%')
  }

  @Builder
  private SystemAction(post: ForumPost): void {
    Row({ space: 8 }) {
      SymbolGlyph($r('sys.symbol.info_circle'))
        .fontSize(16)
        .fontColor(['#52606D'])
      Text(`${post.username.length > 0 ? post.username : '系统'} ${systemActionLabel(post.actionCode)}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#52606D')
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#EEF1F4')
    .borderRadius(18)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .accessibilityText(`${post.username} ${systemActionLabel(post.actionCode)}`)
  }

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
        .fontColor('#2068C9')
    }
    .height(34)
    .padding({ left: 10, right: 10 })
    .backgroundColor('#EAF2FF')
    .borderRadius(17)
    .margin({ right: 6, bottom: 6 })
    .accessibilityText(`${reactionAccessibilityLabel(reaction.id)}回应，${reaction.count} 次`)
  }

  @Builder
  private ReactionPicker(post: ForumPost): void {
    Menu() {
      ForEach(this.state.detail?.validReactions ?? [], (reaction: string) => {
        MenuItem({
          startIcon: reactionEmojiUrl(reaction),
          content: reactionAccessibilityLabel(reaction)
        })
          .enabled(!this.state.postActionState.busy)
          .onClick((): void => this.onToggleReaction(post.id, reaction))
      }, (reaction: string): string => reaction)
    }
  }

  @Builder
  private ReactionTrigger(post: ForumPost): void {
    Button() {
      Image(reactionEmojiUrl('+1'))
        .width(18)
        .height(18)
        .objectFit(ImageFit.Contain)
    }
    .width(42)
    .height(34)
    .backgroundColor(post.currentUserReaction === '+1' ? '#317AF7' : '#EAF2FF')
    .margin({ right: 6, bottom: 6 })
    .enabled(!this.state.postActionState.busy)
    .onClick((): void => this.onToggleReaction(post.id, '+1'))
    .bindContextMenu(this.ReactionPicker(post), ResponseType.LongPress, {
      preview: MenuPreviewMode.NONE,
      enableArrow: true
    })
    .accessibilityText(
      post.currentUserReaction === '+1'
        ? '取消赞同回应，长按选择其他回应'
        : '添加赞同回应，长按选择其他回应'
    )
  }

  @Builder
  private PostActions(post: ForumPost): void {
    Column({ space: 7 }) {
      Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
        ForEach(displayedReactions(post.reactions), (reaction: PostReaction) => {
          this.ReactionSummary(reaction)
        }, (reaction: PostReaction): string => reaction.id)
        this.ReactionTrigger(post)
        Button() {
          if (post.bookmarked) {
            SymbolGlyph($r('sys.symbol.bookmark_fill'))
              .fontSize(18)
              .fontColor(['#FFFFFF'])
          } else {
            SymbolGlyph($r('sys.symbol.bookmark'))
              .fontSize(18)
              .fontColor(['#2068C9'])
          }
        }
        .width(42)
        .height(34)
        .backgroundColor(post.bookmarked ? '#317AF7' : '#EAF2FF')
        .margin({ right: 6, bottom: 6 })
        .enabled(!this.state.postActionState.busy)
        .onClick((): void => this.onToggleBookmark(post.id))
        .accessibilityText(post.bookmarked ? '取消收藏' : '收藏')
      }
      .width('100%')
      if (this.state.postActionState.postId === post.id && this.state.postActionState.busy) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(18)
            .height(18)
          Text('正在同步服务端状态')
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
      } else if (
        this.state.postActionState.postId === post.id &&
        this.state.postActionState.message.length > 0
      ) {
        Text(this.state.postActionState.message)
          .fontSize(12)
          .fontColor('#C62828')
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 8, right: 8 })
  }

  @Builder
  private PostSectionHeader(detail: TopicDetail): void {
    Row() {
      Text(this.hasStarterPost()
        ? `全部 Reply（${Math.max(detail.postCount - 1, 0)}）`
        : `全部 Post（${detail.postCount}）`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .layoutWeight(1)
      if (this.state.hasMorePosts) {
        Text(`已加载 ${this.visiblePosts().length}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, top: 8, bottom: 2 })
  }

  @Builder
  private EmptyPostState(): void {
    Column({ space: 12 }) {
      Text('首屏还没有可展示的 Post')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
      Text(this.state.hasMorePosts ? '可以继续加载后续 Post。' : '这个 Topic 暂无内容。')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding(28)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
  }

  @Builder
  private ReplyComposerSheet(): void {
    ForumComposer({
      presentation: this.composerPresentation(),
      onTitleChange: (_title: string): void => {},
      onBodyChange: (body: string): void => this.onReplyDraftChange(body),
      onSubmit: (): void => this.onSubmitReply(),
      onReauthenticate: (): void => this.onLoginForReply()
    })
  }

  @Builder
  private PaginationFooter(): void {
    Column({ space: 10 }) {
      if (this.state.isLoadingMore) {
        LoadingProgress()
          .width(32)
          .height(32)
        Text('正在加载更多 Post')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(14)
          .fontColor('#C62828')
          .textAlign(TextAlign.Center)
        Button('重试加载更多')
          .height(40)
          .fontSize(13)
          .onClick(this.onLoadMore)
          .accessibilityText('重试加载更多 Post')
      } else if (this.state.hasMorePosts) {
        Button('加载更多 Post')
          .height(40)
          .fontSize(13)
          .onClick(this.onLoadMore)
          .accessibilityText('加载更多 Post')
      } else if (this.state.posts.length > 0) {
        Text('已显示全部 Post')
          .fontSize(13)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .padding(20)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private PreviousPagination(): void {
    Column({ space: 8 }) {
      if (this.state.isLoadingPrevious) {
        LoadingProgress()
          .width(28)
          .height(28)
        Text('正在加载更早的 Post')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.previousPaginationMessage.length > 0) {
        Text(this.state.previousPaginationMessage)
          .fontSize(13)
          .fontColor('#C62828')
        Button('重试加载更早 Post')
          .height(38)
          .fontSize(13)
          .onClick(this.onLoadPrevious)
      } else if (this.state.hasPreviousPosts) {
        Button('加载更早 Post')
          .height(38)
          .fontSize(13)
          .onClick(this.onLoadPrevious)
          .accessibilityText('加载当前窗口之前的 Post')
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SuggestedTopics(detail: TopicDetail): void {
    if (detail.suggestedTopics.length > 0) {
      Column({ space: 10 }) {
        Text('继续阅读')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        ForEach(detail.suggestedTopics, (topic: Topic) => {
          ForumContentCard({
            presentation: ForumCardPresentation.topicPreview(topic, this.categories),
            onOpenTopic: (): void => this.onOpenSuggestedTopic(topic)
          })
        }, (topic: Topic): string => topic.id.toString())
      }
      .width('100%')
      .padding({ top: 10 })
    }
  }

  @Builder
  private ReadingContent(): void {
    List({ space: 10 }) {
      if (this.state.detail !== null) {
        ListItem() {
          this.TopicStarter(
            this.state.detail,
            this.hasStarterPost() ? this.state.posts[0] : null
          )
        }
        .onVisibleAreaApproximateChange(
          { ratios: [0.6], expectedUpdateInterval: 500 },
          (_isExpanding: boolean, currentRatio: number): void => {
            if (currentRatio >= 0.6 && this.hasStarterPost()) {
              this.scheduleReadProgress(this.state.posts[0].postNumber);
            }
          }
        )
        ListItem() {
          this.TopicMetadata(this.state.detail)
        }
        ListItem() {
          this.ReadProgressFeedback()
        }
        ListItem() {
          this.PostSectionHeader(this.state.detail)
        }
        ListItem() {
          this.PreviousPagination()
        }
      }
      if (this.state.kind === TopicReadStateKind.EMPTY) {
        ListItem() {
          this.EmptyPostState()
        }
      }
      ForEach(this.visiblePosts(), (post: ForumPost) => {
        ListItem() {
          if (post.isSystemAction()) {
            this.SystemAction(post)
          } else {
            this.Reply(post)
          }
        }
        .onVisibleAreaApproximateChange(
          { ratios: [0.6], expectedUpdateInterval: 500 },
          (_isExpanding: boolean, currentRatio: number): void => {
            if (currentRatio >= 0.6) {
              this.scheduleReadProgress(post.postNumber);
            }
          }
        )
      }, (post: ForumPost): string => post.id.toString())
      ListItem() {
        this.PaginationFooter()
      }
      if (this.state.detail !== null) {
        ListItem() {
          this.SuggestedTopics(this.state.detail)
        }
      }
      ListItem() {
        Column()
          .width('100%')
          .height(32)
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 10 })
    .backgroundColor('#F5F6F8')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .bindSheet($$this.replySheetVisible, this.ReplyComposerSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      detentSelection: SheetSize.MEDIUM,
      showClose: true,
      dragBar: true,
      title: {
        title: this.composerPresentation().sheetTitle,
        subtitle: `${this.composerPresentation().sheetSubtitle} · 支持 Markdown`
      },
      keyboardAvoidMode: SheetKeyboardAvoidMode.TRANSLATE_AND_RESIZE,
      shouldDismiss: (sheetDismiss: SheetDismiss): void => {
        if (this.replyState.isBusy()) {
          return;
        }
        sheetDismiss.dismiss();
        this.onDismissReply();
      }
    })
  }

  build() {
    if (this.state.kind === TopicReadStateKind.INITIAL || this.state.kind === TopicReadStateKind.LOADING) {
      this.LoadingState()
    } else if (this.state.kind === TopicReadStateKind.ERROR) {
      this.RetryableState()
    } else {
      this.ReadingContent()
    }
  }
}
