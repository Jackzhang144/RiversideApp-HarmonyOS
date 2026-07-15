# Huawei Push Kit 服务端与 HarmonyOS APP 端接入方案

> 调研日期：2026-07-15
> 适用工程：`RiversideApp-harmonyos`，HarmonyOS API 23，包名 `cc.river_side_hm.app`

## 1. 结论

本需求可以用 Huawei Push Kit 实现，并且不需要让 APP 驻留后台。服务端必须发送 Push Kit **通知消息**，即请求头 `push-type: 0`；这类消息由系统展示，应用进程不存在时也能到达通知中心、锁屏或横幅。

不要使用 `push-type: 6` 的后台消息替代通知消息。后台消息不展示通知、不响铃、不更新角标；应用进程不在时只会缓存并等待应用后续启动，不符合“用户没有驻留后台也能收到提醒”的目标。

建议的完整链路是：

1. APP 启动后获取 Push Token，并用当前已登录的 Discourse User API Key 注册到业务服务端。
2. 服务端保存“Discourse 用户 + APP 客户端 + Push Token + 匿名 profileId”的绑定关系。
3. Discourse 产生私信、回复、提及、点赞等事件后，由插件订阅 `push_notification` 事件并异步入队。
4. 推送 Worker 用服务账号私钥生成 PS256 JWT，调用 Push Kit v3 发送通知消息。
5. 系统在 APP 进程不存在时展示通知；用户点击后，APP 从 Want 中解析最小路由参数并进入 Topic、帖子或聊天页面。
6. 服务端接收 Push Kit V2 送达回执，清理卸载、Token 失配等无效注册。

## 2. 当前工程现状与缺口

当前工程还没有接入远程 Push：

- `app/AppScope/app.json5` 的正式包名是 `cc.river_side_hm.app`。
- `app/build-profile.json5` 的目标和兼容 SDK 都是 `6.1.0(23)`。
- `app/entry/src/main/module.json5` 只有 `ohos.permission.INTERNET`，`EntryAbility` 没有 `singleton` 启动模式，也没有 `action.ohos.push.listener` skill。
- `EntryAbility.ets` 只初始化现有上下文和原型通知服务，没有调用 `getToken()`、监听 `tokenUpdate`、处理前台通知或实现 `onNewWant()`。
- 正式消息中心当前通过 Discourse API 拉取数据，APP 回到前台时刷新；现有验证文档明确说明未注册 Push Token，也没有后台轮询。
- `SystemNotificationService.ets` 是原型用的本地 NotificationKit 发布，不是远程 Push 链路。
- 相邻 Flutter 工程的 `push_service.dart` 使用 WorkManager 周期性轮询并发布本地通知，也不是 Push Kit 的服务端事件推送，不能直接照搬。

因此，这不是只在 APP 中增加一个 SDK 调用就能完成的功能；APP、Discourse 服务端、AGC 配置和验收环境必须一起交付。

## 3. AGC 和签名准备

### 3.1 开通能力

1. 在 AppGallery Connect 创建或关联包名为 `cc.river_side_hm.app` 的应用。
2. 在“开发与服务 → 增长 → 推送服务”开通 Push Kit。
3. 确认项目的数据处理位置与服务端、目标用户所在区域匹配。当前官方文档说明 Phone、Tablet、PC/2in1 的 Push Kit 服务仅支持中国境内，不含港澳台。
4. 为实际业务申请通知自分类权益。未申请或分类不匹配时，消息按 `MARKETING` 处理，通常会被静音并受每天每设备 2 条或 5 条限制。

建议按真实语义申请和发送：

| Riverside 事件 | 建议 category | 注意事项 |
| --- | --- | --- |
| 一对一私信、直接聊天 | `IM` | 只用于真实即时通信，不得混入运营内容 |
| 回复、提及、点赞、关注等论坛互动 | `SUBSCRIPTION` | APP 内需要提供独立通知开关，文案必须匹配获批场景 |
| 内容推荐、活动运营 | `MARKETING` | 受严格频次和静音策略约束，不属于本期核心消息链路 |

