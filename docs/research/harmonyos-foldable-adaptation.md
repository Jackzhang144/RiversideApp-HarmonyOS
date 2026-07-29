# RiverSide HarmonyOS 折叠屏适配方案研究

研究日期：2026-07-25

研究范围：

- HarmonyOS 客户端：`/Users/jackzhang/Code/RiversideApp-HarmonyOS`
- 代码基线提交：`d4f29caf08314e6a960d1d61ccec98e32ab04d22`
- 目标 SDK：HarmonyOS API 23
- 资料范围：HarmonyOS 官方本地文档（通过 `devecocli docs search/read` 检索）及其对应的华为官方链接

本记录只做设计研究，没有修改 APP 业务源码，也没有执行 Git 提交。

## 结论

RiverSide 不应实现一套按“普通手机 / 双折叠 / 阔折叠 / 三折叠”切换的设备分支。推荐方案是：

1. **普通页面只认窗口，不认设备型号。** 使用窗口横向、纵向断点驱动布局；折叠开合、横竖屏、分屏、自由窗口缩放都归一为窗口变化。
2. **沿用现有 `HdsNavigation + NavPathStack`。** 小窗口使用单栏；宽度达到 600vp 后，在适合主从浏览的根页面自动切换 Topic 列表 + Post/Reply 详情双栏。
3. **组件内部先自适应，页面结构再响应式。** 文本折行、Flex 伸缩、比例尺寸等不需要断点；只有单双栏、内容重排、栅格列数等结构变化才使用断点。
4. **折叠状态 API 只处理折叠专属体验。** `foldStatusChange`、折痕区域等用于悬停态或必须避开折痕的专用页面，不能作为普通页面开合布局的主信号。
5. **开合连续是功能要求，不只是视觉要求。** 开合过程中必须保留当前路由、选中的 Topic/Post、Reply 草稿、加载状态和滚动阅读焦点。

官方明确指出：页面适配的本质是适配窗口；不推荐使用折叠状态监听实现普通页面响应式布局和开合接续，因为窗口变化时折叠状态不一定改变，而且不同方向的开合回调时序不同。[^screen-diff]

## 当前代码基线

当前工程已经具备一条合适的演进路径：

- `app/entry/src/main/ets/components/PageShell.ets` 使用 `HdsNavigation(this.pathStack)` 和 `HdsNavDestination`。
- `HdsNavigation` 的默认模式就是 `NavigationMode.Auto`，基于组件宽度在单栏和双栏间切换；底层默认 Auto 阈值为 600vp。[^hds-navigation][^navigation]
- `app/entry/src/main/ets/pages/Index.ets` 持有单一 `NavPathStack`、根 Tab 选择、Topic/Post、Chat、Reply 草稿和各页面模型状态，适合在布局重排时保持业务状态不变。
- `Index.ets` 已通过 `@Env(SystemProperties.WINDOW_AVOID_AREA)` 响应窗口避让区变化。
- 目前没有读取 `SystemProperties.BREAK_POINT`，也没有针对宽窗口明确配置主从布局、空详情占位、导航栏宽度和模式切换回调。
- `module.json5` 没有显式设置 `orientation`；应用仍以 `phone` 作为设备类型。折叠屏不是 `deviceTypes` 的独立取值，基础适配不应添加虚构的 `foldable` 类型，继续保留 `phone` 即可。

因此第一阶段不需要改写路由，也不需要创建“FoldableIndex”。应在现有壳层补齐响应式信息和宽屏行为。

另有一个与本次适配相关的既有风险：`RootPageShell`/`DestinationPageShell` 已通过 Hds 组件的 `systemBarStyle` 管理状态栏，而 `Index.ets` 和 `EntryAbility.ets` 仍会调用窗口级 `setWindowSystemBarProperties()`。Hds 官方明确不建议混用两套状态栏样式接口；适配时应统一所有权，避免开合、导航切换和深浅色变化时发生样式竞争。[^hds-navigation]

## 断点与状态模型

### 横向断点

官方推荐的窗口宽度区间如下，单位为 vp：[^responsive][^grid]

