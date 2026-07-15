# 消息中心、活动与前台刷新验证

## 自动验证

在 `app/` 工程根目录执行：

```bash
devecocli build --modules entry
devecocli build --modules entry@ohosTest
devecocli run --module entry --device 127.0.0.1:5555 --skip-build
devecocli run --module entry@ohosTest --device 127.0.0.1:5555 --skip-build
hdc -t 127.0.0.1:5555 shell aa test \
  -b cc.river_side_hm.app \
  -m entry_test \
  -s unittest OpenHarmonyTestRunner \
  -s timeout 120000
```

结果：主 HAP 与测试 HAP 构建成功；设备测试 `205/205` 通过，
`0 Failure / 0 Error / 0 Ignore`，`OHOS_REPORT_CODE: 0`。

本票新增 14 个测试，覆盖：

- 私信、回复、回应和提及四个冻结分桶；
- 私信 Topic、User Action、自定义 Reaction 与赞的严格解析；
- 冻结 Discourse 路径、分页参数、双来源回应合并和 401 传播；
- 首屏、空态、失败、可恢复分页和前台刷新状态；
- UTC 消息时间按设备本地时区展示；
- 前台恢复同时刷新 Chat 频道和当前会话，保留未发送草稿及刷新期间刚确认的消息；
- 正式消息根 Tab 可选，不再保留“未实现”导航语义。

既有 Topic 阅读回归同时覆盖：阅读进度先上报，再只清除同 Topic 且不超过已到达楼层的未读通知。

## API 23 模拟器真实服务只读冒烟

设备：`Mate 70 Pro`，序列号 `127.0.0.1:5555`，HarmonyOS API 23。

账号：现有 Authenticated Session；页面显示为普通成员、已认证、信任等级 3。

已确认：

- 正式“消息”根 Tab 可选择，且显示私信、回复、回应和提及四个桶；
- 回复桶显示真实行为人、Topic 标题、摘要和时间；
- 私信桶显示真实私信 Topic 与空/完整分页尾部语义；
- 回应桶同时显示 `+1` 与自定义 `heart` Reaction，并按时间排序；
- 提及桶显示真实行为人与关联 Topic；
- 应用退到桌面后重新进入，当前回应桶通过前台恢复链路重新获得真实数据；
- 应用没有请求通知权限、发布系统通知、注册 Push token 或启动后台轮询。

本次没有点击消息条目进入 Topic，因为阅读路径会按服务端语义写入 Topic timings 并清除已到达楼层的未读通知。该写入边界已由自动化验证；需要账号持有人在接受真实未读状态变化时再做交互验收。

## 验收边界

- HarmonyOS 远程 Push、服务端 Huawei Push token/发送契约和后台轮询仍在本票范围外。
- 原型中的 NotificationKit 权限与测试发布服务没有进入正式消息实现。
- 本功能不使用新的设备权限，因此不新增物理 Phone 能力门；最终全功能回归仍按总规格执行。
