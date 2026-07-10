# 01 — API 23 浏览基础

**What to build:** 用户可以在 API 23 原生 HarmonyOS 应用中打开 Home 与 Category 两个根入口，浏览真实 RiverSide Category 与 Topic 数据，并获得完整的加载、空态、失败重试和 Category 缓存体验。界面优先采用已验证的 HDS 组件，不满足条件时自然回退到 ArkUI。

**Blocked by:** None — can start immediately.

**Status:** ready-for-human

- [x] 新建的 Stage 模型应用以 API 23 为目标，能构建并在模拟器运行基础交互。
- [x] Home 与 Category 是 AppShell 管理的同级根入口，且未引入任何已排除功能。
- [x] 首页与 Category 使用真实既有论坛契约，分别具有加载、成功空态、页面内错误和重试体验。
- [x] Category 缓存按匿名或 Authenticated Session 身份隔离，命中后后台刷新；刷新失败仍保留可浏览内容并给出非阻塞反馈。
- [x] 自动化测试通过 AppShell 的依赖组合验证浏览流程。
- [ ] API 23 真机就绪后，记录 HDS 视觉验证结果。

## Comments

- 2026-07-10: API 23 Stage 工程、AppShell 状态、真实 RiverSide 契约、Preferences Category 缓存和 HDS 浏览 UI 已实现并分步提交。
- `devecocli build clean && devecocli build` 通过；`HdsNavigation`/`HdsTabs`/`HdsSnackBar` 已在 API 23 SDK 编译通过。
- `Riverside API 23` 模拟器（HarmonyOS 6.1.0(23)）已完成应用安装、Home/Category 切换、真实数据展示与 Category 手动刷新；刷新请求返回 HTTP 200。
- 修复了模拟器验收发现的 HDS 导航标题与页面标题重叠问题；Home 与 Category 复验无重叠。
- 9 个 AppShell 用例和 3 个 JSON 边界用例在 API 23 模拟器执行通过：`Tests run: 12, Failure: 0, Error: 0, Pass: 12, Ignore: 0`。
- HDS 沉浸视效仍不能用模拟器验收，票据继续保持 `ready-for-human`，等待 API 23 中国大陆真机完成最终视觉验收。
