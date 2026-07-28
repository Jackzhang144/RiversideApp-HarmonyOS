import { ReplyComposerState, ReplyComposerStateKind } from '../app/ComposerModels';
import { BrowseState, BrowseStateKind } from '../app/BrowseModels';
import { TopicReadState, TopicReadStateKind } from '../app/TopicReadingModels';
import { ForumComposer } from './ForumComposer';
import {
  ForumComposerPresentation,
  ForumComposerStatus
} from './ForumComposerPresentation';
import { ForumCardPresentation } from './ForumCardPresentation';
import { ForumContentCard } from './ForumContentCard';
import { PostReplyThreadSheet } from './PostReplyThreadSheet';
import { TopicReadingProgressRail } from './TopicReadingProgressRail';
import { UserAvatar } from './UserAvatar';
import {
  Category,
  ForumPost,
  PostReactionUser,
  PostReactionUsers,
  Topic,
  TopicDetail,
  TopicNotificationLevel
} from '../models/ForumModels';
import { RichEmbedProvider } from '../models/RichNavigationPolicy';
import { MediaUploadState } from '../models/MediaModels';
import { ChatEmoji } from '../models/ChatModels';
import { RepositoryResult } from '../core/RepositoryResult';
import { ComposerMentionUser } from '../models/ComposerMentionModels';
import { ForumPollVote } from '../models/PollModels';
import {
  PostFlagOption,
  postFlagOptions,
  reactionEmojiUrl,
  shouldShowSuggestedTopics,
  systemActionLabel,
  TopicNotificationOption,
  topicNotificationLabel,
  topicNotificationOptions,
  topicPostRenderKey,
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
  @Link topicNotificationSheetVisible: boolean;
  @State flagSheetVisible: boolean = false;
  @State flagPostId: number = 0;
  @State flagUsername: string = '';
  @State selectedFlagTypeId: number = 0;
  @State flagMessage: string = '';
  @State topicNotificationSaving: boolean = false;
  @State topicNotificationMessage: string = '';
  @State pendingTopicNotificationLevel: TopicNotificationLevel | null = null;
  @State replyThreadSheetVisible: boolean = false;
  @State replyThreadParent: ForumPost | null = null;
  @State replyThreadPosts: Array<ForumPost> = [];
  @State replyThreadLoading: boolean = false;
  @State replyThreadLoadingMore: boolean = false;
  @State replyThreadHasMore: boolean = false;
  @State replyThreadMessage: string = '';
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
  onVotePoll: (postId: number, pollName: string, vote: ForumPollVote) => void = (
    _postId: number,
    _pollName: string,
    _vote: ForumPollVote
  ): void => {};
  onRemovePollVote: (postId: number, pollName: string) => void = (
    _postId: number,
    _pollName: string
  ): void => {};
  onOpenReactionUsers: (postId: number) => void = (_postId: number): void => {};
  onLoadPostReplies: (
    postId: number,
    afterPostNumber: number
  ) => Promise<RepositoryResult<Array<ForumPost>>> = async (
    _postId: number,
    _afterPostNumber: number
  ): Promise<RepositoryResult<Array<ForumPost>>> => {
    return RepositoryResult.unavailable<Array<ForumPost>>('Reply 线程不可用');
  };
  onToggleBookmark: (postId: number) => void = (_postId: number): void => {};
  onDeletePost: (postId: number) => void = (_postId: number): void => {};
  onSubmitPostFlag: (postId: number, typeId: number, message: string | null) => void = (
    _postId: number,
    _typeId: number,
    _message: string | null
  ): void => {};
  onLoginForPostAction: () => void = (): void => {};
  onToggleAcceptedAnswer: (postId: number) => void = (_postId: number): void => {};
  onSetTopicNotificationLevel: (
    notificationLevel: TopicNotificationLevel
  ) => Promise<RepositoryResult<boolean>> = async (
    _notificationLevel: TopicNotificationLevel
  ): Promise<RepositoryResult<boolean>> => {
    return RepositoryResult.unavailable<boolean>('Topic 通知设置不可用');
  };
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
  onOpenImage: (url: string, title: string, transitionId: string) => void = (
    _url: string,
    _title: string,
    _transitionId: string
  ): void => {};
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
  readingScroller: Scroller = new Scroller();
  @State private currentPostNumber: number = 1;
  @State private currentTopicId: number = 0;
  private synchronizedJumpTopicId: number = 0;
  private synchronizedJumpPostNumber: number = 0;
  private replyThreadRequestVersion: number = 0;

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
  }

  private mergeReplyThreadPosts(
    current: Array<ForumPost>,
    incoming: Array<ForumPost>
  ): Array<ForumPost> {
    const merged: Array<ForumPost> = [];
    const seenIds: Set<number> = new Set<number>();
    for (const post of current.concat(incoming)) {
      if (!seenIds.has(post.id)) {
        seenIds.add(post.id);
        merged.push(post);
      }
    }
    merged.sort((left: ForumPost, right: ForumPost): number => left.postNumber - right.postNumber);
    return merged;
  }

  private openReplyThread(post: ForumPost): void {
    this.replyThreadRequestVersion += 1;
    this.replyThreadParent = post;
    this.replyThreadPosts = [];
    this.replyThreadLoading = true;
    this.replyThreadLoadingMore = false;
    this.replyThreadHasMore = false;
    this.replyThreadMessage = '';
    this.replyThreadSheetVisible = true;
    this.loadReplyThreadPage(true);
  }

  private async loadReplyThreadPage(reset: boolean): Promise<void> {
    const parent: ForumPost | null = this.replyThreadParent;
    if (
      parent === null ||
      (reset ? this.replyThreadLoadingMore : (this.replyThreadLoading || this.replyThreadLoadingMore))
    ) {
      return;
    }
    const requestVersion: number = ++this.replyThreadRequestVersion;
    const cursor: number = reset
      ? parent.postNumber
      : this.replyThreadPosts[this.replyThreadPosts.length - 1]?.postNumber ?? parent.postNumber;
    if (reset) {
      this.replyThreadLoading = true;
      this.replyThreadPosts = [];
    } else {
      this.replyThreadLoadingMore = true;
    }
    this.replyThreadMessage = '';
    const result: RepositoryResult<Array<ForumPost>> =
      await this.onLoadPostReplies(parent.id, cursor);
    if (requestVersion !== this.replyThreadRequestVersion || this.replyThreadParent?.id !== parent.id) {
      return;
    }
    this.replyThreadLoading = false;
    this.replyThreadLoadingMore = false;
    if (!result.isSuccess() || result.data === null) {
      if (result.isUnauthorized()) {
        this.replyThreadSheetVisible = false;
        this.onLoginForPostAction();
        return;
      }
      this.replyThreadMessage = result.message.length > 0 ? result.message : '直接回复加载失败';
      return;
    }
    const merged: Array<ForumPost> = this.mergeReplyThreadPosts(
      reset ? [] : this.replyThreadPosts,
      result.data
    );
    this.replyThreadPosts = merged;
    this.replyThreadHasMore = result.data.length >= 20 && merged.length < parent.replyCount;
  }

  private async openReplyThreadPost(postNumber: number): Promise<void> {
    this.replyThreadRequestVersion += 1;
    this.replyThreadSheetVisible = false;
    await this.onJumpToPost(postNumber);
  }

  private replyThreadSubtitle(): string {
    const parent: ForumPost | null = this.replyThreadParent;
    return parent === null
      ? '查看直接回复'
      : `@${parent.username} · Post #${parent.postNumber} · ${parent.replyCount} 条`;
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

  private topicNotificationIcon(notificationLevel: TopicNotificationLevel): Resource {
    if (notificationLevel === TopicNotificationLevel.WATCHING) {
      return $r('sys.symbol.bell_fill');
    }
    if (notificationLevel === TopicNotificationLevel.TRACKING) {
      return $r('sys.symbol.bell_badge_clock');
    }
    if (notificationLevel === TopicNotificationLevel.MUTED) {
      return $r('sys.symbol.bell_slash');
    }
    return $r('sys.symbol.bell');
  }

  private async saveTopicNotificationLevel(notificationLevel: TopicNotificationLevel): Promise<void> {
    const detail: TopicDetail | null = this.state.detail;
    if (detail === null || this.topicNotificationSaving) {
      return;
    }
    if (detail.notificationLevel === notificationLevel) {
      this.topicNotificationSheetVisible = false;
      return;
    }
    this.topicNotificationSaving = true;
    this.pendingTopicNotificationLevel = notificationLevel;
    this.topicNotificationMessage = '';
    const result: RepositoryResult<boolean> = await this.onSetTopicNotificationLevel(notificationLevel);
    this.topicNotificationSaving = false;
    this.pendingTopicNotificationLevel = null;
    if (result.isSuccess() && result.data === true) {
      this.topicNotificationSheetVisible = false;
      return;
    }
    if (result.isUnauthorized()) {
      this.topicNotificationSheetVisible = false;
      this.onLoginForPostAction();
      return;
    }
    this.topicNotificationMessage = result.message.length > 0 ? result.message : '通知设置失败，请重试';
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

  private async jumpToPostNumber(postNumber: number, retry: boolean = false): Promise<void> {
    const targetPostNumber: number = retry
      ? this.state.postJumpState.targetPostNumber
      : postNumber;
    if (
      !Number.isSafeInteger(targetPostNumber) ||
      targetPostNumber <= 0 ||
      targetPostNumber > this.highestPostNumber()
    ) {
      return;
    }
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
      Text($r('app.string.topic_loading'))
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
      Text($r('app.string.topic_load_failed'))
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
      Text(this.state.message)
        .fontSize(15)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button($r('app.string.common_retry'))
        .onClick(this.onRetry)
        .accessibilityText($r('app.string.topic_reload_accessibility'))
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
        presentation: ForumCardPresentation.topicStarter(
          detail,
          post,
          this.replyState.draft,
          this.canReplyHere(),
          null,
          this.categories
        ),
        richCooked: post?.cooked ?? '',
        richRaw: post?.raw ?? '',
        authorActionAvailable: true,
        topicId: this.state.topicId,
        post: post,
        postActionState: this.state.postActionState,
        bookmarked: post === null ? false : this.bookmarkedPostIds.includes(post.id),
        editable: post === null ? false : this.canEditPost(post),
        validReactions: this.state.detail?.validReactions ?? [],
        authenticated: this.authenticated,
        onOpenRichLink: (url: string): void => this.onOpenRichLink(url),
        onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string): void =>
          this.onOpenRichEmbed(url, provider, title),
        onOpenImage: (url: string, title: string, transitionId: string): void =>
          this.onOpenImage(url, title, transitionId),
        onOpenAuthor: (username: string): void => this.onOpenAuthor(username),
        onReply: (postNumber: number | null): void => this.onOpenReply(postNumber),
        onOpenReplyTarget: (postNumber: number): void => {
          this.onJumpToPost(postNumber);
        },
        onToggleReaction: (postId: number, reaction: string): void => this.onToggleReaction(postId, reaction),
        onVotePoll: this.onVotePoll,
        onRemovePollVote: this.onRemovePollVote,
        onLoginForPostAction: this.onLoginForPostAction,
        onOpenReactionUsers: (postId: number): void => this.onOpenReactionUsers(postId),
        onOpenReplies: (target: ForumPost): void => this.openReplyThread(target),
        onToggleBookmark: (postId: number): void => this.onToggleBookmark(postId),
        onToggleAcceptedAnswer: (postId: number): void => this.onToggleAcceptedAnswer(postId),
        onCopyPostLink: (topicId: number, postNumber: number): void => this.onCopyPostLink(topicId, postNumber),
        onReport: (target: ForumPost): void => this.openPostFlag(target),
        onEdit: (postId: number): void => this.onOpenEdit(postId),
        onDelete: (postId: number): void => this.onDeletePost(postId)
      })
    }
    .width('100%')
  }

  @Builder
  private TopicNotificationOptionRow(
    option: TopicNotificationOption,
    currentLevel: TopicNotificationLevel
  ): void {
    Button() {
      Row({ space: 13 }) {
        Stack() {
          SymbolGlyph(this.topicNotificationIcon(option.level))
            .fontSize(22)
            .fontColor([
              option.level === currentLevel
                ? $r('app.color.brand_primary')
                : $r('sys.color.font_secondary')
            ])
        }
        .width(38)
        .height(38)
        .borderRadius(19)
        .backgroundColor(
          option.level === currentLevel
            ? $r('app.color.brand_tint_surface')
            : $r('sys.color.background_secondary')
        )

        Column({ space: 3 }) {
          Text(option.label)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_primary'))
          Text(option.description)
            .fontSize(12)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(2)
            .lineHeight(17)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        if (this.topicNotificationSaving && option.level === this.pendingTopicNotificationLevel) {
          LoadingProgress()
            .width(20)
            .height(20)
            .color($r('app.color.brand_primary'))
        } else if (option.level === currentLevel) {
          SymbolGlyph($r('sys.symbol.checkmark_circle_fill'))
            .fontSize(22)
            .fontColor([$r('app.color.brand_primary')])
        } else {
          SymbolGlyph($r('sys.symbol.chevron_right'))
            .fontSize(15)
            .fontColor([$r('sys.color.font_tertiary')])
        }
      }
      .width('100%')
      .padding({ left: 14, right: 14 })
      .hitTestBehavior(HitTestMode.None)
    }
    .width('100%')
    .height(64)
    .enabled(!this.topicNotificationSaving)
    .backgroundColor(
      option.level === currentLevel
        ? $r('app.color.brand_tint_surface')
        : $r('sys.color.comp_background_primary')
    )
    .border({
      width: 1,
      color: option.level === currentLevel
        ? $r('app.color.brand_primary')
        : $r('sys.color.comp_divider')
    })
    .borderRadius($r('app.float.card_corner_radius'))
    .onClick((): void => {
      this.saveTopicNotificationLevel(option.level);
    })
    .accessibilityText(
      `${option.label}，${option.description}${option.level === currentLevel ? '，当前选择' : ''}`
    )
  }

  @Builder
  private TopicNotificationSheet(): void {
    if (this.state.detail !== null) {
      Column({ space: 9 }) {
        if (this.topicNotificationMessage.length > 0) {
          Row({ space: 8 }) {
            SymbolGlyph($r('sys.symbol.exclamationmark_circle'))
              .fontSize(17)
              .fontColor([$r('app.color.status_error')])
            Text(this.topicNotificationMessage)
              .fontSize(12)
              .fontColor($r('app.color.status_error'))
              .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 4, right: 4, bottom: 2 })
        }
        ForEach(topicNotificationOptions(), (option: TopicNotificationOption) => {
          this.TopicNotificationOptionRow(option, this.state.detail?.notificationLevel ?? TopicNotificationLevel.REGULAR)
        }, (option: TopicNotificationOption): string => option.level.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 6, bottom: 24 })
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }

  @Builder
  private ReadProgressFeedback(): void {
    if (this.readProgressBusy) {
      Text($r('app.string.topic_read_progress_syncing'))
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
    ForumContentCard({
      presentation: ForumCardPresentation.reply(post, this.canReplyHere()),
      richCooked: post.cooked,
      richRaw: post.raw,
      authorActionAvailable: true,
      topicId: this.state.topicId,
      post: post,
      postActionState: this.state.postActionState,
      bookmarked: this.bookmarkedPostIds.includes(post.id),
      editable: this.canEditPost(post),
      validReactions: this.state.detail?.validReactions ?? [],
      authenticated: this.authenticated,
      onOpenRichLink: (url: string): void => this.onOpenRichLink(url),
      onOpenRichEmbed: (url: string, provider: RichEmbedProvider, title: string): void =>
        this.onOpenRichEmbed(url, provider, title),
      onOpenImage: (url: string, title: string, transitionId: string): void =>
        this.onOpenImage(url, title, transitionId),
      onOpenAuthor: (username: string): void => this.onOpenAuthor(username),
      onReply: (postNumber: number | null): void => this.onOpenReply(postNumber),
      onOpenReplyTarget: (postNumber: number): void => {
        this.onJumpToPost(postNumber);
      },
      onToggleReaction: (postId: number, reaction: string): void => this.onToggleReaction(postId, reaction),
      onVotePoll: this.onVotePoll,
      onRemovePollVote: this.onRemovePollVote,
      onLoginForPostAction: this.onLoginForPostAction,
      onOpenReactionUsers: (postId: number): void => this.onOpenReactionUsers(postId),
      onOpenReplies: (target: ForumPost): void => this.openReplyThread(target),
      onToggleBookmark: (postId: number): void => this.onToggleBookmark(postId),
      onToggleAcceptedAnswer: (postId: number): void => this.onToggleAcceptedAnswer(postId),
      onCopyPostLink: (topicId: number, postNumber: number): void => this.onCopyPostLink(topicId, postNumber),
      onReport: (target: ForumPost): void => this.openPostFlag(target),
      onEdit: (postId: number): void => this.onOpenEdit(postId),
      onDelete: (postId: number): void => this.onDeletePost(postId)
    })
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
  private ReactionUserAvatar(user: PostReactionUser): void {
    UserAvatar({
      avatarUrl: user.avatarUrl,
      displayName: user.username,
      avatarSize: 36,
      avatarAccessibilityText: `${user.username} 的头像`
    })
  }

  @Builder
  private ReactionUsersSheet(): void {
    Column({ space: 12 }) {
      if (this.reactionUsersState.kind === BrowseStateKind.LOADING) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.topic_reaction_users_loading')).fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.reactionUsersState.kind === BrowseStateKind.ERROR) {
        Text(this.reactionUsersState.message.length > 0
          ? this.reactionUsersState.message : '回应用户加载失败')
          .fontSize(14)
          .fontColor($r('app.color.status_error'))
      } else if (this.reactionUsersState.items.length === 0) {
        Text($r('app.string.topic_reaction_users_empty')).fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
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
  private ReplyThreadSheet(): void {
    PostReplyThreadSheet({
      parentPost: this.replyThreadParent,
      replies: this.replyThreadPosts,
      loading: this.replyThreadLoading,
      loadingMore: this.replyThreadLoadingMore,
      hasMore: this.replyThreadHasMore,
      message: this.replyThreadMessage,
      onRetry: (): void => {
        this.loadReplyThreadPage(true);
      },
      onLoadMore: (): void => {
        this.loadReplyThreadPage(false);
      },
      onOpenReply: (postNumber: number): void => {
        this.openReplyThreadPost(postNumber);
      }
    })
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
        Text($r('app.string.topic_report_description'))
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
          .width('100%')
        ForEach(postFlagOptions(this.flagUsername), (option: PostFlagOption) => {
          this.FlagOption(option)
        }, (option: PostFlagOption): string => option.typeId.toString())
        if (this.selectedFlagOption()?.needsMessage === true) {
          TextArea({ text: this.flagMessage, placeholder: $r('app.string.topic_report_placeholder') })
            .width('100%')
            .height(96)
            .maxLength(1000)
            .onChange((value: string): void => { this.flagMessage = value; })
        }
        Button($r('app.string.topic_report_submit'))
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
      Text($r('app.string.topic_posts_empty'))
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
        Text($r('app.string.topic_posts_loading_more'))
          .fontSize(14)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.paginationMessage.length > 0) {
        Text(this.state.paginationMessage)
          .fontSize(14)
          .fontColor($r('app.color.status_error'))
          .textAlign(TextAlign.Center)
        Button($r('app.string.common_retry_load_more'))
          .height(40)
          .fontSize(13)
          .onClick(this.onLoadMore)
          .accessibilityText($r('app.string.topic_posts_retry_more_accessibility'))
      } else if (!this.state.hasNextPosts && this.state.posts.length > 0) {
        Text($r('app.string.topic_posts_all_shown'))
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
        Text($r('app.string.topic_posts_loading_earlier'))
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      } else if (this.state.previousPaginationMessage.length > 0) {
        Text(this.state.previousPaginationMessage)
          .fontSize(13)
          .fontColor($r('app.color.status_error'))
        Button($r('app.string.topic_posts_retry_earlier'))
          .height(38)
          .fontSize(13)
          .onClick(this.onLoadPrevious)
      } else if (this.state.hasPreviousPosts) {
        Button($r('app.string.topic_posts_load_earlier'))
          .height(38)
          .fontSize(13)
          .onClick(this.onLoadPrevious)
          .accessibilityText($r('app.string.topic_posts_load_earlier_accessibility'))
      }
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private SuggestedTopics(detail: TopicDetail): void {
    if (detail.suggestedTopics.length > 0) {
      Column({ space: 10 }) {
        Text($r('app.string.topic_continue_reading'))
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .width('100%')
        ForEach(detail.suggestedTopics, (topic: Topic) => {
          ForumContentCard({
            presentation: ForumCardPresentation.topicPreview(topic, this.categories, null, this.emojis),
            onOpenTopic: (): void => this.onOpenSuggestedTopic(topic)
          })
        }, (topic: Topic): string => `${topic.id}-emoji-${this.emojis.length}`)
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
              this.scheduleReadProgress(this.state.posts[0].postNumber);
            }
          }
        )
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
              this.scheduleReadProgress(post.postNumber);
            }
          }
        )
      }, (post: ForumPost): string => topicPostRenderKey(post))
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
    .clip(false)
    .cachedCount(3, true)
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 10 })
    .backgroundColor($r('sys.color.background_secondary'))
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
    .scrollBar(BarState.Off)
    .onReachEnd(this.onLoadMore)
    .bindSheet($$this.replySheetVisible, this.ReplyComposerSheet(), {
      detents: [SheetSize.MEDIUM, SheetSize.LARGE],
      detentSelection: SheetSize.MEDIUM,
      showClose: true,
      dragBar: true,
      title: {
        title: this.composerPresentation().sheetTitle,
        subtitle: this.composerPresentation().sheetSubtitle
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
    Stack({ alignContent: Alignment.End }) {
      Column() {
        Stack() {
          Refresh({ refreshing: this.state.isRefreshing }) {
            this.ReadingList()
          }
          .width('100%')
          .height('100%')
          .clip(false)
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
        .clip(false)
        .bindSheet($$this.replyThreadSheetVisible, this.ReplyThreadSheet(), {
          detents: [SheetSize.MEDIUM, SheetSize.LARGE],
          detentSelection: SheetSize.LARGE,
          showClose: true,
          dragBar: true,
          title: {
            title: '回复线程',
            subtitle: this.replyThreadSubtitle()
          },
          shouldDismiss: (sheetDismiss: SheetDismiss): void => {
            this.replyThreadRequestVersion += 1;
            sheetDismiss.dismiss();
          }
        })
      }
      .width('100%')
      .height('100%')
      .clip(false)
      .bindSheet($$this.flagSheetVisible, this.PostFlagSheet(), {
        detents: [SheetSize.LARGE],
        detentSelection: SheetSize.LARGE,
        showClose: true,
        dragBar: true,
        title: { title: '举报帖子', subtitle: `Post by @${this.flagUsername}` }
      })

      TopicReadingProgressRail({
        posts: this.state.posts,
        currentPostNumber: this.currentPostNumber,
        highestPostNumber: this.highestPostNumber(),
        jumpBusy: this.state.postJumpState.busy,
        jumpMessage: this.state.postJumpState.message,
        jumpTargetPostNumber: this.state.postJumpState.targetPostNumber,
        onJump: (postNumber: number): void => {
          this.jumpToPostNumber(postNumber);
        },
        onRetry: (): void => {
          this.jumpToPostNumber(this.state.postJumpState.targetPostNumber, true);
        }
      })
        .width('100%')
        .height('100%')
        .zIndex(20)
        .hitTestBehavior(HitTestMode.Transparent)
    }
    .width('100%')
    .height('100%')
    .clip(false)
    .bindSheet($$this.topicNotificationSheetVisible, this.TopicNotificationSheet(), {
      detents: [SheetSize.MEDIUM],
      detentSelection: SheetSize.MEDIUM,
      showClose: true,
      dragBar: true,
      title: {
        title: 'Topic 通知',
        subtitle: `当前：${topicNotificationLabel(
          this.state.detail?.notificationLevel ?? TopicNotificationLevel.REGULAR
        )}`
      },
      shouldDismiss: (sheetDismiss: SheetDismiss): void => {
        if (!this.topicNotificationSaving) {
          sheetDismiss.dismiss();
        }
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
