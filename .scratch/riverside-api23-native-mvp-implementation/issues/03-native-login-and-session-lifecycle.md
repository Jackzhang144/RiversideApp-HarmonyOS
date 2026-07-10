# 03 — 原生登录与会话生命周期

**What to build:** 用户可以在应用内完成 RiverSide User API Key 登录，应用安全保存并恢复 Authenticated Session；登出和认证失效都产生一致、可理解的应用状态。

**Blocked by:** 02 — Topic 与 Post 阅读.

**Status:** ready-for-agent

- [ ] 登录在内嵌 ArkWeb 内完成，严格校验授权回调、RSA 解密结果与 nonce，不依赖外部浏览器回跳。
- [ ] Authenticated Session 以 HUKS 加密持久化，应用重启后可恢复；登出会清除相关本地认证材料。
- [ ] 只有 HTTP 401 触发 AppShell 的全局登出；其他错误保持为页面级错误。
- [ ] 自动化测试覆盖授权成功和失败、nonce 校验、会话恢复、登出与 401；不测试密码学库内部实现。
- [ ] 在 API 23 真机验证授权、RSA 互操作、回调截获、会话恢复和清理，并记录脱敏结果。
