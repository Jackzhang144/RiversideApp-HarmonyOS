# RiverSide API 23 原生 HarmonyOS 手机 MVP

Status: ready-for-agent

## Problem Statement

RiverSide 现有客户端以 Flutter 实现，无法直接成为 API 23 的原生 HarmonyOS 手机体验。用户需要一个面向中国大陆发行的原生客户端，保留论坛浏览、登录与回复的核心价值，同时采用 ArkTS、ArkUI 和华为 UI Design Kit（HDS），并能在真实 API 23 手机上验证 HDS 视觉、认证与回复安全性。

## Solution

交付一个 API 23 原生 HarmonyOS 手机 MVP。应用提供“首页 / Category”两个根入口，支持浏览 Topic 与 Post、通过 Discourse User API Key 登录，并发布纯文本或 Discourse Markdown 源文本 Reply。应用复用现有 RiverSide / Discourse 服务端契约，不要求服务端改动。

UI 以 HDS 为首选、ArkUI 为回退；应用使用单一 AppShell 管理导航和 Authenticated Session。实现按浏览基础、Topic 阅读、认证、Reply 四个纵向切片推进，并按能力类型在模拟器或 API 23 真机上验收。

## User Stories

1. 作为未登录的论坛访客，我想打开首页查看最新 Topic，以便快速了解社区内容。
2. 作为未登录的论坛访客，我想在首页和 Category 两个根入口之间切换，以便按不同方式发现 Topic。
3. 作为访客，我想看到清晰的加载状态，以便知道内容正在请求而不是应用无响应。
4. 作为访客，我想在服务器成功但没有内容时看到空态，以便区分空结果和故障。
5. 作为访客，我想在首页或 Category 请求失败时看到页面内错误与重试操作，以便自行恢复浏览。
6. 作为访客，我想在加载下一页失败时继续保留当前列表内容，以便不丢失正在阅读的位置。
7. 作为访客，我想在 Category 中看到合理的层级和排序，以便找到感兴趣的 Topic。
8. 作为访客，我想从首页或 Category 打开 Topic 详情，以便阅读完整讨论。
9. 作为访客，我想在 Topic 中逐段加载更多 Post，以便阅读长讨论且不等待全部内容下载。
10. 作为访客，我想看到 Topic 已关闭或归档时不可回复的状态，以便理解操作限制。
11. 作为访客，我想在网络暂时不可用时继续查看已缓存的 Category，并能手动刷新，以便不被短暂网络故障阻断。
12. 作为用户，我想在需要回复时发起 RiverSide 授权，以便安全获得可写入论坛的 Authenticated Session。
13. 作为用户，我想在应用内完成授权并回到应用流程，以便不依赖未验证的外部浏览器回跳能力。
14. 作为用户，我想在重启应用后恢复有效会话，以便不必每次重新登录。
15. 作为用户，我想主动退出登录，以便清除本机保存的认证状态。
16. 作为用户，我想在认证失效时被明确引导重新登录，以便恢复需要权限的操作。
17. 作为用户，我想在会话失效后立即重新登录时保留当前 Reply 输入，以便不丢失正在编辑的内容。
18. 作为已登录用户，我想对 Topic 或指定 Post 发布纯文本或 Discourse Markdown 源文本 Reply，以便参与讨论。
19. 作为已登录用户，我想在 Reply 发送成功后立即看到明确反馈，以便确认操作完成。
20. 作为已登录用户，我想在 Reply 被拒绝、限流或网络失败时保留输入并看到可理解的反馈，以便修正或重试。
21. 作为已登录用户，我想在 Reply 超时后让应用先确认提交结果，以便避免重复发布。
22. 作为使用 HarmonyOS 手机的用户，我想看到符合系统习惯的导航、页签、列表与即时反馈，以便获得原生体验而不是 Flutter 像素复刻。
23. 作为无障碍用户，我想让可交互的 Topic 行和操作拥有可读标签，以便能使用系统辅助能力完成浏览和回复。
24. 作为维护者，我想让服务器返回 401 时只在一个地方处理会话失效，以便不会把普通网络或服务器错误错误地转成登出。
25. 作为维护者，我想在真实 API 23 手机上验证 HDS、ArkWeb、密码学与 Reply，以便在发布前确认模拟器无法代表的系统能力。

## Implementation Decisions

