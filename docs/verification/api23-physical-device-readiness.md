# API 23 MVP 验收与回归手册

日期：2026-07-11

本手册把“模拟器自动回归”“模拟器真实服务联机验证”和“API 23 物理真机验收”分开记录。模拟器结果不能替代 HDS 视觉、真实硬件 ArkWeb/HUKS 行为或最终真机结论。

## 当前结论

| 范围 | 环境 | 结果 |
| --- | --- | --- |
| ArkTS 编译、设备测试、主 HAP 安装启动 | `Riverside API 23` 手机模拟器，HarmonyOS 6.1.0(23) | 通过：59/59，0 Failure / 0 Error / 0 Ignore；无应用崩溃。 |
| Home、Category、Topic/Post、缓存、加载/空态/失败/重试 | API 23 模拟器自动测试 | 通过。 |
| User API Key 授权、回调解密、HUKS 会话重启恢复 | API 23 模拟器 + 真实 RiverSide 服务 | 通过。测试账户凭据与会话材料未写入仓库。 |
| Reply 成功和服务端回读 | API 23 模拟器 + 真实 RiverSide 服务 | 通过。在“测试专用”Category 的 `111` Topic 创建 `#4`，重新进入后正文仅出现一次。 |
| HDS 沉浸视觉、真实硬件 ArkWeb/HUKS、401、422/429、超时恢复 | API 23 物理真机 | 未验收：当前没有物理真机连接。 |

已观察到一个非阻塞回显问题：成功 Reply 后返回 Category Topic 列表时，列表中的 Reply 数仍是进入 Topic 前的旧值；重新进入 Topic 后服务端详情与 Post 数正确。当前 MVP 没有主动刷新上一级 Topic 摘要。

## 自动回归

从仓库根目录执行：

```bash
scripts/verify-mvp-api23.sh <device-serial> <device-kind>
```

`device-kind` 必须与 `devecocli device list` 的 Kind 列一致；当前模拟器使用 `emulator`，物理真机使用其实际显示值。脚本会拒绝 Kind 不匹配、非 Phone 或非 API 23 的目标。

脚本会依次：

1. 使用 `devecocli device view` 记录目标环境。
2. 构建并安装 `entry@ohosTest`。
3. 执行 ArkTS Instrument Test，并严格要求 `OHOS_REPORT_CODE: 0`、0 Failure、0 Error、0 Ignore。
4. 构建、安装和启动主 HAP；不使用 `--uninstall`，不会主动清除已保存会话。
5. 读取最近两分钟的崩溃日志，并在输出前执行敏感信息遮盖。

自动测试覆盖矩阵：

| 能力 | 自动证据 |
| --- | --- |
| Home / Category | 根页签、加载、内容、空态、失败、重试、刷新失败保留内容。 |
| Category 缓存 | 匿名/认证分区、缓存读取、后台刷新、写入失败隔离、身份切换清理呈现。 |
| Topic / Post | Category Topic 跳转、首屏、归档空态、Post 分段读取、分页失败保留内容、重试和过期响应隔离。 |
| 认证 | User API Key 请求、主框架回调、RSA PKCS#1/nonce 边界、HUKS 保存/恢复/登出、并发与迟到 401 合并。 |
| Reply | 空白拒绝、Topic/指定 Post 请求体、成功体两种字段、明确拒绝、408/5xx/网络不确定结果、GET 确认、精确作者/正文/目标匹配、显式重试和内存草稿。 |
| JSON 边界 | 非对象拒绝、重复 Topic/Post 去重、Topic 详情与 `highest_post_number`、可读 Post 正文。 |

## 脱敏诊断

只采集本应用最近一段时间的日志：

```bash
scripts/collect-sanitized-app-log.sh <device-serial> 5m
```

采集结果在输出前遮盖：

- `User-Api-Key`、`User-Api-Client-Id`
- 授权 URL 中的 `payload`、`nonce`、`client_id`、`public_key`
- JSON `key`、`ciphertext`、`encryptedSession`
- password 字段和 PEM 私钥块

禁止把账户密码、User API Key、临时私钥、会话密文或签名配置复制到验收文档、Issue、截图文件名、提交信息或应用日志中。失败报告只保留时间、环境、操作步骤、脱敏错误、期望和实际结果。

