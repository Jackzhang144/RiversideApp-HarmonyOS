# Account 身份与权限面验证

日期：2026-07-12  
设备：Mate 70 Pro API 23 Phone 模拟器  
账号：普通测试账号（不记录用户名或认证材料）

## 自动化与构建

- `devecocli build --modules entry`：通过。
- `devecocli build --modules entry@ohosTest`：通过。
- ArkTS Instrument Test：82 项，82 Pass，0 Failure，0 Error，0 Ignore，`OHOS_REPORT_CODE: 0`。
- 新增覆盖：身份/角色/认证/许可呈现；显式发帖拒绝优先级；禁言限制；私聊直接许可；认证群组 ID。

## 真实服务只读验证

1. 初始故障 UI 树稳定命中“未登录 RiverSide”；应用 Preferences 中没有已保存会话。
2. 用户完成网页登录及后续 User API Key 授权后，Account 显示服务端事实：普通成员、已认证、信任等级 3、暂无未读、可发帖、可发起私聊。
3. 完整测试完成后重新安装主 HAP，强制停止并重启应用；Account 仍显示上述身份与许可，证明 Authenticated Session 可恢复。
4. 本验证只读取 `/session/current.json`，没有论坛、Profile 或资产写入。

## 结论

Ticket 01 的普通账号主路径通过。原截图中的“网页登录后仍未登录”是因为尚未完成 User API Key 授权，应用沙箱中没有会话记录；入口现已明确显示“登录并授权 RiverSide”，避免把网页登录误认为应用授权完成。
