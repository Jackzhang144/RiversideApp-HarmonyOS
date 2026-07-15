# API 23 媒体选择、上传、保存、分享与传输契约

日期：2026-07-12
范围：HarmonyOS Phone、冻结 Flutter 参考 `9d8b13c`；本记录不改应用代码、`module.json5`、服务端或权限。

## 结论

当前对等实现应采用“系统选择器 → 应用缓存副本 → 前台 Discourse multipart 上传”链路。图片保存使用 SaveButton 或一次性保存授权弹窗，保持最小权限；对外分享在冻结 Flutter 中没有媒体分享实现，不能把 Share Kit 当作已有对等项。系统传输任务具有暂停/恢复能力，但冻结 Flutter 与现有 Discourse `/uploads.json` 契约都没有服务端断点续传协议，故本阶段不可承诺跨中断续传。

当前 `app/entry/src/main/module.json5` 仅声明 `ohos.permission.INTERNET`；这正是本阶段所需的最小权限集合。

## 冻结 Flutter 行为与范围裁决

| 事项 | 冻结参考证据 | HarmonyOS 对等结论 |
| --- | --- | --- |
| 选择及上传图片 | `profile_page.dart` 的头像/背景使用 `ImagePicker().pickImage` 后读取字节；`api.dart` 以 `POST /uploads.json` 的 multipart `file` 上传。编辑器和 Chat 也分别调用同一上传端点。 | 必须实现。头像、背景、Topic/Reply 编辑器和 Chat 都应复用同一受限媒体管线，但由各业务决定后续提交。 |
| 保存图片 | `utils.dart` 下载原图字节，`image_save_io.dart` 写临时文件并存入图库。 | 必须实现。长按/查看器操作应下载到应用缓存，再在用户明确确认下保存到图库。 |
| 复制链接、浏览器打开 | `utils.dart` 的图片操作菜单提供复制链接和外部浏览器打开。 | 必须实现为独立的复制/外部导航策略；不是媒体文件分享。 |
| 媒体外部分享 | `pubspec.yaml` 没有 Share Kit/`share_plus` 依赖，`lib/` 未找到媒体分享调用。 | 不属于冻结 Flutter 的既有行为；若产品后续要加，应作为新增能力单列验收。 |
| 断点续传 | `pubspec.yaml` 与 `lib/` 未见传输队列、范围请求、上传会话或恢复实现。 | 不属于冻结行为。API 23 可提供系统任务的暂停/恢复，但不能在无服务端协议变更的条件下宣称业务级断点续传。 |

## 选图与上传契约

1. 使用 `PhotoPickerComponent`（需要轻量触发式界面时再评估 `PhotoViewPicker`），不申请相册读权限。官方指南明确：用户选择后应用可访问所选媒体，回调 URI 是只读 URI；不要解析 URI，也不要把它视为永久文件路径。
2. 选中后立即在前台把内容复制到 `context.cacheDir`，并保存受控的显示名、推断 MIME、大小与本次操作 ID。这里“立即复制”是基于官方只读 URI 授权模型和 Request 的输入限制作出的实现推论，用于避免把选择器授权句柄持久化。
3. 上传使用已有的 Discourse 请求头与 `POST /uploads.json` multipart 语义：`type=composer`、`synchronous=true`、`file`；头像还须携带 Flutter 已有的 `client_id`、`user_id`、`upload_type` 等业务字段。上传成功后才向编辑器插入 Markdown、向 Chat 带入 `upload_ids`，或更新 Profile。
4. API 23 的 `request.uploadFile` 可提交 multipart/form-data、表单数据、请求头与上传进度，但其文件 URI 仅支持 `internal://cache/`。因此不能把 PhotoPicker URI 直接传给 Request；缓存副本是必经步骤。小图片应优先前台上传，失败后让用户明确重试，确保“上传成功”和“发帖/发送成功”是两个可见状态。
5. 高像素图片不得默认整图解码进 UI 内存；先读取元数据，再按目标（头像裁剪、背景、编辑器原图）选择缩放/编码策略，并显示大小限制与失败原因。

## 保存图片契约

