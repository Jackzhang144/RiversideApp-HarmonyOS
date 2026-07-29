# `discourse-riverside-push` 插件实施设计

研究日期：2026-07-25

核对基线：

- Discourse：`545168826bcc89dc631b5f3a641ad0a03970eb41`
- RiverSide HarmonyOS APP：当前工作区，仅做只读核对
- 本文只给出设计，不创建插件，也不修改业务代码

## 结论

这个插件可以直接做成一个独立的 Discourse 插件仓库，名称
`discourse-riverside-push`，Ruby namespace 为 `RiversidePush`。

第一版建议：

1. 复用 Discourse 已经算好的 Topic/Post 推送事件
   `:push_notification`，不监听 `post_created` 自行重算收件人。
2. 提供 `PUT /riverside-push/device` 和
   `DELETE /riverside-push/device` 两个端点；APP 每次启动或 Push
   Token 更新后幂等 `PUT`。
3. 设备记录绑定 `user_api_key_id`。发送时只 join active
   User API Key，因此 Authenticated Session 被撤销或过期后立即停止发送。
4. Sidekiq Job 内重新加载 User、Post、Topic、设备记录并重新执行 Guardian
   可见性检查，再调用 Huawei Push Kit V3 API。
5. 只接受 `Notification.types[:replied]` 与
   `Notification.types[:private_message]`：前者映射到 Huawei
   `SUBSCRIPTION`，后者映射到 `IM`。
6. 服务账号 JSON 通过只读文件挂载提供，不把私钥内容写进 SiteSetting。
7. 第一版沿用 APP 现有 `write` scope，不新增一个“看似更小、实际没有缩权”
   的 scope。

整体链路：

```text
Discourse 创建 Notification
  -> PostAlerter 构造 Topic/Post push payload
  -> :push_notification
  -> 插件复用 push filters 和在线时间窗
  -> RiversidePush Sidekiq Job
  -> Guardian 再校验
  -> 查询 active UserApiKey 绑定的设备
  -> Huawei Push Kit V3 通知消息
  -> APP 点击后按 topic_id/post_id 打开 Topic/Post
```

