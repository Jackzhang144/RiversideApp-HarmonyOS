# API 23 上复用 RiverSide / Discourse User API Key 认证

## 结论

可以复用，且不需要为该 MVP 改动 RiverSide / Discourse 服务端。原 Flutter 原生端使用的是 Discourse 标准 User API Key 重定向流；API 23 的 ArkTS 已具备其所需的 RSA 密钥对、PKCS#1 私钥解密、内嵌 Web 导航拦截和密钥库能力。

推荐 MVP 采用 **ArkWeb 内嵌授权页 + `onLoadIntercept` 截获回调**，不打开系统浏览器。这样沿用现有 `riverside://auth_redirect` 协议，但不依赖尚未验证的“外部浏览器将自定义 scheme 再拉回 HarmonyOS 应用”能力。

这是一项可实施结论，不是已在 API 23 真机跑通的验收结论；下列“必须真机验证”项应成为实现票的验收条件。

## 现有客户端和服务端证据

Flutter 参考实现的原生流程为：

1. 在 [auth.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/auth.dart#L20) 固定 `auth_redirect=riverside://auth_redirect`、scope 为 `read,write,session_info`。
2. `AuthRequest.create()` 生成 RSA-2048 密钥对、64 位十六进制 `clientId`、32 位十六进制 `nonce`，并请求 `/user-api-key/new`；`padding=pkcs1`。见 [auth.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/auth.dart#L168) 和 [auth.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/auth.dart#L816)。
3. Flutter WebView 遇到该 scheme 后阻止导航，读取 `payload`，用临时私钥做 PKCS#1 解密，并强制校验 JSON 中的 `nonce`。见 [auth.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/auth.dart#L445) 和 [auth.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/auth.dart#L667)。
4. 持久会话只保存 `key` 和 `clientId`，请求附带 `User-Api-Key` 与 `User-Api-Client-Id`。见 [models.dart](/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp/lib/models.dart#L145)。

Discourse 官方协议规定 `/user-api-key/new` 接收 `public_key`、`nonce`、`scopes`、`client_id`、`application_name`、`auth_redirect` 和可选 `padding`；授权后向 `auth_redirect` 返回加密的 `payload`，其中包括 `key` 与回显的 `nonce`。`pkcs1` 和 `oaep` 都是允许值，但官方建议新应用优先 OAEP；为与已有 RiverSide 客户端及服务端行为严格一致，首次实现应先保持 `pkcs1`。协议也明确了后续 API 使用的两个请求头。来源：[Discourse User API keys specification](https://meta.discourse.org/t/user-api-keys-specification/48536)。

2026-07-10 的只读 `HEAD https://river-side.cc/user-api-key/new` 返回 `Auth-Api-Version: 4`、`Auth-Api-Device-Code: true` 和 `x-discourse-route: user_api_keys/new`。这证明当前生产站点已公开该协议路由和 v4 / device-code 能力；它**没有**证明某个具体 `auth_redirect` 白名单值已经通过。

## API 23 对应实现

| 协议步骤 | API 23 原生等价物 | 证据与实现约束 |
| --- | --- | --- |
| 生成临时 RSA-2048 密钥对、导出公钥 | `@kit.CryptoArchitectureKit`：`createAsyKeyGenerator('RSA2048|PRIMES_2')`、`generateKeyPair()`、`pubKey.getEncodedPem('PKCS1')` | 官方指南确认 RSA KeyPair、二进制导出；PEM 指南确认公钥可输出 PKCS#1 或 X.509。必须在真机用实际生成的 PKCS#1 PEM 请求 RiverSide，确认服务端解析。来源：[随机生成非对称密钥对](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/crypto-generate-asym-key-pair-randomly)，[PEM 转换](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/crypto-convert-string-data-to-asym-key-pair)（DevEco 文档 ID：`crypto-generate-asym-key-pair-randomly`、`crypto-convert-string-data-to-asym-key-pair`）。 |
| 解密 `payload` | `cryptoFramework.createCipher('RSA2048|PKCS1')`，以 `DECRYPT_MODE` 和临时 `PriKey` 执行 `doFinal()`，再 UTF-8 / JSON 解码 | 官方 ArkTS 指南明确支持 RSA PKCS#1 公钥加密、私钥解密。保留 Flutter 的 Base64 容错与 nonce 完整相等校验；不接受缺失 key 或 nonce 不匹配的结果。来源：[RSA PKCS#1 加解密](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/crypto-rsa-asym-encrypt-decrypt-pkcs1)（DevEco 文档 ID：`crypto-rsa-asym-encrypt-decrypt-pkcs1`）。 |
| 承载登录、接收重定向 | `Web` 组件 + `onLoadIntercept` | `onLoadIntercept` 从 API 10 起在 URL 加载前回调，回调返回 `true` 会取消导航，且事件提供请求 URL；API 23 可用。仅当 URI 严格匹配 `riverside://auth_redirect`、为主框架且 payload 非空时才截获并处理。来源：[Web 事件](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/arkts-basic-components-web-events)（DevEco 文档 ID：`arkts-basic-components-web-events`）。 |
| 保留会话 bearer key | HUKS 持有不可导出的加密密钥；密文和必要元数据放应用私有 Preferences | HUKS 的 `generateKeyItem` / `initSession` 从 API 9 起可用，并且生成密钥材料不返回给应用；Preferences 只是持久化 KV 存储，不能直接作为明文 token 的安全替代。实现时以 HUKS 对 `{key, clientId}` 加密、Preferences 存密文；登出时删除密文和 HUKS alias。来源：[HUKS API](https://developer.huawei.com/consumer/cn/doc/harmonyos-references/js-apis-huks)（DevEco 文档 ID：`js-apis-huks`），[Preferences](https://developer.huawei.com/consumer/cn/doc/harmonyos-guides/data-persistence-by-preferences)（DevEco 文档 ID：`data-persistence-by-preferences`）。 |
| 发起已认证 API 调用 | ArkTS HTTP client 在每个需登录请求加入 `User-Api-Key` 与 `User-Api-Client-Id` | 与 Flutter `AuthSession.headers`、Discourse 官方协议完全相同；401 时清除本地密文会话。 |

## MVP 推荐状态机

`idle → generatingRequest → loadingAuthorizationWeb → interceptingCallback → decryptingAndValidating → persistingSession → authenticated`

失败和取消均回到 `idle`，并销毁临时私钥、nonce、clientId。临时私钥只应保留在当前认证会话内；应用进程被杀或认证页面失效时，宁可重新发起授权，不把私钥明文持久化。

## 必须真机验证的风险与验收

1. **服务端 redirect 白名单**：当前只读 HEAD 不能确认 `riverside://auth_redirect` 是否被 `allowed_user_api_auth_redirects` 接受；用测试账号在 API 23 真机完成一次授权。
2. **PEM / 填充互操作性**：用 API 23 生成的 `RSA2048` + PKCS#1 PEM 完整执行服务端加密和本地解密。若生产端或 ArkTS 互操作失败，先记录实际格式差异；不得静默改为 OAEP 或改后端。
3. **ArkWeb 重定向行为**：验证 `onLoadIntercept` 可获取完整 callback URL、阻止自定义 scheme 导航，并在登录、授权取消、网络中断三种路径下不丢失 UI 状态。
4. **安全存储**：验证 HUKS 加密/解密密文会话、重启后的恢复、登出后的密文与 alias 清理。Preferences 明文保存 User API Key 不可接受。
5. **外部浏览器不是 MVP 依赖**：未找到可直接证明 API 23 自定义 URI scheme 外部浏览器回调注册与分发的官方证据。若未来改用系统浏览器，先单独做 PoC；当前的 ArkWeb 截获方案绕开该未知项。

## 对规格的约束

- MVP 可以在“不改服务端”前提下纳入登录与回复；认证实现必须使用内嵌 ArkWeb，不将外部浏览器 callback 作为前置条件。
- 初次实现沿用现有 `pkcs1`、scope、client-id 与 nonce 契约；OAEP 升级另设兼容性任务。
- “登录完成”验收必须包含 API 23 真机一次实际授权、解密、持久恢复和一个带两项 User API 头的受保护请求；模拟器不能替代该结论。
