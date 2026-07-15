# Flutter `9d8b13c` 手机端完整功能对等清单

## 审计结论与边界

本清单是把 Flutter 仓库冻结提交 `9d8b13cfabcb04538c33be87022f64612fb06b56` 当作**手机端用户可见行为与客户端契约的唯一参考快照**所做的只读盘点。它不要求 HarmonyOS 像素级复刻 Flutter；要求是同一服务端权限和语义下的原生等价能力。未在该提交客户端实现的服务端能力不自动纳入。

来源按优先级为冻结源码、冻结测试、同提交的真实抓包 fixture；抓包的 README 明确说明 fixture 用于让客户端适配真实响应，而非猜测。[captures/README.md](../../../RiversideApp/captures/README.md#L1-L23)

### 角色与全局规则

| 角色 | 可见/可用范围 | 对等约束 |
| --- | --- | --- |
| 匿名 | 首页五频道、类别、Topic/用户资料阅读、搜索、世界杯、站内/外部链接；所有写操作、聊天、消息、我的内容均给出登录门槛或空态。 | 不伪造受限内容；匿名 Category 缓存独立保存。 [api.dart](../../../RiversideApp/lib/api.dart#L200-L228) [notifications_page.dart](../../../RiversideApp/lib/pages/notifications_page.dart#L61-L90) |
| 已登录普通用户 | User API Key 会话、发 Topic/Reply、编辑自身允许编辑的帖子、草稿、书签、反应/投票、私信与聊天、关注、个人资料和邮箱、RSC。 | 一切以服务端返回的 `can_*`、Topic 状态和 HTTP 结果为准。 [models.dart](../../../RiversideApp/lib/models.dart#L277-L346) [topic_permissions_test.dart](../../../RiversideApp/test/topic_permissions_test.dart#L5-L56) |
| 管理员/版主 | UI 读取 `admin`/`moderator` 与 Post/Topic 的权限字段，呈现服务器允许的删除、编辑、举报、解答采纳等动作；抓包另含管理动作样本。 | 不在客户端提升权限；本票未发现独立的“管理员后台”页面。 [models.dart](../../../RiversideApp/lib/models.dart#L277-L334) [2026-05-21-topic-management-actions.request.txt](../../../RiversideApp/captures/topics/2026-05-21-topic-management-actions.request.txt#L1-L17) |

所有 Discourse 请求以 User API Key 会话自动添加 `User-Api-Key` 与 `User-Api-Client-Id`；只有 HTTP 401 会清会话并触发重新登录，其它网络/服务端失败必须按页面局部错误处理，不能笼统登出。[api.dart](../../../RiversideApp/lib/api.dart#L173-L212) [api.dart](../../../RiversideApp/lib/api.dart#L1554-L1580)

## 功能对等矩阵

| 领域 | 必须提供的用户可见能力 | 主要接口/状态 | 参考证据 |
| --- | --- | --- | --- |
| 应用 Shell 与设置 | 五个底栏：`首页/类别/聊天/消息/我的`；中英文 locale、浅深色、字体缩放、可持久默认首页频道；启动恢复安全会话、刷新当前用户，移动端检查更新。 | 会话恢复、`GET /session/current.json`、Android 方法通道更新。 | [main.dart](../../../RiversideApp/lib/main.dart#L157-L185) [main.dart](../../../RiversideApp/lib/main.dart#L549-L619) [settings.dart](../../../RiversideApp/lib/settings.dart#L1-L131) [widget_test.dart](../../../RiversideApp/test/widget_test.dart#L15-L30) |
| 登录、退出与在线状态 | RSA User API Key WebView 授权、回调 payload 解密/nonce 校验、安全保存，退出时清 Discourse 与 RSC token；前台登录态每 28 秒上报在线。 | `GET /user-api-key/new`；`GET /session/current.json`；`POST /presence/update.json`。 | [auth.dart](../../../RiversideApp/lib/auth.dart#L20-L73) [auth.dart](../../../RiversideApp/lib/auth.dart#L168-L213) [main.dart](../../../RiversideApp/lib/main.dart#L257-L282) |
| 首页、Category 与在线用户 | 五个频道：最新回复、最新发表、未读、热门、精华；下拉刷新、无限滚动、空/加载/错误态；搜索入口；在线用户；Category 分层网格/列表；主页发帖入口。 | `GET /latest.json`（可 `order=created`）、`/new.json`、`/hot.json`、`/tag/2-tag/2.json`、`/c/{id}.json`、`/site.json`、`/categories.json`。目录缓存按匿名/用户分区并后台刷新，隐藏 category id 1、4。 | [models.dart](../../../RiversideApp/lib/models.dart#L105-L123) [home_page.dart](../../../RiversideApp/lib/pages/home_page.dart#L131-L207) [home_page.dart](../../../RiversideApp/lib/pages/home_page.dart#L462-L505) [api.dart](../../../RiversideApp/lib/api.dart#L214-L228) [api.dart](../../../RiversideApp/lib/api.dart#L1302-L1389) |
| 搜索 | 首页输入关键字，显示 Topic/Post/User 等论坛搜索并分页、typeahead 建议；聊天独立搜索并分页；用户 @ 提及搜索。 | `GET /search.json?q=&page=`、`/search/query?term=&typeahead=true`、`/chat/api/search`、`/u/search/users.json`。 | [api.dart](../../../RiversideApp/lib/api.dart#L1118-L1161) [api.dart](../../../RiversideApp/lib/api.dart#L1279-L1291) [search_page.dart](../../../RiversideApp/lib/pages/search_page.dart#L76-L120) [captures/README.md](../../../RiversideApp/captures/README.md#L196-L219) |
| Topic 阅读 | 标题/类别/作者/统计/状态，首窗与按 Post-ID 的前后增量加载、跳楼、建议 Topic、阅读进度；普通帖和系统动作帖；站内 Topic、用户、RSC 红包链接路由。 | `GET /t/{id}.json?track_visit=true`、`GET /t/{id}/{post}.json?track_visit=true`、`GET /t/{id}/posts.json?post_ids[]=&include_suggested=true`、`POST /topics/timings`。 | [api.dart](../../../RiversideApp/lib/api.dart#L231-L251) [api.dart](../../../RiversideApp/lib/api.dart#L1246-L1276) [topic_suggested_topics_test.dart](../../../RiversideApp/test/topic_suggested_topics_test.dart#L8-L73) |
| 富内容与媒体 | 渲染 `cooked` HTML/Markdown：图片（含原图/缩略图/保存）、emoji/自定义 emoji、链接/onebox、引用、代码、spoiler、列表、表格、目录、公式、投票，以及 Bilibili/YouTube 嵌入；暗色主题与窄屏图片适配。 | `GET /emojis.json`；投票 `PUT /polls/vote`；媒体 URL 及认证图片头。 | [utils.dart](../../../RiversideApp/lib/utils.dart#L173-L258) [topic_page.dart](../../../RiversideApp/lib/pages/topic_page.dart#L800-L930) [markdown_render_test.dart](../../../RiversideApp/test/markdown_render_test.dart#L11-L466) [bilibili_embed_test.dart](../../../RiversideApp/test/bilibili_embed_test.dart#L5-L73) |
| Topic 写作与草稿 | 新建 Topic（标题、Category、正文）、Topic/Reply 编辑、针对某楼回复和自动 quote、草稿保存/恢复/丢弃、图片上传；编辑器提供粗体、代码、链接、标题、图片、列表、emoji、spoiler、目录与 poll 模板。 | `POST /posts.json`、`PUT /posts/{id}`、`PUT /t/-/{id}.json`、`GET/POST/DELETE /drafts...`、`POST /uploads.json`。 | [api.dart](../../../RiversideApp/lib/api.dart#L254-L277) [api.dart](../../../RiversideApp/lib/api.dart#L449-L470) [api.dart](../../../RiversideApp/lib/api.dart#L1180-L1233) [composer_toolbar_test.dart](../../../RiversideApp/test/composer_toolbar_test.dart#L7-L127) [auto_reply_quote_test.dart](../../../RiversideApp/test/auto_reply_quote_test.dart#L6-L72) |
| Topic 互动与治理 | 自定义 reaction 的开关/参与者、投票、书签、举报、删除、解答采纳/取消；每项仅在 Topic/Post 权限与闭合/归档状态允许时显示。 | reactions plugin、`/polls/vote`、`/bookmarks.json`、`/post_actions`、`/solution/{accept,unaccept}`、`DELETE /posts/{id}`。 | [api.dart](../../../RiversideApp/lib/api.dart#L279-L317) [api.dart](../../../RiversideApp/lib/api.dart#L404-L487) [captures/README.md](../../../RiversideApp/captures/README.md#L86-L95) |
| 聊天 | 频道、Direct Message、聊天搜索三 Tab；频道离开；从最后已读加载、向前/向后翻页、标已读；文本/图片上传、@、emoji、回复、复制/链接、reaction 汇总、删除消息呈现。 | `GET /chat/api/me/channels`、`POST /chat/api/direct-message-channels.json`、`GET /chat/api/channels/{id}/messages.json`、`PUT .../read`、`POST /chat/{id}.json`、`PUT /chat/{id}/react/{message}`、`POST /uploads.json`。 | [api.dart](../../../RiversideApp/lib/api.dart#L878-L1010) [chat_reaction_test.dart](../../../RiversideApp/test/chat_reaction_test.dart#L5-L140) [chat_upload_placeholder_test.dart](../../../RiversideApp/test/chat_upload_placeholder_test.dart#L5-L46) [2026-05-17-messages-with-image.request.txt](../../../RiversideApp/captures/chat/2026-05-17-messages-with-image.request.txt#L1-L18) |
| 消息与本地通知 | 消息 Tab 四桶：私信、回复、回应（自定义 reaction + 赞）、提及；分页、跳至目标楼并随阅读进度清关联未读。Android 后台 15 分钟拉取、分组本地通知、点击跳 Topic 或 Chat。 | `/topics/private-messages/{user}.json`、reactions-received、`/user_actions.json`、`/notifications.json`、`PUT /notifications/mark-read.json`。 | [models.dart](../../../RiversideApp/lib/models.dart#L126-L137) [notifications_page.dart](../../../RiversideApp/lib/pages/notifications_page.dart#L61-L160) [api.dart](../../../RiversideApp/lib/api.dart#L362-L401) [push_service.dart](../../../RiversideApp/lib/push_service.dart#L193-L300) [notification_read_test.dart](../../../RiversideApp/test/notification_read_test.dart#L6-L36) |
| 用户资料、社交与我的 | 当前用户卡、编辑姓名/头衔/flair/bio/location/背景/头像、主/备用邮箱；其它用户的资料/统计/徽章/话题/回复、关注/取关、私聊、通知级别、静音/忽略；自己话题、回复、草稿、书签、应用设置、关于页。 | `/u/{username}.json`、`/u/{username}/summary.json`、emails、badge title、profile/avatar upload、`/follow/{user}.json`、notification level、created-by 与 user_actions。 | [profile_page.dart](../../../RiversideApp/lib/pages/profile_page.dart#L40-L279) [api.dart](../../../RiversideApp/lib/api.dart#L489-L729) [profile_email_test.dart](../../../RiversideApp/test/profile_email_test.dart#L5-L51) [draft_item_test.dart](../../../RiversideApp/test/draft_item_test.dart#L5-L34) |
| RSC 钱包与交易 | 创建钱包、余额、每日奖励与发放、账本/转账历史、转账、Topic 打赏、红包创建/复制链接/关闭；先把 Discourse 会话换 RSC JWT，401 只换新 JWT 一次后重试。真实资产操作须按主计划的额外授权门执行。 | `https://coin.river-side.cc`；`/auth/discourse-exchange`、`/wallet/me...`、`/wallet/transfer`、`/wallet/post-tips`、`/wallet/red-packets...`。 | [rsc_api.dart](../../../RiversideApp/lib/rsc_api.dart#L55-L262) [rsc_api_test.dart](../../../RiversideApp/test/rsc_api_test.dart#L20-L424) [rsc_config_test.dart](../../../RiversideApp/test/rsc_config_test.dart#L5-L31) |
| 世界杯 | 首页可关闭横幅，2026 赛程独立页：今天默认、焦点赛（live > future > finished）、赛程、本地时间、积分表、淘汰赛中文轮次、国家旗帜和刷新/错误态。 | 从 OpenFootball GitHub 拉取，SharedPreferences 缓存。 | [world_cup.dart](../../../RiversideApp/lib/world_cup.dart#L1-L95) [world_cup_test.dart](../../../RiversideApp/test/world_cup_test.dart#L6-L129) |
| WebView 与外部能力 | RiverSide 站内 `/u/*` 与 `/t/*` 转原生页面；about 与首页六个特色子站（树洞、选课指南、交易市场、校友地图、觅电、RS date）留在 WebView/浏览器，并按链接需要进入 SSO 起点；图片可保存相册。 | `webview_flutter`、`url_launcher`、`gallery_saver_plus`。 | [home_page.dart](../../../RiversideApp/lib/pages/home_page.dart#L877-L969) [web_view_navigation_test.dart](../../../RiversideApp/test/web_view_navigation_test.dart#L5-L27) [pubspec.yaml](../../../RiversideApp/pubspec.yaml#L29-L50) |

## 当前 ArkTS 实现快照

这是对 `/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp-harmonyos` 当前源码的只读分类，不把未提交中的演进工作视为已验收交付。

| Flutter 能力域 | ArkTS 状态 | 现有证据 |
| --- | --- | --- |
| 最新回复 Home、Category、Category Topic | 已实现，含加载/空态/失败/刷新与 Category 分区缓存；其余四个 Home 频道仍是不可用入口。 | `app/entry/src/main/ets/app/AppShellModel.ets`、`components/HomeBrowsePage.ets:194-212`、`components/CategoryBrowsePage.ets`、`ohosTest/ets/test/AppShellModel.test.ets` |
| Topic/Post 阅读 | 已实现首屏、按 Post-ID 增量窗口、追加失败恢复、关闭/归档限制；Suggested Topics、跳楼、系统动作与完整阅读进度未实现。 | `repositories/DiscourseForumRepository.ets`、`components/TopicDetailPage.ets`、`ohosTest/ets/test/TopicReading.test.ets` |
| User API Key 与会话 | 已实现 ArkWeb 授权、RSA nonce 验证、HUKS 会话、恢复/登出和 401 单点失效；未完成普通/管理员真实账号验收。 | `app/entry/src/main/ets/auth/`、`ohosTest/ets/test/AuthRepository.test.ets` |
| Reply | 已实现对 Topic 或具体 Post 的纯文本/Markdown Reply、草稿保留和不确定提交恢复；新 Topic、编辑、草稿同步、上传和富编辑未实现。 | `app/entry/src/main/ets/models/ReplyModels.ets`、`components/TopicDetailPage.ets`、`ohosTest/ets/test/ReplyTransport.test.ets` |
| 搜索、Profile、富内容/互动、Chat、消息、RSC、世界杯、WebView/媒体/后台 | 未实现为正式产品能力；Chat/消息与系统通知只存在原型 Fixture/测试服务，不能计入对等。 | `pages/Index.ets:664-675`、`components/AccountPage.ets`、`components/prototype/UiPrototypePage.ets`、`core/SystemNotificationService.ets` |

## 生命周期、失败与平台依赖

- 每个远程列表均有加载、空、刷新和局部失败态；分页失败通常停止“更多”而不清掉已得到内容。首页明确把请求异常转为可重试 `ErrorState`，而消息页把本次分页停住。[home_page.dart](../../../RiversideApp/lib/pages/home_page.dart#L131-L207) [notifications_page.dart](../../../RiversideApp/lib/pages/notifications_page.dart#L93-L160)
- Category、emoji、RSC JWT、登录态均有本地缓存/恢复路径；缓存不是授权来源。RSC 对 `USER_NOT_FOUND`、401 与普通 404 有不同的重试/错误语义，必须按测试复刻。[api.dart](../../../RiversideApp/lib/api.dart#L1297-L1433) [api.dart](../../../RiversideApp/lib/api.dart#L847-L875) [rsc_api_test.dart](../../../RiversideApp/test/rsc_api_test.dart#L284-L424)
- Flutter 依赖直接揭示需做 HarmonyOS 等价替换的能力：安全凭据存储、Web 授权/内嵌网页、文件/图片选择和上传、图片缓存、系统相册保存、外链、后台周期任务/本地通知、应用版本信息和高刷新率；不要把 Flutter Android 的 WorkManager 或 MethodChannel 原样搬过去。[pubspec.yaml](../../../RiversideApp/pubspec.yaml#L29-L50) [push_service.dart](../../../RiversideApp/lib/push_service.dart#L205-L248)

## 已识别证据冲突与实施前裁决

1. `captures/README.md` 只将 `verified_uestcer` 说明为认证组，但冻结测试把 `verified_uestcer`、`scuer`、`swufer`、`swjtuer`、`sicnuer` 视为认证、`rs_developer` 不视为认证。实现以测试与 `models.dart` 行为为准，并把抓包说明视作过期辅助材料。[topic_permissions_test.dart](../../../RiversideApp/test/topic_permissions_test.dart#L58-L106) [captures/README.md](../../../RiversideApp/captures/README.md#L160-L166)
2. 某个聊天抓包注释仍称 reaction 未建模/未显示，但冻结模型、页面和测试已保留并显示 reaction。因此对等验收必须包含 reaction，不接受旧注释作为删减理由。[chat_reaction_test.dart](../../../RiversideApp/test/chat_reaction_test.dart#L5-L140) [2026-05-17-messages-with-image.request.txt](../../../RiversideApp/captures/chat/2026-05-17-messages-with-image.request.txt#L14-L17)

## 建议的实施分段（依赖顺序）

1. 完成认证、安全会话、Shell、通用网络/错误模型与富内容安全技术验证。
2. 完成论坛读写闭环：五频道、Category、搜索、完整 Topic、编辑器/上传/草稿、互动。
3. 完成个人资料与社交通知：资料编辑、书签、关注/私聊、消息及 HarmonyOS 原生通知。
4. 完成聊天完整生命周期与外链/Web 容器/图片保存。
5. 在独立的安全验收门后完成 RSC；并完成世界杯、真实普通/管理员账号在“测试专用”板块的逐项验收。
