# RiverSide HarmonyOS

RiverSide 社区的 HarmonyOS 原生客户端，面向 API 23 手机设备构建。应用通过 Discourse User API Key 完成授权，并使用 RiverSide 站点的公开及已授权接口读取和参与社区内容。

## 功能概览

- 浏览首页、分类、Topic 和 Post，支持分页、刷新与搜索
- 使用 Discourse User API Key 登录，安全保存和恢复认证会话
- 阅读与回复 Topic，创建和编辑内容，管理草稿与媒体
- 查看和编辑个人资料，浏览个人 Topic、Reply、草稿等内容
- 支持聊天室、通知中心、富内容与站内链接导航
- 提供持久化的 UI 原型实验区；实验内容不会自动进入正式页面

部分入口会以“未实现”展示，表示对应能力仍在规划中。

## 技术与架构

- **语言与 UI**：ArkTS、ArkUI，目标 SDK 为 HarmonyOS API 23
- **网络边界**：`DiscourseHttpClient` 统一处理基础地址、超时、认证请求头与 401；各类 Discourse 接口由 `repositories/` 封装
- **认证边界**：`AuthRepository` 使用 ArkWeb 完成授权，临时 RSA 密钥只保留在内存中，认证会话由 HUKS 加密持久化
- **应用状态**：`AppShell` 管理导航与当前认证会话；页面模型负责页面级加载、分页及错误状态
- **安全富内容**：富文本、图片与链接在专用模型和展示组件中处理，避免页面直接解析或发起网络请求

主要源码位于 [`app/entry/src/main/ets`](app/entry/src/main/ets)：

| 目录 | 职责 |
| --- | --- |
| `app/` | 应用壳、路由、跨页面协调与状态模型 |
| `auth/` | 授权、会话存储与认证生命周期 |
| `network/` | HTTP 客户端与媒体传输 |
| `repositories/` | Discourse API 合约与响应解码 |
| `models/` | 领域模型及内容解析 |
| `components/` | ArkUI 页面与展示组件 |
| `ohosTest/` | 设备端单元与集成测试 |

更详细的术语和架构约束见 [CONTEXT.md](CONTEXT.md) 与 [`docs/adr/`](docs/adr)。

## 环境要求

- DevEco Studio，已安装 HarmonyOS API 23 SDK
- `devecocli`（用于构建、部署、设备与日志操作）
- Node.js/ohpm 依赖由 DevEco Studio 或首次构建准备
- 可选：一台 API 23 的 HarmonyOS 手机，用于完整回归

## 快速开始

在仓库根目录执行：

```bash
cd app
devecocli build
```

构建成功后，如已连接设备，可查看设备并部署：

```bash
devecocli device list
devecocli run --module entry --device <设备序列号>
```

首次运行前需要在 DevEco Studio 配置本地签名。签名配置包含机器相关的敏感信息，不能提交到 Git；具体步骤见 [本地签名说明](docs/development/local-signing.md)。

## 验证

执行全量静态代码健康检查：

```bash
scripts/check-code-health.sh --all
```

在已连接的 API 23 手机上执行设备测试、安装和启动后崩溃检查：

```bash
scripts/verify-mvp-api23.sh <设备序列号> <设备类型>
```

`<设备类型>` 必须与 `devecocli device list` 输出中目标设备的 Kind 列完全一致；目标必须是 phone 设备。各功能的人工验收步骤在 [`docs/verification/`](docs/verification) 中维护。

## 开发约定

- 保持 ArkTS 严格类型检查：不要引入 `any`，显式处理可空值、失败分支与接口边界。
- 页面不得直接访问网络；通过 Repository 和页面状态模型进行交互。
- 认证状态和 401 失效由共享认证生命周期统一处理。
- 每个提交只处理一个可独立验证的小点；提交前运行与风险相符的验证。
- 不要提交本地签名材料、构建产物或设备日志。

项目中的需求、规格和实施票据保存在 [`.scratch/`](.scratch/)；提交前的敏感配置保护脚本在 [`scripts/check-staged-sensitive-config.sh`](scripts/check-staged-sensitive-config.sh)。
