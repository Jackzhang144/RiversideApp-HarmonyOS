import { ChatChannelState, ChatSearchState, ChatStateKind } from '../app/ChatStateModels';
import { ChatChannel, ChatSearchResult } from '../models/ChatModels';
import { compactActivityTime } from './ActivityTimePresentation';
import { SegmentedCapsule, SegmentedCapsuleItem } from './SegmentedCapsule';

enum ChatRootSection {
  CHANNELS = 'channels',
  DIRECT_MESSAGES = 'direct-messages',
  SEARCH = 'search'
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
  scroller: Scroller = new Scroller();
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

  private sectionItems(): Array<SegmentedCapsuleItem> {
    return [
      new SegmentedCapsuleItem(ChatRootSection.CHANNELS, '频道', $r('sys.symbol.message')),
      new SegmentedCapsuleItem(ChatRootSection.DIRECT_MESSAGES, '直接消息', $r('sys.symbol.envelope')),
      new SegmentedCapsuleItem(ChatRootSection.SEARCH, '搜索', $r('sys.symbol.magnifyingglass'))
    ];
  }

  private selectSection(id: string): void {
    if (id === ChatRootSection.CHANNELS) {
      this.section = ChatRootSection.CHANNELS;
    } else if (id === ChatRootSection.DIRECT_MESSAGES) {
      this.section = ChatRootSection.DIRECT_MESSAGES;
    } else if (id === ChatRootSection.SEARCH) {
      this.section = ChatRootSection.SEARCH;
    }
  }

  private unreadText(count: number): string {
    return count > 99 ? '99+' : count.toString();
  }

