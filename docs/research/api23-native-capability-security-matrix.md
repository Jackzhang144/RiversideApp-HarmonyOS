# API 23 手机端原生能力与安全边界矩阵

> 范围：冻结 Flutter `9d8b13c` 的手机端能力；结论基于 2026-07-12 由 `devecocli docs` 读取的华为官方文档。本文是后续实现票的约束，不修改现有 `module.json5`。当前工程仅声明了 `ohos.permission.INTERNET`。

## 决策摘要

API 23 能完成所需原生能力，但不能把 Flutter 插件逐个“替换/移植”。应以 ArkUI + 平台 Kit 重建边界：论坛正文优先原生受限渲染；只有必须的可信嵌入页面使用隔离 ArkWeb；照片选择、保存、通知、文件传输和安全会话分别走 MediaLibraryKit、NotificationKit/PushKit、Request Kit、HUKS。后台轮询不是可靠的通知机制，Push Kit 还需要服务端接入和真实设备验收。

## 能力矩阵

| 冻结功能 | API 23 原生实现与许可 | 安全/约束 | 必须的真机验收 |
| --- | --- | --- | --- |
| 富文本 Post、链接、Bilibili/外部嵌入 | 原生解析并只渲染许可的 Discourse 标记；确实需要 H5/播放器时才用 `Web`/ArkWeb。加载网络内容保留 `INTERNET`。 | 不把服务端 HTML 当可信模板：禁用任意 JS 字符串执行、保持 `mixedMode(None)`、拒绝 SSL 错误；ArkWeb URL trust list 只能放本方精确 HTTPS 域名，不能放公共 CDN。若注册 JS bridge，必须用 `JavaScriptProxy.permission` 的 URL 白名单；不要给不可信 Post/嵌入 bridge。 | XSS payload、`javascript:`/非 HTTPS、跳转到非白名单域、失效证书、iframe/播放器返回键、登录 Cookie 隔离和长帖性能。 |
| 站内/外链导航与登录 WebView | 站内受信页面可在 ArkWeb；外链按显式用户操作交给系统/Share Kit 方案，不能无确认地把任意 URL 交给 Web 或 Ability。 | 解析和 allowlist scheme/host；禁止把 URL/HTML/JS 直接拼入 `loadData`/`runJavaScript`；不要把 API key、session 或 HUKS 明文暴露给 Web。 | Discourse OAuth/API-key 返回、深链、`mailto`/电话/未知 scheme、无处理应用、取消和回到原页面。 |
| 选图、头像/正文多图上传 | `PhotoPickerComponent` 可免权限选择，应用仅获得用户所选图片/视频的读访问；用返回 URI 流式读取、压缩/校验后经 HTTPS 上传。 | 不申请全相册权限作为快捷替代；URI 不是可解析路径，限制 MIME、尺寸、数量、读取失败和上传取消。 | 多选、取消、超大/损坏/HEIC、相册资源被删、前后台切换、测试专用板块实际上传和回显。 |
| 图片下载、保存到相册、分享 | 下载到应用沙箱；保存相册使用 `SaveButton` 或 `showAssetsCreationDialog`，二者都不需要 `WRITE_IMAGEVIDEO`。大文件上传/下载可用 `@ohos.request` 后台代理，需 `INTERNET`。跨应用分享用 HarmonyOS Share Kit 的原生 API（实现前单独 API spike），不要复用 Flutter 的文件路径假设。 | 只保存已下载且验证过的媒体；文件名净化、限额、临时文件清理；不声明受限/广泛图库权限。Share Kit 的具体 MIME/URI 授权和目标应用行为尚未在本票验证，不能先承诺 Flutter `url_launcher`/`gallery_saver_plus` 等价行为。 | 保存授权拒绝/成功、图库回显、低存储、网络中断后恢复、分享给已安装与未安装目标、前台/后台下载通知。 |
| 本地论坛通知 | `notificationManager.requestEnableNotification(context)` 请求用户使能，随后 `publish`；使用 `WantAgent` 把点击定位至 Topic/消息。 | 发布可能因通知设置拒绝；先查询使能状态并提供应用内降级，通知 payload 不放 API key 或私信全文。 | 首次允许/拒绝/系统后改、分组与角标、点击冷启动/热启动到正确 Topic、管理员与普通账号切换。 |
| Push/消息提醒 | `pushService.getToken()` 后上报既有服务端；订阅 `tokenUpdate`。多账号应调用 `bindAppProfileId`，或登出/切换时删 token 后重新取 token。 | Push Token 会在重装、恢复出厂、删 token、跨地区等变化；Push Kit 需要应用身份/推送权益及服务端发送链路，不能把 Flutter `workmanager` 轮询当同等替代。后台消息可写本地数据库，但不是前台通知。 | 真机真实 token、服务端注册/轮换、普通/管理员切换不串号、应用前后台/已杀进程、拒绝通知时的应用内同步。 |
| 后台同步、上传下载 | 短时任务仅用于即将完成的清理；长时任务需 `ohos.permission.KEEP_BACKGROUND_RUNNING`，只适合平台允许的持续场景，且会有常驻通知。文件传输优先 Request Kit 的后台代理。 | 不以长时任务模拟定期拉取通知：有权限、能力场景和常驻通知成本；在未证明平台调度语义前不复刻 Flutter `workmanager` 的周期执行承诺。 | 锁屏/后台/省电/网络切换、进程被杀、长任务通知、上传下载恢复和取消。 |
| API Key、会话、RSC 敏感数据 | HUKS 生成/管理不可导出的本地密钥，以其加密会话密文；密文和非秘密元数据可置应用私有存储。 | HUKS 是密钥库，不是可直接替换 `flutter_secure_storage` 的键值 API；不得将原始 API key 写入 Preferences、日志、ArkWeb、通知或备份。密钥丢失/卸载后应要求重新登录，不做不可证明安全的迁移。 | 首登、重启、升级、登出、卸载重装、备份/恢复、错误密文、日志脱敏与双账户切换。 |

