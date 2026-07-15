# 05 — 安全富内容渲染与链接导航

**What to build:** 让用户安全阅读 Markdown/HTML、引用、代码、公式、剧透、列表、表格、图片、onebox 和 Bilibili/YouTube 嵌入，并以正确策略打开站内外链接。

**Blocked by:** 03 — 完整 Topic 阅读、Reaction、书签与阅读状态.

**Status:** ready-for-agent

- [ ] 富内容按原生或隔离 ArkWeb 边界呈现，不向不受信任 Post HTML 提供 JavaScript bridge 或原生特权。
- [ ] 使用已验证的精确 ArkWeb 白名单、禁混合内容和 SSL 取消加载策略；站内 Topic/Profile 进入原生页面，外链走明确授权导航。
- [ ] 自动化、构建、模拟器内容回归和物理 Phone 的 ArkWeb/嵌入验收均通过。