| 断点 | 窗口宽度 | RiverSide 建议 |
| --- | --- | --- |
| `xs` | `[0, 320)` | 非主要目标；保证不崩溃、不横向溢出 |
| `sm` | `[320, 600)` | 单栏手机布局 |
| `md` | `[600, 840)` | 双折叠展开态常见范围；主从双栏 |
| `lg` | `[840, 1440)` | 阔折叠、三折叠展开态或后续平板；双栏并增加留白/栅格 |
| `xl` | `[1440, +∞)` | 非第一版目标 |

断点面向**当前应用窗口**，不是面向物理设备。同一设备全屏、分屏、自由窗口、横竖屏或显示缩放后可能落入不同断点，必须呈现对应窗口的布局。[^responsive]

### 纵向断点

官方同时建议使用高宽比区分窗口形状：[^responsive]

| 断点 | 窗口高宽比 |
| --- | --- |
| `sm` | `(0, 0.8)` |
| `md` | `[0.8, 1.2)` |
| `lg` | `[1.2, +∞)` |

RiverSide 的主从导航主要由横向断点决定；纵向断点用于处理小方形外屏、横屏矮窗口、键盘压缩后的可用高度等特殊形态。不要把“宽度大于高度”简单等同于某个折叠设备。

### API 23 的推荐获取方式

API 22 起可以在组件中直接读取响应式断点：

```text
@Env(SystemProperties.BREAK_POINT)
breakpoint: uiObserver.WindowSizeLayoutBreakpointInfo
```

其中 `widthBreakpoint` 和 `heightBreakpoint` 变化会触发关联组件刷新。API 23 还支持 `WINDOW_SIZE`、`WINDOW_SIZE_PX`、`WINDOW_AVOID_AREA` 和 `WINDOW_AVOID_AREA_PX`。[^env]

建议：

- UI 结构选择优先读取 `@Env(SystemProperties.BREAK_POINT)`。
- 只有 Ability 级协调、日志和非 UI 服务确实需要时，才在主窗口注册 `window.on('windowSizeChange')`。
- 如果注册窗口监听，必须保存具名 callback，并在对应生命周期中调用 `off`。
- 不应同时维护多套互相独立的断点算法。

`ContainerReader` 是 API 26 才支持的容器断点能力，不适用于当前 API 23 基线。当前项目中的可复用卡片应优先使用 Flex、约束和 `GridRow` 的组件尺寸参照；以后升级 API 26 后再评估容器级断点。[^container-reader]

## 推荐的页面架构

### 1. 根导航：按页面能力选择 Auto 或 Stack

`HdsNavigation` 支持 `Stack`、`Split` 和 `Auto`，默认是 `Auto`。`Auto` 基于组件宽度切换单双栏；默认最小导航区 240vp、最小内容区 360vp，因此默认阈值是 600vp。[^hds-navigation][^navigation]

建议将模式变成显式策略：

| 根页面 | `sm` | `md` / `lg` | 原因 |
| --- | --- | --- | --- |
| Home Topic 列表 | Stack | Auto/Split | 典型列表 + Topic/Post 主从浏览 |
| Category | Stack | Auto/Split | Category/Topic 列表 + Topic/Post 详情 |
| Chat | Stack | Auto/Split | Conversation 列表 + 消息详情 |
| Notifications | Stack | Auto/Split | 通知列表 + Topic/Post 目标 |
| Account | Stack | Stack | 当前内容不是稳定的主从列表，强制分栏会让账户页缩进窄栏 |

这里的 `Auto/Split` 表示：代码配置 `Auto`，让 Hds 按窗口宽度决定实际 `Stack` 或 `Split`，而不是业务代码根据 `foldStatus` 强制模式。

### 2. 复用现有 NavPathStack

当前工程把根内容放在 `HdsNavigation` 的导航区，把 Topic、Chat Conversation、Settings 等放入 `HdsNavDestination`，这正好符合主从模式：

```text
sm
Topic 列表 -> push Topic -> 全屏 Topic/Post

md / lg
Topic 列表 | 当前 Topic/Post
```

单双栏切换不应创建新路由栈、清空栈或重新加载当前 Topic。应保持同一个 `NavPathStack` 和同一个 `AppShellModel`，只改变呈现方式。

可以使用 `onNavigationModeChange`记录实际模式，处理少量仅与可见性相关的 UI，例如：

- 双栏下隐藏详情页中语义重复的返回提示；
- 为自动化测试暴露当前单双栏状态；
- 决定空详情提示是否可见。

