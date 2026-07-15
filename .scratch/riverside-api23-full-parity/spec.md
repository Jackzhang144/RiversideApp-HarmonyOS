# RiverSide API 23 Phone 完整功能对等规格

Status: ready-for-agent

## Problem Statement

RiverSide 已有 Flutter 客户端覆盖完整的 Discourse 社区使用路径，但当前 HarmonyOS API 23 Phone 客户端仅交付论坛 MVP：最新回复、Category、Topic/Post 阅读、User API Key 登录和基础回复。用户需要一个原生 ArkTS 客户端，在不修改 RiverSide/Discourse 服务端、数据库或权限规则的前提下，复现冻结 Flutter `9d8b13c` 对普通用户与管理员可见的功能和服务语义。

完成不等于像素复制 Flutter。应用应遵循 HarmonyOS Phone 的原生交互，保留现有 AppShell、Authenticated Session 和 Repository 边界，并以可验证的垂直用户闭环逐步替代未实现的入口和占位能力。

## Solution

将产品按用户可完成的纵向闭环实现：论坛浏览和搜索、富内容与媒体、Profile/草稿/社交、Chat、消息与前台刷新、管理员操作、RSC、世界杯和专项链接。每个闭环通过相同 RiverSide/Discourse 契约读写数据，并在不破坏当前 MVP 的前提下获得独立的自动化、构建和真实服务验收。

媒体选择使用最小权限的系统选择器；富内容在隔离 ArkWeb 和原生渲染之间按信任边界处理；HUKS 持久化 Authenticated Session；通知本阶段只完成应用内中心和前台刷新。HarmonyOS 远程 Push 等待服务端接入华为 Push 的 token/发送契约后另行交付，不可由客户端轮询替代。

## User Stories

1. 作为访客，我希望以 User API Key 完成授权并安全恢复 Authenticated Session，以便使用受限社区功能。
2. 作为已登录用户，我希望在会话失效时只收到一次明确登录提示，以便重新授权而不被重复登出。
3. 作为用户，我希望在首页浏览最新回复、最新创建、未读、热门和精选内容，以便按我的阅读目的发现 Topic。
4. 作为用户，我希望首页遵从服务端首页偏好，并能显示/关闭冻结参考已有的世界杯入口，以便获得一致的内容入口。
5. 作为用户，我希望浏览 Category 树及其 Topic 列表，以便定位社区讨论。
6. 作为用户，我希望搜索 Topic、Post、用户、Category、标签和群组，并获得分页和空态反馈，以便找到内容或联系人。
7. 作为用户，我希望打开 Topic 后阅读全部 Post、系统动作、分页加载结果和推荐 Topic，以便完整理解讨论。
8. 作为用户，我希望查看正确的 Category 名称、作者、时间、反应、书签和可用动作，以便判断内容上下文。
9. 作为用户，我希望对 Topic 或指定 Post 回复并自动带入准确引用，以便参与讨论。
10. 作为用户，我希望新建 Topic、编辑自己的 Topic/Post、管理草稿并在失败后保留输入，以便可靠创作。
11. 作为用户，我希望使用 Markdown 编辑器工具、Emoji、链接、列表、代码块、图片和投票模板，以便编写结构化内容。
12. 作为用户，我希望看到 Markdown/HTML、引用、代码、公式、剧透、表格、列表、图片和 onebox 的安全原生等效呈现，以便阅读复杂 Post。
13. 作为用户，我希望在受信任的隔离 ArkWeb 中播放支持的 Bilibili/YouTube 嵌入，并在外链、HTTP、SSL 异常或不受信任跳转时获得安全处理，以便不牺牲设备安全地查看媒体。
14. 作为用户，我希望从系统相册选择图片并上传到编辑器、Chat、头像或个人页背景，以便分享和个性化内容。
15. 作为用户，我希望保存查看器中的图片到图库、复制图片链接或在浏览器打开，以便复用公开图片。
16. 作为用户，我希望查看自己的 Profile、认证状态、徽章/群组、关注状态、书签、Topic、Reply 和草稿，以便管理社区身份与内容。
17. 作为用户，我希望关注、取消关注、静音或忽略其他用户，并看到服务端返回的许可状态，以便管理社交关系。
18. 作为用户，我希望更新资料、头像和个人页背景，并在保存失败时不丢失原值，以便可靠维护个人资料。
19. 作为用户，我希望阅读并发送 Category Chat 和私聊，包含回复、提及、图片、Emoji、Reaction、删除和未读状态，以便即时交流。
20. 作为用户，我希望在消息中心查看通知、私信、收到的 Reaction 和活动，并在阅读对应 Topic 后按服务端语义清除相关未读，以便跟进互动。
21. 作为用户，我希望应用在前台刷新 Chat 与消息状态，而不是伪装成后台 Push，以便状态一致且行为可预期。
22. 作为管理员或具备服务端许可的版主，我希望执行服务端允许的 Topic/Post 移动、关闭、归档、隐藏、删除、置顶、拆分和合并等操作，以便管理讨论。
23. 作为用户，我希望使用 RSC 查看钱包、余额、账本、每日奖励和帖子打赏等只读或低风险信息，以便了解社区资产状态。
24. 作为用户，我希望在明确确认后再执行 RSC 转账、打赏、红包创建或关闭等状态/资产操作，以便避免误操作。
25. 作为用户，我希望查看冻结参考已有的世界杯赛程、焦点赛、积分与淘汰赛信息，以便获取赛事内容。
26. 作为用户，我希望 RiverSide 站内 Topic/Profile 链接进入原生页面，功能子域和外部链接走明确的安全导航策略，以便在正确上下文阅读内容。
27. 作为普通测试账号，我希望所有论坛写入仅发生在 Category `111`，以便不影响真实社区内容。
28. 作为管理员测试账号，我希望仅对 Category `111` 中本次创建的测试内容执行破坏性管理操作，以便验证权限而不伤及既有内容。
29. 作为发布负责人，我希望每个功能有构建、自动化、真实服务和必要物理设备的证据，以便判断对等实现是否真的完成。

