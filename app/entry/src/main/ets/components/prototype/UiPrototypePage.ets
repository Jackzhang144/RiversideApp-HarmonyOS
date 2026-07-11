import {
  hdsMaterial,
  HdsSnackBar,
  HdsTabs,
  HdsTabsController,
  SnackBarOperationType
} from '@kit.UIDesignKit';
import { SymbolGlyphModifier } from '@kit.ArkUI';
import {
  NotificationPublishResult,
  SystemNotificationService
} from '../../core/SystemNotificationService';
import {
  PROTOTYPE_CATEGORIES,
  PROTOTYPE_REPLIES,
  PROTOTYPE_TOPICS,
  PrototypeCategory,
  PrototypeReply,
  PrototypeTopic
} from './PrototypeFixtures';

// PROTOTYPE — 用一条隔离路由在 API 23 设备上验证原生信息流的密度、层级和状态语义。
export enum PrototypeSurface {
  HOME = 0,
  CATEGORY = 1,
  CHAT = 2,
  NOTIFICATIONS = 3,
  ACCOUNT = 4,
  TOPIC = 5,
  REPLY = 6
}

export enum PrototypeViewState {
  CONTENT = 0,
  LOADING = 1,
  EMPTY = 2,
  ERROR = 3,
  UNAUTHORIZED = 4
}

@Component
export struct UiPrototypePage {
  private snackBar: HdsSnackBar | null = null;
  private readonly rootTabsController: HdsTabsController = new HdsTabsController();
  private readonly homeTabsController: HdsTabsController = new HdsTabsController();
  onExit: () => void = (): void => {};

  @State surface: PrototypeSurface = PrototypeSurface.HOME;
  @State viewState: PrototypeViewState = PrototypeViewState.CONTENT;
  @State homeTab: number = 0;
  @State chatMode: number = 0;
  @State notificationMode: number = 1;
  @State replyDraft: string = '';
  @State controlsVisible: boolean = false;
  @State homeRefreshing: boolean = false;
  @State notificationsRefreshing: boolean = false;

  aboutToAppear(): void {
    this.snackBar = new HdsSnackBar(this.getUIContext());
  }

  @Builder
  private SurfaceButton(label: string, target: PrototypeSurface): void {
    Button(label, { type: ButtonType.Normal })
      .fontSize(12)
      .fontColor(this.surface === target ? '#FFFFFF' : $r('sys.color.font_primary'))
      .backgroundColor(this.surface === target ? '#317AF7' : '#EEF1F5')
      .borderRadius(8)
      .height(36)
      .layoutWeight(1)
      .onClick((): void => {
        this.surface = target;
        this.viewState = PrototypeViewState.CONTENT;
      })
      .accessibilityText(`查看${label}设计原型`)
  }

  @Builder
  private SurfaceSwitcher(): void {
    Column({ space: 6 }) {
      Row({ space: 6 }) {
        this.SurfaceButton('首页', PrototypeSurface.HOME)
        this.SurfaceButton('Category', PrototypeSurface.CATEGORY)
        this.SurfaceButton('聊天', PrototypeSurface.CHAT)
      }
      .width('100%')
      Row({ space: 6 }) {
        this.SurfaceButton('消息', PrototypeSurface.NOTIFICATIONS)
        this.SurfaceButton('我的', PrototypeSurface.ACCOUNT)
        this.SurfaceButton('Topic', PrototypeSurface.TOPIC)
      }
      .width('100%')
      Row({ space: 6 }) {
        this.SurfaceButton('Reply', PrototypeSurface.REPLY)
        Blank().layoutWeight(1)
        Blank().layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
  }

  private viewStateLabel(state: PrototypeViewState): string {
    if (state === PrototypeViewState.LOADING) {
      return '加载';
    }
    if (state === PrototypeViewState.EMPTY) {
      return '空态';
    }
    if (state === PrototypeViewState.ERROR) {
      return '失败';
    }
    if (state === PrototypeViewState.UNAUTHORIZED) {
      return '未授权';
    }
    return '内容';
  }

  @Builder
  private StateButton(state: PrototypeViewState): void {
    Button(this.viewStateLabel(state), { type: ButtonType.Normal })
      .fontSize(12)
      .fontColor(this.viewState === state ? '#317AF7' : $r('sys.color.font_secondary'))
      .backgroundColor(Color.Transparent)
      .height(34)
      .onClick((): void => {
        this.viewState = state;
      })
      .accessibilityText(`切换到${this.viewStateLabel(state)}状态`)
  }

  @Builder
  private StateSwitcher(): void {
    Row({ space: 4 }) {
      this.StateButton(PrototypeViewState.CONTENT)
      this.StateButton(PrototypeViewState.LOADING)
      this.StateButton(PrototypeViewState.EMPTY)
      this.StateButton(PrototypeViewState.ERROR)
      this.StateButton(PrototypeViewState.UNAUTHORIZED)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
  }

  private showNotificationResult(title: string, content: string, succeeded: boolean): void {
    if (this.snackBar === null) {
      return;
    }
    this.snackBar.show(
      { icon: succeeded ? $r('sys.symbol.checkmark_circle') : $r('sys.symbol.exclamationmark_circle') },
      { title: title, content: content },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭通知测试提示'
      },
      { duration: 4000 }
    );
  }

  private async triggerSystemNotification(): Promise<void> {
    const result: NotificationPublishResult = await SystemNotificationService.publishPrototypeNotification();
    if (result === NotificationPublishResult.PUBLISHED) {
      this.showNotificationResult('系统通知已发送', '请下拉通知中心查看 RiverSide 测试通知。', true);
      return;
    }
    if (result === NotificationPublishResult.CONTEXT_UNAVAILABLE) {
      this.showNotificationResult('系统通知未发送', '无法获取当前页面的通知授权环境。', false);
      return;
    }
    this.showNotificationResult('系统通知未发送', '请允许 RiverSide 发送通知后重试。', false);
  }

  @Builder
  private NotificationTestButton(): void {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 8 }) {
        SymbolGlyph($r('sys.symbol.bell'))
          .fontSize(17)
          .fontColor(['#FFFFFF'])
        Text('触发系统通知')
          .fontSize(12)
          .fontColor('#FFFFFF')
      }
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height(36)
    .backgroundColor('#317AF7')
    .borderRadius(8)
    .onClick((): void => {
      this.triggerSystemNotification();
    })
    .accessibilityText('触发 RiverSide 系统测试通知')
  }