- 图片查看器先以受认证请求下载原图；下载为空、HTTP 失败、MIME 不被设备支持或写缓存失败，均不得显示“已保存”。
- 仅当用户点“保存图片”时发起保存。优先使用 `SaveButton` 或官方保存授权弹窗，两者都可避免声明受限的 `ohos.permission.WRITE_IMAGEVIDEO`。API 20+ 的 SaveButton 授权窗口为 1 分钟，保存写入必须发生在该授权窗口内。
- 不申请 `WRITE_IMAGEVIDEO`，不进行全量相册扫描，不创建后台自动下载。保存成功才展示成功反馈；用户拒绝授权、授权过期或保存失败应给出可操作的失败反馈。

## 外部分享与传输契约

- 若用户日后明确要求“分享图片”，使用 `systemShare.ShareController`，并为缓存副本构造精确 UTD/MIME 与 `fileUri.getUriFromPath(...)`。`show(...)` 失败、用户取消或无可用目标都应被建模为未完成，不应误报已分享。
- 该能力是新增范围，不能与 Flutter 对等验收混在同一个完成条件中。
- `request.agent` 支持前后台任务、进度、暂停和恢复，适合未来确有大文件的系统传输场景；任务 ID 可查询。但应用级“断点续传”仍依赖服务器接收范围、会话 ID、分片校验和幂等完成语义。现有 Discourse 同步 `/uploads.json` 没有这些证据，且本项目不改服务端，故当前上传失败统一从头重试。
- 不因传输而申请长时任务或常驻通知；官方后台建议也明确文件上传下载应使用系统传输服务而非申请长时任务。

## 权限与用户同意点

| 行为 | 权限 | 用户同意 |
| --- | --- | --- |
| 选择一张图片 | 无新增权限 | 用户在系统选择器中选择；只读取所选 URI。 |
| 上传到 RiverSide | `INTERNET`（已声明） | 用户点击上传/发送；显示进度并允许取消/重试。 |
| 保存到图库 | 无新增权限 | 用户点击 SaveButton 或接受保存授权弹窗。 |
| 分享缓存图片（未来新增） | 无新增权限 | 用户主动打开系统分享面板并选择目标。 |
| 业务级断点续传 | 不适用 | 当前不实现；需要新的服务端契约与用户可见队列设计。 |

## 设备验收（实施票必须执行）

1. 普通账号在“测试专用”Category 的编辑器选择一张 JPEG/PNG，撤销选择不产生上传；确认上传后，帖子只在服务器返回 upload 成功时插入正确 Markdown。
2. Chat 图片发送覆盖“仅图片”和“图片加文字”：上传失败不得发送占位消息；发送失败保留可重试草稿，不重复创建上传。
3. 头像与个人页背景分别覆盖裁剪、上传失败、服务器返回缺少 `id`/`url` 以及刷新后回显；这些是账户资料操作，执行前须由用户确认测试账号影响范围。
4. 图片查看器保存：第一次接受授权、拒绝授权、授权过期后重试、网络下载失败、成功后在图库可见；全程不新增相册广泛权限。
5. 复制链接和外部浏览器打开保持现有站内/外部导航安全策略；它们不得绕过 ArkWeb 的精确白名单决策。
6. 使用物理 Phone 完成上述主路径。模拟器只作为开发冒烟，不能替代图库、分享面板或跨应用结果验收。

## 官方资料

- [使用 PhotoPicker 组件访问图片/视频](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/component-guidelines-photoviewpicker)：无相册读权限、回调只读 URI 与使用约束。
- [保存媒体库资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-savebutton)：SaveButton/授权弹窗可免 `WRITE_IMAGEVIDEO`。
- [SaveButton API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ts-security-components-savebutton)：API 20+ 的授权时长。
- [@ohos.request 上传下载 API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-request)：`uploadFile`、缓存 URI 限制、进度事件，以及 `request.agent` 的任务控制。
- [应用文件上传下载](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/app-file-upload-download)：系统任务、后台代理与网络配置。
- [分享图片](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/share-utd-image)：Share Kit 的 `SharedData`、精确 UTD、沙箱文件 URI 与失败处理。
- [后台上传下载合理使用](https://developer.huawei.com/consumer/cn/doc/best-practices/bpta-reasonable-request-use)：使用系统传输服务而非长时任务。
