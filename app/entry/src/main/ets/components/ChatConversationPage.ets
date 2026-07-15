import { ChatComposerState, ChatConversationState, ChatStateKind } from '../app/ChatModel';
import { RepositoryResult, RepositoryResultKind } from '../core/RepositoryResult';
import { ComposerEdit } from '../models/AuthoringModels';
import { applyChatComposerMention, findChatComposerMention } from '../models/ChatComposerEditing';
import {
  ComposerMentionQuery,
  ComposerMentionRequestGate,
  ComposerMentionUser
} from '../models/ComposerMentionModels';
import {
  absoluteChatUrl,
  ChatChannel,
  ChatEmoji,
  ChatMessage,
  ChatReaction,
  ChatReactionAction,
  ChatReactionUser
} from '../models/ChatModels';
import { MediaUploadResult, MediaUploadState, MediaUploadStateKind } from '../models/MediaModels';
import {
  ChatMessageFragment,
  ChatMessageFragmentKind,
  presentChatMessageBody,
  presentChatText
} from './ChatMessagePresentation';

@Component
export struct ChatConversationPage {
  @Prop state: ChatConversationState = ChatConversationState.initial();
  @Prop composer: ChatComposerState = new ChatComposerState();
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop uploadState: MediaUploadState | null = null;
  @Prop currentUsername: string = '';
  @State emojiQuery: string = '';
  @State mentionUsers: Array<ComposerMentionUser> = [];
  @State mentionLoading: boolean = false;
  @State mentionMessage: string = '';
  onRetry: () => void = (): void => {};
  onLoadOlder: () => void = (): void => {};
  onLoadNewer: () => void = (): void => {};
  onDraftChange: (value: string) => void = (_value: string): void => {};
  onSend: () => void = (): void => {};
  onSelectImages: () => void = (): void => {};
  onRetryUpload: () => void = (): void => {};
  onCancelUpload: () => void = (): void => {};
  onRemoveUpload: (uploadId: number) => void = (_uploadId: number): void => {};
  onReply: (messageId: number) => void = (_messageId: number): void => {};
  onCancelReply: () => void = (): void => {};
  onMention: (username: string) => void = (_username: string): void => {};
  onLoadMentionUsers: (term: string) => Promise<RepositoryResult<Array<ComposerMentionUser>>> =
    async (_term: string): Promise<RepositoryResult<Array<ComposerMentionUser>>> => {
      return RepositoryResult.success<Array<ComposerMentionUser>>([]);
    };
  onInsertEmoji: (name: string, selectionStart: number, selectionEnd: number) => ComposerEdit | null =
    (_name: string, _selectionStart: number, _selectionEnd: number): ComposerEdit | null => null;
  onReact: (messageId: number, emoji: string, action: ChatReactionAction) => void =
    (_messageId: number, _emoji: string, _action: ChatReactionAction): void => {};
  onDelete: (messageId: number) => void = (_messageId: number): void => {};
  onRestore: (messageId: number) => void = (_messageId: number): void => {};
  onCopyMessage: (message: string) => void = (_message: string): void => {};
  onCopyMessageLink: (channelId: number, channelSlug: string, messageId: number) => void =
    (_channelId: number, _channelSlug: string, _messageId: number): void => {};
  onOpenImage: (url: string) => void = (_url: string): void => {};
  onOpenProfile: (username: string) => void = (_username: string): void => {};
  onLeaveChannel: () => void = (): void => {};
  private readonly composerController: TextAreaController = new TextAreaController();
  private readonly mentionRequestGate: ComposerMentionRequestGate = new ComposerMentionRequestGate();
  private mentionTimer: number = -1;
  private composerSelectionStart: number = 0;
  private composerSelectionEnd: number = 0;

  aboutToDisappear(): void {
    this.cancelMentionTimer();
    this.mentionRequestGate.invalidate();
  }

  private cancelMentionTimer(): void {
    if (this.mentionTimer >= 0) {
      clearTimeout(this.mentionTimer);
      this.mentionTimer = -1;
    }
  }

  private resetMentionSuggestions(): void {
    this.mentionUsers = [];
    this.mentionLoading = false;
    this.mentionMessage = '';
  }

