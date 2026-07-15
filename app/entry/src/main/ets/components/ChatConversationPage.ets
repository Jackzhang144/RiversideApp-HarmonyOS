import { ChatComposerState, ChatConversationState, ChatStateKind } from '../app/ChatModel';
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

@Component
export struct ChatConversationPage {
  @Prop state: ChatConversationState = ChatConversationState.initial();
  @Prop composer: ChatComposerState = new ChatComposerState();
  @Prop emojis: Array<ChatEmoji> = [];
  @Prop uploadState: MediaUploadState | null = null;
  @Prop currentUsername: string = '';
  @State emojiQuery: string = '';
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
  onInsertEmoji: (name: string) => void = (_name: string): void => {};
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
  private LoadingState(): void {
    Column({ space: 12 }) {
      LoadingProgress().width(36).height(36)
      Text('正在读取 Chat 消息').fontSize(13).fontColor('#52606D')
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
      Text(reaction.count.toString()).fontSize(11).fontColor('#52606D')
    }
    .height(28).padding({ left: 8, right: 8 }).borderRadius(14)
    .backgroundColor(reaction.reacted ? '#DCEAFF' : '#EEF1F5')
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
          .fontSize(10).fontColor('#98A2B3').layoutWeight(1)
      }
      .width('100%')

      if (message.replyTo !== null) {
        Column({ space: 3 }) {
          Text(`回复 ${message.replyTo.username}`).fontSize(11).fontWeight(FontWeight.Bold).fontColor('#317AF7')
          Text(message.replyTo.excerpt).fontSize(11).fontColor('#52606D').maxLines(2).width('100%')
        }
        .width('100%').padding(8).backgroundColor('#F0F5FC')
        .border({ width: { left: 3 }, color: '#317AF7' })
      }

      Text(message.displayText())
        .fontSize(14).lineHeight(21).fontColor(message.deleted ? '#7B8794' : '#24262B')
        .fontStyle(message.deleted ? FontStyle.Italic : FontStyle.Normal).width('100%')

      if (!message.deleted && message.uploadUrls.length > 0) {
        ForEach(message.uploadUrls, (url: string): void => {
          Image(absoluteChatUrl(url)).width('100%').height(180).borderRadius(10)
            .objectFit(ImageFit.Contain).backgroundColor('#E8EBF0')
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
          .fontSize(10).fontColor('#7B8794').maxLines(2).width('100%')
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
              .width(30).height(30).backgroundColor('#EEF1F5')
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
    .backgroundColor(message.username === this.currentUsername ? '#EAF2FF' : '#FFFFFF')
    .borderRadius(12).border({ width: 1, color: '#E4E8EE' })
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
    .backgroundColor('#F5F6F8').edgeEffect(EdgeEffect.Spring)
    .onReachEnd(this.onLoadNewer)
  }

  @Builder
  private EmojiBar(): void {
    if (this.emojis.length > 0) {
      Column({ space: 5 }) {
        TextInput({ text: this.emojiQuery, placeholder: '搜索 Emoji 名称或分组' })
          .width('100%').height(34).fontSize(11).backgroundColor('#F1F3F5')
          .enabled(this.canWrite())
          .onChange((value: string): void => { this.emojiQuery = value; })
        List({ space: 6 }) {
          ForEach(this.visibleEmojis(), (emoji: ChatEmoji): void => {
            ListItem() {
              Button() {
                Image(emoji.imageUrl()).width(22).height(22).objectFit(ImageFit.Contain)
              }
              .width(34).height(34).backgroundColor('#EEF1F5').enabled(this.canWrite())
              .onClick((): void => this.onInsertEmoji(emoji.name))
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
  private ReplyComposerBar(reply: ChatMessage | null): void {
    if (reply !== null) {
      Row({ space: 8 }) {
        Text(`回复 ${reply.username}：${reply.displayText()}`)
          .fontSize(11).fontColor('#52606D').maxLines(1).layoutWeight(1)
        Button('取消', { type: ButtonType.Normal }).height(28).fontSize(10).onClick(this.onCancelReply)
      }
      .width('100%').padding(8).backgroundColor('#F0F5FC').borderRadius(8)
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
            .fontSize(11).fontColor(this.uploadState.kind === MediaUploadStateKind.FAILED ? '#C62828' : '#52606D')
            .layoutWeight(1)
          if (this.uploadState.canCancel()) {
            Button('取消').height(28).fontSize(10).onClick(this.onCancelUpload)
          } else if (this.uploadState.canRetry()) {
            Button('重试').height(28).fontSize(10).onClick(this.onRetryUpload)
          }
        }.width('100%')
      }
      this.EmojiBar()
      Row({ space: 8 }) {
        Button() { SymbolGlyph($r('sys.symbol.ohos_photo')).fontSize(20) }
          .width(40).height(40).backgroundColor('#EEF1F5')
          .enabled(!this.composer.sending && this.canWrite())
          .onClick(this.onSelectImages).accessibilityText('选择并上传 Chat 图片')
        TextArea({ text: this.composer.draft, placeholder: '输入消息，支持 @ 与 Emoji' })
          .layoutWeight(1).constraintSize({ minHeight: 42, maxHeight: 100 })
          .backgroundColor('#F1F3F5').enabled(this.canWrite()).onChange(this.onDraftChange)
        Button() { SymbolGlyph($r('sys.symbol.paperplane')).fontSize(20) }
          .width(44).height(44).enabled(this.canWrite() && !this.composer.sending &&
            (this.composer.draft.trim().length > 0 || this.composer.uploads.length > 0))
          .onClick(this.onSend).accessibilityText('发送 Chat 消息')
      }
      .width('100%')
      if (this.composer.message.length > 0) {
        Text(this.composer.message).fontSize(11)
          .fontColor(this.composer.sending ? '#52606D' : '#C62828').width('100%')
      }
    }
    .width('100%').padding({ left: 12, right: 12, top: 8, bottom: 12 })
    .backgroundColor('#FFFFFF').border({ width: { top: 1 }, color: '#E4E8EE' })
  }

  build() {
    Column() {
      if (this.state.channel !== null && !this.state.channel.isDirectMessage) {
        Row() {
          Text(this.state.channel.subtitle).fontSize(11).fontColor('#52606D').layoutWeight(1)
          Button('离开频道', { type: ButtonType.Normal }).height(30).fontSize(10).fontColor('#C62828')
            .onClick(this.onLeaveChannel)
        }.width('100%').padding({ left: 12, right: 12, top: 5, bottom: 5 }).backgroundColor('#FFFFFF')
      }
      if (this.state.channel?.userSilenced === true) {
        Text('当前账号不能在此频道发言；历史消息仍可阅读。')
          .fontSize(11).fontColor('#C62828').width('100%')
          .padding({ left: 12, right: 12, top: 6, bottom: 6 }).backgroundColor('#FFF4F4')
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
    .width('100%').height('100%').backgroundColor('#F5F6F8')
  }
}