## Implementation Decisions

- AppShell 继续唯一拥有导航和 Authenticated Session；页面只渲染状态并请求 AppShell 行为，不能建立第二套全局状态。
- AuthRepository 继续唯一拥有 User API Key、临时 RSA 材料、HUKS 存储、会话恢复和登出；功能 Repository 不持有或持久化凭证。
- 功能 Repository 继续唯一拥有对应 RiverSide/Discourse/RSC 服务契约；集中 Transport 继续注入请求头、超时与唯一的 HTTP 401 语义。非 401 错误是页面级可恢复错误。
- 所有新增 ArkTS 代码保持严格类型，不引入 `any`；请求、解析、可空数据、权限、异步过期结果和失败状态显式建模。
- 富内容不向不受信任 Post HTML 暴露原生桥接。Bilibili 的已验证边界是：精确 JSON URL 白名单允许 `river-side.cc`、`player.bilibili.com` 和 `www.bilibili.com/blackboard/webplayer`；不使用通配符或 JavaScriptProxy，禁用混合内容，SSL 异常取消加载。其他导航由明确策略决定。
- 图片从 PhotoPicker 的只读 URI 立即复制到应用缓存，再以 Discourse multipart 上传；不得将选择器 URI 当作永久文件路径。保存图库使用 SaveButton 或官方保存授权弹窗，不申请广泛相册权限。
- 当前媒体对等只包含选择、上传、保存、复制链接和浏览器打开。冻结 Flutter 不含媒体系统分享或业务级断点续传；Share Kit 和系统传输任务不自动扩大本阶段范围。
- Chat、通知、Profile、管理员和 RSC 的可用动作以服务端返回许可为准，客户端不得猜测权限或绕过服务端约束。
- RSC 读操作可常规验证；转账、打赏、红包创建/关闭等状态或资产操作必须逐次获得用户确认。RSC 401 只允许一次 exchange 刷新后重试。
- 远程 Push、服务端 token 注册和发送契约延期；禁止以后台轮询替代。应用内消息中心与前台刷新属于本规格。
- UI 优先采用 API 23 已确认的 HDS/ArkUI 原生组件；HDS 沉浸效果和设备特性以物理 Phone 验收为准。

## Testing Decisions

- 测试面向外部行为：用户动作、服务契约、权限结果、可见状态和错误恢复，而不是私有实现细节。
- 每个小提交运行与风险匹配的 ArkTS 测试与 `devecocli build`；功能切片完成时用普通账号对真实服务进行模拟器冒烟。
- ArkWeb、PhotoPicker、图库保存、系统分享、HDS 沉浸视觉及跨应用行为必须在物理 Phone 通过后才算完成；模拟器只覆盖结构和基本交互回归。
- 每个切片留下最小验证记录：账号角色、设备、主路径、代表失败路径、自动化和构建结果。
- 论坛写入只使用 Category `111`，测试数据保留；Profile、头像和个人页背景可修改两个测试账号并使用可丢弃媒体；邮箱变更在提供专用测试邮箱前只读。
- 管理员破坏性操作仅针对本次在 Category `111` 创建的内容，禁止访问既有内容、其他 Category 或站点级设置。
- RSC 资产/状态写入每次单独请求用户确认；不能用测试通过推断真实资产操作安全。
- 既有 MVP 的 Authenticated Session、Category 缓存、Topic 分段加载、Reply 恢复和 401 生命周期测试是新增功能的回归基线。

## Out of Scope

- HarmonyOS 远程 Push、服务端华为 Push token/发送契约和客户端后台轮询替代。
- RiverSide/Discourse 服务端、数据库、Schema、权限规则或 RSC 服务契约的修改。
- Flutter 像素级 UI 复制、非 Phone 设备布局、Flutter 平台包。
- 冻结 Flutter 未实现的媒体系统分享与业务级断点续传。
- 在没有专用测试邮箱时执行邮箱增删、重发或确认操作。
- 任何未逐次确认的 RSC 状态或资产写入。

## Further Notes

- 冻结基线是 `/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp` 的 `9d8b13c`。测试与实际 Flutter 源码优先级高于过期 capture 注释。
- 认证校友状态由五个校友组名或相应 primary/flair ID 决定；开发者组不等同认证。Chat Reaction 是完整解析、展示、发送和刷新闭环。
- 物理 Phone 是设备能力最终验收门槛。用户会交互登录普通与管理员账号；凭证不得写入仓库、日志或对话。
