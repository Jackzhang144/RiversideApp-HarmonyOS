# Riverside MVP：HDS 组件 API 23 适配结论

日期：2026-07-10
范围：只核验 API 23 手机 MVP 所需的 HdsNavigation、HdsTabs、HdsListItem、HdsSnackBar 与 HdsActionBar；不代表完成真机运行验证。

## 结论

五个候选组件的基础接口起始版本均不高于 API 23：HdsNavigation 从 5.1.0(18) 起，其余四个均从 6.0.0(20) 起。因此，在 **Stage 模型、API 23 手机、且处于中国大陆发行范围** 的工程中，它们可以作为 MVP 的 HDS 候选组件。[1][2][3][4][5][6]

这不是“所有 HDS 新能力都可不经验证地使用”的结论。部分属性在 6.1.0(23) 才新增；沉浸光感材质也从 6.1.0(23) 才开始支持。MVP 应先仅使用下表的基础能力；任何 API 23 新增属性均须在目标真机单独验证后才能纳入验收基线。[2][3][4][5][7]

## 共同前提与已核验限制

- **工程模型与导入：** 这五个组件的参考接口均限定为 Stage 模型，且通过系统 Kit `@kit.UIDesignKit` 导入，而非 `ohpm` 三方包。工程应以 API 23 为目标版本，并在首个最小工程中做一次编译验证。[2][3][4][5][6]
- **地区：已核验。** 官方说明 UI Design Kit 当前仅支持中国境内，明确排除香港特别行政区、澳门特别行政区和中国台湾；本 MVP 的“中国大陆发行”约束与之相符。[1]
- **模拟器：已核验。** 官方说明 Kit 可在模拟器开发，但模拟器不支持 HDS 沉浸视效：点光源、按压阴影、各类边缘/背景流光及沉浸光感材质。故模拟器仅用于结构与基础交互回归；涉及 HDS 视觉的验收必须在 API 23 真机执行。[1]
- **设备：** 五个候选能力在官方设备表中均支持 Phone；本研究不把 TV 差异带入手机 MVP。[1]
- **不应假设的配置：** 本轮查到的组件参考未列出额外的权限、服务开通或 `oh-package.json5` 依赖。是否有工程脚手架/SDK 版本的额外要求，须在创建 API 23 工程并编译首个页面时实测；在此之前标记为未验证，而不是自行补充配置。

## 组件适配表

| 组件 | 起始版本与导入 | API 23 基础适配 | MVP 用法 | 已知限制与使用边界 | ArkUI 回退 |
| --- | --- | --- | --- | --- | --- |
| `HdsNavigation` | 5.1.0(18)；`import { HdsNavigation } from '@kit.UIDesignKit';`。6.0.1(21) 及以前还必须显式导入 `HdsNavigationAttribute`，API 23 对应 6.1.0(23) 不需要。[2] | **可用。** | 应用根导航与话题详情/登录/回复等二级页的标题栏、返回和菜单。配合 ArkUI `NavPathStack`；二级页还需按官方导航模式使用 `HdsNavDestination`（本票未单独核验其 API 细节）。[1][2] | Stage-only；横屏 Stack 模式不能把工具栏并入菜单栏，标题栏默认叠在内容之上。数组工具栏最多显示 5 个图标，且不能以 `SymbolGlyphModifier` 的部分属性修改图标大小或动效。[1][2] | `Navigation` + `NavDestination` + `NavPathStack`；标题栏/工具栏以 `Row`、`Button` 组合。 |
| `HdsTabs` | 6.0.0(20)；`import { HdsTabs, HdsTabsController } from '@kit.UIDesignKit';`。6.0.1(21) 及以前还要导入 `HdsTabsAttribute`。[3] | **可用。** | 若最终信息架构把“首页/分类”做成同级主入口，可作为底部页签容器。 | Stage-only；一个 controller 不能控制多个 `HdsTabs`。悬浮栏/迷你栏等有 API 23 新增能力，首版不采用，待真机核验后再评估。[3][7] | ArkUI `Tabs` + `TabContent` + `TabsController`。 |
| `HdsListItem` | 6.0.0(20)；`import { HdsListItem } from '@kit.UIDesignKit';`。[4] | **基础接口可用；主题列表首版建议以基础 ArkUI 为默认实现。** | 可在分类或话题列表的视觉探索中试用其卡片承载和横滑效果；不应将横滑删除作为 MVP 需求。 | Stage-only；不支持通用属性和通用事件，需先以可点击的实际主题行验证导航与无障碍行为。预览菜单、`menuBuilder`、选择态等于 API 23 才新增，不纳入首版基线。[4] | `List` + `ListItem` + `Row/Column`，在行内使用 `Button`/点击事件完成进入话题。 |
| `HdsSnackBar` | 6.0.0(20)；`import { HdsSnackBar } from '@kit.UIDesignKit';`。[5] | **可用。** | 登录跳转失败、回复提交成功/失败、网络可恢复错误的轻量非模态反馈。 | Stage-only；保持一次提示只描述一个结果。API 23 才新增的可选样式字段不进入首版基线。[5] | ArkUI `promptAction.showToast`；需要操作按钮时用自定义 `Popup`/`Overlay`。 |
| `HdsActionBar` | 6.0.0(20)；`import { HdsActionBar, ActionBarButton, ActionBarStyle } from '@kit.UIDesignKit';`。[6] | **基础接口可用，但不是 MVP 主流程的必选组件。** | 只用于已确认的“话题上下文多操作”；回复提交仍使用明确的 ArkUI 主按钮，避免把唯一动作塞入可展开操作栏。 | Stage-only，且为 `@ComponentV2`；调用方需采用与其兼容的状态管理方式。`margin` 等字段在 API 23 才新增，不纳入首版基线。[6] | `Row`/`Column` + `Button`/`Menu`，或 `HdsNavigation` 工具栏。 |

