# Profile、社交与草稿管理验证记录

日期：2026-07-14

## 结论

Full Profile 已成为身份、群组、校友认证、资料字段、关系状态和能力的权威来源。正式 Account/Profile 流程已接入个人资料、头像、背景图、关注、通知级别、我的 Topic、Reply、草稿和书签；邮箱仅展示，不提供增删、重发或确认入口。

自动化、严格 ArkTS 编译、API 23 模拟器安装和真实服务只读路径均已验证。真实资料、头像和背景写入仍缺少两个明确授权的测试账号、可丢弃媒体和物理 Phone PhotoPicker 环境，因此没有对当前未知用途账号执行破坏性写入，也不能将该项记为完整通过。

## 环境

- 设备：`Mate 70 Pro` Phone 模拟器
- 系统：HarmonyOS API 23 Release
- 设备序列：`127.0.0.1:5555`
- 服务：真实 `river-side.cc`
- 账号：一个已认证普通账号；文档不记录用户名、邮箱、User API Key 或会话材料
- Flutter 对照基线：`../RiversideApp` commit `9d8b13c`

## 自动验证

从 `app/` 工程根目录执行：

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

结果：`169/169` 通过，`0 Failure / 0 Error / 0 Ignore`，`OHOS_REPORT_CODE: 0`；主 HAP 与测试 HAP 均构建成功。

覆盖范围：

- Full Profile 解析身份、群组、primary/flair 权威字段、资料、关系状态和服务端能力。
- 活跃摘要为空时保留有效 Profile；任一受保护请求返回 401 时清空受保护状态并只触发一次会话失效处理。
- Profile 更新只提交显式变化字段；失败、刷新失败和跨用户并发均不覆盖现有权威值。
- 头像与背景上传分离；上传或后续资料写入失败时保留当前值；背景响应缺少可用 URL 时不发送空地址写入。
- 关注、静音/忽略通知级别；忽略提供 1 天、1 周、1 个月和永久四档，并验证选定到期时间请求体。
- 真实 `user_actions` Reply 字段、HTML 可见文本清理、Topic/书签分页、去重、分页失败保值和显式重试。
- 顶层或 draft data 内的 Topic/Reply 标识、动态 `new_topic_*` draft key、选定草稿恢复、sequence 续写和精确清理。

## 真实服务只读验证

1. Account 成功显示服务端身份、认证群组、信任等级和发帖能力。
2. Profile 成功加载资料与活跃摘要；简介 HTML 标记不再直接显示，服务端背景图有正式回显区域。
3. 个人资料编辑页展示服务端资料和只读邮箱，没有邮箱写操作入口。
4. “我的 Topic”加载真实 Topic 列表；“我的 Reply”按服务端实际 `user_actions` 字段解析；搜索用户结果可进入其他用户 Profile。
5. 主 HAP 已安装到 API 23 模拟器并成功启动。

本轮真实服务检查只执行读取，没有更改论坛资料、关系、草稿、书签、邮箱或媒体。

## 未完成的真实写入门槛

完成 Ticket 的资料/头像/背景真实写入验收前，需要同时满足：

1. 指定两个允许修改资料的测试账号，并明确各自初始资料值和恢复值。
2. 提供两组可丢弃头像/背景媒体，不包含个人或生产数据。
3. 至少一台 API 23 物理 Phone 验证系统 PhotoPicker、裁剪/缓存、上传、服务端刷新回显和失败保值。
4. 每个账号依次验证资料字段、头像和背景成功写入并恢复；再用受控失败验证现有值不被覆盖。

邮箱在另有专用可丢弃测试邮箱前继续保持只读。
