# Flutter `9d8b13c` 契约冲突裁决

## 适用范围与证据优先级

本决议只针对冻结 Flutter 提交 `9d8b13cfabcb04538c33be87022f64612fb06b56` 中的两处冲突。当前模型和冻结测试是权威证据；`captures/README.md` 与单个请求注释仅是抓包说明，不能覆盖已更新的实现与测试。

## 决议一：认证校友谓词

**权威规则：**`AccountInfo.isVerified` 只有在下列任一条件成立时为真：

1. `groups` 包含 `verified_uestcer`、`scuer`、`swufer`、`swjtuer` 或 `sicnuer`；
2. `primary_group_id` 是 `41`、`45`、`46`、`48` 或 `49`；
3. `flair_group_id` 是同一组 ID 集合。

`rs_developer`（ID `50`）是已知开发者组和 Flair 来源，但不属于上述认证校友集合。角色标签与认证标签是分开的：管理员、版主、开发者的角色显示不得改变 `isVerified` 的结果。

权威源码与测试：

- [models.dart](../../../RiversideApp/lib/models.dart#L220-L250) 定义已知组、认证组 ID 与名称集合；[models.dart](../../../RiversideApp/lib/models.dart#L358-L394) 按组名、primary ID、flair ID 计算 `isVerified` 并单独计算角色标签。
- [topic_permissions_test.dart](../../../RiversideApp/test/topic_permissions_test.dart#L58-L106) 覆盖五个认证校友组的三种输入形态，并断言 `rs_developer` 为未认证。
- [profile_page.dart](../../../RiversideApp/lib/pages/profile_page.dart#L378-L408) 直接以 `account.isVerified` 呈现“已认证/未认证”。

`captures/README.md` 中“仅 `verified_uestcer` 或 flair 为该组”的规则是旧样本注释，不能作为 ArkTS 实现依据。[captures/README.md](../../../RiversideApp/captures/README.md#L160-L166)

## 决议二：Chat Reaction

**权威规则：**每条 ChatMessage 都必须保留并显示服务端 `reactions[]`。每个 Reaction 至少保留 `emoji`、`count`、`users[]` 和当前用户的 `reacted` 状态。

- 消息气泡仅在 `reactions` 非空时显示 Reaction 行；每个 Emoji 显示图标和总数，`reacted=true` 使用选中视觉。点击任一 Reaction 打开摘要，显示总数、服务端返回的用户列表及“服务端总数大于明细人数”的差异提示。
- 长按消息提供“表情点评”；选择 Emoji 后以 `PUT /chat/{channelId}/react/{messageId}` 发送表单字段 `react_action`（默认 `add`）和 `emoji`，成功后刷新消息列表。
- 乐观发送的新消息初始 Reaction 为空；这不代表服务端返回消息可忽略 Reaction。

权威源码与测试：

- [models.dart](../../../RiversideApp/lib/models.dart) 的 `ChatMessage`/`ChatReaction` 解析路径与 [chat_reaction_test.dart](../../../RiversideApp/test/chat_reaction_test.dart#L5-L140) 要求保留 Reaction、用户明细、图片-only 消息及排序语义。
- [api.dart](../../../RiversideApp/lib/api.dart#L986-L996) 定义 Chat Reaction 写入请求。
- [chat_page.dart](../../../RiversideApp/lib/pages/chat_page.dart#L836-L855) 触发选择与发送；[chat_page.dart](../../../RiversideApp/lib/pages/chat_page.dart#L1221-L1298) 呈现摘要；[chat_page.dart](../../../RiversideApp/lib/pages/chat_page.dart#L1447-L1517) 呈现消息 Reaction 行。

抓包本身已包含 `reactions[]` 字段，但其“未建模/未显示”注释已过期，必须拒绝该结论。[2026-05-17-messages-with-image.request.txt](../../../RiversideApp/captures/chat/2026-05-17-messages-with-image.request.txt#L7-L18)

## ArkTS 对等约束

- 认证模型应把“认证校友”和“开发者/管理员/版主角色”建模为独立布尔/枚举语义；不得通过 UI 文案或单一 Flair 推导认证。
- Chat DTO、持久状态和 UI 均不得丢弃 `reactions[]`；Reaction 行、用户摘要、当前用户选中态和写入后的刷新属于同一个验收闭环。
- 后续票的测试必须涵盖五个认证校友组、`rs_developer` 反例、Reaction 为空/有值、用户明细不全、添加 Reaction 与刷新回读。
