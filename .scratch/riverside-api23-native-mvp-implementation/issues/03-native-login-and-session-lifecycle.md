# 03 — 原生登录与会话生命周期

**What to build:** 用户可以在应用内完成 RiverSide User API Key 登录，应用安全保存并恢复 Authenticated Session；登出和认证失效都产生一致、可理解的应用状态。

**Blocked by:** 02 — Topic 与 Post 阅读.

**Status:** ready-for-human

- [x] 登录在内嵌 ArkWeb 内完成，严格校验授权回调、RSA 解密结果与 nonce，不依赖外部浏览器回跳。
- [x] Authenticated Session 以 HUKS 加密持久化，应用重启后可恢复；登出会清除相关本地认证材料。
- [x] 只有 HTTP 401 触发 AppShell 的全局登出；其他错误保持为页面级错误。
- [x] 自动化测试覆盖授权成功和失败、nonce 校验、会话恢复、登出与 401；不测试密码学库内部实现。
- [ ] 在 API 23 真机验证授权、RSA 互操作、回调截获、会话恢复和清理，并记录脱敏结果。

## Comments

- 2026-07-10: 已实现 HDS “我的”根页、HdsNavDestination 登录页与内嵌 ArkWeb；API 23 模拟器成功加载 RiverSide 登录页并完成返回取消，未输入账号或执行真实授权。
- 授权边界使用临时 RSA-2048 PKCS#1 材料、精确 `riverside://auth_redirect` 主框架回调和 nonce 校验；取消后的迟到生成/解密结果会被丢弃并清理。
- Authenticated Session 使用 HUKS AES-256-GCM 加密，Preferences 只保存版本化 nonce/ciphertext envelope；模拟器完成保存、恢复与清理回归。
- 认证 HTTP 请求仅在存在 Session 时加入 `User-Api-Key` 与 `User-Api-Client-Id`；全局 401 生命周期会合并重叠/迟到通知，并串行化保存与登出清理。
- API 23 模拟器 `onDeviceTest`：42 个测试全部通过，0 Failure / 0 Error；Standards / Spec 双轴复审通过。
- HdsNavDestination 的起始版本、导入、`titleBar` 与 `onBackPressed` API 23 边界已补入 HDS 调研。真实授权、RSA 服务端互操作、重启恢复/清理和 HDS 视觉仍须按真机清单验收。
