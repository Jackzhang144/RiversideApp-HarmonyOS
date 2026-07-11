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
    ForumContentCard({
      presentation: ForumCardPresentation.topicStarter(detail, post, this.replyState.draft),
      onReply: (postNumber: number | null): void => this.onOpenReply(postNumber)
    })
  }

  @Builder
  private Reply(post: ForumPost): void {
    ForumContentCard({
      presentation: ForumCardPresentation.reply(post, this.state.canReply),
      onReply: (postNumber: number | null): void => this.onOpenReply(postNumber)
    })
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
  private ReadingContent(): void {
    List({ space: 10 }) {
      if (this.state.detail !== null) {
        ListItem() {
          this.TopicStarter(
            this.state.detail,
            this.hasStarterPost() ? this.state.posts[0] : null
          )
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
          this.Reply(post)
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