Discourse 的 `PostAlerter` 已提供 `notification_type`、`post_number`、
`topic_title`、`topic_id`、`post_id`、安全摘要、用户名和 `post_url`，
插件没有必要从 Post 重新推导通知语义：
[本地源码 `post_alerter.rb:16-47`](/Users/jackzhang/Code/discourse/app/services/post_alerter.rb:16)；
[官方仓库](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/services/post_alerter.rb#L16-L47)。

## 1. 从官方 skeleton 起步

Discourse 启动时会扫描 `plugins` 下含 `plugin.rb` 的目录；`plugin.rb`
同时承担插件 manifest 和 Ruby 初始化入口。官方文档也建议使用
`discourse-plugin-skeleton`，当前核心提供
`rake plugin:create[plugin-name]`：
[本地官方开发指南 `01-basic-plugin.md:13-33`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/01-basic-plugin.md:13)；
[官方 Meta 指南](https://meta.discourse.org/t/developing-discourse-plugins-part-1-create-a-basic-plugin/30515)；
[官方 skeleton](https://github.com/discourse/discourse-plugin-skeleton)。

将来真正开始编码时，可在 `/Users/jackzhang/Code/discourse` 执行：

```sh
bin/rake plugin:create[discourse-riverside-push]
```

插件应放在独立 Git 仓库中，再 symlink 到本地 Discourse 的 `plugins/`
目录。不要把实现直接提交进当前 Discourse core checkout。

建议目录：

```text
discourse-riverside-push/
├── plugin.rb
├── README.md
├── LICENSE
├── lib/
│   └── riverside_push/
│       └── engine.rb
├── config/
│   ├── routes.rb
│   ├── settings.yml
│   └── locales/
│       └── server.en.yml
├── db/
│   └── migrate/
│       └── YYYYMMDDHHMMSS_create_riverside_push_devices.rb
├── app/
│   ├── controllers/riverside_push/devices_controller.rb
│   ├── models/riverside_push/device.rb
│   ├── jobs/
│   │   ├── regular/riverside_push/deliver_notification.rb
│   │   └── scheduled/riverside_push/prune_devices.rb
│   └── services/riverside_push/
│       ├── current_user_api_key.rb
│       ├── device_registration.rb
│       ├── notification_enqueuer.rb
│       ├── notification_payload.rb
│       └── huawei/
│           ├── service_account.rb
│           ├── jwt_provider.rb
│           └── client.rb
├── spec/
│   ├── fabricators/riverside_push_device_fabricator.rb
│   ├── models/riverside_push/device_spec.rb
│   ├── requests/riverside_push/devices_controller_spec.rb
│   ├── jobs/riverside_push/deliver_notification_spec.rb
│   ├── services/riverside_push/huawei/client_spec.rb
│   └── system/core_features_spec.rb
└── .github/workflows/
    ├── discourse-plugin.yml
    └── d-compat-branch.yml
```

## 2. `plugin.rb`、Engine 与加载时机

`plugin.rb` 只保留元数据、开关、根 namespace、Engine require 和事件接线：

```rb
# name: discourse-riverside-push
# about: Delivers Discourse notifications through HarmonyOS Push Kit
# version: 0.1.0
# authors: RiverSide
# url: ...
# required_version: ...

enabled_site_setting :riverside_push_enabled

module ::RiversidePush
  PLUGIN_NAME = "discourse-riverside-push"
end

require_relative "lib/riverside_push/engine"

after_initialize do
  on(:push_notification) do |user, payload|
    RiversidePush::NotificationEnqueuer.call(user:, payload:)
  end
end
```

Engine 必须放在 `lib/riverside_push/engine.rb`，使用
`engine_name` 和 `isolate_namespace RiversidePush`。Engine 的 require
位于 `after_initialize` 外；`app/controllers`、`app/models` 和
`app/services` 依照 Zeitwerk 命名自动加载。官方文档明确说明了这些约束：
[本地官方开发指南 `11-rails-autoloading.md:15-74`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/11-rails-autoloading.md:15)；
[官方 skeleton Engine](https://github.com/discourse/discourse-plugin-skeleton/blob/main/lib/my_plugin_module/engine.rb)。

定时 Job 目录按当前 skeleton 的 `config.to_prepare` 方式 eager load。

### `register_asset` 的取舍

第一版是纯服务端插件，不需要 `register_asset`，也不需要 Ember 管理界面。
若以后增加管理页，只对 SCSS 等需要手动注册的资产使用它；当前 Discourse
会拒绝用 `register_asset` 手动加入 JS/TS，因为
`assets/javascripts` 下的 JS 已自动进入 bundle：
[本地源码 `plugin/instance.rb:800-819`](/Users/jackzhang/Code/discourse/lib/plugin/instance.rb:800)。

`after_initialize` 用于 Rails 完成初始化后挂事件。插件 DSL 的 `on`
会在插件关闭时跳过 handler：
[本地源码 `plugin/instance.rb:641-674`](/Users/jackzhang/Code/discourse/lib/plugin/instance.rb:641)。

## 3. SiteSetting

`config/settings.yml` 建议只放非密钥配置：

| Setting | 默认值 | 用途 |
| --- | --- | --- |
| `riverside_push_enabled` | `false` | 总开关 |
| `riverside_push_service_account_path` | 空 | 只读挂载的服务账号 JSON 绝对路径 |
| `riverside_push_test_message` | `true` | 预发布阶段测试消息 |
| `riverside_push_ttl_seconds` | `86400` | 过期提醒不再投递 |
| `riverside_push_foreground_show` | `true` | 前台是否也显示系统通知 |
| `riverside_push_private_content` | `false` | PM/受限 Category 是否显示正文 |
| `riverside_push_open_timeout_seconds` | `5` | 建连超时 |
| `riverside_push_read_timeout_seconds` | `5` | 读取超时 |
| `riverside_push_prune_after_days` | `30` | 失效设备保留期 |

Site settings 在 `config/settings.yml` 声明，并为每项提供
`config/locales/server.en.yml` 翻译；`enabled_site_setting` 指定插件开关。
没有 `client: true` 的设置不会发给浏览器：
[本地官方开发指南 `03-site-settings.md:17-76`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/03-site-settings.md:17)；
[官方 Meta 指南](https://meta.discourse.org/t/developing-discourse-plugins-part-3-add-custom-site-settings/31115)。

华为服务账号文件包含 `project_id`、`key_id`、`private_key`、
`sub_account` 和 token URI。官方就是以下载的 JSON 密钥文件作为输入：
[Huawei 基于服务账号生成鉴权令牌](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-jwt-token)。

因此不要把 `private_key` 放入 SiteSetting。`secret: true` 主要控制后台展示，
不应把它当成通用数据库字段加密保证。生产环境应把 JSON 以只读 volume
挂载进 web 与 Sidekiq 都可读取的位置，文件权限限制到 Discourse 运行用户。

## 4. 数据表：绑定 `user_api_key_id`

第一版使用自建表，不用 `PluginStore`。`PluginStore` 只有
`plugin_name + key` 唯一键，值放在一个 text 字段，适合小型配置，不适合
设备查询、active key join、唯一约束、错误计数和过期清理：
[本地源码 `plugin_store.rb:27-60`](/Users/jackzhang/Code/discourse/app/models/plugin_store.rb:27)；
[本地源码 `plugin_store_row.rb:6-18`](/Users/jackzhang/Code/discourse/app/models/plugin_store_row.rb:6)。

`riverside_push_devices`：

| 字段 | 约束/说明 |
| --- | --- |
| `user_api_key_id` | bigint，非空，FK 到 `user_api_keys`，删除时 cascade |
| `token` | text，非空；发送所需的 Push Token 原文 |
| `token_digest` | 64 字符 SHA-256 hex，全局唯一，用于查重与安全日志 |
| `reply_enabled` | boolean，默认 true |
| `private_message_enabled` | boolean，默认 true |
| `failure_count` | integer，默认 0 |
| `disabled_reason` | string，可空，不保存华为原始响应 |
| `last_registered_at` | datetime，非空 |
| `last_success_at` | datetime，可空 |
| `last_failure_at` | datetime，可空 |
| `created_at/updated_at` | timestamps |

唯一索引：

- `user_api_key_id`：一个 Authenticated Session 一条设备订阅。
- `token_digest`：一个 Push Token 同时只能属于一个 session。

当前 Discourse 使用 ActiveRecord 8.0；新迁移应使用
`ActiveRecord::Migration[8.0]`。官方插件的 migration/model 结构可参考：
[RSS Polling migration](/Users/jackzhang/Code/discourse/plugins/discourse-rss-polling/db/migrate/20230318130154_create_discourse_rss_polling_rss_feeds.rb:3)；
[RSS Polling model](/Users/jackzhang/Code/discourse/plugins/discourse-rss-polling/app/models/discourse_rss_polling/rss_feed.rb:3)。

Discourse 当前没有可直接套在插件 model 上的通用 ActiveRecord encryption
约定，所以第一版应如实把 `token` 视为数据库中的敏感原文，而不是声称已加密。
保护措施是：

- controller/serializer 永不返回 Token；
- 日志只写 `token_digest` 前 8～12 位；
- 不记录 Huawei 响应中的完整 `msg`，其中可能带非法 Token；
- active key join 和定时清理缩短保留时间；
- 数据库、备份和管理员访问按敏感数据保护。

幂等 PUT 在 `DistributedMutex` 下以 `token_digest` 串行化：

1. 从已经通过认证的 `User-Api-Key` header 查出 active `UserApiKey`。
2. 删除同 digest 但绑定其他 key 的旧行。
3. 按当前 `user_api_key_id` find-or-initialize。
4. 更新 Token、digest、两个通知开关、注册时间并把失败计数归零。

发送查询使用 `Device.joins(:user_api_key).merge(UserApiKey.active)`。
`UserApiKey.active` 同时排除 revoked 和 expired key：
[本地源码 `user_api_key.rb:11-17`](/Users/jackzhang/Code/discourse/app/models/user_api_key.rb:11)。

## 5. 设备端点与认证

### API 契约

```text
PUT    /riverside-push/device.json
DELETE /riverside-push/device.json
```

PUT 请求体：

```json
{
  "device": {
    "token": "<Push Token>",
    "reply_enabled": true,
    "private_message_enabled": true
  }
}
```

PUT 是幂等注册/Token 轮换；返回 `registered: true` 和时间，不返回 Token。
DELETE 按当前请求中的 User API Key 删除对应记录，返回 `204 No Content`。
第一版无需 GET；APP 每次启动直接 PUT 成本更低且自然修复 Token 轮换。

### Route/Controller

官方推荐用隔离 Rails Engine、`config/routes.rb` 和挂载点：
[本地官方开发指南 `11-rails-autoloading.md:76-91`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/11-rails-autoloading.md:76)；
[官方 skeleton routes](https://github.com/discourse/discourse-plugin-skeleton/blob/main/config/routes.rb)。

Controller 约束：

- 继承 `::ApplicationController`；
- `requires_plugin PLUGIN_NAME`；
- `requires_login`；
- 要求 `is_user_api?`，不接受 cookie session 注册设备；
- User 只取 `current_user`，请求体不接受 `user_id`；
- `params.require(:device).permit(:token, :reply_enabled, :private_message_enabled)`；
- Token 非空且设合理上限（当前官方文档说明 Token 长度为 112，但服务端上限可留余量）；
- 按当前 User 限流，例如每分钟 10 次。

Discourse `ApplicationController` 默认启用 CSRF；经过验证的 User API Key
请求才绕过 CSRF，并同时绕过非 GET 的 XHR 限制，所以插件不应手动
`skip_forgery_protection`：
[本地源码 `application_controller.rb:22-34`](/Users/jackzhang/Code/discourse/app/controllers/application_controller.rb:22)；
[本地源码 `application_controller.rb:731-735`](/Users/jackzhang/Code/discourse/app/controllers/application_controller.rb:731)。

User API middleware 会查 active key、执行 route scope 匹配、拒绝
suspended/inactive User，并限流：
[本地源码 `default_current_user_provider.rb:193-218`](/Users/jackzhang/Code/discourse/lib/auth/default_current_user_provider.rb:193)。

### 为什么 v1 不新增专用 scope

当前 APP Authorization Request 是
`read,write,session_info`：
[本地 APP `AuthModels.ets:6-8`](/Users/jackzhang/Code/RiversideApp-HarmonyOS/app/entry/src/main/ets/auth/AuthModels.ets:6)。
所有认证请求都发送 `User-Api-Key` 和 `User-Api-Client-Id`：
[本地 APP `DiscourseHttpClient.ets:233-277`](/Users/jackzhang/Code/RiversideApp-HarmonyOS/app/entry/src/main/ets/network/DiscourseHttpClient.ets:233)。

核心 `write` scope 已匹配 GET/POST/PATCH/PUT/DELETE；新增
`discourse-riverside-push:device` 后：

- 旧 Authenticated Session 必须重新走 Authorization Request 才能拿到它；
- APP 若仍请求 `write`，专用 scope 没有产生实际最小权限收益。

依据：
[本地源码 `user_api_key_scope.rb:3-19`](/Users/jackzhang/Code/discourse/app/models/user_api_key_scope.rb:3)。

所以 v1 直接依赖现有 `write`。只有未来把 APP 的广泛 `write` 拆成一组
route-specific scopes 时，再用 `add_user_api_key_scope`。该 DSL 会自动加
插件名前缀：
[本地源码 `plugin/instance.rb:1027-1053`](/Users/jackzhang/Code/discourse/lib/plugin/instance.rb:1027)。

## 6. 事件监听与入队

`PostAlerter.push_notification` 当前顺序是：

1. 检查 User DND。
2. 触发 `:push_notification`。
3. 执行全部 `push_notification_filters`。
4. 检查核心 Web Push/Hub client。
5. 应用在线时间窗。
6. 入队核心 delivery Job。

源码：
[本地 `post_alerter.rb:73-99`](/Users/jackzhang/Code/discourse/app/services/post_alerter.rb:73)；
[官方仓库](https://github.com/discourse/discourse/blob/545168826bcc89dc631b5f3a641ad0a03970eb41/app/services/post_alerter.rb#L73-L99)。

事件位于 filters 和在线时间窗之前；源码注释明确要求订阅者自行复用
filters。因此 `NotificationEnqueuer` 必须：

1. 只接受同时含 `topic_id` 和 `post_id` 的 payload。
2. `notification_type` 只接受
   `Notification.types[:replied]` 和
   `Notification.types[:private_message]`。
3. 明确忽略 `posted`、`mentioned`、`group_mentioned`、`quoted`、
   `liked`、`reaction`、`invited_to_private_message` 和全部 Chat 类型。
4. 若 User 没有对应偏好已开启的 active key 设备则返回。
5. 执行所有 `DiscoursePluginRegistry.push_notification_filters`。
6. 复制核心 `push_notification_time_window_mins` 延迟算法。
7. 只入队 JSON 可序列化的标量/Array/Hash。

`Jobs.enqueue` 会 stringify key、验证 JSON 往返，并通过
`DB.after_commit` 入队：
[本地源码 `jobs/base.rb:379-418`](/Users/jackzhang/Code/discourse/app/jobs/base.rb:379)。

这两个类型在当前枚举中分别为 `replied: 2` 和
`private_message: 6`；`invited_to_private_message: 7`、`posted: 9`、
`reaction: 25` 以及 Chat 类型都是独立值，因此不应使用范围判断或
“所有 Topic/Post payload”判断：
[本地源码 `notification.rb:126-178`](/Users/jackzhang/Code/discourse/app/models/notification.rb:126)。

防御性检查还应确认：

- `replied` 对应的 `Topic#private_message?` 为 false；
- `private_message` 对应的 `Topic#private_message?` 为 true。

这样即使未来某个插件构造了类型与 Topic archetype 不一致的 payload，也不会
以错误分类发送。

## 7. Delivery Job

`Jobs::RiversidePush::DeliverNotification < ::Jobs::Base` 建议显式设置
有限重试次数，例如 5 次，并为暂态错误做退避。

Job 执行顺序：

1. 检查插件开关。
2. 重新加载 User；不存在、suspended 或 DND 时退出。
3. 再检查在线时间窗，仍在线则按剩余窗口重新排队。
4. 通过 `post_id` 重新加载 Post 和 Topic。
5. `Guardian.new(user).can_see?(post)`；不可见、删除或目标不存在则退出。
6. join `UserApiKey.active`，按当前通知类型重新查询对应开关已开启的 devices。
7. 在 `user.effective_locale` 下构造标题和正文。
8. Private Message 一律使用泛化标题和正文，避免锁屏泄漏。
9. 计算稳定 `notifyId`，对同一 Topic 的重试/高频 Reply 做覆盖。
10. 按 Huawei 上限分批发送。
11. 按响应更新设备成功/失败状态。

Guardian 会按对象类型分派到对应 `can_see_*?`：
[本地源码 `guardian.rb:204-209`](/Users/jackzhang/Code/discourse/lib/guardian.rb:204)。
`can_see_post?` 同时检查 Topic、Post 类型、删除和隐藏状态：
[本地源码 `post_guardian.rb:309-319`](/Users/jackzhang/Code/discourse/lib/guardian/post_guardian.rb:309)。

核心邮件 Job 也在异步执行时重新用 Guardian 校验 Post，说明这种二次校验
符合 Discourse 自身做法：
[本地源码 `user_email.rb:63-70`](/Users/jackzhang/Code/discourse/app/jobs/regular/user_email.rb:63)。

`notifyId` 取值必须在 `0..2147483647`，相同值可让新通知覆盖旧通知。
可用 `Zlib.crc32("#{Discourse.current_hostname}:topic:#{topic_id}")`
再限制到 31 位：
[Huawei 发送通知消息](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert)。

## 8. Huawei Push Kit 客户端

请求固定为：

```text
POST https://push-api.cloud.huawei.com/v3/{projectId}/messages:send
Content-Type: application/json
Authorization: Bearer <JWT>
push-type: 0
```

第一版 payload：

```json
{
  "payload": {
    "notification": {
      "category": "SUBSCRIPTION",
      "title": "...",
      "body": "...",
      "clickAction": {
        "actionType": 0,
        "data": {
          "kind": "post",
          "topic_id": 123,
          "post_id": 456
        }
      },
      "foregroundShow": true,
      "notifyId": 123456
    }
  },
  "target": {
    "token": ["..."]
  },
  "pushOptions": {
    "testMessage": true,
    "ttl": 86400
  }
}
```

V3 URL、Bearer JWT、`push-type: 0`、`clickAction`、`foregroundShow`、
`notifyId`、测试消息和 TTL 均来自华为官方通知消息文档：
[Huawei 发送通知消息](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert)。

分类：

- `replied` 且 Topic 不是 Private Message：`SUBSCRIPTION`。
- `private_message` 且 Topic 是 Private Message：`IM`。
- 其他所有类型直接忽略。
- 不发送推荐/运营内容，因此 v1 不用 `MARKETING`。

### JWT

`ServiceAccount` 从只读 JSON 校验 `project_id`、`key_id`、
`private_key`、`sub_account`。`JwtProvider` 使用 PS256：

- Header：`kid`、`typ=JWT`、`alg=PS256`。
- Payload：固定 `aud`、`iss=sub_account`、UTC `iat`、`exp=iat+3600`。
- 每个 Ruby 进程用 Mutex 做内存缓存，提前 5 分钟刷新。
- 文件 mtime 改变后立即丢弃缓存，以支持密钥轮换。
- 不把 JWT 放 Redis、数据库或日志。

这些字段和一小时有效期由华为官方定义：
[Huawei JWT 文档](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-jwt-token)。
当前 Discourse 依赖树已经包含 `jwt 2.10.1`：
[本地 `Gemfile.lock:315`](/Users/jackzhang/Code/discourse/Gemfile.lock:315)；
实现前仍应写一个 PS256 单测，防止依赖升级改变行为。

### HTTP 与响应

目标 host 固定为 `push-api.cloud.huawei.com`，不要把任意 API base URL
开放成设置，避免形成 SSRF 面。使用 Discourse 已有
`FinalDestination::HTTP`，设置 TLS、open/read timeout。

华为正常消息每次最多 1000 个 Token，测试消息最多 10 个，因此 batch size
根据 `riverside_push_test_message` 选择。消息体不含 Token 时仍不得超过
4096 bytes：
[Huawei REST 响应参数](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-scenariozed-api-response)。

响应策略：

| 情况 | 动作 |
| --- | --- |
| `80000000` | 全部成功，清零失败计数 |
| `80100000` | 解析 `msg` 内层 JSON，按 illegal token 原因逐个处理 |
| `80200005` | JWT 强制刷新后只立即重试一次 |
| HTTP 500/502/503、超时 | 抛暂态异常，交给有限 Sidekiq 重试 |
| 400/401、结构/权益/项目配置错误 | 不盲重试，记录 requestId 和原因计数并告警 |
| `tokenFormatError`/`tokenPlatformNotSupport` | 停用对应 device |
| `noRight` | 先视为项目/凭证配置问题，不批量删除 Token |

华为的 `msg` 在部分成功/全部 Token 无效时可能嵌套含完整 Token 的 JSON，
因此日志只能记录 `requestId`、业务码、reason counts 和本地 digest，不能
打印原始 body：
[Huawei REST 响应参数](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-scenariozed-api-response)。

## 9. APP 注册与退出契约

启动/登录：

1. Authenticated Session 可用后获取 Push Token。
2. `PUT /riverside-push/device.json`。
3. 每次冷启动重复 PUT。
4. `tokenUpdate` 回调拿到新 Token 后再次 PUT。

退出顺序必须在本地 key 清除之前完成：

1. 用当前 Authenticated Session 调
   `DELETE /riverside-push/device.json`。
2. 调 `pushService.deleteToken()`，即使步骤 1 网络失败也执行。
3. 用当前 key 调 Discourse core
   `POST /user-api-key/revoke`，撤销当前 User API Key。
4. 最后才清 HUKS 中的本地 session。

核心 revoke 端点允许 User API Key 撤销自身：
[本地 routes `routes.rb:1909-1918`](/Users/jackzhang/Code/discourse/config/routes.rb:1909)；
[本地 controller `user_api_keys_controller.rb:436-446`](/Users/jackzhang/Code/discourse/app/controllers/user_api_keys_controller.rb:436)。

当前 APP logout 只执行本地 store clear：
[本地 APP `AuthRepository.ets:122-153`](/Users/jackzhang/Code/RiversideApp-HarmonyOS/app/entry/src/main/ets/auth/AuthRepository.ets:122)。
这是实现客户端时必须补上的行为。

Push Kit 明确建议社交应用切换账号/退出登录时调用 `deleteToken`，否则同一
应用实例切换账号后可能收到旧账号消息：
[Huawei pushService API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-pushservice)。

如果服务器离线，DELETE 和 revoke 可能失败，但本地仍须继续
`deleteToken` 并清 session；Huawei Token 失效后插件发送会收到非法 Token，
随后停用服务端设备行。

## 10. 测试

最低 RSpec 矩阵：

### Request specs

- 匿名、cookie session、错误 scope 均不能 PUT/DELETE。
- current User API Key 可幂等 PUT。
- 请求里的 `user_id` 被忽略/拒绝。
- 相同 key 更新 Token 不增行。
- 相同 Token 被新 Authenticated Session 注册时安全转移。
- DELETE 只删除当前 key 的设备。
- 响应和日志不出现 Token。
- 限流生效。

### Model/service specs

- digest、唯一索引、active key scope。
- revoked/expired key 不进入发送查询。
- 直接 Reply 只接受 `replied`，映射为 `SUBSCRIPTION`。
- Private Message 只接受 `private_message`，映射为 `IM`。
- `posted`、mention、quote、like、Reaction、
  `invited_to_private_message` 和 Chat 全部被忽略。
- Private Message 内容始终泛化。
- filters、DND 和在线时间窗被遵守。

### Job/HTTP specs

- Post 删除或 Guardian 拒绝时不发送。
- Huawei success、partial success、invalid token。
- 500/502/503/timeout 有界重试。
- 400/401/配置错误不形成重试风暴。
- JWT 过期只刷新重试一次。
- 测试模式每批 10，正式模式每批 1000。
- 原始 Huawei body 不写日志。

官方插件后端使用 RSpec，前端使用 QUnit：
[本地官方测试指南 `06-acceptance-tests.md:11-23`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/06-acceptance-tests.md:11)。
当前官方插件的 request/job 测试可参考：
[RSS Polling request spec](/Users/jackzhang/Code/discourse/plugins/discourse-rss-polling/spec/requests/feed_settings_controller_spec.rb:3)；
[RSS Polling job spec](/Users/jackzhang/Code/discourse/plugins/discourse-rss-polling/spec/jobs/poll_feed_spec.rb:3)。

执行：

```sh
LOAD_PLUGINS=1 bin/rake plugin:spec[discourse-riverside-push]
```

核心 rake task 会收集插件 `spec/**/*_spec.rb` 并排除 system specs：
[本地源码 `plugin.rake:192-233`](/Users/jackzhang/Code/discourse/lib/tasks/plugin.rake:192)。
GitHub Actions 使用官方 skeleton 的 reusable workflow：
[本地官方 CI 指南 `08-ci-with-github-actions.md:7-31`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/03-code-internals/08-ci-with-github-actions.md:7)。

## 11. 安装、升级与发布

本地非 Docker 开发：

1. 独立 repo symlink 到 `/Users/jackzhang/Code/discourse/plugins/`。
2. 从 Discourse 根目录运行
   `LOAD_PLUGINS=1 bundle exec rake db:migrate`。
3. 重启 `bin/dev`。

[官方本地安装指南](https://meta.discourse.org/t/install-plugins-in-your-non-docker-development-environment/205337)。

生产 self-hosted：

1. 在 `/var/discourse/containers/app.yml` 的 `after_code` clone 插件。
2. 将服务账号 JSON 只读挂载进容器。
3. 备份。
4. `./launcher rebuild app`；rebuild 会安装插件并执行 migration。
5. 后台填写 JSON 路径、开启 test mode，先发测试 Token。
6. 验证后关闭 test mode 并开启插件。

[官方 self-hosted 安装指南](https://meta.discourse.org/t/install-plugins-on-a-self-hosted-site/19157)。

发布时 README 至少说明安装、设置、凭证挂载、Push 权益、退出语义和故障排查；
官方建议同时维护 GitHub README 和 Meta 插件 Topic：
[本地官方发布指南 `07-publish-your-plugin.md:13-73`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/04-plugins/07-publish-your-plugin.md:13)。

Discourse 更新频繁。主分支面向 latest；旧版本用
`d-compat/YYYY.M` 分支，官方 skeleton 已带自动创建 workflow：
[本地官方兼容指南 `05-version-compatibility.md:7-36`](/Users/jackzhang/Code/discourse/docs/developer-guides/docs/03-code-internals/05-version-compatibility.md:7)。

## 12. 建议分步提交

遵守“一步一提交”，每个点独立验证：

1. `chore(plugin): scaffold discourse-riverside-push`
   - skeleton、Engine、开关、core feature smoke spec。
2. `feat(push): persist devices for authenticated sessions`
   - migration、model、digest、active key scope、model specs。
3. `feat(push): add idempotent device registration endpoints`
   - PUT/DELETE、认证、strong params、限流、request specs。
4. `feat(push): enqueue reply and private message notifications`
   - 两项精确类型白名单、filters、时间窗、负向类型测试。
5. `feat(push): build secure harmony notification payloads`
   - Guardian、隐私正文、分类、notifyId、payload specs。
6. `feat(push): authenticate with huawei service account`
   - 只读 JSON、PS256 JWT、缓存/轮换、JWT specs。
7. `feat(push): deliver notifications through push kit`
   - HTTP、batch、响应解析、重试、token invalidation、WebMock specs。
8. `chore(push): prune stale device registrations`
   - scheduled job 和保留期 specs。
9. `docs(push): document deployment and operations`
   - README、app.yml volume 示例、权益与告警 runbook。

APP 侧另起提交序列：获取/更新 Token、启动 PUT、点击路由、退出清理。

## 13. v1 验收条件

- 插件关闭时不监听、不入队、不发送。
- 一个 User 的 active Authenticated Session 可注册一个 Push Token。
- revoked/expired key 的设备绝不发送。
- 只发送核心 `:push_notification` 给出的 `replied` 和
  `private_message` payload。
- watched Topic 普通新 Post、mention、quote、Like、Reaction、
  Private Message 邀请和 Chat 均不会发送。
- filters、DND、在线时间窗和 Guardian 均生效。
- 直接 Reply 使用 `SUBSCRIPTION`，Private Message 使用 `IM`。
- 私密 Topic 默认不在锁屏泄露标题/摘要。
- 无 Token、私钥、JWT、User API Key 出现在响应或日志。
- 502/503/timeout 可恢复，永久错误不会形成重试风暴。
- logout 执行服务端注销、Push Token 删除、User API Key revoke，再清本地 session。
- plugin RSpec、迁移和独立 CI 全部通过后才进入真实消息小流量验证。