- 基础框架是 ArkTS + ArkUI，目标为 API 23 的 Stage 模型手机应用。
- UI 首选 HDS 扩展组件和视觉能力；没有合适组件或未证明 API 23 可用时，使用 ArkUI 基础组件回退。
- HDS 仅用于中国大陆发行范围。HDS 沉浸视效不以模拟器截图为验收依据，必须在 API 23 真机验证。
- 根信息架构仅包含 Home 与 Category 两个同级页签。优先使用 HdsTabs；无法满足 API 23 条件时回退到 ArkUI Tabs。
- Topic 详情、登录和 Reply 是二级页面，由 HdsNavigation 优先、ArkUI Navigation 回退的导航栈承载。
- HdsNavigation 与 HdsSnackBar 是 MVP 的优先 HDS 候选。HdsListItem 必须先证明 Topic 行点击与无障碍可用后才可采用；HdsActionBar 不是 Reply 主路径的前置组件。
- 单一 AppShell 持有导航栈、根页签选择和 Authenticated Session。页面不直接访问 HUKS、ArkWeb 或 HTTP。
- ForumRepository 是唯一的论坛契约边界，负责 Category、Topic、Post 与 Reply 的请求/响应转换。
- AuthRepository 独立负责 ArkWeb 授权、临时 RSA 材料、nonce 校验、HUKS 会话持久化、会话恢复、会话校验和登出。
- DiscourseHttpClient 统一拥有基址、超时、User-Agent、Authenticated Session 请求头注入与 401 结果；AppShell 是唯一触发全局登出的消费者。
- 复用现有服务端契约：列表使用最新 Topic 与 Category Topic 路径；Category 目录来自站点与 Category 数据；Topic 使用详情与 Post 窗口路径；登录使用 User API Key；Reply 使用现有 Post 创建路径。不会新增或修改服务端接口。
- User API Key 登录在内嵌 ArkWeb 中完成。授权回调必须严格匹配约定的回调 URI、解密后校验 nonce、拒绝缺失 key 或 nonce 不匹配的结果。外部浏览器自定义 scheme 回跳不是 MVP 依赖。
- 初次认证兼容现有 RSA-2048、PKCS#1、scope、client ID 与 nonce 约定。临时私钥只存在于当前授权流程内；最终 Authenticated Session 使用 HUKS 加密后保存为应用私有密文。
- 只有 HTTP 401 清除 Authenticated Session。其他 HTTP、解析或网络错误保持为页面级错误。
- 仅 Category 目录使用按匿名/Authenticated Session 身份分区的本地缓存，并采用命中后后台刷新。Topic 列表、Post 窗口和 Reply 草稿不持久化。
- 无可用内容时，首屏使用完整加载态、成功空态或可重试错误态。分页保留已显示内容，在底部显示加载或失败，并按 Topic/Post 标识去重。
- Category 缓存刷新失败时保留旧内容，使用 HdsSnackBar 进行非阻塞反馈，并提供手动刷新入口。
- Reply 发送前去除首尾空白，空输入不提交。超时或中断后先确认预期 Post 是否已创建；无法确认时保留输入并要求用户手动重试，绝不自动重发。
- 实现顺序固定为四个纵向切片：浏览基础、Topic 阅读、认证、Reply；不提前建设已排除的功能。

## Testing Decisions

- 自动化测试以 AppShell 的依赖组合为唯一最高层接缝：替换网络与系统能力依赖，验证用户可见状态和流程，不断言页面内部实现细节。
- 浏览基础测试覆盖：Home/Category 根入口、加载、空态、首屏错误、重试、Category 缓存后台刷新与缓存刷新失败。
- Topic 阅读测试覆盖：二级导航、详情首屏、Post 分段加载、ID 去重、分页失败重试、关闭或归档 Topic 的回复限制。
- 认证流程测试通过替换的认证运行时覆盖：授权启动、回调 URI 校验、nonce 不匹配、解密失败、会话恢复、登出和 401 全局失效。密码学库本身不以实现细节作为单元测试对象。
- Reply 测试覆盖：空输入阻止、成功、验证或限流失败、取消、网络中断、超时确认、未确认时的人工重试，以及不自动重复提交。
- 模拟器用于工程编译、结构、基础交互、浏览和 Topic 读取回归。模拟器不作为 HDS 沉浸视效、ArkWeb 授权、HUKS 持久化或真实 Reply 的通过证据。
- API 23 真机必须验收：HDS 视觉、ArkWeb 回调截获、RSA PKCS#1 互操作、nonce 校验、HUKS 会话恢复与清理、401 登出、Reply 成功与异常恢复。
- 真机失败诊断应使用过滤后的应用日志；不得记录或提交测试账户密码、User API Key、私钥、会话密文或签名材料。

## Out of Scope

- RiverSide / Discourse 服务端改动、接口新增或认证协议改造。
- 中国大陆以外的发行适配。
- Flutter 客户端的像素级复刻。
- 搜索、通知、私信、聊天、个人中心、发起新 Topic、图片或附件上传、@提及、表情面板、富文本工具栏、反应、投票、书签、钱包、推送和后台任务。
- Reply 草稿的跨进程持久化。
- 将外部浏览器回跳作为认证主流程。

## Further Notes

- 当前开发机没有连接 API 23 真机，但本地存在可用于基础回归的 API 23 手机模拟器和映像。
- 真机验收前需要准备：中国大陆 API 23 手机、开发者模式与 USB 调试、调试签名、可访问 RiverSide 的网络，以及可发布一次性 Reply 的专用测试账户。
- 真机未就绪不降低验收标准；实现 ticket 必须保留真机门槛和人工前置条件。
- 规格中的术语以项目领域词汇为准：Topic 是讨论串，Post 是串内消息，Reply 是首帖之后的 Post；Authenticated Session 与 Authorization Request 具有不同生命周期。
