import {
  ForumCardBadge,
  ForumCardBadgeKind,
  ForumCardAuthor,
  ForumCardMode,
  ForumCardPresentation,
  ForumCardReplyAction,
  ForumCardStatistic,
  ForumCardStatisticKind
} from './ForumCardPresentation';
import { RichEmbedProvider } from '../models/RichNavigationPolicy';
import {
  RichContentInlineFragment,
  RichContentInlineFragmentKind
} from '../models/RichContentBlocks';
import { ForumPost } from '../models/ForumModels';
import { ForumPoll, ForumPollVote, removeDiscoursePollMarkup } from '../models/PollModels';
import { TopicPostActionState } from '../app/TopicReadingModels';
import { PostPollCard } from './PostPollCard';
import { RichPostContent } from './RichPostContent';
import { TopicPostActionBar } from './TopicPostActionBar';
import { UserAvatar } from './UserAvatar';
import { UserStatusPill } from './UserStatusPill';

@Component
export struct ForumContentCard {
  @Require @Prop presentation: ForumCardPresentation;
  @Prop richCooked: string = '';
  @Prop richRaw: string = '';
  @Prop authorActionAvailable: boolean = false;
  @Prop topicId: number = 0;
  @Prop post: ForumPost | null = null;
  @Prop postActionState: TopicPostActionState = TopicPostActionState.idle();
  @Prop bookmarked: boolean = false;
  @Prop editable: boolean = false;
  @Prop validReactions: Array<string> = [];
  @Prop authenticated: boolean = false;
  @Prop cardActionAvailable: boolean = false;
  onOpenTopic: () => void = (): void => {};
  onOpenCard: () => void = (): void => {};
  onReply: (postNumber: number | null) => void = (_postNumber: number | null): void => {};
  onOpenReplyTarget: (postNumber: number) => void = (_postNumber: number): void => {};
  onOpenRichLink: (url: string) => void = (_url: string): void => {};
  onResolveRichEmbed: (url: string, provider: RichEmbedProvider, title: string) => Promise<string> = async (
    _url: string,
    _provider: RichEmbedProvider,
    _title: string
  ): Promise<string> => '';
  onOpenImage: (url: string, title: string, transitionId: string) => void = (
    _url: string,
    _title: string,
    _transitionId: string
  ): void => {};
  onOpenAuthor: (username: string) => void = (_username: string): void => {};
  onToggleReaction: (postId: number, reaction: string) => void = (
    _postId: number,
    _reaction: string
  ): void => {};
  onOpenReactionUsers: (postId: number) => void = (_postId: number): void => {};
  onOpenReplies: (post: ForumPost) => void = (_post: ForumPost): void => {};
  onToggleBookmark: (postId: number) => void = (_postId: number): void => {};
  onToggleAcceptedAnswer: (postId: number) => void = (_postId: number): void => {};
  onCopyPostLink: (topicId: number, postNumber: number) => void = (
    _topicId: number,
    _postNumber: number
  ): void => {};
  onReport: (post: ForumPost) => void = (_post: ForumPost): void => {};
  onEdit: (postId: number) => void = (_postId: number): void => {};
  onDelete: (postId: number) => void = (_postId: number): void => {};
  onVotePoll: (postId: number, pollName: string, vote: ForumPollVote) => void = (
    _postId: number,
    _pollName: string,
    _vote: ForumPollVote
  ): void => {};
  onRemovePollVote: (postId: number, pollName: string) => void = (
    _postId: number,
    _pollName: string
  ): void => {};
  onLoginForPostAction: () => void = (): void => {};
  @Builder
  private Badge(badge: ForumCardBadge): void {
    Text(badge.label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(badge.kind === ForumCardBadgeKind.PINNED ? $r('app.color.status_error') : $r('app.color.text_link'))
      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      .backgroundColor($r('sys.color.background_secondary'))
      .borderRadius(10)
      .maxLines(1)
      .textOverflow({ overflow: TextOverflow.Ellipsis })
  }

  @Builder
  private AuthorRow(author: ForumCardAuthor): void {
    Row({ space: 9 }) {
      UserAvatar({
        avatarUrl: author.avatarUrl,
        displayName: author.name,
        avatarSize: 36,
        interactive: this.authorActionAvailable && author.username.length > 0,
        avatarAccessibilityText: this.authorActionAvailable && author.username.length > 0
          ? `查看用户 ${author.username}`
          : `${author.name} 的头像`,
        flairUrl: author.flairUrl,
        flairName: author.flairName,
        flairBackgroundColor: author.flairBackgroundColor,
        flairColor: author.flairColor,
        onActivate: (): void => {
          if (this.authorActionAvailable && author.username.length > 0) {
            this.onOpenAuthor(author.username);
          }
        }
      })
      Column({ space: 2 }) {
        Text(author.name)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
        Text(author.timestamp)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
        if (author.userStatus !== null) {
          UserStatusPill({ status: author.userStatus })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (this.presentation.headerBadge !== null) {
        this.Badge(this.presentation.headerBadge)
      }
    }
    .width('100%')
  }

  @Builder
  private ReplyTarget(post: ForumPost, targetPostNumber: number): void {
    Row({ space: 6 }) {
      if (post.replyToAvatarUrl !== null && post.replyToAvatarUrl.length > 0) {
        Image(post.replyToAvatarUrl)
          .width(18)
          .height(18)
          .objectFit(ImageFit.Cover)
          .borderRadius(9)
      } else {
        Text(post.replyToUsername?.slice(0, 1).toUpperCase() ?? '回')
          .width(18)
          .height(18)
          .textAlign(TextAlign.Center)
          .fontSize(9)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.brand_primary'))
          .backgroundColor($r('app.color.brand_tint_surface'))
          .borderRadius(9)
      }
      if (post.replyToUsername !== null && post.replyToUsername.length > 0) {
        Text(`回复 ${post.replyToUsername}`)
          .fontSize(12)
          .fontColor($r('app.color.text_link'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      } else {
        Text(`回复 #${targetPostNumber}`)
          .fontSize(12)
          .fontColor($r('app.color.text_link'))
      }
      SymbolGlyph($r('sys.symbol.arrowshape_turn_up_left'))
        .fontSize(13)
        .fontColor([$r('app.color.text_link')])
    }
    .width('100%')
    .padding({ left: 8, right: 8, top: 6, bottom: 6 })
    .backgroundColor($r('sys.color.background_secondary'))
    .borderRadius(8)
    .onClick((): void => this.onOpenReplyTarget(targetPostNumber))
    .accessibilityText(`跳转至回复对象 #${targetPostNumber}`)
  }

  @Builder
  private Content(): void {
    if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
      if (this.presentation.title.length > 0) {
        Text(this.presentation.title)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      if (this.presentation.body.length > 0) {
        Text() {
          if (this.presentation.bodyInlineFragments.length > 0) {
            ForEach(this.presentation.bodyInlineFragments, (fragment: RichContentInlineFragment) => {
              if (fragment.kind === RichContentInlineFragmentKind.EMOJI) {
                ImageSpan(fragment.imageUrl)
                  .width(16)
                  .height(16)
                  .objectFit(ImageFit.Contain)
                  .verticalAlign(ImageSpanAlignment.CENTER)
              } else {
                Span(fragment.text)
              }
            }, (fragment: RichContentInlineFragment, index: number): string => `${index}-${fragment.text}`)
          } else {
            Span(this.presentation.body)
          }
        }
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(20)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
    } else {
      if (this.presentation.title.length > 0) {
        Text(this.presentation.title)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .lineHeight(25)
          .width('100%')
      }
      if (this.richCooked.length > 0 || this.richRaw.length > 0) {
        RichPostContent({
          cooked: this.post !== null && this.post.polls.length > 0
            ? removeDiscoursePollMarkup(this.richCooked)
            : this.richCooked,
          raw: this.richRaw,
          imageTransitionScope: `topic-${this.topicId}-post-${this.post?.id ?? 0}`,
          onOpenLink: (url: string): void => this.onOpenRichLink(url),
          onResolveEmbed: async (
            url: string,
            provider: RichEmbedProvider,
            title: string
          ): Promise<string> => this.onResolveRichEmbed(url, provider, title),
          onOpenImage: (url: string, title: string, transitionId: string): void =>
            this.onOpenImage(url, title, transitionId)
        })
      } else if (this.presentation.body.length > 0) {
        Text(this.presentation.body)
          .fontSize(14)
          .lineHeight(22)
          .fontColor($r('sys.color.font_primary'))
          .width('100%')
      }
    }
  }

  @Builder
  private PostPolls(post: ForumPost): void {
    if (post.polls.length > 0) {
      Column({ space: 10 }) {
        ForEach(post.polls, (poll: ForumPoll) => {
          PostPollCard({
            postId: post.id,
            poll: poll,
            actionState: this.postActionState,
            authenticated: this.authenticated,
            onVote: this.onVotePoll,
            onRemoveVote: this.onRemovePollVote,
            onLogin: this.onLoginForPostAction
          })
        }, (poll: ForumPoll): string => poll.name)
      }
      .width('100%')
    }
  }

  @Builder
  private Statistic(statistic: ForumCardStatistic): void {
    if (statistic.kind === ForumCardStatisticKind.REPLIES) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    } else if (statistic.kind === ForumCardStatisticKind.VIEWS) {
      SymbolGlyph($r('sys.symbol.eye'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    } else {
      SymbolGlyph($r('sys.symbol.heart'))
        .fontSize(14)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    Text(statistic.value.toString())
      .fontSize(11)
      .fontColor($r('sys.color.font_tertiary'))
  }

  @Builder
  private ReplyAction(action: ForumCardReplyAction): void {
    Button() {
      Row({ space: 4 }) {
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([$r('app.color.brand_primary')])
        Text(action.label)
          .fontSize(12)
          .fontColor($r('app.color.brand_primary'))
      }
    }
    .height(36)
    .backgroundColor(Color.Transparent)
    .onClick((): void => this.onReply(action.targetPostNumber))
    .accessibilityText(action.accessibilityText)
  }

  @Builder
  private Footer(): void {
    Row({ space: 5 }) {
      if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
        if (this.presentation.footerBadge !== null) {
          this.Badge(this.presentation.footerBadge)
        }
        Blank()
        ForEach(this.presentation.statistics, (statistic: ForumCardStatistic) => {
          this.Statistic(statistic)
        }, (statistic: ForumCardStatistic): string => statistic.kind)
      } else {
        ForEach(this.presentation.statistics, (statistic: ForumCardStatistic) => {
          this.Statistic(statistic)
        }, (statistic: ForumCardStatistic): string => statistic.kind)
        Blank()
      }
      if (this.presentation.replyAction !== null && this.post === null) {
        this.ReplyAction(this.presentation.replyAction)
      }
    }
    .width('100%')
  }

  @Builder
  private Restriction(): void {
    if (this.presentation.restrictionText.length > 0) {
      Text(this.presentation.restrictionText)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('app.color.status_error'))
        .padding({ left: 10, right: 10, top: 7, bottom: 7 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius(8)
        .width('100%')
    }
  }

  @Builder
  private PostActions(post: ForumPost): void {
    TopicPostActionBar({
      post: post,
      topicId: this.topicId,
      validReactions: this.validReactions,
      actionState: this.postActionState,
      bookmarked: this.bookmarked,
      editable: this.editable,
      replyAvailable: this.presentation.replyAction !== null,
      onToggleReaction: this.onToggleReaction,
      onOpenReactionUsers: this.onOpenReactionUsers,
      onOpenReplies: this.onOpenReplies,
      onToggleBookmark: this.onToggleBookmark,
      onToggleAcceptedAnswer: this.onToggleAcceptedAnswer,
      onCopyPostLink: this.onCopyPostLink,
      onReport: this.onReport,
      onEdit: this.onEdit,
      onDelete: this.onDelete,
      onReply: (): void => this.onReply(this.presentation.replyAction?.targetPostNumber ?? null)
    })
  }

  @Builder
  private CardSurface(): void {
    Column({ space: 10 }) {
      if (this.presentation.author !== null) {
        this.AuthorRow(this.presentation.author)
      }
      if (this.post !== null && this.post.replyToPostNumber !== null) {
        this.ReplyTarget(this.post, this.post.replyToPostNumber)
      }
      this.Content()
      if (this.post !== null) {
        this.PostPolls(this.post)
      }
      if (this.post === null && (this.presentation.footerBadge !== null || this.presentation.statistics.length > 0 ||
        this.presentation.replyAction !== null)) {
        this.Footer()
      }
      this.Restriction()
      if (this.post !== null) {
        this.PostActions(this.post)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding($r('app.float.card_content_padding'))
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .accessibilityText(this.presentation.accessibilityText)
  }

  build() {
    if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW || this.cardActionAvailable) {
      Stack() {
        this.CardSurface()
      }
      .width('100%')
      .onClick((): void => {
        if (this.presentation.mode === ForumCardMode.TOPIC_PREVIEW) {
          this.onOpenTopic();
        } else {
          this.onOpenCard();
        }
      }, 8)
    } else {
      this.CardSurface()
    }
  }
}