### 3.2 调试和发布签名

- 手动调试签名：开通 Push Kit 后重新申请包含 Push 能力的调试 Profile。
- DevEco 自动签名：关联已注册应用并勾选 Push Kit 开放能力；AGC 能力同步可能需要 5 至 10 分钟。
- 发布包：Push Kit 开通后重新申请发布 Profile，并使用发布证书签名。
- HarmonyOS NEXT Developer Beta2 起不再需要按旧 Android HMS 教程配置公钥指纹和 Client ID。

## 4. APP 端设计

### 4.1 Token 生命周期

Push Kit 是系统 Kit，直接使用：

```ts
import { pushService } from '@kit.PushKit';
```

建议新增类型严格的 `PushRegistrationService`，职责如下：

1. `EntryAbility.onCreate()` 每次启动调用一次 `pushService.getToken()`。
2. API 23 注册 `pushService.on('tokenUpdate', this, callback)`，Token 变化后重新上报。
3. 不根据 Token 长度做判断，不高频重复申请，不在日志打印完整 Token。
4. 只有存在已认证会话时，才调用业务服务端注册接口；未登录时暂存最新 Token，登录完成后再绑定。
5. 注册接口成功返回匿名 `profileId` 后，调用 `bindAppProfileId()`；Token 更新后需要重新绑定，因为 Token 变化会解除已有账号绑定关系。

Push Token 代表应用实例，不代表当前业务账号。账号 A 退出后若只保留 Token 映射，账号 B 可能看到发给 A 的私信。因此建议：

- 登录：注册 Token → 服务端返回 HMAC 派生的匿名 `profileId` → APP 绑定 profileId。
- 退出/切号：先注销服务端注册 → `unbindAppProfileId()` → 对私密社交场景可进一步 `deleteToken()` → 清理本地会话。
- 新账号登录后重新 `getToken()`、注册并绑定。
- `profileId` 不使用真实用户 ID，最大 64 字符；服务端发送时必须同时携带 Token 与相同的 `notification.profileId`。

### 4.2 通知权限

Push Kit 本身不需要在 `module.json5` 增加额外 Push 权限，但系统通知展示需要用户授权：

```ts
notificationManager.isNotificationEnabled();
notificationManager.requestEnableNotification(context);
```

应把授权请求放在用户能理解的时机，例如登录成功后或开启“消息推送”开关时，并完整处理已允许、拒绝、稍后开启和跳转系统设置等状态。不能把发起请求等同于授权成功。

### 4.3 前台与后台行为

本项目建议服务端发送 `foregroundShow: false`：

- 后台或进程不存在：Push Kit 由系统展示通知。
- APP 前台：不重复弹系统通知，而是通过 `pushService.receiveMessage('DEFAULT', ...)` 接收后刷新正式消息中心、未读数和当前会话。

为此前台接收能力，需要在 `EntryAbility` 的独立 skill 中配置唯一的 `action.ohos.push.listener`。同一应用只能有一个 Ability 声明该 action。

如果后续产品决定前台也必须显示系统通知，可改成 `foregroundShow: true`；此时系统负责展示，`receiveMessage` 不会收到该通知消息。

### 4.4 点击通知和应用内导航

当前 APP 是单一 `EntryAbility` 加内部 Navigation/AppShell，建议使用：

- `clickAction.actionType: 0`，点击后进入现有入口 Ability。
- `clickAction.data` 只携带最小、带版本的路由数据，例如 `routeType`、`topicId`、`postNumber`、`channelId`、`chatMessageId`、`eventId`。
- `EntryAbility` 配置 `launchType: "singleton"`。
- 冷启动在 `onCreate(want, ...)` 解析；热启动在 `onNewWant(want, ...)` 解析。
- 新增 `PushNavigationCoordinator` 缓冲路由意图：Ability 可能先于页面和认证会话初始化，不能收到 Want 后直接访问尚未就绪的 UI 状态。
- `Index.ets` 就绪后消费路由意图，复用现有 Topic/帖子/聊天导航，并从服务端重新读取权威数据。

