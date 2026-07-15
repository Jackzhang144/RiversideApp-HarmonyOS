# 01 — 账号身份与权限面

**What to build:** 让已授权用户在 Account 中看到真实身份、角色、认证校友状态、基础许可与未读概况；所有后续能力据此正确显示或禁用，而不猜测服务器权限。

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] 读取并呈现当前用户、群组、认证校友规则、管理员/版主与服务端许可；开发者组不误判为认证。
- [ ] 保持 Authenticated Session、全局 401 与页面级失败语义，补充可观察的加载、空态和错误反馈。
- [ ] 完成自动化、构建和普通账号真实服务模拟器验证记录。
