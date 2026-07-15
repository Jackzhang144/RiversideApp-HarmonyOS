# 11 — RSC 只读钱包与账本

**What to build:** 让用户在独立 RSC 会话中查看钱包、余额、账本、每日奖励状态和帖子打赏信息，并获得准确的授权与路径错误反馈。

**Blocked by:** 01 — 账号身份与权限面.

**Status:** ready-for-agent

- [ ] 仅使用生产 RSC 地址和 Discourse exchange 后的受限会话；401 只 refresh 一次后重试。
- [ ] 清晰区分用户不存在、路径不匹配、授权失效和一般网络错误；不会影响论坛 Authenticated Session。
- [ ] 完成只读自动化、构建和普通账号真实服务验证，无资产或状态写入。
