# 首页沉浸式悬浮顶栏：HarmonyOS 官方实现结论

日期：2026-07-16
范围：API 23 手机首页；只研究“首屏避让后可滚动穿透、顶部渐变模糊、状态栏可读性”，不包含产品源码修改。

## 结论

当前工程目标版本是 `6.1.0(23)`，官方推荐能力均可用。首页应让 `HdsNavigation` 正式承载顶部区域，而不是继续把悬浮按钮作为与导航组件无关的普通 `Stack` 覆盖层：

1. 将 LOGO、频道选择、搜索、发帖、在线人数放进 `HdsNavigation.titleBar.content.stackBuilder`；标题栏使用 `HdsNavigationTitleMode.MINI`。
2. 设置 `titleBar.enableComponentSafeArea: true`，让列表初始位置自动避让标题栏；列表再设置 `contentStartOffset(8~12)`，形成按钮下方的小间距。这个偏移属于滚动内容，向上滚动后会消失，不会形成固定黑色占位。
3. 保留现有的 `bindToScrollable([homeScroller])`、`List.clip(false)` 和 `List.cachedCount(3, true)`。官方动态模糊示例正是用这组配置让内容滚入标题栏下方，并避免穿透区域中的 `ListItem` 消失。
4. 首页是列表型页面，顶部空间渐变模糊首选 `ScrollEffectType.GRADIENT_BLUR`；为了首帧就保护状态栏可读性，使用 `enableScrollEffect: false`，让空间渐变模糊常驻。`maskExtraHeight` 可让蒙层向标题栏下方额外延伸，官方默认值为 32vp。
5. API 23 可叠加 `systemMaterialEffect`，优先使用 `MaterialType.ADAPTIVE + MaterialLevel.ADAPTIVE`，让系统根据设备性能自适应材质和等级。
6. 状态栏文字颜色交给 `HdsNavigation.systemBarStyle()`，并按浅色/深色主题提供高对比颜色。官方明确不建议同时用它和窗口级 `setWindowSystemBarProperties()` 设置状态栏；当前工程两处窗口级状态栏设置需要在实施时收口，避免两个所有者互相覆盖。

## 本项目实机实施结论

本次最终实现采用 `HdsNavigation.titleBar.content.stackBuilder`、`avoidLayoutSafeArea: true`、`enableComponentSafeArea: true`、`GRADIENT_BLUR`、`contentStartOffset(10)` 与 `bindToScrollable`。Mate 70 Pro+ 实机验证结果如下：

- 冷启动时，悬浮按钮位于状态栏下方，第一张卡片在按钮底部之后保留约 10vp 的滚动起始间距。
- 滚动后，卡片可以进入按钮与状态栏背后，并由上强下弱的渐变模糊保护状态栏可读性。
- 根导航内容嵌套在 `HdsTabs` 中，除了 `List.clip(false)`，还必须对 `Refresh`、首页根容器、首页 `TabContent` 和 `HdsTabs` 逐层设置 `clip(false)`。否则列表虽然滚入标题栏坐标范围，仍会被任一祖先裁掉，按钮后方只能透出黑色窗口背景。
- 最终未启用 `systemMaterialEffect`。在当前深色主题和真机组合下，`IMMERSIVE_GRADIENT_BLUR + systemMaterialEffect` 会形成不透明黑色材质背板，违背“透明并能看到后方帖子”的产品要求。最终使用显式透明背景的 `GRADIENT_BLUR`，保留 `maskExtraHeight: 32` 与 `blurRadius: 16`。
- 首页频道菜单和 Topic 二级页均完成实机回归，未出现安全区或点击行为退化。

## 推荐结构

以下是结构示意，不是可直接粘贴的最终补丁：

```arkts
HdsNavigation(pathStack) {
  List({ scroller: homeScroller }) {
    // topic items
  }
  .contentStartOffset(8)
  .clip(false)
  .cachedCount(3, true)
}
.titleBar({
  enableComponentSafeArea: true,
  content: {
    title: { mainTitle: '' },
    stackBuilder: (): void => this.HomeFloatingHeader()
  },
  style: {
    scrollEffectOpts: {
      enableScrollEffect: false,
      enableRefreshOffsetChange: true,
      scrollEffectType: ScrollEffectType.GRADIENT_BLUR
    },
    originalStyle: {
      backgroundStyle: {
        maskExtraHeight: 32
      }
    },
    systemMaterialEffect: {
      materialType: hdsMaterial.MaterialType.ADAPTIVE,
      materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
    }
  }
})
.titleMode(HdsNavigationTitleMode.MINI)
.bindToScrollable([homeScroller])
.systemBarStyle(
  { statusBarContentColor: initialStatusColor },
  { statusBarContentColor: scrolledStatusColor }
)
.ignoreLayoutSafeArea(
  [LayoutSafeAreaType.SYSTEM],
  [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]
)
```

### 为什么起始位置这样处理