## API 23 物理真机准备

1. 使用中国大陆地区的 HarmonyOS 6.1.0(23) 手机，开启开发者模式和 USB 调试并接受信任提示。
2. 通过 `devecocli device list` 和 `devecocli device view -t <serial>` 确认设备类型、API 级别与系统构建。
3. 使用本地调试签名部署；不得提交签名路径、口令或证书材料，也不要求每次移除签名配置。
4. 确认设备可访问 `https://river-side.cc`，并使用专用测试账户；凭据只在登录 UI 输入。
5. 先执行自动回归脚本，再开始人工场景。

## 物理真机人工验收

### HDS 与 ArkUI

- 验证 `HdsNavigation` / `HdsNavDestination` 标题、返回栈和安全区。
- 验证 `HdsTabs` 切换、选中态、触控反馈和底部安全区。
- 验证 `HdsSnackBar` 成功/失败样式、关闭按钮与可读性。
- 只在真机判断点光、按压阴影、边缘/背景流光和沉浸材质；模拟器截图不得作为视觉结论。
- 验证 ArkUI `List`、`TextArea`、`Button` 的滚动、键盘遮挡、长文本和无障碍标签。

### ArkWeb 授权与 HUKS

1. 退出测试账户后重新登录，确认授权页面显示 `read,write,session_info`。
2. 同意授权，确认 ArkWeb 拦截 `riverside://auth_redirect`，页面不继续导航到未知 scheme。
3. 确认 RSA PKCS#1 payload 解密、nonce 完整相等校验和 Authenticated Session 保存成功。
4. 强制结束并重启应用，确认 HUKS 加密会话恢复。
5. 登出后确认 UI 回到未认证态，重启后不恢复旧会话。
6. 401 使用可撤销的专用 User API Key 验证：先让应用保存该会话，再由维护者在账户安全页面撤销该 key，随后发起受保护请求；确认只触发一次全局登出。不要撤销非测试 key。

### Reply

所有可写验证只能在“测试专用”Category 中执行，正文带唯一时间标记，发布前记录目标 Topic 与预期下一个 Post Number。

1. 创建一次 Topic Reply，回读作者、正文、Post Number，并确认唯一标记只出现一次。
2. 创建一次指定 Post Reply，确认 `reply_to_post_number` 指向所选 Post。
3. 空白输入与收起编辑器不产生请求；草稿仅在当前进程内保留。
4. 422 使用维护者确认过的无害校验失败输入；429 只能使用管理员提供的限流测试条件，禁止靠高频发布制造限流。
5. 超时/响应丢失必须通过受控网络代理在“服务端已接收、客户端未收到响应”时制造；确认应用先 GET 预期 Post，未确认时只展示“显式重试”，不得自动再次 POST。
6. 每个异常场景结束后重新进入 Topic，按唯一标记统计服务端 Post，证明没有重复 Reply。

## 证据记录模板

| 字段 | 内容 |
| --- | --- |
| 环境 | 设备型号、HarmonyOS 构建、API 23；序列号只保留末四位。 |
| 构建 | Git commit、构建模式、调试签名类型；不记录签名材料。 |
| 场景 | HDS / 授权 / HUKS / 401 / Reply success / 422 / 429 / timeout。 |
| 步骤 | 可重复操作，不含密码、key、payload、私钥或密文。 |
| 期望与实际 | 状态变化、可见反馈、Post Number 和唯一标记计数。 |
| 日志 | 脱敏命令输出；无失败时记录“无应用崩溃”。 |
| 结论 | `pass` / `fail` / `blocked`，模拟器与真机分开填写。 |

## 当前阻塞

- `devecocli device list` 只有 `Riverside API 23` 模拟器，没有 API 23 物理真机。
- 因此 HDS 沉浸视觉、真实硬件 ArkWeb/HUKS、真实 401/422/429 和受控超时恢复仍为 `blocked`，不得标记为通过。

## 参考

- [HDS API 23 组件适配结论](../research/hds-api23-component-fit.md)
- [User API Key 认证调研](../research/user-api-key-auth-api23.md)
- [MVP API 契约](../research/mvp-api-contract.md)