  @Builder
  private PrototypeControlPanel(): void {
    Column({ space: 8 }) {
      Row() {
        Column({ space: 2 }) {
          Text('设计原型控制')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
          Text('静态数据 · 不连接后端')
            .fontSize(11)
            .fontColor('#C9CDD4')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('收起', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor('#FFFFFF')
          .backgroundColor('#3B3D42')
          .onClick((): void => {
            this.controlsVisible = false;
          })
      }
      this.SurfaceSwitcher()
      this.StateSwitcher()
      this.NotificationTestButton()
      Button('退出原型', { type: ButtonType.Normal })
        .fontSize(12)
        .fontColor('#FFFFFF')
        .backgroundColor('#3B3D42')
        .width('100%')
        .height(34)
        .onClick(this.onExit)
        .accessibilityText('退出原生 UI UX 设计原型')
    }
    .width('94%')
    .padding(12)
    .margin({ right: 12, bottom: 12 })
    .backgroundColor('#24262B')
    .borderRadius(14)
  }

  @Builder
  private PrototypeControlTrigger(): void {
    Button('原型控制', { type: ButtonType.Normal })
      .fontSize(12)
      .fontColor('#FFFFFF')
      .backgroundColor('#24262B')
      .borderRadius(18)
      .height(36)
      .margin({ right: 12, bottom: 76 })
      .onClick((): void => {
        this.controlsVisible = true;
      })
      .accessibilityText('展开设计原型页面和状态控制')
  }

  @Builder
  private LoadingSkeleton(): void {
    Column({ space: 18 }) {
      ForEach([1, 2, 3, 4], (skeletonItem: number) => {
        Row({ space: 12 }) {
          Column({ space: 8 }) {
            Row().width('82%').height(16).backgroundColor('#E8EBF0').borderRadius(4)
            Row().width('100%').height(12).backgroundColor('#EFF1F4').borderRadius(4)
            Row().width('58%').height(12).backgroundColor('#EFF1F4').borderRadius(4)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')
      }, (skeletonKey: number): string => skeletonKey.toString())
    }
    .width('100%')
    .padding(20)
  }

  @Builder
  private EmptyState(): void {
    Column({ space: 12 }) {
      Text('暂时没有内容')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
      Text('稍后再来看看，或切换其他页面。')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
      Button('刷新原型')
        .onClick((): void => {
          this.viewState = PrototypeViewState.CONTENT;
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private ErrorState(): void {
    Column({ space: 12 }) {
      Text('加载失败，请检查网络')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
      Text('这是用于评审布局的静态失败状态。')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
      Button('重新加载')
        .onClick((): void => {
          this.viewState = PrototypeViewState.CONTENT;
        })
        .accessibilityText('重新加载设计原型')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private UnauthorizedState(): void {
    Column({ space: 12 }) {
      Text('需要登录后继续')
        .fontSize(20)
        .fontWeight(FontWeight.Medium)
      Text('登录后可 Reply，并查看需要身份的论坛内容。')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .textAlign(TextAlign.Center)
      Button('模拟登录成功')
        .onClick((): void => {
          this.viewState = PrototypeViewState.CONTENT;
        })
        .accessibilityText('仅在设计原型中模拟登录成功')
    }
    .padding(24)
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }

  @Builder
  private AppHeader(title: string, showActions: boolean): void {
    Row({ space: 8 }) {
      Button() {
        SymbolGlyph($r('sys.symbol.chevron_left'))
          .fontSize(22)
          .fontColor([$r('sys.color.font_primary')])
          .hitTestBehavior(HitTestMode.None)
      }
        .backgroundColor('#F2F3F5')
        .width(40)
        .height(40)
        .borderRadius(20)
        .onClick(this.onExit)
        .accessibilityText('退出设计原型')
      Text(title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .layoutWeight(1)
      if (showActions) {
        Button() {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(22)
            .fontColor([$r('sys.color.font_primary')])
            .hitTestBehavior(HitTestMode.None)
        }
          .backgroundColor(Color.Transparent)
          .width(40)
          .height(40)
          .borderRadius(20)
          .accessibilityText('搜索')
        Button() {
          SymbolGlyph($r('sys.symbol.plus'))
            .fontSize(22)
            .fontColor([$r('sys.color.font_primary')])
            .hitTestBehavior(HitTestMode.None)
        }
          .backgroundColor(Color.Transparent)
          .width(40)
          .height(40)
          .borderRadius(20)
          .accessibilityText('创建 Topic')
      }
    }
    .width('100%')
    .height(56)
    .padding({ left: 12, right: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: { bottom: 1 }, color: '#ECEEF2' })
  }

  private RootTabStyle(label: string, icon: Resource): BottomTabBarStyle {
    const normal: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .fontSize(21)
      .fontColor([$r('sys.color.font_secondary')]);
    const selected: SymbolGlyphModifier = new SymbolGlyphModifier(icon)
      .fontSize(21)
      .fontColor(['#317AF7']);
    return BottomTabBarStyle.of({ normal: normal, selected: selected }, label)
      .labelStyle({
        maxLines: 1,
        unselectedColor: $r('sys.color.font_secondary'),
        selectedColor: '#317AF7',
        font: { size: 11 }
      })
      .padding({ left: 4, right: 4, top: 4, bottom: 4 });
  }

  private rootSurfaceForIndex(index: number): PrototypeSurface {
    if (index === 1) {
      return PrototypeSurface.CATEGORY;
    }
    if (index === 2) {
      return PrototypeSurface.CHAT;
    }
    if (index === 3) {
      return PrototypeSurface.NOTIFICATIONS;
    }
    if (index === 4) {
      return PrototypeSurface.ACCOUNT;
    }
    return PrototypeSurface.HOME;
  }

  private isRootSurface(): boolean {
    return this.surface === PrototypeSurface.HOME ||
      this.surface === PrototypeSurface.CATEGORY ||
      this.surface === PrototypeSurface.CHAT ||
      this.surface === PrototypeSurface.NOTIFICATIONS ||
      this.surface === PrototypeSurface.ACCOUNT;
  }

  @Builder
  private TopicRow(topic: PrototypeTopic): void {
    Column({ space: 10 }) {
      Row({ space: 9 }) {
        Text(topic.author.substring(0, 1))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#317AF7')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EAF2FF')
          .borderRadius(18)
        Column({ space: 2 }) {
          Text(topic.author)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text(topic.updatedAt)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (topic.pinned) {
          Row({ space: 4 }) {
            SymbolGlyph($r('sys.symbol.pin'))
              .fontSize(13)
              .fontColor(['#317AF7'])
            Text('置顶')
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor('#317AF7')
          }
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor('#EAF2FF')
          .borderRadius(12)
          .accessibilityText('置顶 Topic')
        }
      }
      Text(topic.title)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
      Text(topic.excerpt)
        .fontSize(13)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(20)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      Row({ space: 8 }) {
        Row() {
          Text(topic.category)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#20A77A')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#EAF8F3')
            .borderRadius(10)
        }
        .layoutWeight(1)
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.message'))
            .fontSize(14)
            .fontColor([$r('sys.color.font_tertiary')])
          Text(topic.replies.toString())
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        Row({ space: 4 }) {
          SymbolGlyph($r('sys.symbol.eye'))
            .fontSize(14)
            .fontColor([$r('sys.color.font_tertiary')])
          Text(topic.views)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
    .accessibilityText(`${topic.title}，作者 ${topic.author}，${topic.replies} 条 Reply，${topic.views} 浏览`)
  }

  private HomeTabStyle(label: string): SubTabBarStyle {
    return SubTabBarStyle.of(label)
      .labelStyle({
        maxLines: 1,
        overflow: TextOverflow.Clip,
        font: { size: 14 }
      })
      .padding({ left: 8, right: 8, top: 0, bottom: 0 });
  }

  @Builder
  private HomeContent(): void {
    Column() {
      this.AppHeader('Riverside', true)
      HdsTabs({ controller: this.homeTabsController }) {
        TabContent() {
          this.RefreshableHomeTopicList(0)
        }
        .tabBar(this.HomeTabStyle('最新回复'))
        TabContent() {
          this.RefreshableHomeTopicList(1)
        }
        .tabBar(this.HomeTabStyle('最新发表'))
        TabContent() {
          this.RefreshableHomeTopicList(2)
        }
        .tabBar(this.HomeTabStyle('未读'))
        TabContent() {
          this.RefreshableHomeTopicList(3)
        }
        .tabBar(this.HomeTabStyle('热门'))
        TabContent() {
          this.RefreshableHomeTopicList(4)
        }
        .tabBar(this.HomeTabStyle('精华'))
      }
      .barPosition(BarPosition.Start)
      .vertical(false)
      .scrollable(true)
      .barMode(BarMode.Scrollable, {
        margin: 8,
        nonScrollableLayoutStyle: LayoutStyle.ALWAYS_CENTER
      })
      .barHeight(44)
      .onChange((index: number): void => {
        this.homeTab = index;
      })
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  private topicsForHomeTab(index: number): Array<PrototypeTopic> {
    if (index === 2) {
      return PROTOTYPE_TOPICS.slice(0, 2);
    }
    if (index === 4) {
      return PROTOTYPE_TOPICS.slice(0, 1);
    }
    return PROTOTYPE_TOPICS;
  }

  private showRefreshResult(title: string): void {
    if (this.snackBar === null) {
      return;
    }
    this.snackBar.show(
      { icon: $r('sys.symbol.checkmark_circle') },
      { title: title, content: '设计原型已完成一次本地刷新，不会请求后端。' },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭刷新提示'
      },
      { duration: 3000 }
    );
  }

  private refreshHomeTopics(): void {
    setTimeout((): void => {
      this.homeRefreshing = false;
      this.showRefreshResult('帖子列表已刷新');
    }, 800);
  }

  private refreshNotifications(): void {
    setTimeout((): void => {
      this.notificationsRefreshing = false;
      this.showRefreshResult('消息列表已刷新');
    }, 800);
  }

  @Builder
  private HomeTopicList(index: number): void {
    List({ space: 10 }) {
      ForEach(this.topicsForHomeTab(index), (topic: PrototypeTopic) => {
        ListItem() {
          this.TopicRow(topic)
        }
      }, (topic: PrototypeTopic): string => `${index}-${topic.id}`)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 12 })
    .backgroundColor('#F5F6F8')
    .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
  }

  @Builder
  private RefreshableHomeTopicList(index: number): void {
    Refresh({ refreshing: $$this.homeRefreshing }) {
      this.HomeTopicList(index)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .refreshOffset(64)
    .pullToRefresh(true)
    .pullUpToCancelRefresh(false)
    .onRefreshing((): void => {
      this.refreshHomeTopics();
    })
  }

  @Builder
  private CategoryRow(category: PrototypeCategory): void {
    Row({ space: 12 }) {
      this.CategoryIcon(category)
      Column({ space: 3 }) {
        Text(category.name)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
        Text(category.description)
          .fontSize(12)
          .fontColor($r('sys.color.font_secondary'))
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(category.topicCount)
        .fontSize(12)
        .fontColor($r('sys.color.font_tertiary'))
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(62)
    .padding({ left: 16, right: 16 })
    .accessibilityText(`${category.name}，${category.description}，${category.topicCount} 个 Topic`)
  }

  @Builder
  private CategoryIcon(category: PrototypeCategory): void {
    if (category.id === 1) {
      SymbolGlyph($r('sys.symbol.school'))
        .fontSize(22)
        .fontColor([category.accent])
    } else if (category.id === 2) {
      SymbolGlyph($r('sys.symbol.calendar'))
        .fontSize(22)
        .fontColor([category.accent])
    } else if (category.id === 3) {
      SymbolGlyph($r('sys.symbol.book'))
        .fontSize(22)
        .fontColor([category.accent])
    } else if (category.id === 4) {
      SymbolGlyph($r('sys.symbol.books_vertical_fill'))
        .fontSize(22)
        .fontColor([category.accent])
    } else if (category.id === 5) {
      SymbolGlyph($r('sys.symbol.fork_knife'))
        .fontSize(22)
        .fontColor([category.accent])
    } else {
      SymbolGlyph($r('sys.symbol.house'))
        .fontSize(22)
        .fontColor([category.accent])
    }
  }

  @Builder
  private CategoryContent(): void {
    Column() {
      this.AppHeader('全部分类', true)
      List() {
        ListItem() {
          Text('校内事务')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 16, top: 14, bottom: 6 })
        }
        ForEach(PROTOTYPE_CATEGORIES.slice(0, 2), (category: PrototypeCategory) => {
          ListItem() {
            Column() {
              this.CategoryRow(category)
              Divider().margin({ left: 46 }).color('#ECEEF2')
            }
          }
        }, (category: PrototypeCategory): string => category.id.toString())
        ListItem() {
          Text('学习交流')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 16, top: 18, bottom: 6 })
        }
        ForEach(PROTOTYPE_CATEGORIES.slice(2, 4), (category: PrototypeCategory) => {
          ListItem() {
            Column() {
              this.CategoryRow(category)
              Divider().margin({ left: 46 }).color('#ECEEF2')
            }
          }
        }, (category: PrototypeCategory): string => category.id.toString())
        ListItem() {
          Text('生活服务')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('sys.color.font_secondary'))
            .padding({ left: 16, top: 18, bottom: 6 })
        }
        ForEach(PROTOTYPE_CATEGORIES.slice(4, 6), (category: PrototypeCategory) => {
          ListItem() {
            Column() {
              this.CategoryRow(category)
              Divider().margin({ left: 46 }).color('#ECEEF2')
            }
          }
        }, (category: PrototypeCategory): string => category.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  private ChatModeButton(label: string, icon: Resource, index: number): void {
    Button() {
      Row({ space: 6 }) {
        SymbolGlyph(icon)
          .fontSize(17)
          .fontColor([this.chatMode === index ? '#245D86' : $r('sys.color.font_secondary')])
        Text(label)
          .fontSize(13)
          .fontColor(this.chatMode === index ? '#245D86' : $r('sys.color.font_primary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(42)
    .layoutWeight(1)
    .backgroundColor(this.chatMode === index ? '#DCEBFA' : '#FFFFFF')
    .borderRadius(0)
    .onClick((): void => {
      this.chatMode = index;
    })
    .accessibilityText(`${label}${this.chatMode === index ? '，已选择' : ''}`)
  }

  @Builder
  private ChatChannelCard(title: string, preview: string, time: string, unread: boolean): void {
    Row({ space: 12 }) {
      SymbolGlyph($r('sys.symbol.message'))
        .fontSize(26)
        .fontColor(['#317AF7'])
        .width(44)
        .height(44)
        .padding(9)
        .backgroundColor('#EAF2FF')
        .borderRadius(22)
      Column({ space: 5 }) {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Row({ space: 8 }) {
          Text(preview)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          Text(time)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      if (unread) {
        Circle()
          .width(8)
          .height(8)
          .fill('#D52B32')
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
  }

  @Builder
  private ChatModeContent(): void {
    if (this.chatMode === 0) {
      List({ space: 10 }) {
        ListItem() {
          this.ChatChannelCard('校友广场', '还是那句话，短期缺生猪…', '2 小时前', true)
        }
        ListItem() {
          this.ChatChannelCard('推广专区', 'API 站不都是充值余额的吗…', '2 天前', true)
        }
        ListItem() {
          this.ChatChannelCard('学习交流', '期末资料整理与答疑', '3 天前', false)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor('#F5F6F8')
    } else if (this.chatMode === 1) {
      List({ space: 10 }) {
        ListItem() {
          this.ChatChannelCard('GPT Sol', '原型的 Topic 页面已经更新', '12 分钟前', true)
        }
        ListItem() {
          this.ChatChannelCard('图书馆小助手', '感谢你提交的体验建议', '昨天', false)
        }
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor('#F5F6F8')
    } else {
      Column({ space: 16 }) {
        Row({ space: 8 }) {
          SymbolGlyph($r('sys.symbol.magnifyingglass'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
          TextInput({ placeholder: '搜索频道或用户' })
            .fontSize(14)
            .backgroundColor(Color.Transparent)
            .layoutWeight(1)
        }
        .width('100%')
        .height(48)
        .padding({ left: 14, right: 14 })
        .backgroundColor('#FFFFFF')
        .borderRadius(12)
        .border({ width: 1, color: '#E8EBF0' })
        Text('输入关键词后显示匹配的频道和用户')
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
      }
      .width('100%')
      .height('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor('#F5F6F8')
    }
  }

  @Builder
  private ChatContent(): void {
    Column() {
      this.AppHeader('聊天', false)
      Column() {
        Row() {
          this.ChatModeButton('频道', $r('sys.symbol.message'), 0)
          Divider().vertical(true).height(42).color('#C9CDD4')
          this.ChatModeButton('直接消息', $r('sys.symbol.envelope'), 1)
          Divider().vertical(true).height(42).color('#C9CDD4')
          this.ChatModeButton('搜索', $r('sys.symbol.magnifyingglass'), 2)
        }
        .width('100%')
        .height(42)
        .backgroundColor('#FFFFFF')
        .borderRadius(21)
        .border({ width: 1, color: '#9BA1AA' })
        .clip(true)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })
      .backgroundColor('#F5F6F8')
      Column() {
        this.ChatModeContent()
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F6F8')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private NotificationFilter(label: string, icon: Resource, index: number): void {
    Button() {
      Row({ space: 5 }) {
        SymbolGlyph(icon)
          .fontSize(16)
          .fontColor([this.notificationMode === index ? '#245D86' : $r('sys.color.font_secondary')])
        Text(label)
          .fontSize(12)
          .fontColor(this.notificationMode === index ? '#245D86' : $r('sys.color.font_primary'))
      }
      .justifyContent(FlexAlign.Center)
    }
    .height(40)
    .layoutWeight(1)
    .backgroundColor(this.notificationMode === index ? '#DCEBFA' : '#FFFFFF')
    .borderRadius(10)
    .onClick((): void => {
      this.notificationMode = index;
    })
    .accessibilityText(`${label}${this.notificationMode === index ? '，已选择' : ''}`)
  }

  @Builder
  private NotificationCard(
    author: string,
    action: string,
    title: string,
    excerpt: string,
    time: string
  ): void {
    Row({ space: 10 }) {
      Text(author.substring(0, 1))
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor('#317AF7')
        .width(36)
        .height(36)
        .textAlign(TextAlign.Center)
        .backgroundColor('#EAF2FF')
        .borderRadius(18)
      Column({ space: 5 }) {
        Row() {
          Text(`${author} ${action}`)
            .fontSize(13)
            .fontColor($r('sys.color.font_secondary'))
            .layoutWeight(1)
          Text(time)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        Text(title)
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(excerpt)
          .fontSize(13)
          .fontColor($r('sys.color.font_secondary'))
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
  }

  @Builder
  private NotificationsContent(): void {
    Column() {
      this.AppHeader('消息', false)
      Row({ space: 6 }) {
        this.NotificationFilter('私信', $r('sys.symbol.envelope'), 0)
        this.NotificationFilter('回复', $r('sys.symbol.message'), 1)
        this.NotificationFilter('回应', $r('sys.symbol.heart'), 2)
        this.NotificationFilter('提及', $r('sys.symbol.at'), 3)
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })
      Refresh({ refreshing: $$this.notificationsRefreshing }) {
        List({ space: 10 }) {
          ListItem() {
            this.NotificationCard('zhiQ', '回复了', '一个人去逛了永辉超市', '对我来讲永辉已经够大了…', '1 小时前')
          }
          ListItem() {
            this.NotificationCard('通电螺线管', '回复了', '一个问题', '你这是不是给报销', '16 小时前')
          }
          ListItem() {
            this.NotificationCard('maryleninmao', '回复了', '上了班才知道周末有多么珍贵', '这周末打算玩什么？', '18 小时前')
          }
        }
        .width('100%')
        .height('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 12 })
        .backgroundColor('#F5F6F8')
        .edgeEffect(EdgeEffect.Spring, { alwaysEnabled: true })
      }
      .width('100%')
      .layoutWeight(1)
      .backgroundColor('#F5F6F8')
      .refreshOffset(64)
      .pullToRefresh(true)
      .pullUpToCancelRefresh(false)
      .onRefreshing((): void => {
        this.refreshNotifications();
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private ReplyRow(reply: PrototypeReply): void {
    Column({ space: 10 }) {
      Row({ space: 9 }) {
        Text(reply.author.substring(0, 1))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#317AF7')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EAF2FF')
          .borderRadius(18)
        Column({ space: 2 }) {
          Text(reply.author).fontSize(14).fontWeight(FontWeight.Medium)
          Text(`${reply.level}  ·  ${reply.publishedAt}`)
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      Text(reply.content)
        .fontSize(14)
        .lineHeight(21)
      Row({ space: 5 }) {
        Blank()
        SymbolGlyph($r('sys.symbol.heart'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
        Text(reply.likes.toString())
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ left: 8 })
        Text('Reply')
          .fontSize(11)
          .fontColor($r('sys.color.font_secondary'))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
  }

  @Builder
  private TopicPostCard(): void {
    Column({ space: 12 }) {
      Row({ space: 9 }) {
        Text('李')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor('#317AF7')
          .width(36)
          .height(36)
          .textAlign(TextAlign.Center)
          .backgroundColor('#EAF2FF')
          .borderRadius(18)
        Column({ space: 2 }) {
          Text('李同学')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
          Text('昨天 14:32')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('校内事务')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor('#20A77A')
          .padding({ left: 9, right: 9, top: 5, bottom: 5 })
          .backgroundColor('#EAF8F3')
          .borderRadius(12)
      }
      Text('图书馆座位预约系统使用体验优化建议')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .lineHeight(25)
      Text('最近使用图书馆座位预约系统时，遇到了一些不太方便的地方，想听听大家的意见，也希望能给开发团队一些参考建议。')
        .fontSize(14)
        .fontColor($r('sys.color.font_secondary'))
        .lineHeight(22)
      Text('1. 放号时间不够明确\n有时候提前几分钟进去刷新也看不到余位，建议在首页增加倒计时提示。\n\n2. 筛选条件可以更丰富\n希望可以按楼层、区域、桌型等进行筛选。\n\n3. 增加预约记录与评价\n方便持续优化使用体验。')
        .fontSize(14)
        .lineHeight(22)
      Row({ space: 5 }) {
        Blank()
        SymbolGlyph($r('sys.symbol.message'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
        Text('23')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
        SymbolGlyph($r('sys.symbol.eye'))
          .fontSize(14)
          .fontColor([$r('sys.color.font_tertiary')])
          .margin({ left: 8 })
        Text('1.2k')
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8EBF0' })
  }

  @Builder
  private TopicContent(showComposer: boolean): void {
    Column() {
      this.AppHeader('主题详情', false)
      List({ space: 10 }) {
        ListItem() {
          this.TopicPostCard()
        }
        ListItem() {
          Row() {
            Text('全部 Reply（23）')
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .layoutWeight(1)
            Text('最早')
              .fontSize(13)
              .fontColor('#317AF7')
            Text('最新')
              .fontSize(13)
              .fontColor($r('sys.color.font_secondary'))
              .margin({ left: 16 })
          }
          .padding({ left: 4, right: 4, top: 8, bottom: 2 })
        }
        ForEach(PROTOTYPE_REPLIES, (reply: PrototypeReply) => {
          ListItem() {
            this.ReplyRow(reply)
          }
        }, (reply: PrototypeReply): string => reply.id.toString())
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 12, right: 12, top: 10, bottom: 12 })
      .backgroundColor('#F5F6F8')
      .edgeEffect(EdgeEffect.Spring)

      if (showComposer) {
        this.ReplyComposer()
      } else {
        Row({ space: 8 }) {
          Text('输入 Reply 内容')
            .fontSize(13)
            .fontColor($r('sys.color.font_tertiary'))
            .layoutWeight(1)
            .padding({ left: 12, top: 10, bottom: 10 })
            .backgroundColor('#F4F5F7')
            .borderRadius(8)
          Button('Reply Topic')
            .fontSize(13)
            .onClick((): void => {
              this.surface = PrototypeSurface.REPLY;
            })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .border({ width: { top: 1 }, color: '#E7E9ED' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
  }

  @Builder
  private AccountContent(): void {
    Column() {
      this.AppHeader('我的', false)
      Scroll() {
        Column({ space: 12 }) {
          Row({ space: 14 }) {
            Text('飞')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#317AF7')
              .width(68)
              .height(68)
              .textAlign(TextAlign.Center)
              .backgroundColor('#EAF2FF')
              .borderRadius(34)
            Column({ space: 7 }) {
              Row({ space: 8 }) {
                Text('飞雪残鸣')
                  .fontSize(20)
                  .fontWeight(FontWeight.Bold)
                Text('已认证')
                  .fontSize(11)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#17845A')
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor('#EAF8F3')
                  .borderRadius(10)
              }
              Text('认证校友')
                .fontSize(13)
                .fontColor($r('sys.color.font_secondary'))
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)
            Button() {
              SymbolGlyph($r('sys.symbol.gearshape'))
                .fontSize(24)
                .fontColor([$r('sys.color.font_secondary')])
                .hitTestBehavior(HitTestMode.None)
            }
            .width(44)
            .height(44)
            .backgroundColor(Color.Transparent)
            .accessibilityText('打开账户设置，设计原型中不可用')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E8EBF0' })

          Column() {
            this.AccountAction('个人信息', $r('sys.symbol.person_text_rectangle'))
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('RSC 钱包', $r('sys.symbol.wallet'), '规划中')
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('我的 Topic', $r('sys.symbol.folder'))
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('我的 Reply', $r('sys.symbol.message'))
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('我的草稿', $r('sys.symbol.doc_plaintext_and_pencil'))
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('我的书签', $r('sys.symbol.bookmark'))
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E8EBF0' })

          Column() {
            this.AccountAction('应用设置', $r('sys.symbol.gearshape'))
            Divider().margin({ left: 52 }).color('#ECEEF2')
            this.AccountAction('关于 RiverSide', $r('sys.symbol.info_circle'))
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: 1, color: '#E8EBF0' })

          Button('退出登录', { type: ButtonType.Normal })
            .fontColor('#C62828')
            .backgroundColor('#FFFFFF')
            .width('100%')
            .height(48)
            .borderRadius(12)
          Text('RiverSide · UI 原型')
            .fontSize(11)
            .fontColor($r('sys.color.font_tertiary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 4, bottom: 8 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 10, bottom: 12 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F5F7')
  }

  @Builder
  private AccountAction(label: string, icon: Resource, detail: string = ''): void {
    Row({ space: 12 }) {
      SymbolGlyph(icon)
        .fontSize(22)
        .fontColor([$r('sys.color.font_secondary')])
      Text(label)
        .fontSize(15)
        .layoutWeight(1)
      if (detail.length > 0) {
        Text(detail)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      SymbolGlyph($r('sys.symbol.chevron_right'))
        .fontSize(18)
        .fontColor([$r('sys.color.font_tertiary')])
    }
    .width('100%')
    .height(52)
    .padding({ left: 16, right: 16 })
    .accessibilityText(`${label}${detail.length > 0 ? `，${detail}` : ''}`)
  }

  private publishReply(): void {
    if (this.replyDraft.trim().length === 0 || this.snackBar === null) {
      return;
    }
    this.replyDraft = '';
    this.snackBar.show(
      { icon: $r('sys.symbol.checkmark_circle') },
      { title: 'Reply 已发布', content: '这是设计原型，不会写入论坛。' },
      {
        operationType: SnackBarOperationType.CLOSE_BUTTON_ONLY,
        closeButtonAccessibilityText: '关闭提示'
      },
      { duration: 4000 }
    );
  }

  @Builder
  private ReplyComposer(): void {
    Column({ space: 8 }) {
      Row() {
        Text('Reply Topic')
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .layoutWeight(1)
        Text(`${this.replyDraft.length}/1000`)
          .fontSize(11)
          .fontColor($r('sys.color.font_tertiary'))
      }
      TextArea({ text: this.replyDraft, placeholder: '输入 Reply 内容' })
        .height(86)
        .maxLength(1000)
        .backgroundColor('#F4F5F7')
        .borderRadius(8)
        .onChange((value: string): void => {
          this.replyDraft = value;
        })
        .accessibilityText('Reply 内容，最多 1000 个字符')
      Row({ space: 10 }) {
        Button() {
          SymbolGlyph($r('sys.symbol.ohos_photo'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
            .hitTestBehavior(HitTestMode.None)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .accessibilityText('添加图片，设计原型中不可用')
        Button() {
          SymbolGlyph($r('sys.symbol.at'))
            .fontSize(20)
            .fontColor([$r('sys.color.font_secondary')])
            .hitTestBehavior(HitTestMode.None)
        }
        .width(40)
        .height(40)
        .backgroundColor(Color.Transparent)
        .accessibilityText('提及用户，设计原型中不可用')
        Blank()
        Button('发布 Reply')
          .fontSize(13)
          .enabled(this.replyDraft.trim().length > 0)
          .onClick((): void => this.publishReply())
          .accessibilityText('发布 Reply，仅更新设计原型状态')
      }
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 10, bottom: 10 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 1 }, color: '#E7E9ED' })
  }

  @Builder
  private ContentSurface(): void {
    if (this.surface === PrototypeSurface.HOME) {
      this.HomeContent()
    } else if (this.surface === PrototypeSurface.CATEGORY) {
      this.CategoryContent()
    } else if (this.surface === PrototypeSurface.CHAT) {
      this.ChatContent()
    } else if (this.surface === PrototypeSurface.NOTIFICATIONS) {
      this.NotificationsContent()
    } else if (this.surface === PrototypeSurface.TOPIC) {
      this.TopicContent(false)
    } else if (this.surface === PrototypeSurface.ACCOUNT) {
      this.AccountContent()
    } else {
      this.TopicContent(true)
    }
  }

  @Builder
  private RootNavigation(): void {
    HdsTabs({ controller: this.rootTabsController, index: this.surface }) {
      TabContent() {
        this.HomeContent()
      }
      .tabBar(this.RootTabStyle('首页', $r('sys.symbol.house')))
      TabContent() {
        this.CategoryContent()
      }
      .tabBar(this.RootTabStyle('Category', $r('sys.symbol.square_grid_2x2')))
      TabContent() {
        this.ChatContent()
      }
      .tabBar(this.RootTabStyle('聊天', $r('sys.symbol.message')))
      TabContent() {
        this.NotificationsContent()
      }
      .tabBar(this.RootTabStyle('消息', $r('sys.symbol.bell')))
      TabContent() {
        this.AccountContent()
      }
      .tabBar(this.RootTabStyle('我的', $r('sys.symbol.person_crop_circle_fill_1')))
    }
    .scrollable(false)
    .vertical(false)
    .barPosition(BarPosition.End)
    .barOverlap(true)
    .barFloatingStyle({
      barSideMargin: 12,
      barBottomMargin: 28,
      adaptToHandedness: true,
      systemMaterialEffect: {
        materialType: hdsMaterial.MaterialType.ADAPTIVE,
        materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
      }
    })
    .onChange((index: number): void => {
      this.surface = this.rootSurfaceForIndex(index);
      this.viewState = PrototypeViewState.CONTENT;
    })
    .width('100%')
    .height('100%')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
  }

  @Builder
  private SelectedState(): void {
    if (this.viewState === PrototypeViewState.LOADING) {
      this.LoadingSkeleton()
    } else if (this.viewState === PrototypeViewState.EMPTY) {
      this.EmptyState()
    } else if (this.viewState === PrototypeViewState.ERROR) {
      this.ErrorState()
    } else if (this.viewState === PrototypeViewState.UNAUTHORIZED) {
      this.UnauthorizedState()
    } else {
      this.ContentSurface()
    }
  }

  build() {
    Stack({ alignContent: Alignment.BottomEnd }) {
      if (this.viewState === PrototypeViewState.CONTENT && this.isRootSurface()) {
        this.RootNavigation()
      } else {
        this.SelectedState()
      }
      if (this.controlsVisible) {
        this.PrototypeControlPanel()
      } else {
        this.PrototypeControlTrigger()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F6F8')
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.BOTTOM])
  }
}
