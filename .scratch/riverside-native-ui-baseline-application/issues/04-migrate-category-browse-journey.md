# 04 — 迁移 Category 浏览完整路径

**What to build:** 将原型确认的原生目录层级应用到真实 Category 数据、缓存和 Category Topic 列表，让用户从根入口到打开 Topic 的整条路径保持可读、可恢复且不依赖 Fixture。

**Blocked by:** 03 — 迁移 Home 最新回复完整路径.

**Status:** ready-for-agent

- [ ] Category 根页面使用系统 Symbol、原生列表层级和统一间距展示真实服务端 Category 树与排序。
- [ ] 正式页面不包含原型 Fixture 的分类名称或“校内事务、学习交流、生活服务”等 Fixture 分组。
- [ ] 缓存命中时先显示已有 Category 并进行后台刷新；刷新失败保留缓存内容并提供非阻塞反馈。
- [ ] 无缓存时正确呈现 initial、loading、content、empty 和 error，并提供可恢复操作。
- [ ] 打开 Category 后显示真实 Topic 列表，复用已建立的 Topic 卡片视觉，并覆盖加载、内容、空态、错误和重试。
- [ ] 从 Category Topic 列表打开 Topic、返回列表和保留 Category 根选择的导航语义保持不变。
- [ ] AppShell 自动测试继续覆盖缓存分区、后台刷新、刷新失败保留内容、Category Topic 错误恢复和二级导航。
- [ ] 使用 `devecocli` 完成 API 23 构建与 Category 完整路径验证，且不修改或提交本地签名配置。

