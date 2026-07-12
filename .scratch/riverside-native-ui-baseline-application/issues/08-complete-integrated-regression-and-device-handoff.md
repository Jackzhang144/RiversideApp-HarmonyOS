# 08 — 完成集成回归与真机验收交接

**What to build:** 对已迁移的正式 UI、未实现占位和持久原型实验区执行完整集成回归，证明现有论坛、认证和 Reply 能力未回退，并形成可由 API 23 中国大陆物理真机继续执行的 HDS 验收交接。

**Blocked by:** 04 — 迁移 Category 浏览完整路径; 06 — 迁移“我的”与账户认证路径; 07 — 迁移 Reply 编辑与安全恢复路径.

**Status:** resolved

- [x] 使用统一 AppShell 最高层接缝覆盖规格中的完整正式状态矩阵，并保持所有现有自动测试通过。
- [x] 验证首页、Category、我的三个真实根入口和 Topic、认证、Reply 二级路径能够组合工作且没有状态所有权回退。
- [x] 验证聊天、消息、Home 四个排序、搜索、新 Topic、账户八项、图片和 @提及全部符合“未实现”、无响应、无请求和无障碍语义。
- [x] 验证正式页面不读取 Fixture，原型 Fixture、状态控制和系统通知测试只能通过原型胶囊入口访问。
- [x] 使用 `devecocli` 完成 API 23 全量构建、自动设备测试、安装启动和模拟器关键路径回归，并确认没有应用崩溃。
- [x] 模拟器人工检查覆盖五 Tab、安全区、页面结构、下拉刷新、Topic/Post 追加、账户状态和 Reply 编辑器基础键盘行为。
- [x] 记录模拟器证据与限制，不把模拟器截图描述为 HDS 沉浸材质、触控、软键盘或动效的真机验收结果。
- [x] 更新物理真机验收交接，明确 HDS 悬浮材质、Symbol、触控、安全区、软键盘、动效和无障碍的待验项目与复现步骤。
- [x] 验证过程不记录账户密码、User API Key、私钥、会话密文或签名材料，也不修改或提交本地签名配置。

## Answer

2026-07-12，正式 UI 基线完成 API 23 模拟器集成回归与物理真机验收交接。

- 新增 AppShell 组合回归，从 Category 根入口串联 Category Topic、Topic、指定 Post Reply、Post 追加和返回栈，证明状态仍由同一个 AppShell 持有。
- `scripts/verify-mvp-api23.sh 127.0.0.1:5555 emulator` 通过：80/80，0 Failure / 0 Error / 0 Ignore；正式 HAP 安装启动成功，脱敏崩溃日志为空。
- 人工结构回归覆盖五 Tab 占位、Home/Category 下拉刷新、Topic/Post 追加、指定楼层 Reply、半模态键盘避让、已登录账户占位，以及原型进入/退出。
- 完整模拟器证据、脱敏规则和物理真机复现步骤见 `docs/verification/api23-physical-device-readiness.md`。

本票的 `resolved` 表示模拟器回归与真机交接材料已经完成，不表示 API 23 物理真机验收已经通过。当前仍无物理真机连接，因此 HDS 材质、真实触控与安全区、真实软键盘、动效、屏幕阅读器，以及真实硬件 ArkWeb/HUKS 继续保持待验。