## Flutter 依赖不可直接照搬

| Flutter 依赖/模式 | 原生替代与结论 |
| --- | --- |
| `webview_flutter`、`url_launcher` | ArkWeb + 严格域名/JS bridge 边界；外部跳转与分享改由原生 Intent/Share Kit，先验证 URI/MIME 与错误路径。 |
| `image_picker`、`gallery_saver_plus`、`path_provider` | PhotoPicker 的用户授权 URI + 应用沙箱 + SaveButton/保存授权弹窗；不能假定公开文件系统路径可写。 |
| `flutter_local_notifications`、`workmanager` | NotificationKit + PushKit；周期后台轮询不作为通知可靠性设计。 |
| `flutter_secure_storage` | HUKS 包裹/生成密钥加密私有存储；显式设计密钥遗失与重新认证。 |

## 最小权限计划

现在保留 `ohos.permission.INTERNET`。实施时仅在对应功能票中增加：

- `ohos.permission.KEEP_BACKGROUND_RUNNING`：仅在验收证明存在合规持续任务时加入；它不是轮询权限。
- 不为 PhotoPicker、相册保存而添加 `READ_IMAGEVIDEO` / `WRITE_IMAGEVIDEO`：官方组件和保存授权流程可避免广泛图库权限。
- 本地通知使用系统使能授权 API；Push Kit 还需要 AppGallery Connect/Push 权益与服务端配合，不能只改 manifest。

## 已识别风险与下一步

1. **高风险先行验证：**独立 ArkWeb spike，证明白名单、导航委派、富内容 XSS 防护与 Bilibili 可用；未通过前不让 Web 承担正文或认证 bridge。
2. **服务端依赖：**现有 RiverSide/Discourse 契约未必具备 HarmonyOS Push token 注册/发送端点。该差异必须先记录为服务端契约缺口，不以客户端后台轮询掩盖。
3. **RSC：**仅验证 HUKS 会话保护和 UI/只读路径；任何真实资产操作仍遵循逐笔授权。

## 官方证据

1. [ArkWeb 组件安全开发](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/bpta-arkweb-component-security)：URL/bridge 白名单、混合内容、SSL、调试和不可信资源边界。
2. [使用 Web 组件加载页面](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/web-page-loading-with-web-components) 与 [WebviewController](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-apis-webview-webviewcontroller)：网络/本地/HTML 富文本加载与控制接口。
3. [PhotoPickerComponent](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/ohos-file-photopickercomponent) 与 [保存媒体库资源](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/photoaccesshelper-savebutton)：选中资源的只读访问、无广泛图库权限的保存流程。
4. [Request Kit 上传下载](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-request)：HTTP/HTTPS 文件传输、后台代理和 `INTERNET` 要求。
5. [NotificationManager](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-notificationmanager)：通知发布、启用授权和使能状态查询。
6. [Push Service](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/push-pushservice)：token 生命周期、多账号绑定和前后台消息模型。
7. [BackgroundTaskManager](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-resourceschedule-backgroundtaskmanager)、[短时任务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/transient-task)、[长时任务](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/continuous-task)：短/长任务的场景、权限和常驻通知约束。
8. [HUKS](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-huks)：应用侧密钥管理和密码学操作接口。