  private scheduleMentionSearch(source: string, cursor: number): void {
    this.cancelMentionTimer();
    this.mentionRequestGate.invalidate();
    const query: ComposerMentionQuery | null = findChatComposerMention(source, cursor);
    if (query === null) {
      this.resetMentionSuggestions();
      return;
    }
    this.resetMentionSuggestions();
    this.mentionTimer = setTimeout((): void => {
      this.mentionTimer = -1;
      this.loadMentionUsers(query.term);
    }, 300);
  }

  private async loadMentionUsers(term: string): Promise<void> {
    const generation: number = this.mentionRequestGate.issue();
    this.mentionLoading = true;
    let result: RepositoryResult<Array<ComposerMentionUser>>;
    try {
      result = await this.onLoadMentionUsers(term);
    } catch (_) {
      if (this.mentionRequestGate.isCurrent(generation)) {
        this.mentionLoading = false;
        this.mentionUsers = [];
        this.mentionMessage = '搜索用户失败，请稍后重试';
      }
      return;
    }
    if (!this.mentionRequestGate.isCurrent(generation)) {
      return;
    }
    this.mentionLoading = false;
    if (result.kind === RepositoryResultKind.SUCCESS && result.data !== null) {
      this.mentionUsers = result.data;
      this.mentionMessage = result.data.length === 0 ? '没有匹配的用户' : '';
      return;
    }
    this.mentionUsers = [];
    this.mentionMessage = result.kind === RepositoryResultKind.UNAUTHORIZED
      ? '登录后可搜索用户'
      : result.message;
  }

  private handleDraftChange(value: string): void {
    this.onDraftChange(value);
    this.scheduleMentionSearch(value, Math.min(this.composerSelectionEnd, value.length));
  }