  @Builder
  private SectionSwitcher(): void {
    Column() {
      SegmentedCapsule({
        items: this.sectionItems(),
        selectedId: this.section,
        onSelect: (id: string): void => this.selectSection(id)
      })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor($r('sys.color.background_secondary'))
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
        Button($r('app.string.chat_login')).onClick(this.onLogin)
      }
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private CapabilityErrorState(): void {
    Column({ space: 14 }) {
      SymbolGlyph($r('sys.symbol.exclamationmark_circle')).fontSize(42).fontColor([$r('app.color.status_error')])
      Text($r('app.string.chat_capability_failed')).fontSize(18).fontWeight(FontWeight.Bold)
      Text(this.capabilityError).fontSize(13).fontColor($r('sys.color.font_secondary')).textAlign(TextAlign.Center)
      Button($r('app.string.chat_capability_retry')).onClick(this.onRetryCapability)
    }
    .width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
  }

  @Builder
  private ChannelRow(channel: ChatChannel): void {
    Row({ space: 12 }) {
      SymbolGlyph(channel.isDirectMessage ? $r('sys.symbol.envelope') : $r('sys.symbol.message'))
        .fontSize(22)
        .fontColor([$r('app.color.brand_primary')])
        .width(40)
        .height(40)
        .padding(9)
        .backgroundColor($r('app.color.brand_tint_surface'))
        .borderRadius(12)
      Column({ space: 4 }) {
        Row({ space: 8 }) {
          Text(channel.title)
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (channel.unreadCount > 0) {
            Text(this.unreadText(channel.unreadCount))
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.on_accent'))
              .height(18)
              .constraintSize({ minWidth: 18 })
              .padding({ left: 5, right: 5 })
              .textAlign(TextAlign.Center)
              .backgroundColor($r('app.color.brand_primary'))
              .borderRadius(9)
          }
        }
        .width('100%')
        Row({ space: 8 }) {
          Text(channel.preview.length > 0
            ? (channel.lastMessageUsername.length > 0
              ? `${channel.lastMessageUsername}：${channel.preview}`
              : channel.preview)
            : channel.subtitle)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (channel.lastMessageAt.length > 0) {
            Text(compactActivityTime(channel.lastMessageAt))
              .fontSize(11)
              .fontColor($r('sys.color.font_tertiary'))
              .maxLines(1)
          }
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(15)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .constraintSize({ minHeight: 68 })
    .padding({ left: 14, right: 14, top: 10, bottom: 10 })
    .onClick((): void => this.onOpenChannel(channel))
    .accessibilityText(`${channel.title}${channel.unreadCount > 0 ? `，${channel.unreadCount} 条未读` : ''}`)
  }

  @Builder
  private ChannelGroup(directMessages: boolean): void {
    Column({ space: 8 }) {
      Row({ space: 8 }) {
        Text(directMessages ? '直接消息' : '我的频道')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('sys.color.font_secondary'))
        Text(this.channels(directMessages).length.toString())
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
          .height(20)
          .constraintSize({ minWidth: 20 })
          .padding({ left: 6, right: 6 })
          .textAlign(TextAlign.Center)
          .backgroundColor($r('sys.color.comp_background_primary'))
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 8, right: 8 })

      Column() {
        ForEach(this.channels(directMessages), (channel: ChatChannel, index: number): void => {
          this.ChannelRow(channel)
          if (index < this.channels(directMessages).length - 1) {
            Divider()
              .margin({ left: 66, right: 14 })
              .color($r('sys.color.comp_divider'))
          }
        }, (channel: ChatChannel): string => channel.id.toString())
      }
      .width('100%')
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius(18)
      .border({ width: 1, color: $r('sys.color.comp_divider') })
      .clip(true)
    }
    .width('100%')
  }

  @Builder
  private ChannelList(directMessages: boolean): void {
    if (this.state.kind === ChatStateKind.LOADING && this.state.channels.length === 0) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.chat_channel_loading')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.state.kind === ChatStateKind.ERROR && this.state.channels.length === 0) {
      Column({ space: 12 }) {
        Text($r('app.string.chat_channel_load_failed')).fontSize(18).fontWeight(FontWeight.Bold)
        Text(this.state.message).fontSize(13).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
        Button($r('app.string.common_retry')).onClick(this.onRefresh)
      }.width('100%').height('100%').padding(32).justifyContent(FlexAlign.Center)
    } else if (this.channels(directMessages).length === 0) {
      Column({ space: 12 }) {
        Text(directMessages ? '暂无直接消息' : '暂无可见频道').fontSize(17).fontWeight(FontWeight.Bold)
        Text($r('app.string.chat_channel_empty_description')).fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else {
      Refresh({ refreshing: this.state.refreshing }) {
        List({ scroller: this.scroller }) {
          ListItem() {
            this.ChannelGroup(directMessages)
          }
          ListItem() {
            Column()
              .width('100%')
              .height(104)
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 12, top: 8 })
        .clip(true)
        .cachedCount(3, true)
        .backgroundColor($r('sys.color.background_secondary'))
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .width('100%')
      .height('100%')
      .refreshOffset(64)
      .pullToRefresh(true)
      .pullUpToCancelRefresh(false)
      .onRefreshing((): void => {
        this.onRefresh();
      })
    }
  }

  @Builder
  private SearchPanel(): void {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.magnifyingglass'))
          .fontSize(20)
          .fontColor([$r('sys.color.font_secondary')])
        TextInput({ text: this.searchText, placeholder: $r('app.string.chat_search_placeholder') })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(Color.Transparent)
          .onChange((value: string): void => { this.searchText = value; })
          .onSubmit((): void => this.onSearch(this.searchText))
        Button() {
          SymbolGlyph($r('sys.symbol.arrow_right'))
            .fontSize(17)
            .fontColor([$r('app.color.brand_primary')])
        }
        .width(36)
        .height(36)
        .backgroundColor(Color.Transparent)
        .onClick((): void => this.onSearch(this.searchText))
        .accessibilityText($r('app.string.chat_search_placeholder'))
      }
      .width('100%')
      .height(48)
      .padding({ left: 14, right: 8 })
      .backgroundColor($r('sys.color.comp_background_primary'))
      .borderRadius($r('app.float.card_corner_radius'))
      .border({ width: 1, color: $r('sys.color.comp_divider') })

      if (this.canStartDirectChat) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.envelope'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
          TextInput({ text: this.directUsername, placeholder: $r('app.string.chat_direct_placeholder') })
            .layoutWeight(1)
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .onChange((value: string): void => { this.directUsername = value; })
          Button() {
            SymbolGlyph($r('sys.symbol.plus'))
              .fontSize(17)
              .fontColor([$r('app.color.brand_primary')])
          }
            .width(36)
            .height(36)
            .backgroundColor(Color.Transparent)
            .enabled(this.directUsername.trim().length > 0)
            .onClick((): void => this.onOpenDirectChat(this.directUsername))
            .accessibilityText($r('app.string.chat_direct_start_accessibility'))
        }
        .width('100%')
        .height(48)
        .padding({ left: 14, right: 8 })
        .backgroundColor($r('sys.color.comp_background_primary'))
        .borderRadius($r('app.float.card_corner_radius'))
        .border({ width: 1, color: $r('sys.color.comp_divider') })
      }

      if (this.searchState.kind === ChatStateKind.INITIAL) {
        Column({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass')).fontSize(34)
            .fontColor([$r('sys.color.font_tertiary')])
          Text($r('app.string.chat_search_hint')).fontSize(13).fontColor($r('sys.color.font_secondary'))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.LOADING) {
        Column({ space: 8 }) { LoadingProgress().width(30).height(30); Text($r('app.string.chat_searching')) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.ERROR) {
        Column({ space: 8 }) {
          Text(this.searchState.message).fontSize(13).fontColor($r('app.color.status_error')).textAlign(TextAlign.Center)
          Button($r('app.string.common_retry')).onClick((): void => this.onSearch(this.searchText))
        }.layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else if (this.searchState.kind === ChatStateKind.EMPTY) {
        Column() { Text($r('app.string.chat_search_empty')).fontSize(14)
          .fontColor($r('sys.color.font_secondary')) }
          .layoutWeight(1).width('100%').justifyContent(FlexAlign.Center)
      } else {
        List({ space: 9, scroller: this.scroller }) {
          ForEach(this.searchState.results, (result: ChatSearchResult): void => {
            ListItem() {
              Column({ space: 5 }) {
                Text(result.channel.title).fontSize(14).fontWeight(FontWeight.Bold).width('100%')
                Text(`${result.message.username}：${result.message.displayText()}`)
                  .fontSize(13).fontColor($r('sys.color.font_secondary')).maxLines(3).width('100%')
              }
              .width('100%').padding($r('app.float.card_content_padding')).backgroundColor($r('sys.color.comp_background_primary')).borderRadius($r('app.float.card_corner_radius'))
              .border({ width: 1, color: $r('sys.color.comp_divider') })
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
        .clip(false).cachedCount(3, true)
        .backgroundColor($r('sys.color.background_secondary'))
        .onReachEnd(this.onLoadMoreSearch)
      }
    }
    .width('100%').height('100%').padding({ left: 12, right: 12, top: 8 })
    .backgroundColor($r('sys.color.background_secondary'))
  }

  build() {
    if (this.authenticated && this.capabilityLoading) {
      Column({ space: 12 }) {
        LoadingProgress().width(36).height(36)
        Text($r('app.string.chat_capability_loading')).fontSize(13).fontColor($r('sys.color.font_secondary'))
      }.width('100%').height('100%').justifyContent(FlexAlign.Center)
    } else if (this.authenticated && this.capabilityError.length > 0) {
      this.CapabilityErrorState()
    } else if (!this.authenticated || !this.canChat) {
      this.AuthenticationState()
    } else {
      Column() {
        this.SectionSwitcher()
        if (this.section === ChatRootSection.CHANNELS) {
          this.ChannelList(false)
        } else if (this.section === ChatRootSection.DIRECT_MESSAGES) {
          this.ChannelList(true)
        } else {
          this.SearchPanel()
        }
      }
      .width('100%').height('100%').clip(false)
      .backgroundColor($r('sys.color.background_secondary'))
    }
  }
}
