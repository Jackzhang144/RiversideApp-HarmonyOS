# Wayfinder map: Riverside API 23 full functional parity

## Destination

Produce an implementation-ready specification and dependency-ordered ticket plan for a native HarmonyOS API 23 phone client that is functionally equivalent to the frozen Flutter reference at `/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp` commit `9d8b13c`.

## Notes

- Functional parity means every user-visible Flutter capability available to an ordinary or administrator account is implemented with equivalent server semantics. The native UI may follow HarmonyOS conventions; pixel-level Flutter reproduction is not required.
- The scope is HarmonyOS phone only. Tablets, foldables, wearables, desktop, web, and Flutter platform packaging are outside this effort.
- Reuse the existing RiverSide/Discourse server contracts and their authorization model. Do not introduce server, schema, or permission-rule changes.
- Rich Post content is in scope: Markdown/HTML, media, links, supported embeds, and in-app navigation must have native-equivalent behaviour.
- Final acceptance uses the user's ordinary and administrator accounts against the existing service. Forum writes occur only in the designated test Category. RSC operations require a separately proven safe test path or explicit per-operation user authorization.
- Preserve the current native architecture unless a resolved ticket records an ADR: AppShell owns navigation and the Authenticated Session; repositories own contracts; only HTTP 401 invalidates the global session.
- Read `CONTEXT.md` and applicable ADRs before working a ticket. Use `devecocli` for HarmonyOS documentation, builds, devices, runs, and logs. Keep ArkTS strictly typed and do not introduce `any`.
- Existing unrelated working-tree changes are user-owned and out of scope for this planning effort.

## Decisions so far

<!-- Closed ticket decisions appear here as links and one-line gists. -->

- [审计冻结 Flutter 参考的功能与契约表面](issues/01-audit-frozen-flutter-parity-surface.md) — Flutter `9d8b13c` 的完整产品面已归档；当前 ArkTS 只有论坛 MVP，富内容、Profile、Chat/通知、RSC、世界杯和设备能力均须单独规划。
- [映射 API 23 原生能力与安全边界](issues/02-map-api23-native-capability-and-security-boundaries.md) — API 23 有原生实现路径，但富内容必须隔离 ArkWeb，媒体走最小权限流程，HUKS 保护会话；Push/后台不能照搬 Flutter 轮询。
- [准备真实账户与测试 Category 验收条件](issues/03-prepare-real-account-and-test-category-acceptance.md) — 普通与管理员账号由用户交互登录；所有论坛写入固定在 Category `111` 且保留测试数据；RSC 状态/资产操作逐笔确认，物理手机仍是最终系统验收门槛。
- [裁决冻结参考中的契约证据冲突](issues/05-resolve-frozen-reference-contract-conflicts.md) — 认证校友由五个组名或对应 primary/flair ID 判定，开发者组不等同认证；Chat Reaction 是完整的解析、展示、写入和刷新闭环。
- [决定 HarmonyOS 消息提醒交付契约](issues/06-decide-notification-delivery-contract.md) — 本阶段保留应用内消息与前台刷新，但不接入远程 Push、服务端 token 契约或后台轮询替代。
- [原型验证 ArkWeb 富内容安全边界](issues/07-prototype-arkweb-rich-content-security-boundary.md) — Bilibili 播放器及其已观察到的站内重定向可在无桥接、禁混合内容的精确 JSON 白名单内加载；该结论只验证安全导航边界，正式渲染仍需另行验收。
- [验证媒体选择、保存、分享与传输契约](issues/08-validate-media-save-share-and-transfer-contracts.md) — 选图后复制至应用缓存再上传，保存使用 SaveButton/授权弹窗且不申请广泛相册权限；分享和断点续传不是冻结 Flutter 行为，不能在不改服务端的前提下承诺。
- [决定完整对等的验收标准与交付切片](issues/04-decide-parity-acceptance-and-delivery-slices.md) — 以用户闭环纵向切片和分层验收推进；管理员仅操作 Category `111` 测试内容，资料媒体可用测试账号验证，远程 Push 单独延期。
- [完整对等规格](spec.md) — 已按确认的架构缝面、验收门槛和延期范围固化为 `ready-for-agent` 规格，并发布了 [14 个依赖有序的实现票](../riverside-api23-full-parity-implementation/issues/)。

## Not yet specified

- The per-feature release evidence required after the product contract and HarmonyOS capability limits are known.

## Out of scope

- Server-side RiverSide/Discourse changes, data migrations, or permission-rule changes.
- New product functionality not present in Flutter commit `9d8b13c`.
- Pixel-for-pixel Flutter UI reproduction.
- Non-phone device layouts and Flutter platform distribution artifacts.
- [HarmonyOS 远程 Push 交付](issues/06-decide-notification-delivery-contract.md) — 等待用户协调服务端接入华为推送并重新定义 token/发送契约；本阶段不得用客户端轮询替代。
