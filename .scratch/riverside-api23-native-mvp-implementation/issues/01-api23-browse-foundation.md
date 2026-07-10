# 01 — API 23 浏览基础

**What to build:** 用户可以在 API 23 原生 HarmonyOS 应用中打开 Home 与 Category 两个根入口，浏览真实 RiverSide Category 与 Topic 数据，并获得完整的加载、空态、失败重试和 Category 缓存体验。界面优先采用已验证的 HDS 组件，不满足条件时自然回退到 ArkUI。

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 新建的 Stage 模型应用以 API 23 为目标，能构建并在模拟器运行基础交互。
- [ ] Home 与 Category 是 AppShell 管理的同级根入口，且未引入任何已排除功能。
- [ ] 首页与 Category 使用真实既有论坛契约，分别具有加载、成功空态、页面内错误和重试体验。
- [ ] Category 缓存按匿名或 Authenticated Session 身份隔离，命中后后台刷新；刷新失败仍保留可浏览内容并给出非阻塞反馈。
- [ ] 自动化测试通过 AppShell 的依赖组合验证浏览流程；API 23 真机就绪后，记录 HDS 视觉验证结果。
