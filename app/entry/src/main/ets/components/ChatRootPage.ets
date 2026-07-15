import { ChatChannelState, ChatSearchState, ChatStateKind } from '../app/ChatModel';
import { ChatChannel, ChatSearchResult } from '../models/ChatModels';

enum ChatRootSection {
  CHANNELS = 0,
  DIRECT_MESSAGES = 1,
  SEARCH = 2
}

@Component
export struct ChatRootPage {
  @Prop authenticated: boolean = false;
  @Prop capabilityLoading: boolean = false;
  @Prop capabilityError: string = '';
  @Prop canChat: boolean = false;
  @Prop canStartDirectChat: boolean = false;
  @Prop state: ChatChannelState = ChatChannelState.initial();
  @Prop searchState: ChatSearchState = new ChatSearchState();
  @State section: ChatRootSection = ChatRootSection.CHANNELS;
  @State searchText: string = '';
  @State directUsername: string = '';
  onLogin: () => void = (): void => {};
  onRetryCapability: () => void = (): void => {};
  onRefresh: () => void = (): void => {};
  onOpenChannel: (channel: ChatChannel) => void = (_channel: ChatChannel): void => {};
  onOpenSearchResult: (result: ChatSearchResult) => void = (_result: ChatSearchResult): void => {};
  onSearch: (query: string) => void = (_query: string): void => {};
  onLoadMoreSearch: () => void = (): void => {};
  onOpenDirectChat: (username: string) => void = (_username: string): void => {};

  private channels(directMessages: boolean): Array<ChatChannel> {
    return this.state.channels.filter(
      (channel: ChatChannel): boolean => channel.isDirectMessage === directMessages
    );
  }