不要在该回调中重新 push 当前页面或重建业务模型。

### 3. 处理双栏空详情

API 23 的 `HdsNavigation.splitPlaceholder()` 可在双栏且路由栈为空时展示默认右栏，但官方规定该占位内容不可获焦、不可响应事件。[^hds-navigation]

第一版建议使用纯展示占位：

```text
选择一个 Topic 继续阅读
```

如果后续产品希望展开态自动显示首个 Topic，应向原有 `NavPathStack` 推入一个真实 Topic destination，而不是把可交互内容塞进 `splitPlaceholder`。自动选择还必须避免覆盖用户从折叠态带来的既有路由和阅读位置。

### 4. 导航栏宽度

Hds 默认导航区为 240vp、内容区最小 360vp。对于 RiverSide 的 Topic 卡片，240vp 是可用下限而不是理想宽度。

建议原型验证：

- 导航区可拖拽范围约 240–320vp；
- 详情区最小 360vp；
- 保留 `enableModeChangeAnimation`；
- 只有确认用户需要手动调整时再启用 `enableDragBar`。

不要只设置 `navBarWidth` 后假设分隔线可拖动；官方说明只有 `navBarWidthRange` 才定义拖动范围，并同时受 `minContentWidth` 约束。[^hds-navigation][^navigation]

## 页面布局策略

官方把常见响应式页面结构归纳为重复、分栏、挪移和缩进等方式。RiverSide 应按页面内容选择，而不是所有页面统一套栅格。[^page-layout]

### Home、Category、Notifications、Chat 列表

- `sm`：保持一列 List。
- `md`：主从导航中的左侧列表仍保持一列，右侧显示详情。
- `lg`：如果页面当前没有进入主从模式，可使用 `List.lanes` 或 Grid/WaterFlow 增加列数；如果已经是主从模式，主列表不应再次机械拆成多列。
- 卡片内部使用 Flex 伸缩、文本折行和 `displayPriority`，避免固定宽度。
- 加载、空态和错误态应占当前容器，而不是使用按设备写死的全屏宽度。

### Topic/Post 阅读页

- 保持单一阅读流，不建议把一个 Topic 内的 Post 再拆成左右两列。
- 宽屏时通过内容最大宽度、左右缩进和稳定的行宽提升可读性，不要把手机正文等比拉伸铺满整个展开屏。
- Topic 详情作为 Hds 右栏时，宽度由导航区和 `minContentWidth` 约束。
- Suggested Topic、Reaction 用户等可在 `md`/`lg` 使用栅格或重复布局。

### Reply 与创建 Topic

- 开合前后的草稿对象、上传状态、光标/选区和提交状态必须保持。
- `sm` 可继续使用底部 Sheet。
- `md`/`lg` 可评估居中 Sheet 或更紧凑的浮层，但这是第二阶段体验增强，不应阻塞基础开合连续。
- 键盘弹出后必须基于新的窗口/避让区重新布局，不能使用展开前缓存的高度。

### Account、Settings、Profile

- 使用居中内容列和最大宽度，避免整页拉宽。
- 只有存在稳定“列表选择 + 详情”的子场景时才引入分栏。
- Profile 的卡片区域可以使用 `GridRow/GridCol`；正文和表单仍保持可读宽度。

## 栅格使用建议

`GridRow/GridCol` 的默认断点正是 320/600/840vp。API 20 及以后默认列数为：

```text
xs: 2, sm: 4, md: 8, lg: 12, xl: 12, xxl: 12
```

它支持按断点配置 `columns`、`gutter`，以及 `GridCol` 的 `span`、`offset`、`order`。断点参照默认是 `BreakpointsReference.WindowSize`；官方认为以应用窗口为参照更适合非全屏场景。[^grid]

RiverSide 的建议用法：

- 用于 Profile 信息块、设置卡片、搜索建议块、Reaction 用户等可以重复排列的内容。
- 不用 GridRow 替代长列表；Home Topic、Post 和 Chat Message 仍应使用 List。
- 显式配置需要的断点列数，避免依赖列数自动补全后产生意外布局。
- 当使用 `ComponentSize` 作为参照时，不要在 `onBreakpointChange` 中动态修改同一个 GridRow 的 margin/padding，官方标记此用法不推荐。[^grid-api]

