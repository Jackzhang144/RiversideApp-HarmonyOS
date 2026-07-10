# 02 — Topic 与 Post 阅读

**What to build:** 用户可以从 Home 或 Category 打开 Topic，阅读首屏 Post 并继续分段加载更多 Post；阅读过程保留已显示内容，清晰处理加载、空态、失败与重试。

**Blocked by:** 01 — API 23 浏览基础.

**Status:** ready-for-agent

- [ ] Topic 详情作为 AppShell 推入的二级页面，返回时保留根入口浏览上下文。
- [ ] 首屏 Topic 与 Post 成功显示，长 Topic 可按既有契约分段加载，且 Topic/Post 不重复。
- [ ] 首屏失败、分页失败、空结果和手动重试都有用户可见且可恢复的状态。
- [ ] 已关闭或归档的 Topic 明确不可 Reply。
- [ ] 模拟器自动化回归覆盖读取主路径与主要失败路径，不依赖认证或真实 Reply。
