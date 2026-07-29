# RiverSide HarmonyOS 与 Discourse 实时内容更新研究

研究日期：2026-07-29

研究范围：

- RiverSide HarmonyOS：`/Users/jackzhang/Code/RiversideApp-HarmonyOS`
- RiverSide 基线提交：`cedcd19aea0d5bb3d2c36e43ecfeb5a30d8038e4`
- Discourse：官方仓库源码，本机完整基线提交 `545168826bcc89dc631b5f3a641ad0a03970eb41`；并以 2026-07-29 官方 `main` 提交 `fc96c733db08a5d6255c7c6d7d6e6b8994840282` 复核关键链路
- MessageBus：Discourse 使用的官方 `message_bus` 项目；本机锁定 `v4.5.2`，并以 2026-07-29 官方 `main` 提交 `50c1cb4381c4857e938767049dc6611f4c7b4e0c` 复核协议

本记录只做源码与交互研究，没有修改 APP 或 Discourse 业务源码。

## 结论

可以实现，而且不需要定时全量轮询。

推荐采用“MessageBus 负责通知发生了什么，现有 Discourse HTTP API 负责取得权威内容”的混合方案：

```mermaid
flowchart LR
  A["Discourse Post/Topic 发生变化"] --> B["MessageBus 发送轻量事件"]
  B --> C["RiverSide 前台长轮询"]
  C --> D["合并、去重事件"]
  D --> E["按 Topic/Post ID 调用 HTTP API"]
  E --> F["更新首页或 Topic 详情状态"]
```

不要把 MessageBus payload 当作完整业务对象。官方 payload 通常只有 Topic/Post ID、事件类型和少量计数；Discourse Web 客户端收到事件后同样会再调用 Topic/Post HTTP 接口。这个边界还能抵抗插件字段变化、权限变化和事件漏收。

交互上也不建议“每次事件都立即重排屏幕”：

- 首页：已有卡片的计数可以静默更新；会改变排序的新建/顶起 Topic 先聚合成“有 N 个 Topic 更新”提示。用户在列表顶端且没有操作时可以自动合并，否则点提示后再合并。
- Topic 详情：用户已经位于末尾时自动追加新 Reply；不在末尾时显示“有 N 条新 Reply”按钮，点击后滚到第一条新 Reply。编辑、Reaction、删除只更新原位置，不抢滚动位置。
- APP 从后台回到前台、网络重连或 MessageBus 游标不可信时，再做一次 HTTP 对账；下拉刷新继续作为用户可见的兜底。

## Discourse 官方实现

### 1. MessageBus 是 HTTP 长轮询，不是 WebSocket

MessageBus 的客户端协议使用：

```text
POST /message-bus/{client_id}/poll
Content-Type: application/json

{
  "/latest": 123,
  "/topic/456": 78,
  "__seq": 9
}
```

请求体中每个 channel 的数字是客户端已处理的最后一个 **channel message ID**，`__seq` 是同一个 `client_id` 下递增的请求序号。响应是：

```json
[
  {
    "global_id": 1200,
    "message_id": 124,
    "channel": "/latest",
    "data": {
      "topic_id": 456,
      "message_type": "latest",
      "payload": {}
    }
  }
]
```

