# Chat 与媒体消息验证

## 自动验证

在 `app/` 工程根目录执行：

```bash
devecocli build --modules entry
devecocli build --modules entry@ohosTest
devecocli run --module entry@ohosTest --device 127.0.0.1:5555 --skip-build
hdc -t 127.0.0.1:5555 shell aa test \
  -b cc.river_side_hm.app \
  -m entry_test \
  -s unittest OpenHarmonyTestRunner \
  -s timeout 120000
```

结果：主 HAP 与测试 HAP 均构建成功；设备测试 `185/185` 通过，
`0 Failure / 0 Error / 0 Ignore`，`OHOS_REPORT_CODE: 0`。

Chat 专项覆盖：

- 服务端频道排序、未读数和真实最后消息时间；
- 图片消息、Reply、Reaction 用户、删除墓碑和 Emoji 解析；
- 频道消息分页、搜索结果目标消息窗口、真实消息 ID 已读上报；
- 私聊、发送、Reaction、删除、恢复、搜索和离开频道接口契约；
- 上传失败和发送失败时保留可重试草稿，不创建伪消息；
- 认证会话失效时清空受保护 Chat 状态。

## API 23 模拟器只读冒烟

设备：`Mate 70 Pro`，序列号 `127.0.0.1:5555`，HarmonyOS API 23。

正式 HAP 安装并启动成功。已进入 Chat 根页面，从真实服务读取到当前账号可见频道，
并确认频道标题、预览、未读徽标和服务端最后消息时间可见。为了不擅自改变真实账号和服务端数据，
本次没有点击频道触发已读写入，也没有执行发送、上传、私聊创建、Reaction、删除、恢复或离开频道。

## 尚需人工验收

- 使用普通账号在真机或 API 23 模拟器完成频道与私聊主路径；
- 验证纯图片、图文、Reply、Mention、Emoji 与 Reaction 用户列表；
- 分别制造上传失败与发送失败，确认草稿可重试且服务端没有伪消息；
- 验证删除、恢复、未读清零、历史分页、搜索定位和离开频道。

这些步骤会修改真实服务状态，应由账号持有人操作，或在得到明确授权后执行。
