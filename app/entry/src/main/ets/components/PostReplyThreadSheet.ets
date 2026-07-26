import { ForumPost } from '../models/ForumModels';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';

@Component
export struct PostReplyThreadSheet {
  @Prop parentPost: ForumPost | null = null;
  @Prop replies: Array<ForumPost> = [];
  @Prop loading: boolean = false;
  @Prop loadingMore: boolean = false;
  @Prop hasMore: boolean = false;
  @Prop message: string = '';
  onRetry: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onOpenReply: (postNumber: number) => void = (_postNumber: number): void => {};

  private parentInitial(): string {
    const username: string = this.parentPost?.username.trim() ?? '';
    return username.length > 0 ? username.slice(0, 1).toUpperCase() : '回';
  }

  @Builder
  private ParentAvatar(post: ForumPost): void {
    Stack() {
      Text(this.parentInitial())
        .width(38)
        .height(38)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .textAlign(TextAlign.Center)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(19)
      if (post.avatarUrl.length > 0) {
        Image(post.avatarUrl)
          .width(38)
          .height(38)
          .objectFit(ImageFit.Cover)
          .borderRadius(19)
      }
    }
    .width(38)
    .height(38)
  }

  @Builder
  private ParentPostCard(post: ForumPost): void {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        this.ParentAvatar(post)
        Column({ space: 3 }) {
          Text(post.username.length > 0 ? post.username : '匿名')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(`Post #${post.postNumber}`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Row({ space: 5 }) {
          SymbolGlyph($r('sys.symbol.message'))
            .fontSize(14)
            .fontColor([$r('app.color.text_link')])
          Text(`${post.replyCount}`)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_link'))
        }
        .height(32)
        .padding({ left: 10, right: 10 })
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(16)
      }
      .width('100%')
      if (post.displayText.length > 0) {
        Text(post.displayText)
          .fontSize(13)
          .lineHeight(19)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    }
    .width('100%')
    .padding(13)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(
      `${post.username} 的 Post #${post.postNumber}，${post.replyCount} 条直接回复`
    )
  }

  @Builder
  private ReplyCard(post: ForumPost): void {
    ForumContentCard({
      presentation: ForumCardPresentation.reply(post, false),
      onOpenCard: (): void => this.onOpenReply(post.postNumber)
    })
  }

  @Builder
  private LoadingState(): void {
    Column({ space: 12 }) {
      LoadingProgress()
        .width(34)
        .height(34)
        .color($r('app.color.brand_primary'))
      Text('正在加载直接回复')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 10 }) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(30)
        .fontColor([$r('sys.color.font_tertiary')])
      Text('暂时没有可显示的直接回复')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ErrorState(): void {
    Column({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
        .fontSize(28)
        .fontColor([$r('app.color.status_error')])
      Text(this.message.length > 0 ? this.message : '直接回复加载失败')
        .fontSize(14)
        .fontColor($r('app.color.status_error'))
        .textAlign(TextAlign.Center)
      Button('重试')
        .height(40)
        .onClick(this.onRetry)
        .accessibilityText('重新加载直接回复')
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ReplyList(): void {
    List({ space: 10 }) {
      ForEach(this.replies, (reply: ForumPost) => {
        ListItem() {
          this.ReplyCard(reply)
        }
      }, (reply: ForumPost): string => `${reply.id}-${reply.postNumber}`)
      if (this.loadingMore) {
        ListItem() {
          Row({ space: 8 }) {
            LoadingProgress()
              .width(20)
              .height(20)
              .color($r('app.color.brand_primary'))
            Text('正在加载更多回复')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .height(48)
          .justifyContent(FlexAlign.Center)
        }
      } else if (this.hasMore) {
        ListItem() {
          Button('加载更多回复')
            .height(42)
            .fontSize(13)
            .onClick(this.onLoadMore)
            .accessibilityText('加载更多直接回复')
        }
      } else {
        ListItem() {
          Text(`已显示 ${this.replies.length} 条直接回复`)
            .fontSize(12)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .height(40)
            .textAlign(TextAlign.Center)
        }
      }
    }
    .layoutWeight(1)
    .width('100%')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
  }

  build() {
    Column({ space: 12 }) {
      if (this.parentPost !== null) {
        this.ParentPostCard(this.parentPost)
      }
      if (this.loading) {
        this.LoadingState()
      } else if (this.replies.length === 0 && this.message.length > 0) {
        this.ErrorState()
      } else if (this.replies.length === 0) {
        this.EmptyState()
      } else {
        this.ReplyList()
      }
    }
    .width('100%')
    .height('100%')
    .padding({ left: 16, right: 16, top: 8, bottom: 24 })
    .backgroundColor($r('sys.color.background_secondary'))
  }
}