订阅续传使用 `message_id`，不是 `global_id`。没有新消息时，连接可以保持到服务端长轮询超时；Discourse 当前默认是 25 秒。若开启 chunked encoding，一个请求还能连续返回多批数据；Native 第一版可以发送 `Dont-Chunk: true`，使用更容易实现和测试的普通长轮询。[MessageBus subscriber protocol](https://github.com/discourse/message_bus/blob/v4.5.2/README.md#L623-L691)；[Discourse MessageBus 配置](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/config/initializers/004-message_bus.rb#L136-L145)

MessageBus 保存有限 backlog。客户端持续携带最后已处理的 channel message ID，就能在短暂断线后补收。`/__status` 是控制消息：首次以 `-1` 订阅、客户端游标超前，或部分消息因 user/group 权限被过滤时，服务端用它告诉客户端各 channel 应推进到的 ID。[MessageBus status message](https://github.com/discourse/message_bus/blob/v4.5.2/README.md#L669-L691)

默认 Redis backend 只保留每 channel 1000 条、全局 2000 条消息，闲置 channel 7 天后会被清理；部署者还可以修改这些值。因此 backlog 适合短暂断线续传，不是永久同步日志。[MessageBus data retention](https://github.com/discourse/message_bus/blob/50c1cb4381c4857e938767049dc6611f4c7b4e0c/README.md#L391-L410)

### 2. 首页使用的 channels

Discourse Web 的 `TopicTrackingState` 订阅：

| Channel | 作用 | 主要 payload |
| --- | --- | --- |
| `/latest` | 新建或被新 Reply 顶起的普通 Topic | `topic_id`、`message_type: "latest"`、`bumped_at`、`category_id`、`archetype`，可选 tag IDs |
| `/new` | 对当前用户属于新 Topic 的状态 | `topic_id`、`message_type: "new_topic"`、创建时间、Category、初始楼层状态 |
| `/unread` | 被跟踪/关注 Topic 出现新 Reply | `topic_id`、`message_type: "unread"`、`highest_post_number`、更新时间、Category |
| `/unread/{user_id}` | 当前用户自己的已读/通知状态同步 | `read`、`dismiss_new`、`dismiss_new_posts` 等 |
| `/delete` | Topic 软删除或用户失去可见性 | `topic_id`、`message_type: "delete"` |
| `/recover` | Topic 恢复 | `topic_id`、`message_type: "recover"` |
| `/destroy` | Topic 永久删除 | `topic_id`、`message_type: "destroy"` |

服务端定义和发布 payload 的源码在 [topic_tracking_state.rb:22-79](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/topic_tracking_state.rb#L22-L79)、[topic_tracking_state.rb:121-178](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/topic_tracking_state.rb#L121-L178) 和 [topic_tracking_state.rb:210-228](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/topic_tracking_state.rb#L210-L228)。Web 客户端的订阅清单见 [topic-tracking-state.js:69-145](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/models/topic-tracking-state.js#L69-L145)。

新 Topic 创建后会发布 `/new`；后台 Job 还会对普通 Topic 发布 `/latest`。新 Reply 会发布 `/unread` 和 `/latest`。[post_jobs_enqueuer.rb:54-82](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/post_jobs_enqueuer.rb#L54-L82)；[post_update_topic_tracking_state.rb:4-22](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/jobs/regular/post_update_topic_tracking_state.rb#L4-L22)

`/latest` 并不包含首页卡片所需的完整标题、作者、摘要和统计。官方 Web 只把 `topic_id` 放进 `newIncoming`，显示“有 N 个新或更新的 Topic”；用户点击后才用当前列表 filter 和 `topic_ids` 请求对应 Topic，再把它们合并到列表顶部并高亮第一项。[topic-tracking-state.js:247-335](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/models/topic-tracking-state.js#L247-L335)；[discovery/topics.gjs:71-89](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/components/discovery/topics.gjs#L71-L89)；[topic-list.js:229-258](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/models/topic-list.js#L229-L258)

这也是 RiverSide 首页不应该收到一个事件就立即重排的直接依据：官方选择先提示、后合并，是为了避免用户正在浏览时列表跳动。

### 3. Topic 详情使用 `/topic/{topic_id}`

打开 Topic 后，Web 客户端订阅 `/topic/{id}`，并把 Topic JSON 中的 `message_bus_last_id` 作为起点。[topic.js controller:2026-2043](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/controllers/topic.js#L2026-L2043)

`message_bus_last_id` 由服务端创建 `TopicView` 时读取，并通过 Topic serializer 返回。这样可以避免“先加载 Topic、后建立订阅”中间的竞态：加载后发生的事件仍在 backlog 中，可以从该 ID 之后补回。[topic_view.rb:134-143](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/topic_view.rb#L134-L143)；[topic_view_serializer.rb:55-98](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/serializers/topic_view_serializer.rb#L55-L98)

Post 的基础事件 payload 由 `Post.publish_change_to_clients!` 统一构造：

```json
{
  "id": 789,
  "post_number": 12,
  "updated_at": "...",
  "user_id": 42,
  "last_editor_id": 43,
  "type": "created",
  "version": 1
}
```

消息只发给可见该 Topic/Post 的 user/group audience。[post.rb:222-252](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/post.rb#L222-L252)

官方 Web 对主要事件的处理如下：

| `data.type` / 标记 | Web 行为 | RiverSide 可采用的行为 |
| --- | --- | --- |
| `created` | 收集 Post IDs，批量调用 Topic posts API；已加载到底部时追加，否则先扩充 stream | 批量拉取新 Reply；在末尾自动追加，不在末尾只增加“新 Reply”计数 |
| `revised`、`rebaked` | 已加载的 Post 调用 `GET /posts/{id}` 后原位替换 | 原位更新，保留滚动锚点 |
| `deleted` | 若 Post 已加载，调用 `GET /posts/{id}`；无权读取时移除 | 有权限显示删除状态，否则移除 |
| `destroyed` | 立即从 stream 移除 | 移除；若为主楼/Topic 已销毁则提示并返回 |
| `recovered` | 已加载则刷新；未加载则获取后插回 stream | 获取并按 `post_number` 恢复 |
| `liked`、`unliked` | 用 payload 中 `likes_count` 原位更新 | 静默更新计数 |
| `acted` | 获取 Post，但保留 cooked 正文 | 更新操作状态/计数 |
| `stats` | 更新 Topic 的 `last_posted_at`、`like_count`、`posts_count` 和 `last_poster` | 更新详情统计与进度总数 |
| `reload_topic: true` | 重新获取 Topic；若同时 `refresh_stream` 则刷新 Post stream | 做一次权威 Topic 对账，按当前 Post 恢复滚动锚点 |

事件分派见 [topic.js controller:2045-2178](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/controllers/topic.js#L2045-L2178)。新增 Reply 事件来自 [post_creator.rb:653-656](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/post_creator.rb#L653-L656)，编辑事件来自 [post_revisor.rb:862-873](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/post_revisor.rb#L862-L873)，删除/恢复事件来自 [post_destroyer.rb:116-182](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/post_destroyer.rb#L116-L182) 和 [post_destroyer.rb:188-257](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/post_destroyer.rb#L188-L257)，Topic 统计事件来自 [topic.rb:2208-2232](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/topic.rb#L2208-L2232)。

Web 客户端对新 Post 按 ID 批量调用 `GET /t/{topic_id}/posts.json?post_ids[]=...`；编辑和删除则调用 `GET /posts/{post_id}`。[post-stream.js:728-890](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/models/post-stream.js#L728-L890)；[post-stream.js:1163-1214](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/models/post-stream.js#L1163-L1214)

### 4. 权限与第三方客户端复用

MessageBus middleware 会用 Discourse 的 `CurrentUser.lookup_from_env` 识别当前用户，并取其 group IDs；发布端也按 Topic 的 secure audience 设置 `user_ids` 或 `group_ids`，所以受限 Category 和 Private Message 不会仅因为客户端知道 channel 名就泄露。[004-message_bus.rb:17-107](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/config/initializers/004-message_bus.rb#L17-L107)；[topic.rb:2194-2205](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/topic.rb#L2194-L2205)

Native 客户端可以在 MessageBus POST 上发送与普通 API 相同的：

```text
User-Api-Key: ...
User-Api-Client-Id: ...
```

Discourse 的 User API Key scope 明确定义了 `message_bus`，`notifications` 也允许 MessageBus POST；`write` scope 则允许 GET/POST/PATCH/PUT/DELETE。[user_api_key_scope.rb:3-19](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/models/user_api_key_scope.rb#L3-L19)；[default_current_user_provider.rb:193-218](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/lib/auth/default_current_user_provider.rb#L193-L218)

RiverSide 当前 Authorization Request 请求 `read,write,session_info`，因此现有 Authenticated Session 的 `write` 已覆盖 MessageBus POST，不需要仅为验证原型重新授权；如果以后收窄权限，应显式申请 `message_bus`。当前定义见 `app/entry/src/main/ets/auth/AuthModels.ets:6-8`。

但需要区分“可复用”和“公开稳定 API”：

- Topic/Post HTTP API 是 Discourse 对外 API，官方文档列出了 Topic 列表和 `GET /t/{id}/posts.json` 等接口。[Discourse API 文档](https://docs.discourse.org/)
- MessageBus 协议由 Discourse 官方项目文档化，适合第三方客户端实现。
- `/latest`、`/topic/{id}` 等具体 channel 名和 payload 来自 Discourse Web 内部源码，并不是 OpenAPI 中承诺长期不变的公共业务契约。

因此客户端应把 MessageBus 封装在独立、严格类型化的适配层里：忽略未知事件、记录协议诊断、以 HTTP 对账为最终正确性保证。若以后希望获得完全受控的长期契约，可以再考虑 Discourse 插件发布一个 RiverSide 专用 channel；第一版没有这个必要。

## 重连、补拉与一致性

### 官方 Web 的策略

官方 JS client 会：

- 每个 channel 保存最后收到的 `message_id`，下一次 poll 带回；
- 网络连续失败超过两次后线性退避，最多退避到 180 秒；
- 收到 429 时尊重 `Retry-After`，且至少等待 15 秒；
- 页面重新可见时立即发起新的 long poll；
- Discourse 页面在用户连续 20 分钟不在场时停止 long poll，重新在场时唤醒。

实现见 [message-bus client:103-165](https://github.com/discourse/message_bus/blob/v4.5.2/assets/message-bus.js#L103-L165)、[message-bus client:263-347](https://github.com/discourse/message_bus/blob/v4.5.2/assets/message-bus.js#L263-L347)、[message-bus client:423-476](https://github.com/discourse/message_bus/blob/v4.5.2/assets/message-bus.js#L423-L476) 和 [Discourse initializer:80-97](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/frontend/discourse/app/instance-initializers/message-bus.js#L80-L97)。

Topic 页面有明确的无竞态起点：先获取 Topic JSON，再用其中的 `message_bus_last_id` 订阅。

首页 Web 的首次 channel ID 来自页面预加载的 `TopicTrackingStateSerializer.meta`，它包含所有 tracking channels 的 `MessageBus.last_ids`。[topic_tracking_state_serializer.rb:3-26](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/serializers/topic_tracking_state_serializer.rb#L3-L26) 这个 meta 没有随普通 `/latest.json` API 返回，第三方 Native 客户端不能照搬页面 preload。

### RiverSide 推荐策略

#### 首次进入首页

为避免“列表快照完成后、订阅建立前”漏掉事件：

1. 先以 `-1` 订阅首页相关 channels，收到 `"/__status"` 后得到当前 channel IDs。
2. 同时开始获取首页 HTTP 快照；在快照完成前暂存后续事件。
3. 快照完成后再顺序处理暂存事件。

`/__status` 之前的变化已经包含在稍后取得的 HTTP 快照中，之后的变化会进入事件缓冲，所以不需要 Web preload meta 也能封闭竞态。

#### 首次进入 Topic

1. 解析并保存 `/t/{id}.json` 返回的 `message_bus_last_id`。
2. 订阅 `/topic/{id}`，起点就是该 ID。
3. 收到 `created` 时合并 100–300ms 内的 Post IDs，一次调用 `GET /t/{id}/posts.json?post_ids[]=...`。

RiverSide 当前 `TopicDetail` 和 `TopicResponseParser` 尚未保留 `message_bus_last_id`；实现时需要先把这个字段纳入严格类型模型。这里只记录设计，不在本次调研中修改代码。

#### 断网与前后台切换

- APP 在前台时维持一条共享 MessageBus long poll，不要为首页和每个页面各建连接；动态增减订阅 channel。
- APP 进入后台时取消 long poll。后台新内容提醒使用 Push，而不是维持常驻连接。
- APP 回到前台时立即重连，并对当前首页首屏或当前 Topic 做一次 HTTP 对账。若离线时间很短，MessageBus backlog 可以减少多余刷新；HTTP 对账仍负责处理 backlog 已裁剪、权限变化和 APP 被杀后的情况。
- channel cursor 按“站点 + Authenticated Session 用户 + channel”隔离，账号切换时清空，避免跨账号继承权限状态。
- 只有事件已成功应用或已经通过 HTTP 对账覆盖后，才持久化对应 `message_id`；所有状态合并都必须按 Topic/Post ID 幂等。
- 403 视为 Authenticated Session 无效或 scope 不足；429 尊重 `Retry-After`；其他网络失败做带随机抖动的退避。

不要只靠 message ID 连续性判断“是否漏消息”。权限过滤本来就会让客户端看不到某些消息，`/__status` 还会主动推进 channel ID。最可靠的修复方式始终是 HTTP 对账。

## 推荐交互

### 首页

推荐把“自动更新”拆成两层：

1. **不改变位置的更新自动应用**：当前可见 Topic 的回复数、最后回复时间、最后回复人等，在按 ID 拉取完成后原位刷新。
2. **会改变列表位置的更新先提示**：聚合成顶部吸附提示，例如“3 个 Topic 有更新”。点击后按当前 tab 的 HTTP filter 获取这些 Topic，合并到正确位置并轻微高亮。

在以下条件同时满足时，可以自动执行第 2 层：

- 用户位于列表顶部；
- 当前没有拖动、下拉刷新、菜单或编辑器；
- 最近约 1 秒没有触摸交互。

否则保留提示，不抢位置。提示应合并 Topic ID，同一个 Topic 连续收到多个 Reply 只计为一个更新。

不同首页 tab 不能完全使用同一种策略：

| RiverSide tab | 建议 |
| --- | --- |
| 最新回复 | `/latest` 是直接触发器，按 `topic_ids` 获取并按 `bumped_at` 合并 |
| 最新发表 | 只把新建 Topic 插入顶部；普通 Reply 只更新卡片，不按 Reply 时间重排 |
| 未读 | 结合 `/new`、`/unread`、`/unread/{user_id}`；当前代码的 `HomeChannel.UNREAD` 实际请求 `/new.json`，实现前要先确认产品语义是“新 Topic”还是“新 + 未读” |
| 热门 | 没有能完整反映排名变化的单一 channel；把 `/latest` 当作失效提示，前台恢复或短时间 debounce 后刷新首屏 |
| 精华 | 可用 `/latest` 中的 tag IDs 过滤候选，但 tag 排序和移除仍应通过当前 tag 列表 API 对账 |

首页已有下拉刷新应继续保留。MessageBus 失败时无需弹持续错误 Toast；只在更新提示上显示轻量离线状态，用户手动刷新失败时再给明确错误。

### Topic 详情

推荐三个状态：

| 用户位置 | 新 Reply 到达后的交互 |
| --- | --- |
| 已在末尾，未拖动 | 拉取后自动追加，保持末尾；用淡入动画和轻量触觉反馈 |
| 接近末尾但正在拖动 | 不移动位置；显示“有 N 条新 Reply” |
| 阅读历史楼层 | 不改变视口；显示“有 N 条新 Reply”，点击滚到第一条新 Reply |

“有 N 条新 Reply”按钮应放在底部操作区上方或内容底部中央，不占用右侧阅读进度条。点击后：

1. 确保缺失 Post 已拉取；
2. 滚到第一条新 Reply；
3. 清零计数；
4. 之后按现有阅读进度机制标记已读。

其他事件：

- Post 编辑：原位替换，短暂显示“已更新”但不弹 Toast。
- 软删除：有权限查看删除态则保留占位；无权限则折叠移除，尽量保持相邻 Post 的屏幕坐标。
- 永久删除：移除；若主楼或整个 Topic 被销毁，显示说明并返回来源页。
- Reaction/like：静默更新数字，不触发“新 Reply”提示。
- Topic 标题、Category、关闭状态变化：收到 `reload_topic` 后刷新 metadata；保存当前可见 Post ID 和其顶部偏移，刷新后恢复，而不是回到主楼。
- 回复编辑器打开时：后台仍可以接收、拉取和累计新 Reply，但不要关闭编辑器或抢焦点。
- 阅读进度条：总楼层数可随权威 Topic stats 更新，但不要因为总数改变而主动移动当前阅读位置。

### 可访问性与反馈

- 新内容提示提供明确 accessibility text，例如“有 3 条新回复，双击跳转”。
- 自动追加只做一次无打断的 accessibility announcement，不连续朗读正文。
- 尊重系统“减少动态效果”；此时使用颜色/文字变化，不做位移动画。
- 一批事件只产生一次提示或触觉反馈。

## 建议实施顺序

1. 先实现严格类型化的 MessageBus transport：普通 long poll、认证 headers、`/__status`、每 channel cursor、退避、前后台生命周期。
2. 在 Topic JSON 模型中保留 `message_bus_last_id`，只接入 `/topic/{id}` 的 `created`，验证“末尾自动追加 / 非末尾提示”。
3. 增加 `revised`、`deleted`、`destroyed`、`recovered` 和 `reload_topic`，每种事件都用现有 HTTP repository 对账。
4. 接入首页 `/latest`，先实现官方同款“有 N 个 Topic 更新”提示和按 ID 获取。
5. 再补 `/new`、`/unread`、`/delete`、`/recover`、`/destroy`，最后处理 Hot/Featured 的 debounce 对账策略。
6. 加入断网、重连、账号切换、后台恢复和 backlog 被裁剪的集成测试。

第一版不建议：

- 每几秒全量刷新首页和 Topic；
- APP 在后台保持 MessageBus；
- 收到事件就全量重建 Topic 详情并把用户滚回顶部；
- 依赖 undocumented payload 中没有在模型里显式校验的字段；
- 让每个页面各自拥有一条 long poll。