- `enableComponentSafeArea: true`：官方定义为“将标题栏设置为组件级安全区”，内容区可以避让标题栏。这负责避开整组悬浮按钮。
- `List.contentStartOffset(8~12)`：官方定义为“列表滚动到起始位置时，列表内容与显示区域边界保留指定距离”。这负责用户要求的“再靠下一点”。它从 API 11 起可用，API 22 起参数还支持资源类型。
- `clip(false)`：允许列表内容越过原裁剪范围，穿透到标题栏下方。
- `cachedCount(3, true)`：官方示例用于防止穿透标题栏下方的列表项消失。

不要再给整个 `List` 或外层页面设置固定顶部 `padding`。固定视口内边距会一直存在，无法得到“首屏避让、滚动后穿过”的效果。

如果短期内不能把悬浮按钮迁入 `stackBuilder`，低改动回退方案是给现有列表设置：

```arkts
.contentStartOffset(topSafeArea + floatingHeaderHeight + 8)
```

但该方案只解决首屏位置，不会自动得到 HDS 标题栏的渐变模糊、系统材质和状态栏滚动样式，因此不是最终推荐结构。

## 渐变模糊能力选择

| 能力 | 起始版本 | 实际语义 | 本页结论 |
| --- | --- | --- | --- |
| `ScrollEffectType.GRADIENT_BLUR` | 6.0.0(20) | 标题栏背景在空间维度渐强/渐弱，边界柔和；官方定位为列表型非沉浸式页面。`enableScrollEffect: false` 时直接生效。 | **首页首选。** 与列表场景匹配，并支持 `maskExtraHeight`。 |
| `ScrollEffectType.IMMERSIVE_GRADIENT_BLUR` | 6.1.0(23) | 沉浸式空间渐变模糊；官方定位为沉浸式图文页面。HDS 管理的标题文字和图标会从白到黑线性过渡。 | API 23 可用，但当前是帖子列表，不作为首选。若以后首页变成大图/图文封面，再切换并做真机对比。 |
| `systemMaterialEffect` | 6.1.0(23) | 给 HDS 标题栏按钮增加沉浸光感材质。 | 建议使用 `ADAPTIVE/ADAPTIVE`；系统自适应性能和效果。 |
| `HdsNavigationBackgroundStyle.maskExtraHeight` | 6.0.0(20) | 模糊蒙层超出标题栏的额外高度，默认 32vp。 | 只对 `GRADIENT_BLUR` 生效；可从默认 32vp 开始真机调节。 |
| `HdsNavigationBackgroundStyle.blurRadius` | 6.1.0(23) | `GRADIENT_BLUR`/`IMMERSIVE_GRADIENT_BLUR` 的模糊半径，范围 0~128。 | 先使用系统默认；静态渐变无材质默认 16，有材质默认 12，避免一开始手工加重。 |

`IMMERSIVE_GRADIENT_BLUR` 虽然名字更贴近“沉浸式”，但官方的场景区分以内容类型为准：图文大图用沉浸式渐变，列表用普通渐变。当前需求真正需要的是“列表内容从标题栏下穿过，同时顶部边缘柔和”，因此 `GRADIENT_BLUR` 更准确。

### 通用 ArkUI 模糊为什么不是首选

| API | 起始版本 | 官方语义/限制 | 是否适合本页顶栏 |
| --- | --- | --- | --- |
| `blur()` | API 7 | 模糊当前组件自身内容。 | 不适合；会把目标内容本身模糊。 |
| `foregroundBlurStyle()` | API 10 | 给当前组件内容套材质模糊。 | 不适合；不是透过顶栏模糊后方列表。 |
| `linearGradientBlur()` | API 12 | 对当前组件内容做线性渐变模糊；半径 0~1000，`fractionStops` 至少 2 个且位置严格递增。 | 不适合直接放在空顶栏上；它不是背景穿透模糊。 |
| `backgroundBlurStyle()` | API 9 | 对组件后方内容做材质背景模糊，封装半径、蒙版、饱和度、亮度等。 | 自定义顶栏的回退方案，但本身是均匀材质模糊，不如 HDS 标题栏渐变语义完整。 |
| `backdropBlur()` | API 9 | 自定义半径的背景模糊。 | 可作回退，但仍需自己处理渐变蒙层、滚动联动和状态栏。 |

官方同时指出 `backgroundBlurStyle`、`blur`、`backdropBlur` 以及 `foregroundBlurStyle` 都属于每帧实时渲染的高负载接口。当前已有 HDS 导航且目标为 API 23，应优先使用 HDS 的自适应材质方案。

## 状态栏可读性