通知 payload 不能替代鉴权和业务查询，也不要包含整份帖子或私信对象。锁屏内容只放必要摘要；私信等敏感内容可使用“你有一条新消息”，详情进入 APP 并完成会话校验后再加载。

建议的服务端通知片段：

```json
{
  "payload": {
    "notification": {
      "category": "SUBSCRIPTION",
      "title": "有人回复了你的主题",
      "body": "点击查看回复",
      "profileId": "opaque-profile-id",
      "foregroundShow": false,
      "notifyId": 230041,
      "clickAction": {
        "actionType": 0,
        "data": {
          "version": 1,
          "routeType": "topicPost",
          "topicId": 2300,
          "postNumber": 41,
          "eventId": "notification-9876"
        }
      }
    }
  },
  "target": {
    "token": ["PUSH_TOKEN"]
  },
  "pushOptions": {
    "ttl": 86400,
    "biTag": "notification-9876"
  }
}
```

## 5. 服务端设计

当前工作区没有 Discourse 服务端源码。推荐在部署于 `river-side.cc` 的 Discourse 中增加独立插件；如果服务端仓库另有位置，需要在实现前把它加入任务范围。

### 5.1 注册接口

建议插件提供：

```text
PUT    /riverside-push/v1/registration
DELETE /riverside-push/v1/registration
POST   /riverside-push/v1/receipts/huawei
```

`PUT` 请求体可包含：

```json
{
  "token": "PUSH_TOKEN",
  "appVersion": "1.0.0",
  "sdkApi": 23,
  "notificationsEnabled": true
}
```

当前 APP 的 User API Key scope 已包含 `read,write,session_info`，可继续使用现有 User API Key Header 调用插件接口。服务端必须从认证上下文取得 `current_user` 和客户端 ID，不能接受 APP 自报的用户 ID。

注册表至少保存：

- Discourse user、现有 User API 客户端 ID；
- Push Token 密文和用于唯一索引的不可逆摘要；
- 服务端生成的匿名 profileId；
- APP 版本、SDK API、通知开关、最后上报时间；
- active/disabled/uninstalled/token_mismatch/inactive 等状态和原因。

Token 上传使用幂等 upsert。私钥、JWT、完整 Token、私信正文不得写入普通日志。

### 5.2 Discourse 事件入口

不建议在每个帖子、通知和聊天 Job 中分别增加 Huawei 请求。Discourse 的论坛通知和 Chat 通知最终都会调用 `PostAlerter.push_notification(user, payload)`，该方法触发统一事件：

```ruby
on(:push_notification) do |user, payload|
  # 校验通知偏好、过滤器和时间窗后，只写 outbox / enqueue Sidekiq
end
```

需要注意：`push_notification` 事件发生在 DND 检查之后，但早于 Discourse 原有 push filters 和 `push_notification_time_window_mins` 延迟逻辑。插件必须重用或等价执行这些过滤/时间窗规则，避免绕过用户偏好；事件回调中只入队，不同步访问 Huawei。

Forum payload 已包含 `notification_type`、`topic_id`、`post_id`、`post_number`、`post_url` 等；Chat 通知包含 `channel_id`、`chat_message_id`、`is_direct_message_channel` 等，足以转换为最小 Push 路由。

### 5.3 Huawei 鉴权与发送

在华为 API Console 创建 Push 服务账号密钥 JSON，核心字段为：

- `project_id`
- `key_id`
- `sub_account`
- `private_key`

服务端生成 PS256 JWT：

- Header：`kid=key_id`、`typ=JWT`、`alg=PS256`
- Payload：`iss=sub_account`
- `aud=https://oauth-login.cloud.huawei.com/oauth2/v3/token`
- `iat` 为当前 UTC 秒；`exp=iat+3600`