  private selectMention(user: ComposerMentionUser): void {
    const edit: ComposerEdit | null = applyChatComposerMention(
      this.composer.draft,
      this.composerSelectionEnd,
      user.username
    );
    if (edit === null) {
      this.resetMentionSuggestions();
      return;
    }
    this.onDraftChange(edit.text);
    this.composerSelectionStart = edit.selectionStart;
    this.composerSelectionEnd = edit.selectionEnd;
    this.resetMentionSuggestions();
    this.mentionRequestGate.invalidate();
    setTimeout((): void => {
      this.composerController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  private insertEmoji(name: string): void {
    const edit: ComposerEdit | null = this.onInsertEmoji(
      name,
      this.composerSelectionStart,
      this.composerSelectionEnd
    );
    if (edit === null) {
      return;
    }
    this.composerSelectionStart = edit.selectionStart;
    this.composerSelectionEnd = edit.selectionEnd;
    setTimeout((): void => {
      this.composerController.setTextSelection(edit.selectionStart, edit.selectionEnd);
    }, 0);
  }

  private messageForId(messageId: number | null): ChatMessage | null {
    if (messageId === null) {
      return null;
    }
    return this.state.messages.find((message: ChatMessage): boolean => message.id === messageId) ?? null;
  }

  private emojiForReaction(reaction: ChatReaction): ChatEmoji | null {
    const name: string = reaction.emoji.replace(/reaction\.|emoji\.|:/g, '');
    return this.emojis.find((emoji: ChatEmoji): boolean => emoji.name === name) ?? null;
  }

  private emojiUrlForReaction(reaction: ChatReaction): string {
    const emoji: ChatEmoji | null = this.emojiForReaction(reaction);
    return emoji?.imageUrl() ?? '';
  }

  private reactionUsernames(message: ChatMessage): string {
    const usernames: Array<string> = [];
    message.reactions.forEach((reaction: ChatReaction): void => {
      reaction.users.forEach((user: ChatReactionUser): void => {
        if (!usernames.includes(user.username)) {
          usernames.push(user.username);
        }
      });
    });
    return usernames.join('、');
  }

  private canDelete(message: ChatMessage): boolean {
    const channel: ChatChannel | null = this.state.channel;
    if (channel === null) {
      return false;
    }
    return message.username === this.currentUsername
      ? channel.canDeleteSelf
      : channel.canDeleteOthers;
  }

  private canWrite(): boolean {
    return this.state.channel !== null && !this.state.channel.userSilenced;
  }

  private visibleEmojis(): Array<ChatEmoji> {
    const query: string = this.emojiQuery.trim().toLowerCase();
    return this.emojis.filter((emoji: ChatEmoji): boolean => query.length === 0 ||
      emoji.name.toLowerCase().includes(query) || emoji.group.toLowerCase().includes(query)).slice(0, 40);
  }

  @Builder
  private MessageBody(message: ChatMessage): void {
    Text() {
      ForEach(presentChatMessageBody(message, this.emojis), (fragment: ChatMessageFragment) => {
        if (fragment.kind === ChatMessageFragmentKind.EMOJI) {
          ImageSpan(fragment.imageUrl)
            .width(18)
            .height(18)
            .objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(fragment.text)
        }
      }, (fragment: ChatMessageFragment, index: number): string => `${index}-${fragment.text}`)
    }
    .fontSize(14)
    .lineHeight(21)
    .fontColor(message.deleted ? $r('sys.color.font_tertiary') : $r('sys.color.font_primary'))
    .fontStyle(message.deleted ? FontStyle.Italic : FontStyle.Normal)
    .width('100%')
  }

  @Builder
  private ReplyPreviewText(value: string): void {
    Text() {
      ForEach(presentChatText(value, this.emojis), (fragment: ChatMessageFragment) => {
        if (fragment.kind === ChatMessageFragmentKind.EMOJI) {
          ImageSpan(fragment.imageUrl)
            .width(14)
            .height(14)
            .objectFit(ImageFit.Contain)
            .verticalAlign(ImageSpanAlignment.CENTER)
        } else {
          Span(fragment.text)
        }
      }, (fragment: ChatMessageFragment, index: number): string => `${index}-${fragment.text}`)
    }
    .fontSize(11)
    .fontColor($r('sys.color.font_secondary'))
    .maxLines(2)
    .textOverflow({ overflow: TextOverflow.Ellipsis })
    .width('100%')
  }

  @Builder
  private LoadingState(): void {
    Column({ space: 12 }) {
      LoadingProgress().width(36).height(36)
      Text('正在读取 Chat 消息').fontSize(13).fontColor($r('sys.color.font_secondary'))
    }.width('100%').height('100%').justifyContent(FlexAlign.Center)
  }

  @Builder
  private ErrorState(): void {
    Column({ space: 12 }) {
      Text('消息加载失败').fontSize(20).fontWeight(FontWeight.Bold)
      Text(this.state.message).fontSize(13).fontColor('#C62828').textAlign(TextAlign.Center)
      Button('重试').onClick(this.onRetry)
    }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ReactionChip(message: ChatMessage, reaction: ChatReaction): void {
    Row({ space: 4 }) {
      if (this.emojiUrlForReaction(reaction).length > 0) {
        Image(this.emojiUrlForReaction(reaction))
          .width(18).height(18).objectFit(ImageFit.Contain)
      } else {
        Text(`:${reaction.emoji.replace(/:/g, '')}:`).fontSize(11)
      }
      Text(reaction.count.toString()).fontSize(11).fontColor($r('sys.color.font_secondary'))
    }
    .height(28).padding({ left: 8, right: 8 }).borderRadius(14)
    .backgroundColor($r('sys.color.background_secondary'))
    .onClick((): void => this.onReact(
      message.id,
      reaction.emoji,
      reaction.reacted ? ChatReactionAction.REMOVE : ChatReactionAction.ADD
    ))
    .accessibilityText(
      `${reaction.emoji}，${reaction.count} 人${reaction.users.length > 0
        ? `，${reaction.users.map((user: ChatReactionUser): string => user.username).join('、')}` : ''}`
    )
  }

  @Builder
  private MessageCard(message: ChatMessage): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(message.username.length > 0 ? message.username : '未知用户')
          .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#317AF7')
          .onClick((): void => this.onOpenProfile(message.username))
        Text(message.createdAt.replace('T', ' ').replace('Z', ''))
          .fontSize(10).fontColor($r('sys.color.font_tertiary')).layoutWeight(1)
      }
      .width('100%')

      if (message.replyTo !== null) {
        Column({ space: 3 }) {
          Text(`回复 ${message.replyTo.username}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#317AF7')
          this.ReplyPreviewText(message.replyTo.excerpt)
        }
        .width('100%').padding(8).backgroundColor($r('sys.color.background_secondary'))
        .border({ width: { left: 3 }, color: '#317AF7' })
      }

      this.MessageBody(message)

      if (!message.deleted && message.uploadUrls.length > 0) {
        ForEach(message.uploadUrls, (url: string): void => {
          Image(absoluteChatUrl(url)).width('100%').height(180).borderRadius(10)
            .objectFit(ImageFit.Contain).backgroundColor($r('sys.color.background_secondary'))
            .onClick((): void => this.onOpenImage(absoluteChatUrl(url))).accessibilityText('打开 Chat 图片')
        }, (url: string): string => url)
      }

      if (message.reactions.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(message.reactions, (reaction: ChatReaction): void => {
            this.ReactionChip(message, reaction)
          }, (reaction: ChatReaction): string => reaction.emoji)
        }
        .width('100%')
        Text(this.reactionUsernames(message))
          .fontSize(10).fontColor($r('sys.color.font_tertiary')).maxLines(2).width('100%')
      }

      Row({ space: 6 }) {
        Button('复制', { type: ButtonType.Normal }).height(30).fontSize(11)
          .onClick((): void => this.onCopyMessage(message.message))
        if (this.state.channel !== null) {
          Button('复制链接', { type: ButtonType.Normal }).height(30).fontSize(11)
            .onClick((): void => this.onCopyMessageLink(
              this.state.channel?.id ?? 0,
              this.state.channel?.slug ?? '',
              message.id
            ))
        }
        if (!message.deleted && this.canWrite()) {
          Button('回复', { type: ButtonType.Normal }).height(30).fontSize(11)
            .onClick((): void => this.onReply(message.id))
          Button('@', { type: ButtonType.Normal }).height(30).fontSize(11)
            .onClick((): void => this.onMention(message.username))
          if (this.emojis.length > 0) {
            ForEach(this.emojis.slice(0, 5), (emoji: ChatEmoji): void => {
              Button() {
                Image(emoji.imageUrl()).width(18).height(18).objectFit(ImageFit.Contain)
              }
              .width(30).height(30).backgroundColor($r('sys.color.background_secondary'))
              .onClick((): void => this.onReact(message.id, emoji.name, ChatReactionAction.ADD))
              .accessibilityText(`添加 Reaction ${emoji.name}`)
            }, (emoji: ChatEmoji): string => emoji.name)
          }
        }
        if (this.canDelete(message) && !message.deleted) {
          Button('删除', { type: ButtonType.Normal }).height(30).fontSize(11).fontColor('#C62828')
            .onClick((): void => this.onDelete(message.id))
        } else if (this.canDelete(message) && message.deleted) {
          Button('恢复', { type: ButtonType.Normal }).height(30).fontSize(11)
            .onClick((): void => this.onRestore(message.id))
        }
      }
      .width('100%')
    }
    .width('88%').padding(12)
    .backgroundColor(message.username === this.currentUsername
      ? $r('sys.color.background_secondary')
      : $r('sys.color.comp_background_primary'))
    .borderRadius(12).border({ width: 1, color: $r('sys.color.comp_divider') })
  }

  @Builder
  private MessageList(): void {
    List({ space: 10 }) {
      if (this.state.canLoadMorePast || this.state.loadingPast || this.state.message.length > 0) {
        ListItem() {
          Column({ space: 5 }) {
            if (this.state.message.length > 0) {
              Text(this.state.message).fontSize(11).fontColor('#C62828').textAlign(TextAlign.Center)
            }
            if (this.state.canLoadMorePast || this.state.loadingPast) {
              Button(this.state.loadingPast ? '正在加载' : '加载更早消息')
                .enabled(!this.state.loadingPast).height(34).onClick(this.onLoadOlder)
            }
          }.width('100%')
        }
      }
      ForEach(this.state.messages, (message: ChatMessage): void => {
        ListItem() {
          Row() { this.MessageCard(message) }
            .width('100%')
            .justifyContent(message.username === this.currentUsername ? FlexAlign.End : FlexAlign.Start)
        }
      }, (message: ChatMessage): string => message.id.toString())
      if (this.state.canLoadMoreFuture || this.state.loadingFuture) {
        ListItem() {
          Button(this.state.loadingFuture ? '正在加载' : '加载更新消息')
            .width('100%').enabled(!this.state.loadingFuture).onClick(this.onLoadNewer)
        }
      }
    }
    .layoutWeight(1).width('100%').padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.background_secondary')).edgeEffect(EdgeEffect.Spring)
    .onReachEnd(this.onLoadNewer)
  }

  @Builder
  private EmojiBar(): void {
    if (this.emojis.length > 0) {
      Column({ space: 5 }) {
        TextInput({ text: this.emojiQuery, placeholder: '搜索 Emoji 名称或分组' })
          .width('100%').height(34).fontSize(11).backgroundColor($r('sys.color.background_secondary'))
          .enabled(this.canWrite())
          .onChange((value: string): void => { this.emojiQuery = value; })
        List({ space: 6 }) {
          ForEach(this.visibleEmojis(), (emoji: ChatEmoji): void => {
            ListItem() {
              Button() {
                Image(emoji.imageUrl()).width(22).height(22).objectFit(ImageFit.Contain)
              }
              .width(34).height(34).backgroundColor($r('sys.color.background_secondary')).enabled(this.canWrite())
              .onClick((): void => this.insertEmoji(emoji.name))
              .accessibilityText(`插入 Emoji ${emoji.name}`)
            }
          }, (emoji: ChatEmoji): string => emoji.name)
        }
        .width('100%').height(40).listDirection(Axis.Horizontal).edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
    }
  }

  @Builder
  private MentionSuggestions(): void {
    if (this.mentionLoading || this.mentionUsers.length > 0 || this.mentionMessage.length > 0) {
      Column({ space: 4 }) {
        if (this.mentionLoading) {
          Row({ space: 8 }) {
            LoadingProgress().width(18).height(18)
            Text('正在搜索用户').fontSize(12).fontColor($r('sys.color.font_secondary'))
          }
          .width('100%')
          .padding(8)
        } else if (this.mentionUsers.length > 0) {
          ForEach(this.mentionUsers, (user: ComposerMentionUser) => {
            Row({ space: 8 }) {
              if (user.avatarTemplate.length > 0) {
                Image(absoluteChatUrl(user.avatarTemplate.replace('{size}', '48')))
                  .width(28)
                  .height(28)
                  .borderRadius(14)
                  .objectFit(ImageFit.Cover)
              }
              Column({ space: 2 }) {
                Text(`@${user.username}`).fontSize(13).fontWeight(FontWeight.Medium)
                if (user.name.length > 0) {
                  Text(user.name).fontSize(11).fontColor($r('sys.color.font_secondary')).maxLines(1)
                }
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .padding({ left: 10, right: 10, top: 7, bottom: 7 })
            .onClick((): void => this.selectMention(user))
            .accessibilityText(`提及用户 ${user.username}`)
          }, (user: ComposerMentionUser): string => user.username)
        } else {
          Text(this.mentionMessage).fontSize(12).fontColor($r('sys.color.font_secondary')).width('100%').padding(8)
        }
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .borderRadius(10)
    }
  }

  @Builder
  private ReplyComposerBar(reply: ChatMessage | null): void {
    if (reply !== null) {
      Row({ space: 8 }) {
        Column({ space: 2 }) {
          Text(`回复 ${reply.username}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#317AF7')
          this.ReplyPreviewText(reply.displayText())
        }
        .layoutWeight(1)
        Button('取消', { type: ButtonType.Normal }).height(28).fontSize(10).onClick(this.onCancelReply)
      }
      .width('100%').padding(8).backgroundColor($r('sys.color.background_secondary')).borderRadius(8)
    }
  }

  @Builder
  private Composer(): void {
    Column({ space: 8 }) {
      this.ReplyComposerBar(this.messageForId(this.composer.replyToMessageId))
      if (this.composer.uploads.length > 0) {
        Flex({ direction: FlexDirection.Row, wrap: FlexWrap.Wrap, justifyContent: FlexAlign.Start }) {
          ForEach(this.composer.uploads, (upload: MediaUploadResult): void => {
            Button(`图片 ${upload.id} ×`, { type: ButtonType.Normal })
              .height(30).fontSize(10).onClick((): void => this.onRemoveUpload(upload.id))
          }, (upload: MediaUploadResult): string => upload.id.toString())
        }.width('100%')
      }
      if (this.uploadState !== null) {
        Row({ space: 8 }) {
          Text(this.uploadState.message.length > 0
            ? this.uploadState.message
            : `图片上传 ${this.uploadState.progressPercent}%`)
            .fontSize(11).fontColor(this.uploadState.kind === MediaUploadStateKind.FAILED
              ? '#C62828'
              : $r('sys.color.font_secondary'))
            .layoutWeight(1)
          if (this.uploadState.canCancel()) {
            Button('取消').height(28).fontSize(10).onClick(this.onCancelUpload)
          } else if (this.uploadState.canRetry()) {
            Button('重试').height(28).fontSize(10).onClick(this.onRetryUpload)
          }
        }.width('100%')
      }
      this.EmojiBar()
      this.MentionSuggestions()
      Row({ space: 8 }) {
        Button() { SymbolGlyph($r('sys.symbol.ohos_photo')).fontSize(20) }
          .width(40).height(40).backgroundColor($r('sys.color.background_secondary'))
          .enabled(!this.composer.sending && this.canWrite())
          .onClick(this.onSelectImages).accessibilityText('选择并上传 Chat 图片')
        TextArea({
          text: this.composer.draft,
          placeholder: '输入消息，支持 @ 与 Emoji',
          controller: this.composerController
        })
          .layoutWeight(1).constraintSize({ minHeight: 42, maxHeight: 100 })
          .backgroundColor($r('sys.color.background_secondary')).enabled(this.canWrite()).onChange((value: string): void => {
            this.handleDraftChange(value);
          })
          .onTextSelectionChange((selectionStart: number, selectionEnd: number): void => {
            this.composerSelectionStart = selectionStart;
            this.composerSelectionEnd = selectionEnd;
            this.scheduleMentionSearch(this.composer.draft, selectionEnd);
          })
        Button() { SymbolGlyph($r('sys.symbol.paperplane')).fontSize(20) }
          .width(44).height(44).enabled(this.canWrite() && !this.composer.sending &&
            (this.composer.draft.trim().length > 0 || this.composer.uploads.length > 0))
          .onClick(this.onSend).accessibilityText('发送 Chat 消息')
      }
      .width('100%')
      if (this.composer.message.length > 0) {
        Text(this.composer.message).fontSize(11)
          .fontColor(this.composer.sending ? $r('sys.color.font_secondary') : '#C62828').width('100%')
      }
    }
    .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 12 })
    .backgroundColor($r('sys.color.comp_background_primary'))
    .border({ width: { top: 1 }, color: $r('sys.color.comp_divider') })
  }

  build() {
    Column() {
      if (this.state.channel !== null && !this.state.channel.isDirectMessage) {
        Row() {
          Text(this.state.channel.subtitle).fontSize(11).fontColor($r('sys.color.font_secondary')).layoutWeight(1)
          Button('离开频道', { type: ButtonType.Normal }).height(30).fontSize(10).fontColor('#C62828')
            .onClick(this.onLeaveChannel)
        }.width('100%').padding({ left: 12, right: 12, top: 5, bottom: 5 })
          .backgroundColor($r('sys.color.comp_background_primary'))
      }
      if (this.state.channel?.userSilenced === true) {
        Text('当前账号不能在此频道发言；历史消息仍可阅读。')
          .fontSize(11).fontColor('#C62828').width('100%')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor($r('sys.color.background_secondary'))
      }
      if (this.state.kind === ChatStateKind.LOADING) {
        this.LoadingState()
      } else if (this.state.kind === ChatStateKind.ERROR) {
        this.ErrorState()
      } else {
        this.MessageList()
        this.Composer()
      }
    }
    .width('100%').height('100%').backgroundColor($r('sys.color.background_secondary'))
  }
}
