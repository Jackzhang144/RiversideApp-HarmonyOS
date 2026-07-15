import {
  BrowseState,
  BrowseStateKind,
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
import {
  Category,
  ForumPost,
  PostReaction,
  PostReactionUser,
  PostReactionUsers,
  Topic,
  TopicDetail
} from '../models/ForumModels';
import { RichEmbedProvider } from '../models/RichContentModels';
import { MediaUploadState } from '../models/MediaModels';
import { ChatEmoji } from '../models/ChatModels';
import { RepositoryResult } from '../core/RepositoryResult';
import { ComposerMentionUser } from '../models/ComposerMentionModels';
import {
  categoryLabel,
  displayedReactions,
  normalizeTopicFloor,
  PostFlagOption,
  postFlagOptions,
  reactionAccessibilityLabel,
  reactionEmojiUrl,
  shouldShowSuggestedTopics,
  systemActionLabel,
  topicPostListIndex
} from './TopicReadingPresentation';

@Component
export struct TopicDetailPage {
  @Prop @Watch('synchronizeFloorFromState') state: TopicReadState = TopicReadState.initial();
  @Prop authenticated: boolean = false;
  @Prop reactionUsersState: BrowseState<PostReactionUsers> = BrowseState.initial<PostReactionUsers>();
  @Link reactionUsersSheetVisible: boolean;
  @Link bookmarkedPostIds: Array<number>;
  @Link lastReadPostNumber: number;
  @Link readProgressBusy: boolean;
  @Link readProgressMessage: string;
  @Prop replyState: ReplyComposerState = ReplyComposerState.closed();
  @Prop mediaState: MediaUploadState | null = null;
  @Prop categories: Array<Category> = [];
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop emojiLoading: boolean = false;
  @Link replySheetVisible: boolean;
  @State flagSheetVisible: boolean = false;
  @State flagPostId: number = 0;
  @State flagUsername: string = '';
  @State selectedFlagTypeId: number = 0;
  @State flagMessage: string = '';
  onRetry: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onLoadMore: () => void = (): void => {};
  onLoadPrevious: () => void = (): void => {};
  onOpenReply: (postNumber: number | null) => void = (_postNumber: number | null): void => {};
  onOpenEdit: (postId: number) => void = (_postId: number): void => {};
  onToggleReaction: (postId: number, reaction: string) => void = (
    _postId: number,
    _reaction: string
  ): void => {};
  onOpenReactionUsers: (postId: number) => void = (_postId: number): void => {};
  onToggleBookmark: (postId: number) => void = (_postId: number): void => {};
  onDeletePost: (postId: number) => void = (_postId: number): void => {};
  onSubmitPostFlag: (postId: number, typeId: number, message: string | null) => void = (
    _postId: number,
    _typeId: number,
    _message: string | null
  ): void => {};
  onLoginForPostAction: () => void = (): void => {};
  onToggleAcceptedAnswer: (postId: number) => void = (_postId: number): void => {};
  onCopyPostLink: (topicId: number, postNumber: number) => void = (
    _topicId: number,
    _postNumber: number
  ): void => {};
  onOpenSuggestedTopic: (topic: Topic) => void = (_topic: Topic): void => {};
  onOpenRichLink: (url: string) => void = (_url: string): void => {};
  onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string) => void = (
    _url: string,
    _provider: RichEmbedProvider,
    _title: string
  ): void => {};
  onOpenImage: (url: string, title: string) => void = (_url: string, _title: string): void => {};
  onOpenAuthor: (username: string) => void = (_username: string): void => {};
  onReadProgress: (postNumber: number) => void = (_postNumber: number): void => {};
  onJumpToPost: (postNumber: number) => Promise<boolean> = async (_postNumber: number): Promise<boolean> => false;
  onRetryPostJump: () => Promise<boolean> = async (): Promise<boolean> => false;
  onSubmitFinalReadProgress: (topicId: number, postNumbers: Array<number>) => void = (
    _topicId: number,
    _postNumbers: Array<number>
  ): void => {};
  onReplyDraftChange: (draft: string) => void = (_draft: string): void => {};
  onSubmitReply: () => void = (): void => {};
  onSaveReplyDraft: () => void = (): void => {};
  onDiscardReplyDraft: () => void = (): void => {};
  onDismissReply: () => void = (): void => {};
  onLoginForReply: () => void = (): void => {};
  onSelectMedia: () => void = (): void => {};
  onCancelMedia: () => void = (): void => {};
  onRetryMedia: () => void = (): void => {};
  onRemoveMedia: () => void = (): void => {};
  onLoadEmojis: () => void = (): void => {};
  onLoadMentionUsers: (term: string) => Promise<RepositoryResult<Array<ComposerMentionUser>>> =
    async (_term: string): Promise<RepositoryResult<Array<ComposerMentionUser>>> => {
      return RepositoryResult.success<Array<ComposerMentionUser>>([]);
    };
  private readProgressTimer: number = -1;
  private pendingReadPostNumber: number = 0;
  private readonly readingScroller: Scroller = new Scroller();
  @State private currentPostNumber: number = 1;
  @State private currentTopicId: number = 0;
  @State private selectedFloor: number = 1;
  @State private floorInput: string = '1';
  @State private floorInputMessage: string = '';
  private synchronizedJumpTopicId: number = 0;
  private synchronizedJumpPostNumber: number = 0;

  aboutToDisappear(): void {
    if (this.readProgressTimer >= 0) {
      clearTimeout(this.readProgressTimer);
      this.readProgressTimer = -1;
    }
    this.submitFinalReadProgress();
  }

  aboutToAppear(): void {
    this.synchronizeFloorFromState();
  }

  private synchronizeFloorFromState(): void {
    const requestedPostNumber: number = this.state.postJumpState.targetPostNumber;
    const requestedPostVisible: boolean = this.state.posts.some(
      (post: ForumPost): boolean => post.postNumber === requestedPostNumber
    );
    const requestedPostChanged: boolean = this.synchronizedJumpTopicId !== this.state.topicId ||
      this.synchronizedJumpPostNumber !== requestedPostNumber;
    if (requestedPostVisible && (requestedPostChanged || this.state.postJumpState.busy)) {
      this.synchronizedJumpTopicId = this.state.topicId;
      this.synchronizedJumpPostNumber = requestedPostNumber;
      this.currentTopicId = this.state.topicId;
      this.currentPostNumber = requestedPostNumber;
      this.selectedFloor = requestedPostNumber;
      this.floorInput = requestedPostNumber.toString();
      setTimeout((): void => this.scrollToPost(requestedPostNumber), 50);
      return;
    }
    const currentPostVisible: boolean = this.currentTopicId === this.state.topicId && this.state.posts.some(
      (post: ForumPost): boolean => post.postNumber === this.currentPostNumber
    );
    if (currentPostVisible) {
      return;
    }
    const focusedPostNumber: number = requestedPostVisible
      ? requestedPostNumber
      : this.state.posts[0]?.postNumber ?? 1;
    this.synchronizedJumpTopicId = this.state.topicId;
    this.synchronizedJumpPostNumber = requestedPostVisible ? requestedPostNumber : 0;
    this.currentTopicId = this.state.topicId;
    this.currentPostNumber = focusedPostNumber;
    this.selectedFloor = focusedPostNumber;
    this.floorInput = focusedPostNumber.toString();
  }

  private scheduleReadProgress(postNumber: number): void {
    this.pendingReadPostNumber = Math.max(this.pendingReadPostNumber, postNumber);
    if (this.readProgressTimer >= 0) {
      clearTimeout(this.readProgressTimer);
    }
    this.readProgressTimer = setTimeout((): void => {
      this.readProgressTimer = -1;
      this.flushPendingReadProgress();
    }, 2000);
  }

  private flushPendingReadProgress(): void {
    const targetPostNumber: number = this.pendingReadPostNumber;
    this.pendingReadPostNumber = 0;
    if (targetPostNumber > 0) {
      this.onReadProgress(targetPostNumber);
    }
  }

  private submitFinalReadProgress(): void {
    const targetPostNumber: number = this.pendingReadPostNumber;
    this.pendingReadPostNumber = 0;
    if (targetPostNumber <= 0 || this.state.topicId <= 0) {
      return;
    }
    const postNumbers: Array<number> = this.state.posts
      .map((post: ForumPost): number => post.postNumber)
      .filter((postNumber: number): boolean => {
        return postNumber > this.lastReadPostNumber && postNumber <= targetPostNumber;
      });
    if (postNumbers.length > 0) {
      this.onSubmitFinalReadProgress(this.state.topicId, postNumbers);
    }
  }

  private hasStarterPost(): boolean {
    return this.state.posts.length > 0 && this.state.posts[0].postNumber === 1;
  }

  private visiblePosts(): Array<ForumPost> {
    return this.hasStarterPost() ? this.state.posts.slice(1) : this.state.posts;
  }

  private isPostBookmarked(postId: number): boolean {
    return this.bookmarkedPostIds.includes(postId);
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
    if (this.replyState.isEditingPost()) {
      return ForumComposerPresentation.editPost(
        this.state.topicId,
        this.state.title,
        this.replyState.draft,
        this.composerStatus(),
        this.replyState.message,
        this.mediaState
      );
    }
    return ForumComposerPresentation.reply(
      this.state.topicId,
      this.state.title,
      this.replyState.replyToPostNumber,
      this.replyState.draft,
      this.composerStatus(),
      this.replyState.message,
      this.mediaState
    );
  }

  private canEditPost(post: ForumPost): boolean {
    if (!post.canEdit) {
      return false;
    }
    return post.postNumber !== 1 || this.state.detail?.canEdit === true;
  }

  private canReplyHere(): boolean {
    return this.state.canReply;
  }

  private highestPostNumber(): number {
    return Math.max(1, this.state.detail?.highestPostNumber ?? 1);
  }

  private listIndexForPost(postNumber: number): number {
    return topicPostListIndex(this.state.posts, postNumber);
  }

  private scrollToPost(postNumber: number): void {
    const listIndex: number = this.listIndexForPost(postNumber);
    if (listIndex >= 0) {
      this.readingScroller.scrollToIndex(listIndex, true, ScrollAlign.START);
    }
  }

  private async jumpToFloor(retry: boolean = false): Promise<void> {
    const targetPostNumber: number | null = retry
      ? this.state.postJumpState.targetPostNumber
      : normalizeTopicFloor(this.floorInput, this.highestPostNumber());
    if (targetPostNumber === null || targetPostNumber <= 0) {
      this.floorInputMessage = '请输入有效楼层';
      return;
    }
    this.floorInputMessage = '';
    this.floorInput = targetPostNumber.toString();
    this.selectedFloor = targetPostNumber;
    const succeeded: boolean = retry
      ? await this.onRetryPostJump()
      : await this.onJumpToPost(targetPostNumber);
    if (!succeeded) {
      return;
    }
    this.currentPostNumber = targetPostNumber;
    setTimeout((): void => this.scrollToPost(targetPostNumber), 50);
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
    .backgroundColor($r('sys.color.background_secondary'))
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
    .backgroundColor($r('sys.color.background_secondary'))
  }

  @Builder
  private TopicStarter(detail: TopicDetail, post: ForumPost | null): void {
    Column({ space: 8 }) {
      ForumContentCard({
        presentation: ForumCardPresentation.topicStarter(detail, post, this.replyState.draft, this.canReplyHere()),
        richCooked: post?.cooked ?? '',
        richRaw: post?.raw ?? '',
        authorActionAvailable: true,
        onOpenRichLink: (url: string): void => this.onOpenRichLink(url),
        onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string): void =>
          this.onOpenRichEmbed(url, provider, title),
        onOpenImage: (url: string, title: string): void => this.onOpenImage(url, title),
        onOpenAuthor: (username: string): void => this.onOpenAuthor(username),
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
        .fontColor($r('app.color.text_link'))
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor($r('sys.color.background_secondary'))
        .borderRadius($r('app.float.card_corner_radius'))
      if (detail.authorUsername.length > 0) {
        Text(`作者 ${detail.authorUsername}`)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      Blank()
      Text(`已读 #${this.lastReadPostNumber}`)
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
  }

  @Builder
  private FloorLocator(): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(`当前 #${this.currentPostNumber} / ${this.highestPostNumber()}`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        TextInput({ text: this.floorInput, placeholder: '楼层' })
          .width(88)
          .height(36)
          .type(InputType.Number)
          .enabled(!this.state.postJumpState.busy)
          .onChange((value: string): void => {
            this.floorInput = value;
            const normalized: number | null = normalizeTopicFloor(value, this.highestPostNumber());
            if (normalized !== null) {
              this.selectedFloor = normalized;
            }
          })
        Button('跳转')
          .height(36)
          .fontSize(13)
          .enabled(!this.state.postJumpState.busy)
          .onClick((): void => {
            this.jumpToFloor();
          })
          .accessibilityText('跳转到输入楼层')
      }
      if (this.highestPostNumber() > 1) {
        Slider({
          value: this.selectedFloor,
          min: 1,
          max: this.highestPostNumber(),
          step: 1,
          style: SliderStyle.OutSet
        })
          .enabled(!this.state.postJumpState.busy)
          .onChange((value: number, mode: SliderChangeMode): void => {
            const targetPostNumber: number = Math.floor(value);
            this.selectedFloor = targetPostNumber;
            this.floorInput = targetPostNumber.toString();
            if (mode === SliderChangeMode.End) {
              this.jumpToFloor();
            }
          })
      }
      if (this.state.postJumpState.busy) {
        Row({ space: 6 }) {
          LoadingProgress()
            .width(18)
            .height(18)
          Text(`正在定位 #${this.state.postJumpState.targetPostNumber}`)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
        }
      } else if (this.state.postJumpState.message.length > 0) {
        Row({ space: 8 }) {
          Text(this.state.postJumpState.message)
            .fontSize(12)
            .fontColor($r('app.color.status_error'))
            .layoutWeight(1)
          Button('重试')
            .height(32)
            .fontSize(12)
            .onClick((): void => {
              this.jumpToFloor(true);
            })
            .accessibilityText(`重试定位楼层 ${this.state.postJumpState.targetPostNumber}`)
        }
      } else if (this.floorInputMessage.length > 0) {
        Text(this.floorInputMessage)
          .fontSize(12)
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }
    }
    .width('100%')
    .padding(12)
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private ReadProgressFeedback(): void {
    if (this.readProgressBusy) {
      Text('正在同步阅读进度')
        .fontSize(12)
        .fontColor($r('sys.color.font_secondary'))
        .width('100%')
        .textAlign(TextAlign.Center)
    } else if (this.readProgressMessage.length > 0) {
      Text(this.readProgressMessage)
        .fontSize(12)
        .fontColor($r('app.color.status_error'))
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
          .fontColor($r('app.color.text_link'))
          .width('100%')
          .padding({ left: 8 })
      }
      ForumContentCard({
        presentation: ForumCardPresentation.reply(post, this.canReplyHere()),
        richCooked: post.cooked,
        richRaw: post.raw,
        authorActionAvailable: true,
        onOpenRichLink: (url: string): void => this.onOpenRichLink(url),
        onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string): void =>
          this.onOpenRichEmbed(url, provider, title),
        onOpenImage: (url: string, title: string): void => this.onOpenImage(url, title),
        onOpenAuthor: (username: string): void => this.onOpenAuthor(username),
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
        .fontColor([$r('sys.color.font_secondary')])
      Text(`${post.username.length > 0 ? post.username : '系统'} ${systemActionLabel(post.actionCode)}`)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor($r('sys.color.font_secondary'))
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
    }
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor($r('sys.color.background_secondary'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
    .borderRadius(18)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .accessibilityText(`${post.username} ${systemActionLabel(post.actionCode)}`)
  }

  @Builder
  private ReactionSummary(postId: number, reaction: PostReaction): void {
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
    .margin({ right: 6, bottom: 6 })
    .onClick((): void => this.onOpenReactionUsers(postId))
    .accessibilityText(`${reactionAccessibilityLabel(reaction.id)}回应，${reaction.count} 次`)
  }

  @Builder
  private ReactionUserAvatar(user: PostReactionUser): void {
    Stack() {
      Text(user.username.slice(0, 1).toUpperCase())
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_primary'))
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(18)
      if (user.avatarUrl.length > 0) {
        Image(user.avatarUrl)
          .width(36)
          .height(36)
          .borderRadius(18)
          .objectFit(ImageFit.Cover)
      }
    }
    .width(36)
    .height(36)
  }

  @Builder
  private ReactionUsersSheet(): void {
    Column({ space: 12 }) {
      if (this.reactionUsersState.kind === BrowseStateKind.LOADING) {
        LoadingProgress().width(36).height(36)
        Text('正在加载回应用户').fontSize(14).fontColor($r('sys.color.font_secondary'))
      } else if (this.reactionUsersState.kind === BrowseStateKind.ERROR) {
        Text(this.reactionUsersState.message.length > 0
          ? this.reactionUsersState.message : '回应用户加载失败')
          .fontSize(14)
          .fontColor($r('app.color.status_error'))
      } else if (this.reactionUsersState.items.length === 0) {
        Text('暂无可展示的回应用户').fontSize(14).fontColor($r('sys.color.font_secondary'))
      } else {
        if (this.reactionUsersState.message.length > 0) {
          Text(this.reactionUsersState.message)
            .fontSize(12)
            .fontColor($r('app.color.status_warning'))
            .width('100%')
        }
        List({ space: 14 }) {
          ForEach(this.reactionUsersState.items, (reaction: PostReactionUsers) => {
            ListItem() {
              Column({ space: 10 }) {
                Row({ space: 8 }) {
                  Image(reactionEmojiUrl(reaction.id))
                    .width(22)
                    .height(22)
                    .objectFit(ImageFit.Contain)
                  Text(`${reaction.count} 人`)
                    .fontSize(13)
                    .fontColor($r('sys.color.font_secondary'))
                }
                .width('100%')
                Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
                  ForEach(reaction.users, (user: PostReactionUser) => {
                    Button() {
                      Column({ space: 4 }) {
                        this.ReactionUserAvatar(user)
                        Text(user.username)
                          .fontSize(11)
                          .fontColor($r('app.color.text_link'))
                          .maxLines(1)
                          .textOverflow({ overflow: TextOverflow.Ellipsis })
                      }
                    }
                    .width(76)
                    .height(62)
                    .backgroundColor(Color.Transparent)
                    .onClick((): void => {
                      this.reactionUsersSheetVisible = false;
                      this.onOpenAuthor(user.username);
                    })
                    .accessibilityText(`查看 ${user.username} 的资料`)
                  }, (user: PostReactionUser): string => user.username)
                  if (reaction.users.length === 0) {
                    Text(`${reaction.count} 人参与，服务未返回用户名`)
                      .fontSize(12)
                      .fontColor($r('sys.color.font_tertiary'))
                  }
                }
                .width('100%')
              }
              .width('100%')
            }
          }, (reaction: PostReactionUsers): string => reaction.id)
        }
        .width('100%')
        .height(320)
      }
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 8, bottom: 20 })
    .alignItems(HorizontalAlign.Start)
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
    .backgroundColor(post.currentUserReaction === '+1'
      ? $r('app.color.brand_primary')
      : $r('sys.color.background_secondary'))
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
        if (post.acceptedAnswer) {
          Text('已采纳')
            .height(34)
            .fontSize(12)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.status_success'))
            .padding({ left: 10, right: 10 })
            .backgroundColor($r('sys.color.background_secondary'))
            .borderRadius(17)
            .margin({ right: 6, bottom: 6 })
            .accessibilityText('此回答已被采纳')
        }
        ForEach(displayedReactions(post.reactions), (reaction: PostReaction) => {
          this.ReactionSummary(post.id, reaction)
        }, (reaction: PostReaction): string => reaction.id)
        this.ReactionTrigger(post)
        Button() {
          if (this.isPostBookmarked(post.id)) {
            SymbolGlyph($r('sys.symbol.bookmark_fill'))
              .fontSize(18)
              .fontColor([$r('app.color.on_accent')])
          } else {
            SymbolGlyph($r('sys.symbol.bookmark'))
              .fontSize(18)
              .fontColor([$r('app.color.text_link')])
          }
        }
        .width(42)
        .height(34)
        .backgroundColor(this.isPostBookmarked(post.id)
          ? $r('app.color.brand_primary')
          : $r('sys.color.background_secondary'))
        .margin({ right: 6, bottom: 6 })
        .enabled(!this.state.postActionState.busy)
        .onClick((): void => this.onToggleBookmark(post.id))
        .accessibilityText(this.isPostBookmarked(post.id) ? '取消收藏' : '收藏')
        if (post.canAcceptAnswer || post.canUnacceptAnswer) {
          Button(post.acceptedAnswer ? '取消采纳' : '采纳回答')
            .height(34)
            .fontSize(12)
            .backgroundColor($r('sys.color.background_secondary'))
            .fontColor(post.acceptedAnswer ? $r('app.color.status_warning') : $r('app.color.status_success'))
            .margin({ right: 6, bottom: 6 })
            .enabled(!this.state.postActionState.busy)
            .onClick((): void => this.onToggleAcceptedAnswer(post.id))
            .accessibilityText(post.acceptedAnswer ? '取消采纳此回答' : '采纳此回答')
        }
        Button('复制链接')
          .height(34)
          .fontSize(12)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('app.color.text_link'))
          .margin({ right: 6, bottom: 6 })
          .onClick((): void => this.onCopyPostLink(this.state.topicId, post.postNumber))
          .accessibilityText(`复制 Post #${post.postNumber} 链接`)
        Button('举报')
          .height(34)
          .fontSize(12)
          .backgroundColor($r('sys.color.background_secondary'))
          .fontColor($r('sys.color.font_secondary'))
          .margin({ right: 6, bottom: 6 })
          .enabled(!this.state.postActionState.busy)
          .onClick((): void => this.openPostFlag(post))
          .accessibilityText(`举报 Post #${post.postNumber}`)
        if (this.canEditPost(post)) {
          Button('编辑')
            .height(34)
            .fontSize(12)
            .backgroundColor($r('sys.color.background_secondary'))
            .fontColor($r('app.color.text_link'))
            .margin({ right: 6, bottom: 6 })
            .enabled(!this.state.postActionState.busy)
            .onClick((): void => this.onOpenEdit(post.id))
            .accessibilityText(post.postNumber === 1 ? '编辑 Topic' : `编辑 Post #${post.postNumber}`)
        }
        if (post.canDelete) {
          Button('删除')
            .height(34)
            .fontSize(12)
            .backgroundColor($r('sys.color.background_secondary'))
            .fontColor($r('app.color.status_error'))
            .margin({ right: 6, bottom: 6 })
            .enabled(!this.state.postActionState.busy)
            .onClick((): void => this.onDeletePost(post.id))
            .accessibilityText(post.postNumber === 1 ? '删除 Topic 首帖' : `删除 Post #${post.postNumber}`)
        }
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
          .fontColor($r('app.color.status_error'))
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 8, right: 8 })
  }

  private openPostFlag(post: ForumPost): void {
    if (!this.authenticated) {
      this.onLoginForPostAction();
      return;
    }
    this.flagPostId = post.id;
    this.flagUsername = post.username;
    this.selectedFlagTypeId = 0;
    this.flagMessage = '';
    this.flagSheetVisible = true;
  }

  private selectedFlagOption(): PostFlagOption | null {
    const option: PostFlagOption | undefined = postFlagOptions(this.flagUsername).find(
      (candidate: PostFlagOption): boolean => candidate.typeId === this.selectedFlagTypeId
    );
    return option ?? null;
  }

  private canSubmitPostFlag(): boolean {
    const option: PostFlagOption | null = this.selectedFlagOption();
    return option !== null && (!option.needsMessage || this.flagMessage.trim().length > 0);
  }

  private submitPostFlag(): void {
    const option: PostFlagOption | null = this.selectedFlagOption();
    if (option === null || !this.canSubmitPostFlag()) {
      return;
    }
    this.onSubmitPostFlag(
      this.flagPostId,
      option.typeId,
      option.needsMessage ? this.flagMessage.trim() : null
    );
    this.flagSheetVisible = false;
  }

  @Builder
  private FlagOption(option: PostFlagOption): void {
    Row({ space: 10 }) {
      if (option.typeId === this.selectedFlagTypeId) {
        SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
          .fontSize(22)
          .fontColor([$r('app.color.brand_primary')])
      } else {
        SymbolGlyph($r('sys.symbol.circle'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_tertiary')])
      }
      Column({ space: 3 }) {
        Text(option.label)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_primary'))
        Text(option.description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .lineHeight(17)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .onClick((): void => {
      this.selectedFlagTypeId = option.typeId;
      this.flagMessage = '';
    })
    .accessibilityText(`${option.label}${option.typeId === this.selectedFlagTypeId ? '，已选择' : ''}`)
  }

  @Builder
  private PostFlagSheet(): void {
    Scroll() {
      Column({ space: 8 }) {
        Text('感谢您维护社区的文明！版主收到举报后将尽快进行审核。')
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        ForEach(postFlagOptions(this.flagUsername), (option: PostFlagOption) => {
          this.FlagOption(option)
        }, (option: PostFlagOption): string => option.typeId.toString())
        if (this.selectedFlagOption()?.needsMessage === true) {
          TextArea({ text: this.flagMessage, placeholder: '请描述具体问题（必填）' })
            .width('100%')
            .height(96)
            .maxLength(1000)
            .onChange((value: string): void => { this.flagMessage = value; })
        }
        Button('提交举报')
          .width('100%')
          .height(44)
          .enabled(this.canSubmitPostFlag())
          .onClick((): void => this.submitPostFlag())
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 4, bottom: 28 })
    }
    .width('100%')
    .height('100%')
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
    .backgroundColor($r('sys.color.comp_background_primary'))
    .borderRadius($r('app.float.card_corner_radius'))
    .border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private ReplyComposerSheet(): void {
    ForumComposer({
      presentation: this.composerPresentation(),
      emojis: this.emojis,
      emojiLoading: this.emojiLoading,
      onTitleChange: (_title: string): void => {},
      onBodyChange: (body: string): void => this.onReplyDraftChange(body),
      onSubmit: (): void => this.onSubmitReply(),
      onSaveDraft: (): void => this.onSaveReplyDraft(),
      onDiscard: (): void => this.onDiscardReplyDraft(),
      onReauthenticate: (): void => this.onLoginForReply(),
      onSelectMedia: (): void => this.onSelectMedia(),
      onCancelMedia: (): void => this.onCancelMedia(),
      onRetryMedia: (): void => this.onRetryMedia(),
      onRemoveMedia: (): void => this.onRemoveMedia(),
      onLoadEmojis: (): void => this.onLoadEmojis(),
      onLoadMentionUsers: (term: string): Promise<RepositoryResult<Array<ComposerMentionUser>>> => {
        return this.onLoadMentionUsers(term);
      }
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
          .fontColor($r('app.color.status_error'))
          .textAlign(TextAlign.Center)
        Button('重试加载更多')
          .height(40)
          .fontSize(13)
          .onClick(this.onLoadMore)
          .accessibilityText('重试加载更多 Post')
      } else if (!this.state.hasNextPosts && this.state.posts.length > 0) {
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
          .fontColor($r('app.color.status_error'))
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
  private ReadingList(): void {
    List({ space: 10, scroller: this.readingScroller }) {
      if (this.state.refreshMessage.length > 0) {
        ListItem() {
          Text(this.state.refreshMessage)
            .width('100%')
            .fontSize(13)
            .fontColor($r('app.color.status_error'))
            .textAlign(TextAlign.Center)
            .padding({ top: 6, bottom: 6 })
        }
      }
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
              this.currentPostNumber = this.state.posts[0].postNumber;
              this.currentTopicId = this.state.topicId;
              this.selectedFloor = this.currentPostNumber;
              this.floorInput = this.currentPostNumber.toString();
              this.scheduleReadProgress(this.state.posts[0].postNumber);
            }
          }
        )
        ListItem() {
          this.TopicMetadata(this.state.detail)
        }
        ListItem() {
          this.FloorLocator()
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
              this.currentPostNumber = post.postNumber;
              this.currentTopicId = this.state.topicId;
              this.selectedFloor = post.postNumber;
              this.floorInput = post.postNumber.toString();
              this.scheduleReadProgress(post.postNumber);
            }
          }
        )
      }, (post: ForumPost): string => post.id.toString())
      ListItem() {
        this.PaginationFooter()
      }
      if (this.state.detail !== null && shouldShowSuggestedTopics(
        this.state.hasNextPosts,
        this.state.detail.suggestedTopics.length
      )) {
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
    .backgroundColor($r('sys.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .onReachEnd(this.onLoadMore)
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

  @Builder
  private ReadingContent(): void {
    Column() {
      Refresh({ refreshing: this.state.isRefreshing }) {
        this.ReadingList()
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('sys.color.background_secondary'))
      .refreshOffset(64)
      .pullToRefresh(true)
      .pullUpToCancelRefresh(false)
      .onRefreshing(this.onRefresh)
      .bindSheet($$this.reactionUsersSheetVisible, this.ReactionUsersSheet(), {
        detents: [SheetSize.MEDIUM, SheetSize.LARGE],
        detentSelection: SheetSize.MEDIUM,
        showClose: true,
        dragBar: true,
        title: { title: '回应用户', subtitle: '点击头像查看用户资料' }
      })
    }
    .width('100%')
    .height('100%')
    .bindSheet($$this.flagSheetVisible, this.PostFlagSheet(), {
      detents: [SheetSize.LARGE],
      detentSelection: SheetSize.LARGE,
      showClose: true,
      dragBar: true,
      title: { title: '举报帖子', subtitle: `Post by @${this.flagUsername}` }
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
