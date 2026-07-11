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
import { ForumPost, TopicDetail } from '../models/ForumModels';

@Component
export struct TopicDetailPage {
  @Prop state: TopicReadState = TopicReadState.initial();
  @Prop replyState: ReplyComposerState = ReplyComposerState.closed();
  @Link replySheetVisible: boolean;
  onRetry: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenReply: (postNumber: number | null) => void = (_postNumber: number | null): void => {};
  onReplyDraftChange: (draft: string) => void = (_draft: string): void => {};
  onSubmitReply: () => void = (): void => {};
  onDismissReply: () => void = (): void => {};
  onLoginForReply: () => void = (): void => {};

  private authorName(post: ForumPost): string {
    return post.username.length > 0 ? post.username : '匿名';
  }

  private authorInitial(post: ForumPost): string {
    const author: string = this.authorName(post);
    return author === '匿名' ? '匿' : author.slice(0, 1).toUpperCase();
  }

  private publishedAt(post: ForumPost): string {
    const timestamp: string = post.createdAt.trim();
    if (timestamp.length >= 16 && timestamp.includes('T')) {
      return timestamp.slice(0, 16).replace('T', ' ');
    }
    return timestamp.length > 0 ? timestamp : '时间未知';
  }

  private replyRestriction(detail: TopicDetail): string {
    if (detail.archived) {
      return '此 Topic 已归档，不可 Reply';
    }
    if (detail.closed) {
      return '此 Topic 已关闭，不可 Reply';
    }
    return detail.canReply ? '' : '当前会话不可 Reply';
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
  private TopicStatistics(detail: TopicDetail): void {
    Row({ space: 5 }) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
      Text(Math.max(detail.postCount - 1, 0).toString())
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
      SymbolGlyph($r('sys.symbol.eye'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
        .margin({ left: 8 })
      Text(detail.viewCount.toString())
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
        .margin({ left: 8 })
      Text(detail.likeCount.toString())
        .fontSize(11)
        .fontColor($r('sys.color.font_tertiary'))
    }
    .width('100%')
  }

  @Builder
  private TopicReplyAction(detail: TopicDetail): void {
    if (this.replyRestriction(detail).length > 0) {
      Text(this.replyRestriction(detail))
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor('#C62828')
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor('#FDECEC')
        .borderRadius(8)
        .width('100%')
    } else {
      Button(this.replyState.draft.trim().length > 0 ? '继续 Reply' : 'Reply Topic')
        .height(40)
        .fontSize(13)
        .onClick((): void => this.onOpenReply(null))
        .accessibilityText('回复当前 Topic')
    }
  }

  @Builder
  private TopicSummary(detail: TopicDetail): void {
    Column({ space: 12 }) {
      Text(detail.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .lineHeight(25)
        .width('100%')
      this.TopicStatistics(detail)
      this.TopicReplyAction(detail)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(
      `${detail.title}，${Math.max(detail.postCount - 1, 0)} 条 Reply，` +
      `${detail.viewCount} 浏览，${detail.likeCount} 赞`
    )
  }

  @Builder
  private PostAuthor(post: ForumPost): void {
    Row({ space: 9 }) {
      Text(this.authorInitial(post))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#317AF7')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EAF2FF')
        .borderRadius(18)
      Column({ space: 2 }) {
        Text(this.authorName(post))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        Text(this.publishedAt(post))
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(`#${post.postNumber}`)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor('#2068C9')
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#EAF2FF')
        .borderRadius(10)
    }
    .width('100%')
  }

  @Builder
  private TopicStarterCard(detail: TopicDetail, post: ForumPost): void {
    Column({ space: 12 }) {
      this.PostAuthor(post)
      Text(detail.title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .lineHeight(25)
        .width('100%')
      Text(post.displayText)
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      this.TopicStatistics(detail)
      this.TopicReplyAction(detail)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(
      `${detail.title}，${this.authorName(post)} 的第 1 条 Post，` +
      `${Math.max(detail.postCount - 1, 0)} 条 Reply，${detail.viewCount} 浏览`
    )
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
  private PostRow(post: ForumPost): void {
    Column({ space: 10 }) {
      this.PostAuthor(post)
      Text(post.displayText)
        .fontSize(14)
        .lineHeight(22)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (this.state.canReply) {
        Row() {
          Blank()
          Button() {
            Row({ space: 4 }) {
              SymbolGlyph($r('sys.symbol.message'))
                .fontSize(14)
                .fontColor(['#317AF7'])
              Text('Reply')
                .fontSize(12)
                .fontColor('#317AF7')
            }
          }
          .height(36)
          .backgroundColor(Color.Transparent)
          .onClick((): void => this.onOpenReply(post.postNumber))
          .accessibilityText(`回复第 ${post.postNumber} 条 Post`)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(`${this.authorName(post)} 的第 ${post.postNumber} 条 Post`)
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
  private ReadingContent(): void {
    List({ space: 10 }) {
      if (this.state.detail !== null) {
        if (this.hasStarterPost()) {
          ListItem() {
            this.TopicStarterCard(this.state.detail, this.state.posts[0])
          }
        } else {
          ListItem() {
            this.TopicSummary(this.state.detail)
          }
        }
        ListItem() {
          this.PostSectionHeader(this.state.detail)
        }
      }
      if (this.state.kind === TopicReadStateKind.EMPTY) {
        ListItem() {
          this.EmptyPostState()
        }
      }
      ForEach(this.visiblePosts(), (post: ForumPost) => {
        ListItem() {
          this.PostRow(post)
        }
      }, (post: ForumPost): string => post.id.toString())
      ListItem() {
        this.PaginationFooter()
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
