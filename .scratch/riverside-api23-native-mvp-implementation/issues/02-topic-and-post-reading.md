# 02 — Topic 与 Post 阅读

**What to build:** 用户可以从 Home 或 Category 打开 Topic，阅读首屏 Post 并继续分段加载更多 Post；阅读过程保留已显示内容，清晰处理加载、空态、失败与重试。

**Blocked by:** 01 — API 23 浏览基础.

**Status:** resolved

- [x] Topic 详情作为 AppShell 推入的二级页面，返回时保留根入口浏览上下文。
- [x] 首屏 Topic 与 Post 成功显示，长 Topic 可按既有契约分段加载，且 Topic/Post 不重复。
- [x] 首屏失败、分页失败、空结果和手动重试都有用户可见且可恢复的状态。
- [x] 已关闭或归档的 Topic 明确不可 Reply。
- [x] 模拟器自动化回归覆盖读取主路径与主要失败路径，不依赖认证或真实 Reply。

## Answer

已完成 Home/Category → Topic 的 HDS 二级导航、Topic 首屏与 Post 分段读取、失败恢复、空态、关闭/归档限制，以及按 Topic/Post ID 去重。Post 正文从 Discourse `cooked` 内容生成 ArkUI 原生可读文本；避免在 `List` 中批量嵌入 WebView 型 RichText。

验证证据：

- `devecocli build clean` 与 `devecocli build --modules entry` 通过。
- API 23 模拟器 `onDeviceTest`：25 个测试全部通过，0 Failure / 0 Error。
- 真实 RiverSide 数据完成 Home → Topic、Category → Topic、返回保留 Category 上下文的交互回归。
- Standards / Spec 双轴复审通过；过期响应覆盖、Topic 重复和 cooked 展示三项发现均已修复。