1. 保持状态栏显示，不把交互控件放进状态栏避让区。官方沉浸式指南明确指出，状态栏承载系统信息；界面元素发生冲突时应避让。
2. 状态栏背景保持透明，让 HDS 的渐变模糊背板延伸到状态栏区域；状态栏文字/图标必须与背板保持对比。
3. HDS 页面使用 `systemBarStyle(originalStyle, scrollEffectStyle)`。`SystemBarStyle.statusBarContentColor` 从 API 12 起可用；HDS 的 `systemBarStyle` 从 5.1.0(18) 起可用。
4. 浅色主题使用深色状态栏内容，深色主题使用浅色状态栏内容。主题切换时同步更新，不只在冷启动设置一次。
5. 不要让窗口层和 HDS 页面同时控制状态栏。HDS 官方 API 参考明确写明“不建议混合使用 `systemBarStyle` 和 `setWindowSystemBarProperties`”。当前工程的 `EntryAbility.ets` 和 `Index.ets` 都会调用后者，实施时应将状态栏内容颜色的职责迁给 HDS；窗口层最多继续负责不与 HDS 冲突的窗口/底部导航区域设置。
6. 自定义 `stackBuilder` 内按钮的图标颜色仍应使用深浅色系统资源。官方“白到黑线性过渡”的描述针对 HDS 管理的标题和图标，不应假设任意自定义子树会被自动改色。

## 当前工程落点

- `app/entry/src/main/ets/pages/Index.ets`：根 `HdsNavigation` 已恢复首页标题栏并配置 `titleBar`，同时继续绑定 `homeScroller`；非首页根 Tab 仍隐藏该标题栏。
- `app/entry/src/main/ets/components/HomeFloatingHeader.ets`：LOGO、频道选择、搜索、发帖、在线人数及其菜单/半模态已抽成独立组件，供 `titleBar.content.stackBuilder` 使用。
- `app/entry/src/main/ets/components/HomeBrowsePage.ets`：保留 `List.clip(false)` 和 `cachedCount(3, true)`，新增 `contentStartOffset(10)`，并放开 `Refresh` 与根容器裁剪。
- `app/entry/src/main/ets/entryability/EntryAbility.ets` 与 `Index.ets`：当前窗口级状态栏样式有两个更新入口；应与 HDS 的页面级状态栏样式统一所有权。

## 验证要求

1. API 23 真机验证浅色、深色各四个状态：冷启动首屏、滚动穿透、下拉刷新、滚回顶部。
2. 首屏第一张卡片应位于悬浮按钮下方 8~12vp；滚动后卡片可以从按钮和模糊背板下穿过。
3. 状态栏在浅/深模式和滚动前后均可读；页面切换时不闪成相反颜色。
4. 检查下拉刷新时模糊是否跟手。`enableRefreshOffsetChange` 从 API 23 起可用，默认值为 `true`。
5. 沉浸光感材质必须以真机截图和滚动流畅度验收。官方说明模拟器不支持沉浸光感材质等 HDS 沉浸视效，不能用模拟器判断最终视觉。

## 官方来源

1. `API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsNavigation/ui-design-hdsnavigation`：`titleBar`、`enableComponentSafeArea`、`bindToScrollable`、`ScrollEffectType`、`maskExtraHeight`、`blurRadius`、`systemBarStyle`、完整示例。
2. `开发指南/UI_Design_Kit_UI设计套件/组件导航/设置动态模糊样式/ui-design-navigation-dynamic-blur`：列表穿透标题栏的官方组合 `enableComponentSafeArea + clip(false) + cachedCount(3, true) + bindToScrollable`。
3. `开发指南/UI_Design_Kit_UI设计套件/组件导航/设置自定义区域/ui-design-navigation-customized-area`：通过 `titleBar.content.stackBuilder` 放置自定义顶部操作区。
4. `API参考/ArkUI_方舟UI框架/ArkTS组件/滚动与滑动/List/ts-container-list`：`contentStartOffset` 的行为、版本和参数约束。
5. `开发指南/UI_Design_Kit_UI设计套件/沉浸光感/ui-design-hds-component-material`：HDS 标题栏的系统材质配置与自适应推荐。
6. `API参考/UI_Design_Kit_UI设计套件/ArkTS_API/hdsMaterial/ui-design-hdsmaterial`：`MaterialType`、`MaterialLevel`、设备能力查询与降级策略。
7. `API参考/ArkUI_方舟UI框架/ArkTS组件/通用属性/视效与模糊/图像效果/ts-universal-attributes-image-effect`：`blur`、`linearGradientBlur` 的内容模糊语义和参数约束。
8. `API参考/ArkUI_方舟UI框架/ArkTS组件/通用属性/视效与模糊/组件内容模糊/ts-universal-attributes-foreground-blur-style`：`foregroundBlurStyle` 的内容模糊语义和实时渲染成本。
9. `API参考/ArkUI_方舟UI框架/ArkTS组件/通用属性/基础属性/背景设置/ts-universal-attributes-background`：`backgroundBlurStyle`、`backdropBlur`、实时模糊性能提示。
10. `开发指南/ArkUI_方舟UI框架/UI开发_ArkTS声明式开发范式/组件布局/开发应用沉浸式效果/arkts-develop-apply-immersive-effects`：全屏布局、避让区、状态栏可读性和安全区原则。
11. `API参考/ArkUI_方舟UI框架/ArkTS_API/窗口管理/ohos_window_窗口_/Interfaces_其他/arkts-apis-window-i`：`SystemBarStyle.statusBarContentColor`。
12. `开发指南/UI_Design_Kit_UI设计套件/UI_Design_Kit简介/ui-design-introduction`：HDS 设备支持及模拟器不支持沉浸光感材质等沉浸视效的限制。