HarmonyOS 5+/NEXT v3 不再使用旧 OAuth2 令牌交换。生成的 JWT 直接用于：

```http
POST https://push-api.cloud.huawei.com/v3/{projectId}/messages:send
Content-Type: application/json
Authorization: Bearer <JWT>
push-type: 0
```

JWT 在有效期内缓存复用，服务器必须校时。当前 v3 的目标只支持 Token 数组：普通请求最多 1000 个 Token，测试请求最多 10 个；测试项目每天最多 1000 条。消息体不含 Token 最大 4096 Bytes，`ttl` 默认 1 天、最大 15 天。

发送接口返回 HTTP 200 和 `code="80000000"` 只表示华为接受请求，不表示设备已经展示或用户已经阅读。`80100000` 代表部分 Token 成功，必须解析 `illegalTokens`，不能整批标记成功。

### 5.4 队列、幂等与重试

建议结构：

```text
Discourse event
  -> push outbox（business_event_id + registration_id 唯一）
  -> Sidekiq worker
  -> Huawei client
  -> send result / requestId
  -> receipt callback
```

- 400/401/404：参数、鉴权或 URI 错误，修复后再发送，不盲重试。
- 500/502/503、明确网络瞬态错误：有限次数、带抖动的退避；503 还需要主动摊平发送速率。
- `80200005`：JWT 过期，刷新 JWT 后最多重试一次。
- 请求超时且服务端状态未知：不要无限重发；稳定 `notifyId` 可降低重复通知堆叠。
- 使用稳定的 `business_event_id`、唯一 outbox 键和有限状态机保证业务幂等。

### 5.5 送达回执

在 AGC 开启 V2 消息回执，并配置使用商用 CA 证书的 HTTPS 回调。校验：

```text
X-HUAWEI-CALLBACK-ID.value
= Base64(HMAC-SHA256(secret, timestamp + nonce + userName))
```

除 HMAC 外，还要校验 timestamp 有效窗口、缓存 nonce 防重放。成功处理后返回：

```json
{"code":"0","message":"success"}
```

重点处理结果：

- `2` 应用卸载、`5` Token 不匹配：停用并删除对应 Token 映射。
- `6` 通知/渠道关闭：标记禁用，避免无效推送。
- `10` 设备 30 天未联网：标记不活跃，降低或暂停发送。
- 回执是送达状态，不是阅读/点击状态；点击统计需 APP 根据 `eventId` 单独上报。

## 6. 分阶段实施建议

### 阶段一：AGC 与最小通知闭环

- 开通 Push Kit、配置正确签名、创建服务账号。
- APP 获取并显示脱敏 Token；用 AGC 或最小服务端脚本发送 `testMessage`。
- 验证前台、后台、进程被系统回收、点击冷启动。

### 阶段二：APP 正式接入

- 实现 Token 获取/更新/注册，通知授权状态和用户开关。
- 实现 profileId 绑定、退出解绑和严格的账号切换流程。
- 实现 `singleton`、`onNewWant()`、前台消息接收和路由协调器。
- 为 payload 解析、Token 生命周期、路由缓冲和账号切换补单元测试。

### 阶段三：Discourse 插件

- 实现注册表和 User API Key 认证接口。
- 订阅 `push_notification`，兼容偏好、过滤器和时间窗。
- 实现 outbox/Sidekiq、JWT 客户端、分类映射、部分成功和重试。
- 先仅对内部测试账号发送 testMessage，再逐步开放正式 Token。

### 阶段四：回执、运营与发布

- 开启并验证 V2 回执，完成 Token 清理和发送指标。
- 完成 IM/SUBSCRIPTION 场景化权益申请和 APP 独立开关。
- 使用发布 Profile 做实体设备验收，准备密钥轮换、告警和回滚开关。

## 7. 验收矩阵

至少覆盖：