## 折叠状态、折痕和避让区域

### 普通页面

普通浏览页面只需要：

- `SystemProperties.BREAK_POINT`
- `SystemProperties.WINDOW_SIZE`（确有精确尺寸计算时）
- `SystemProperties.WINDOW_AVOID_AREA`
- Hds 的安全区与状态栏能力

当前 `Index.ets` 已读取状态栏和 cutout 避让区，应继续保持响应式读取，不能只在 Ability 启动时计算一次。

如果使用窗口 API，`getWindowAvoidArea()` 获取当前避让区，`on('avoidAreaChange')` 监听变化。窗口从全屏变为悬浮、系统栏显示状态变化等都可能改变避让区。[^window]

### 悬停态

悬停态适用于视频、相机、游戏控制等“上半屏展示、下半屏操作”的场景。RiverSide 当前没有强烈的悬停专属功能，因此第一版不建议为整个 APP 引入悬停布局。

如果未来为媒体预览或视频 Embed 增加悬停体验，优先级如下：[^hover][^fold-split]

1. `FolderStack`：适合全屏视频等少交互场景；组件会把 `upperItems` 放在上半屏，其他内容放在下半屏，并自动避让折痕。
2. `FoldSplitContainer`：适合固定的上下二分栏或加侧栏三分栏；自动处理折叠、展开、悬停区域和折痕避让。
3. 自定义：只有页面结构复杂、需要限制进入悬停的方向或自定义旋转策略时，才使用 `display.on('foldStatusChange')` 和 `getCurrentFoldCreaseRegion()`。

自定义实现时：

- 先用 `display.isFoldable()` 做能力检查；
- `getCurrentFoldCreaseRegion()` 返回当前显示模式的 `creaseRects`，单位为 px，需要通过 UIContext 转成 vp；
- 使用具名 callback 注册 `foldStatusChange`；
- 离开页面或销毁时必须用同一 callback 调用 `off`；
- 不要把折痕区域混同于系统状态栏/cutout 避让区。

### 不用折叠状态驱动普通页面

官方给出的双折叠回调时序并不对称：[^screen-diff]

```text
展开 -> 折叠：
half foldStatus -> folded foldStatus -> foldDisplayMode -> windowSize

折叠 -> 展开：
half foldStatus -> foldDisplayMode -> windowSize -> expanded foldStatus
```

如果普通布局由 `foldStatusChange` 驱动，会出现先用旧窗口尺寸渲染、漏掉分屏/自由窗变化或回调竞态。普通页面必须由窗口断点驱动。

## 横竖屏策略

`display.Orientation` 是屏幕当前方向，`window.Orientation` 是应用可设置的窗口旋转策略；`display.rotation` 与 `display.Orientation` 在折叠设备上没有固定映射，不能互相替代。[^direction]

对 RiverSide 这类通用内容应用，建议：

- 根页面使用官方推荐的 `FOLLOW_DESKTOP`，让直板机、折叠态、展开态和后续平板跟随系统桌面策略。
- 不为普通页面在 `aboutToAppear` 中反复锁定横屏或竖屏。
- 只有视频全屏、图片编辑等明确场景才临时调用 `setPreferredOrientation()`，离开时恢复页面原本策略。
- 窗口旋转后的布局仍由断点和窗口尺寸刷新，不额外按“横屏设备”分支。

官方指出，首页类通用页面推荐 `FOLLOW_DESKTOP`；它还会在同一设备折叠形态切换时自动更新旋转策略。[^direction]

## 开合连续与状态保存

官方把“开合连续”定义为页面不改变、焦点不偏移，任务和相关状态能保存、延续或快速恢复。[^screen-diff]

RiverSide 的验收状态至少包括：

| 场景 | 必须保持 |
| --- | --- |
| Home/Category | 当前 Tab、筛选项、已加载分页、首个可见 Topic |
| Topic/Post | 当前 Topic、目标 Post、已加载 Post 窗口、阅读焦点、书签/Reaction 临时状态 |
| Reply/Composer | 草稿、回复目标 Post、媒体上传状态、提交中状态、键盘遮挡后的可编辑区域 |
| Chat | 当前 Conversation、消息窗口、未发送文本、Reply target、滚动锚点 |
| Notifications | 当前筛选/分页、打开的目标 Topic/Post |
| Profile/Settings | 当前页面、表单编辑值、提交状态 |

