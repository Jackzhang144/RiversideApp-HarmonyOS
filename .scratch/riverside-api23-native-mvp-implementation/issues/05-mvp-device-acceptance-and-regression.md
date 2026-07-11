# 05 — MVP 真机验收与回归

**What to build:** 维护者获得一套可重复执行的 MVP 回归与 API 23 真机验收结果，证明浏览、认证和 Reply 在各自正确的运行环境中可靠工作。

**Blocked by:** 04 — 安全 Reply 闭环.

**Status:** claimed

- [x] 模拟器回归覆盖浏览、Category 缓存、Topic/Post 读取、加载、空态、失败和重试。
- [ ] API 23 真机验收 HDS 视觉、ArkWeb 授权、HUKS 会话生命周期、401 登出及 Reply 成功与异常恢复。
- [x] 已使用专用测试账户完成必要的可写入验证，且没有将密码、User API Key、私钥、会话密文或签名材料写入仓库或日志。
- [x] 失败诊断使用脱敏后的应用日志，结果清楚区分模拟器回归和真机验收证据。

## Comments

- `scripts/verify-mvp-api23.sh <serial> <kind>` 会校验 Kind、Phone 与 API 23，构建/安装测试 HAP，拒绝零测试、缺少必需 suite、失败/忽略及崩溃输出，再构建并启动主 HAP。
- 2026-07-11 在 `Riverside API 23` 模拟器重复执行通过：59/59，11 个必需 suite，0 Failure / 0 Error / 0 Ignore，无脱敏后崩溃输出。
- 模拟器真实服务联机已完成 User API Key 授权、HUKS 重启恢复，并在“测试专用”Category 的 `111` Topic 创建和回读唯一 Reply；未将账户或会话秘密写入仓库。
- `scripts/collect-sanitized-app-log.sh` 与 `scripts/redact-sensitive-output.sh` 统一采集并遮盖认证头、授权参数、password、会话字段和私钥块；结构化 JSON 与带引号格式已有合成反例验证。
- 完整步骤、证据矩阵和真机异常场景见 `docs/verification/api23-physical-device-readiness.md`。
- 当前 `devecocli device list` 仍只有 API 23 模拟器；HDS 沉浸视觉、真实硬件 ArkWeb/HUKS、401、422/429 和受控超时恢复继续阻塞，Ticket 保持 `claimed`。
