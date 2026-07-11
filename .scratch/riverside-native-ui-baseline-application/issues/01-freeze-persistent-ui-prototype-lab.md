# 01 — 固化持久 UI 原型实验区

**What to build:** 将当前已确认的五入口 UI 原型固化为可构建、可进入且长期保留的实验区，让后续 UI 变化可以继续先用 Fixture 和状态控制完成评审，同时不改变正式页面的真实业务能力。

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 原型继续提供首页、Category、聊天、消息、我的、Topic 和 Reply 的设计评审表面，并明确说明使用静态数据且不连接论坛后端。
- [ ] 原型状态控制能够继续展示适用的 content、loading、empty、error 和 unauthorized 评审状态。
- [ ] 原型控制中的系统通知测试继续检查授权并给出成功或失败反馈，但该能力不出现在正式消息行为中。
- [ ] 原型可以从当前账户入口进入并正常退出，且不会改变正式根导航、论坛数据或 Authenticated Session。
- [ ] ArkTS 类型保持完整，不引入 `any` 或不安全断言，通知运行环境通过强类型能力注入。
- [ ] 使用 `devecocli` 完成 API 23 构建验证；现有自动测试保持通过，且不修改或提交本地签名配置。