## MVP 页面映射

| MVP 场景 | HDS 优先方案 | 必须保留的 ArkUI 基础部分/回退 | 验收重点 |
| --- | --- | --- | --- |
| 首页/分类入口 | `HdsNavigation`；只有在“首页、分类”确定为同级根入口时再用 `HdsTabs`。 | `Navigation`；`Tabs`。 | API 23 真机标题栏、返回、页签切换；模拟器回归结构和点击。 |
| 分类话题列表 | `HdsNavigation`；`HdsListItem` 仅通过可点击原型后采纳。 | `List`、`ListItem`、`Row`/`Column`，这是首版安全路径。 | 主题行点击、长标题截断、加载/空态/错误态。 |
| 话题详情与 Post 列表 | `HdsNavigation` 负责页级标题/菜单。 | `List` + 自定义 Post 行；不要假定 HdsListItem 能覆盖 Post 的所有语义与交互。 | 返回、滚动、帖子可读性、登录前后的回复入口。 |
| 登录与纯文本/Markdown 回复 | `HdsNavigation`；提交结果用 `HdsSnackBar`。 | `TextArea`、`Button`、`Navigation`；必要时 `promptAction.showToast`。 | API 23 真机完成浏览器回调、回复成功与失败反馈。 |
| 话题上下文动作 | 只有功能范围确定为多个动作时采用 `HdsActionBar`。 | `Button`/`Menu`/导航工具栏。 | 不阻塞 MVP；先保证回复主路径。 |

## 实施门槛

1. 创建 API 23 Stage 模型最小工程，分别导入五个组件并进行编译；记录 SDK/DevEco Studio 版本和首个编译结果。
2. 在 API 23 真机验证 `HdsNavigation`、`HdsTabs`、`HdsSnackBar` 的基础交互与 HDS 视觉；若使用 `HdsListItem`，先验证主题行点击和无障碍；若使用 `HdsActionBar`，先验证 `ComponentV2` 状态更新。
3. 在模拟器只回归非沉浸结构和基础交互。不要以模拟器截图判断点光、阴影、流光或沉浸光感材质。[1]
4. 默认不使用 API 23 新增的悬浮/迷你页签、列表预览菜单及沉浸材质；它们要有单独真机证据才可启用。[3][4][7]

## 官方来源

1. [华为开发者：UI Design Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-introduction)（地区、设备支持表、模拟器不支持的 HDS 沉浸视效、HDS 与 ArkUI 的关系）。本机检索标识：`开发指南/UI_Design_Kit_UI设计套件/UI_Design_Kit简介/ui-design-introduction`。
2. [华为开发者：HdsNavigation API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdsnavigation)（起始版本、导入、Stage 模型与导航/工具栏限制）。本机检索标识：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsNavigation/ui-design-hdsnavigation`。
3. [华为开发者：HdsTabs API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdstabs)（起始版本、导入、Stage 模型、controller 与 API 23 新增能力）。本机检索标识：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsTabs/ui-design-hdstabs`。
4. [华为开发者：HdsListItem API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdslistitem)（起始版本、导入、通用属性/事件限制与 API 23 新增字段）。本机检索标识：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsListItem/ui-design-hdslistitem`。
5. [华为开发者：HdsSnackBar API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdssnackbar)（起始版本、导入、Stage 模型与样式字段）。本机检索标识：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsSnackBar/ui-design-hdssnackbar`。
6. [华为开发者：HdsActionBar API 参考](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ui-design-hdsactionbar)（起始版本、导入、`ComponentV2` 与 API 23 新增字段）。本机检索标识：`API参考/UI_Design_Kit_UI设计套件/ArkTS组件/HdsActionBar/ui-design-hdsactionbar`。
7. [华为开发者：HDS 沉浸光感](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/ui-design-hds-component-material)（6.1.0(23) 起的导航/页签沉浸材质及按设备能力降级建议）。本机检索标识：`开发指南/UI_Design_Kit_UI设计套件/沉浸光感/ui-design-hds-component-material`。