- APP 前台：`foregroundShow=false` 时不重复弹通知，消息中心和当前会话刷新。
- APP 后台、进程被系统回收：系统正常展示；点击冷启动到目标内容。
- APP 已运行：点击通知进入 `onNewWant()`，不创建重复 Ability。
- 设备离线再上线：TTL 内补发，超时不补发；`collapseKey` 行为符合预期。
- 通知关闭/重新开启：APP 状态和回执结果正确。
- 卸载重装：旧 Token 失效，新 Token 自动注册。
- A 账号退出并登录 B：A 消息不会展示给 B，B 重新绑定后正常接收。
- Token 部分非法、JWT 过期、HTTP 503：部分成功、清理和退避逻辑正确。
- 锁屏、重启未解锁、休眠、系统回收、用户手动强行停止分别测试。

官方文档说明普通 Push 通知支持模拟器，但不支持云真机调试。当前本机只有 API 23 模拟器，因此普通联调可以先做；进程回收、锁屏、重启、休眠、通知开关和强行停止的最终结论必须在正确签名的实体 HarmonyOS 手机上验证。官方保证“应用进程不存在”可推送，但未找到“用户手动强行停止/禁用应用后仍保证送达”的等价承诺，两者不能混为一谈。

## 8. 官方资料与源码依据

### Huawei Push Kit

- [Push Kit 简介](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-kit-introduction)
- [开通推送服务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-config-setting)
- [申请场景化消息权益](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-apply-right)
- [获取 Push Token](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-get-token)
- [pushService API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-pushservice)
- [发送通知消息](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-send-alert)
- [发送后台消息](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-background)
- [基于服务账号生成鉴权令牌](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-jwt-token)
- [v3 请求结构](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-scenariozed-api-request-struct)
- [v3 请求参数](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-scenariozed-api-request-param)
- [v3 响应与错误码](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-scenariozed-api-response)
- [消息回执](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/push-msg-receipt)
- [官方 ArkTS 客户端示例](https://gitcode.com/harmonyos_samples/push-kit-sample-code-clientdemo-arkts)
- [官方 Java 服务端示例](https://gitcode.com/harmonyos_samples/push-kit_-sample-code_-server-demo_-java)

### Discourse 当前主线源码（固定提交 `9c00d07ef97b0b798df80d67089b5fd4022158a5`）

- [PostAlerter 统一 push_notification 事件](https://github.com/discourse/discourse/blob/9c00d07ef97b0b798df80d67089b5fd4022158a5/app/services/post_alerter.rb)
- [Notification 创建事件](https://github.com/discourse/discourse/blob/9c00d07ef97b0b798df80d67089b5fd4022158a5/app/models/notification.rb)
- [Chat notifier](https://github.com/discourse/discourse/blob/9c00d07ef97b0b798df80d67089b5fd4022158a5/plugins/chat/lib/chat/notifier.rb)
- [Chat mentioned job](https://github.com/discourse/discourse/blob/9c00d07ef97b0b798df80d67089b5fd4022158a5/plugins/chat/app/jobs/regular/chat/notify_mentioned.rb)
- [Chat watching job](https://github.com/discourse/discourse/blob/9c00d07ef97b0b798df80d67089b5fd4022158a5/plugins/chat/app/jobs/regular/chat/notify_watching.rb)

## 9. 当前尚未验证的外部条件

本次是方案研究，没有修改 APP 业务代码，也没有实际向 Huawei Push API 发送消息。以下外部状态在当前工作区无法确认：

- AGC 中是否已创建并正确关联 `cc.river_side_hm.app`；
- Push Kit 是否已开通，IM/SUBSCRIPTION 权益是否已申请；
- 调试/发布 Profile 是否已经包含 Push 能力；
- Huawei 服务账号密钥和回执配置是否已准备；
- `river-side.cc` 的 Discourse 插件源码和部署入口；
- 正确签名的实体 API 23 手机。

进入实现前，最有价值的下一步是先完成 AGC 开通与签名确认，并把 Discourse 服务端插件仓库/部署方式纳入同一交付范围。