  @Builder
  private Header(): void {
    Column({ space: 12 }) {
      Row() {
        Text('聊天').fontSize(24).fontWeight(FontWeight.Bold).layoutWeight(1)
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_clockwise')).fontSize(20)
        }
        .width(40).height(40).backgroundColor(Color.Transparent)
        .enabled(!this.state.refreshing)
        .onClick(this.onRefresh)
        .accessibilityText('刷新聊天频道与未读状态')
      }
      .width('100%')

      Row({ space: 8 }) {
        this.SectionButton('频道', ChatRootSection.CHANNELS)
        this.SectionButton('直接消息', ChatRootSection.DIRECT_MESSAGES)
        this.SectionButton('搜索', ChatRootSection.SEARCH)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 10 })
    .backgroundColor($r('sys.color.comp_background_primary'))
  }

  @Builder
  private SectionButton(label: string, section: ChatRootSection): void {
    Button(label, { type: ButtonType.Normal })
      .layoutWeight(1)
      .height(36)
      .fontSize(13)
      .fontColor(this.section === section ? '#FFFFFF' : $r('sys.color.font_secondary'))
      .backgroundColor(this.section === section ? '#317AF7' : $r('sys.color.background_secondary'))
      .onClick((): void => {
        this.section = section;
      })
  }

  @Builder
  private AuthenticationState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.message')).fontSize(46).fontColor([$r('sys.color.font_tertiary')])
      Text(this.authenticated ? '当前账号不可使用 Chat' : '登录后查看 RiverSide Chat')
        .fontSize(18).fontWeight(FontWeight.Bold).textAlign(TextAlign.Center)
      Text(this.authenticated
        ? '服务端没有为当前账号返回 Chat 许可，客户端不会猜测或绕过权限。'
        : '频道、私聊、未读与消息操作都需要 Authenticated Session。')
        .fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      if (!this.authenticated) {
        Button('登录并授权').onClick(this.onLogin)
      }
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private CapabilityErrorState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle')).fontSize(42).fontColor(['#C62828'])
      Text('无法确认 Chat 权限').fontSize(18).fontWeight(FontWeight.Bold)
      Text(this.capabilityError).fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      Button('重试账号能力检查').onClick(this.onRetryCapability)
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ChannelCard(channel: ChatChannel): void {
    Column({ space: 7 }) {
      Row({ space: 8 }) {
        Text(channel.title).fontSize(16).fontWeight(FontWeight.Bold).layoutWeight(1).maxLines(1)
        if (channel.unreadCount > 0) {
          Text(channel.unreadCount.toString())
            .fontSize(11).fontColor('#FFFFFF').backgroundColor('#D32F2F')
            .padding({ left: 7, right: 7, top: 3, bottom: 3 }).borderRadius(10)
        }
      }
      if (channel.preview.length > 0) {
        Text(channel.lastMessageUsername.length > 0
          ? `${channel.lastMessageUsername}：${channel.preview}`
          : channel.preview)
          .fontSize(13).fontColor($r('sys.color.font_secondary')).maxLines(2).width('100%')
      } else {
        Text(channel.subtitle).fontSize(12).fontColor($r('sys.color.font_tertiary')).maxLines(1).width('100%')
      }
      if (channel.lastMessageAt.length > 0) {
        Text(channel.lastMessageAt.replace('T', ' ').replace('Z', ''))
          .fontSize(10).fontColor($r('sys.color.font_tertiary')).width('100%')
      }
    }
    .width('100%').padding(14).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(12)
    .border({ width: channel.unreadCount > 0 ? 1 : 0, color: '#B9D2FF' })
    .onClick((): void => this.onOpenChannel(channel))
    .accessibilityText(`${channel.title}${channel.unreadCount > 0 ? `，${channel.unreadCount} 条未读` : ''}`)
  }

  @Builder
  private ChannelList(directMessages: boolean): void {
    if (this.state.kind === ChatStateKind.LOADING && this.state.channels.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text('正在读取服务器 Chat 频道').fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === ChatStateKind.ERROR && this.state.channels.length === 0) {
      Column({ space: 12 }) {
        Text('聊天频道加载失败').fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.state.message).fontSize(13).fontColor('#C62828').textAlign(TextAlign.Center)
        Button('重试').onClick(this.onRefresh)
      }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
    } else if (this.channels(directMessages).length === 0) {
      Column({ space: 12 }) {
        Text(directMessages ? '暂无直接消息' : '暂无可见频道').fontSize(17).fontWeight(FontWeight.Bold)
        Text('列表完全遵从服务端返回。').fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      List({ space: 10 }) {
        ForEach(this.channels(directMessages), (channel: ChatChannel): void => {
          ListItem() { this.ChannelCard(channel) }
        }, (channel: ChatChannel): string => channel.id.toString())
      }
      .width('100%').height('100%').padding({ left: 12, right: 12, top: 10, bottom: 124 })
      .backgroundColor($r('sys.color.background_secondary')).edgeEffect(EdgeEffect.Spring)
    }
  }

  @Builder
  private SearchPanel(): void {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        TextInput({ text: this.searchText, placeholder: '搜索 Chat 消息' })
          .layoutWeight(1).height(42).backgroundColor($r('sys.color.background_secondary'))
          .onChange((value: string): void => { this.searchText = value; })
          .onSubmit((): void => this.onSearch(this.searchText))
        Button('搜索').height(42).onClick((): void => this.onSearch(this.searchText))
      }
      .width('100%')

      if (this.canStartDirectChat) {
        Row({ space: 8 }) {
          TextInput({ text: this.directUsername, placeholder: '输入用户名发起私聊' })
            .layoutWeight(1).height(40).backgroundColor($r('sys.color.background_secondary'))
            .onChange((value: string): void => { this.directUsername = value; })
          Button('新私聊', { type: ButtonType.Normal })
            .height(40).enabled(this.directUsername.trim().length > 0)
            .onClick((): void => this.onOpenDirectChat(this.directUsername))
        }
        .width('100%')
      }

      if (this.searchState.kind === ChatStateKind.INITIAL) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(34)
            .fontColor([$r('sys.color.font_tertiary')])
          Text('输入关键词搜索可访问的 Chat 消息').fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.LOADING) {
        Column({ space: 8 }) { LoadingProgress().width(30).height(30); Text('正在搜索') }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.ERROR) {
        Column({ space: 8 }) {
          Text(this.searchState.message).fontSize(13).fontColor('#C62828').textAlign(TextAlign.Center)
          Button('重试').onClick((): void => this.onSearch(this.searchText))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.EMPTY) {
        Column() { Text('没有找到 Chat 消息').fontSize(14).fontColor($r('sys.color.font_secondary')) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: 9 }) {
          ForEach(this.searchState.results, (result: ChatSearchResult): void => {
            ListItem() {
              Column({ space: 5 }) {
                Text(result.channel.title).fontSize(14).fontWeight(FontWeight.Bold).width('100%')
                Text(`${result.message.username}：${result.message.displayText()}`)
                  .fontSize(13).fontColor($r('sys.color.font_secondary')).maxLines(3).width('100%')
              }
              .width('100%').padding(13).backgroundColor($r('sys.color.comp_background_primary')).borderRadius(10)
              .onClick((): void => this.onOpenSearchResult(result))
            }
          }, (result: ChatSearchResult): string => result.message.id.toString())
          if (this.searchState.hasMore || this.searchState.loadingMore || this.searchState.message.length > 0) {
            ListItem() {
              Button(this.searchState.loadingMore ? '正在加载' : '加载更多')
                .width('100%').enabled(!this.searchState.loadingMore).onClick(this.onLoadMoreSearch)
            }
          }
        }
        .layoutWeight(1).width('100%').padding({ bottom: 112 })
        .backgroundColor($r('sys.color.background_secondary'))
        .onReachEnd(this.onLoadMoreSearch)
      }
    }
    .width('100%').height('100%').padding({ left: 12, right: 12, top: 10 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    if (this.authenticated && this.capabilityLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text('正在确认 Chat 权限').fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.authenticated && this.capabilityError.length > 0) {
      this.CapabilityErrorState()
    } else if (!this.authenticated || !this.canChat) {
      this.AuthenticationState()
    } else {
      Column() {
        this.Header()
        if (this.section === ChatRootSection.CHANNELS) {
          this.ChannelList(false)
        } else if (this.section === ChatRootSection.DIRECT_MESSAGES) {
          this.ChannelList(true)
        } else {
          this.SearchPanel()
        }
      }
      .width('100%').height('100%').backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
