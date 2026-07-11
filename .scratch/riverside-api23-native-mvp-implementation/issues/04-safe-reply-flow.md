# 04 — 安全 Reply 闭环

**What to build:** 已登录用户可以对 Topic 或指定 Post 提交纯文本或 Discourse Markdown 源文本 Reply，并在成功、失败或不确定结果下得到不会造成重复发布的可靠体验。

**Blocked by:** 02 — Topic 与 Post 阅读; 03 — 原生登录与会话生命周期.

**Status:** ready-for-human

- [x] 空白输入不会提交；用户可对 Topic 或指定 Post 创建 Reply，并得到成功或失败反馈。
- [x] 会话在编辑中失效时，当前 Reply 仅在内存中保留以支持立即重新登录；应用退出后不恢复草稿。
- [x] 拒绝、限流、取消和网络错误保留用户输入并提供清晰的下一步。
- [x] 超时或中断先确认预期 Post 是否已创建；未确认时必须由用户显式重试，绝不自动重发。
- [ ] API 23 真机验证成功与异常 Reply 路径，并证明不会产生重复 Reply。

## 自动验证证据

- API 23 模拟器 `onDeviceTest`：59 个测试全部通过，0 Failure / 0 Error。
- 主 HAP 通过 ArkTS 编译、签名、安装与启动检查；模拟器未出现应用崩溃。
- Standards / Spec 双轴复审通过；Reply 成功体兼容字段、登录后草稿恢复、`highest_post_number`、精确目标匹配及 408/5xx 确认路径均有回归覆盖。
- 当前仅连接 API 23 模拟器；HDS 视觉以及真实 422/429、超时恢复与无重复 Reply 仍须 API 23 真机验收。
