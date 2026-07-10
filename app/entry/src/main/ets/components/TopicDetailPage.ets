import { TopicReadState, TopicReadStateKind } from '../app/AppShellModel';
import { ForumPost, TopicDetail } from '../models/ForumModels';

@Component
export struct TopicDetailPage {
  @Prop state: TopicReadState = TopicReadState.initial();
  onRetry: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};

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
  }

  @Builder
  private TopicSummary(detail: TopicDetail): void {
    Column({ space: 10 }) {
      Text(detail.title)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .width('100%')
      Text(`${detail.postCount} Post  ·  ${detail.viewCount} 浏览  ·  ${detail.likeCount} 赞`)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
      if (detail.closed || detail.archived) {
        Text(detail.archived ? '此 Topic 已归档，不可 Reply' : '此 Topic 已关闭，不可 Reply')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_emphasize'))
          .width('100%')
      } else if (!detail.canReply) {
        Text('当前会话不可 Reply')
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(16)
  }

  @Builder
  private PostRow(post: ForumPost): void {
    Column({ space: 12 }) {
      Row() {
        Text(post.username.length > 0 ? post.username : '匿名')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text(`#${post.postNumber}`)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      Text(post.displayText)
        .fontSize(16)
        .lineHeight(25)
        .fontColor($r('sys.color.font_primary'))
        .width('100%')
      if (post.createdAt.length > 0) {
        Text(post.createdAt)
          .fontSize(12)
          .fontColor($r('sys.color.font_tertiary'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor($r('sys.color.comp_background_tertiary'))
    .borderRadius(16)
    .accessibilityText(`${post.username} 的第 ${post.postNumber} 条 Post`)
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
          .fontColor($r('sys.color.font_secondary'))
          .textAlign(TextAlign.Center)
        Button('重试加载更多')
          .onClick(this.onLoadMore)
          .accessibilityText('重试加载更多 Post')
      } else if (this.state.hasMorePosts) {
        Button('加载更多 Post')
          .onClick(this.onLoadMore)
          .accessibilityText('加载更多 Post')
      } else if (this.state.posts.length > 0) {
        Text('已显示全部 Post')
          .fontSize(14)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  private ReadingContent(): void {
    List({ space: 10 }) {
      if (this.state.detail !== null) {
        ListItem() {
          this.TopicSummary(this.state.detail)
        }
      }
      if (this.state.kind === TopicReadStateKind.EMPTY) {
        ListItem() {
          Column({ space: 12 }) {
            Text('首屏还没有可展示的 Post')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
            Text(this.state.hasMorePosts ? '可以继续加载后续 Post。' : '这个 Topic 暂无内容。')
              .fontSize(14)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(28)
        }
      }
      ForEach(this.state.posts, (post: ForumPost) => {
        ListItem() {
          this.PostRow(post)
        }
      }, (post: ForumPost): string => post.id.toString())
      ListItem() {
        this.PaginationFooter()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, bottom: 12 })
    .edgeEffect(EdgeEffect.Spring)
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