当前业务状态集中在 `Index`、页面模型和 `AppShellModel`，这对保持连续有利。适配时应避免：

- 根据断点创建不同的 Entry 页面；
- 在 `onNavigationModeChange` 清空/替换 `NavPathStack`；
- 折叠开合时重新调用首屏初始化；
- 为宽屏复制一套独立页面状态。

### 滚动焦点

官方特别指出：只保存像素 offset 往往无法在开合后保持同一阅读内容，因为布局宽度变化会改变每项高度。推荐：[^screen-diff]

- List：通过 `onScrollIndex` 保存首个可见 item 的稳定索引/业务 ID，变化后使用 `Scroller.scrollToIndex()` 恢复。
- WaterFlow：列数变化时使用 `WaterFlowLayoutMode.SLIDING_WINDOW` 保持最小可见索引。
- Scroll：需要业务计算变化前后的目标位置，再通过 `scrollBy()` 修正。

RiverSide 当前 Home、Category、Topic、Chat 均大量使用 List/Scroller，适合按稳定 Topic ID、Post number、Message ID 保存锚点，而不是只保存像素值。

## 推荐实施顺序

每一步都应独立验证并单独提交。

### 第 1 步：建立响应式窗口上下文

- 在壳层读取 `SystemProperties.BREAK_POINT`。
- 继续读取 `WINDOW_AVOID_AREA`。
- 用严格类型封装当前宽/高断点和实际 Navigation 模式。
- 添加断点映射和根页面分栏资格的纯逻辑测试。

### 第 2 步：启用现有 Hds 主从导航

- 显式配置 `NavigationMode.Auto`。
- 仅 Home、Category、Chat、Notifications 启用主从模式；Account 保持 Stack。
- 配置导航区范围和详情最小宽度。
- 增加不可交互的空详情占位。
- 验证 Topic、Post、Chat、Settings 现有 `NavPathStack` 行为在单/双栏间不丢失。

### 第 3 步：适配页面内容

- 修复固定宽高、横向溢出和宽屏等比拉伸。
- 对可重复卡片使用 GridRow/GridCol 或 List lanes。
- 为阅读页和表单设置合理内容宽度与缩进。
- 验证 Sheet、键盘、cutout、状态栏和底部导航避让。

### 第 4 步：实现开合连续锚点

- Home/Category/Notifications 保存首个可见业务 ID。
- Topic 保存 Post number 和项内偏移。
- Chat 保存 Message ID 和列表对齐方式。
- Composer 保持草稿、上传和选区。
- 添加折叠 -> 展开 -> 折叠的连续性设备测试。

### 第 5 步：方向与系统栏收敛

- 根 Ability 配置并验证 `FOLLOW_DESKTOP`。
- 统一 Hds 与 Window 的 system bar 样式所有权。
- 只为明确全屏媒体场景保留临时方向切换。

### 第 6 步：可选悬停体验

只有确定媒体/视频场景值得支持时，再选择 FolderStack 或 FoldSplitContainer。不要把此步骤作为基础折叠屏适配的前置条件。

## 模拟器与测试矩阵

### 本机现状

本次调研通过 `devecocli emulator list` 和 `devecocli emulator image list --all --format json` 检查到：

- 当前运行实例：`Mate 70 RS`，Phone，HarmonyOS 6.1.0(23)。
- 本地已下载 API 23 镜像：Phone、Foldable、WideFold、TripleFold。
- 目前没有已创建的 Foldable/WideFold/TripleFold 实例。

不需要再次下载 API 23 折叠设备镜像；后续只需按需创建实例。

官方模拟器支持 Foldable、WideFold、TripleFold。工具栏可直接切换折叠、展开、悬停并显示折痕避让区；三折叠还支持单屏、双屏、三屏和多种半折组合，工具栏同时支持左右旋转 90°。[^emulator-types][^emulator-toolbar]

### 第一版最低矩阵

