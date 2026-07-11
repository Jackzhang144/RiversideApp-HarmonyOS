# 05 — 迁移 Topic/Post 阅读完整路径

**What to build:** 将正式 Topic/Post 阅读页面迁移到与 Home 一致的原生卡片、排版和反馈基线，同时完整保留现有 Post 顺序、分段加载、失败恢复和不可 Reply 限制。

**Blocked by:** 03 — 迁移 Home 最新回复完整路径.

**Status:** ready-for-agent

- [ ] Topic 详情与 Post 使用统一的原生页面容器、卡片、字体、颜色和间距，并保持长文本可读。
- [ ] initial、loading、content、empty 和 error 状态使用真实 Topic/Post 数据且提供正确恢复操作。
- [ ] Post 按现有服务端顺序展示，不增加“最早/最新”排序控件、倒序加载或虚假跳转。
- [ ] 分段追加加载继续按现有 Post 窗口执行；追加失败保留已显示 Post、加载位置和可重试入口。
- [ ] Topic 关闭、归档或当前会话不可 Reply 时，页面显示真实限制且不会开放无效 Reply 操作。
- [ ] 从 Home 或 Category 打开 Topic、返回来源页面和保留根选择的行为保持不变。
- [ ] 现有 Reply 业务在本票完成后仍可使用；本票不改变 Reply 提交、草稿或恢复契约。
- [ ] AppShell 自动测试继续覆盖首屏、空 Post、请求失败、追加失败、同窗口重试、过期响应隔离和关闭/归档限制。
- [ ] 使用 `devecocli` 完成 API 23 构建与 Topic/Post 阅读验证，且不修改或提交本地签名配置。