| 设备/窗口 | 形态 | 方向/窗口 | 重点 |
| --- | --- | --- | --- |
| Phone API 23 | 普通 | 竖屏、横屏 | 现有行为不回归 |
| Foldable API 23 | 折叠 | 竖屏、横屏 | `sm` 单栏、状态保持 |
| Foldable API 23 | 展开 | 两个方向 | `md` 双栏、开合连续 |
| Foldable API 23 | 悬停 | 横屏半折 | 不错位、不跨折痕；无专用悬停布局也需可用 |
| WideFold API 23 | 外屏/折叠 | 小方形、旋转 | 横纵断点组合、内容不截断 |
| WideFold API 23 | 展开 | 两个方向 | 双栏与宽屏留白 |
| TripleFold API 23 | 单/双/三屏 | 典型方向 | 第一版保证通用响应，不要求专属三栏 |

### 断点边界

必须验证：

- 319 / 320vp
- 599 / 600vp
- 839 / 840vp

同时覆盖：

- 全屏；
- 系统分屏；
- 如果设备支持，自由窗口拖拽跨越断点；
- 显示缩放导致的 vp 变化；
- 键盘弹出/收起；
- 深浅色；
- 系统状态栏、导航栏、cutout 避让变化。

### 连续性用例

每个关键流程都执行“折叠 -> 展开 -> 折叠”和“展开 -> 折叠 -> 展开”：

1. Home 滚动至深处并加载多页。
2. 打开 Topic，定位到非首个 Post。
3. 编辑 Reply 草稿并选择媒体。
4. 打开 Chat Conversation，定位到历史消息并输入未发送文本。
5. 打开通知对应的 Topic/Post。
6. 打开 Profile/Settings 并修改尚未提交的表单值。
7. 在网络加载中、失败态和重试态切换形态。

验收：

- 页面和当前路由不跳转；
- 首个可见业务项/阅读焦点不偏移；
- 草稿、选择和异步状态不丢；
- 不重复请求或重复提交；
- 不出现白屏、拉伸、截断、重叠和点击热区错位；
- 返回行为在 Stack/Split 两种模式下语义一致。

### 自动化与人工测试

- 使用现有 ohosTest 补充断点映射、根页面模式选择、滚动锚点恢复的纯逻辑测试。
- 现有 `scripts/verify-mvp-api23.sh` 会同时校验设备列表中的 `Kind ... phone` 和详情中的 `Device Type: phone`，因此会拒绝 Foldable/WideFold/TripleFold 实例。接入折叠屏回归前，应将它参数化为可接受的设备形态，或新增一个复用同一构建、安装、启动流程的折叠屏验证脚本；不要削弱原有 Phone 门禁。
- 用 API 23 Foldable/WideFold/TripleFold 模拟器做结构和回归测试。
- 使用 DevEco Testing 的“多设备布局对比测试”；官方支持竖屏、折叠、横屏三种模式，并建议全选，报告会给出同一页面的多设备截图、问题规则和修复指引。[^ux-test]
- 最终必须在真实双折叠设备验证触摸、键盘、开合连续、折痕、性能和系统多窗；模拟器不能完全替代真机体验。

官方 AppAnalyzer/UX 规则还应作为基础门槛：开合/旋转不得错位、截断和变形，任务及输入不得中断；展开态不应把手机 UI 整体无节制放大，文字/图标相对折叠态通常保持在约 1–1.2 倍；主要点击热区推荐至少 48×48vp、不得小于 40×40vp；文本推荐至少 12vp、不得小于 8vp。[^analyzer]

## 推荐与反模式

### 推荐

- 以窗口宽度和高宽比统一覆盖折叠、旋转、分屏和自由窗口。
- 使用 `@Env(SystemProperties.BREAK_POINT)` 让组件响应式刷新。
- 沿用一个 `NavPathStack` 和一套业务状态。
- 先使用 Hds Navigation Auto，再做局部页面响应式。
- 普通内容优先使用 Flex、约束、折行、List；可重复卡片再使用栅格。
- 保存业务锚点而不是只保存像素滚动量。
- 折叠专属布局优先系统组件。
- 对所有 `on` 注册保留 callback 并成对 `off`。

### 反模式

- 按 `deviceType`、设备型号或 `isFoldable()` 选择普通页面布局。
- 用 `foldStatusChange` 代替窗口断点。
- 为折叠态和展开态维护两套 Entry 页面、路由栈或页面模型。
- 开合时清空路由、重新拉取首屏或丢弃草稿。
- 只测试全屏，不测试分屏、旋转和断点边界。
- 展开态把手机 UI 等比放大并铺满。
- 大量硬编码 px 或固定大宽高。
- 只看宽度，不处理小方形/横屏矮窗口的高度断点。
- 用 `display.rotation` 推导窗口方向。
- 在 Hds Split 空右栏放可交互 `splitPlaceholder`。
- 混用 Hds `systemBarStyle` 与 Window 状态栏样式接口。
- 注册窗口、避让区或折叠状态监听后不取消。
- 为整个论坛壳套用 FoldSplitContainer；它适合固定上下显示/操作区，不适合通用 Topic 浏览。

## 官方资料索引

[^responsive]: [响应式布局](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-responsive-layout)，本地 documentId：`最佳实践/多设备界面开发/界面布局响应式变化/响应式布局/bpta-multi-device-responsive-layout`。

[^page-layout]: [页面布局场景](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-page-layout)，本地 documentId：`最佳实践/多设备界面开发/界面布局响应式变化/页面布局场景/bpta-multi-device-page-layout`。

[^screen-diff]: [多设备适配屏幕差异](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-screen-diff)，本地 documentId：`最佳实践/多设备功能开发/多设备适配屏幕差异/bpta-multi-device-screen-diff`。

[^env]: [@Env：环境变量](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-env-system-property)，本地 documentId：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/学习响应式环境变量/Env_环境变量/arkts-env-system-property`。

[^grid]: [栅格布局（GridRow/GridCol）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-layout-development-grid-layout)，本地 documentId：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/组件布局/构建布局/栅格布局_GridRow_GridCol/arkts-layout-development-grid-layout`。

[^grid-api]: [GridRow API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-container-gridrow)，本地 documentId：`API参考/ArkUI_方舟UI框架/ArkTS组件/栅格与分栏/GridRow/ts-container-gridrow`。

[^container-reader]: [容器断点（ContainerReader）](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-layout-development-container-reader)，本地 documentId：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/组件布局/构建布局/容器断点_ContainerReader/arkts-layout-development-container-reader`。

[^navigation]: [Navigation API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-basic-components-navigation)，本地 documentId：`API参考/ArkUI_方舟UI框架/ArkTS组件/导航与切换/Navigation/ts-basic-components-navigation`；另见 [Navigation 分栏开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/arkts-navigation-split-mode)，本地 documentId：`开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/设置组件导航和页面路由/组件导航_Navigation_推荐/Navigation分栏开发/arkts-navigation-split-mode`。

[^hds-navigation]: [HdsNavigation API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdsnavigation)，本地 documentId：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsNavigation/ui-design-hdsnavigation`。

[^window]: [Window API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-window-window)，本地 documentId：`API参考/ArkUI_方舟UI框架/ArkTS_API/窗口管理/ohos_window_窗口_/Interface_Window/arkts-apis-window-window`。

[^hover]: [折叠屏悬停态](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-folded-hover)，本地 documentId：`最佳实践/多设备界面开发/特殊界面布局场景/折叠屏悬停态/bpta-folded-hover`。

[^fold-split]: [FoldSplitContainer API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ohos-arkui-advanced-foldsplitcontainer)，本地 documentId：`API参考/ArkUI_方舟UI框架/ArkTS组件/系统预置UI组件库/FoldSplitContainer/ohos-arkui-advanced-foldsplitcontainer`。

[^direction]: [窗口方向](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-multi-device-window-direction)，本地 documentId：`最佳实践/多设备界面开发/多设备窗口形态/窗口方向/bpta-multi-device-window-direction`。

[^emulator-types]: [模拟器设备支持类型](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-devicetype)，本地 documentId：`开发指南/使用模拟器运行应用/概述/设备支持类型/ide-emulator-devicetype`。

[^emulator-toolbar]: [模拟器工具栏](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-emulator-toolbar)，本地 documentId：`开发指南/使用模拟器运行应用/使用模拟器/使用工具栏/ide-emulator-toolbar`。

[^ux-test]: [DevEco Testing UX 测试](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ux-testing)，本地 documentId：`开发指南/专项测试/DevEco_Testing/UX测试/ux-testing`。

[^analyzer]: [AppAnalyzer 规则总览](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ide-app-analyzer-all-rules)，本地 documentId：`开发指南/开发自测试/应用与元服务体检/附录/体检规则/规则总览/ide-app-analyzer-all-rules`。
