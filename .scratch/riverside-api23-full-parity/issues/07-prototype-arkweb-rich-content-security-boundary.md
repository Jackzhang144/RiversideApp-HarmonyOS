# 07 — 原型验证 ArkWeb 富内容安全边界

Type: prototype
Status: resolved
Assignee: Codex
Blocked by: 02

## Question

Can an API 23 phone prototype safely provide the frozen Flutter rich-content requirements—trusted embedded Bilibili/YouTube content, navigation delegation, long-post rendering, and back behaviour—while preventing untrusted Post HTML, arbitrary redirects, and JavaScript bridge access from gaining native privileges?

Build only the smallest disposable prototype needed to demonstrate the allowlist, no-bridge boundary, navigation decisions, and failure states on a real device. Link the artifact and user evaluation to the answer; it must not become production code automatically.

## Comments

- Throwaway artifact: `app/entry/src/main/ets/components/prototype/ArkWebRichContentPrototype.ets`, mounted only through the existing permanent UI-prototype route. It permits only `https://river-side.cc` and `https://player.bilibili.com`, does not register a JavaScriptProxy, uses `mixedMode(None)`, and renders all navigation decisions in the prototype UI.
- Verification command: `cd app && devecocli build`; build succeeded. The signed HAP was installed and launched on API 23 emulator `127.0.0.1:5555` with `devecocli run --module entry --device 127.0.0.1:5555 --skip-build`.
- Required HITL evaluation: open “我的 → 原生 UI UX 设计原型 → ArkWeb”; try RiverSide, Bilibili 播放器, 外部 HTTPS, 阻断 HTTP, 阻断 JS; report whether the allowed player loads and the displayed decisions match the requested policy.
- 2026-07-12 HITL result: the Bilibili case failed. Screenshot evidence showed `URL 白名单设置失败` and the main-frame redirect `https://www.bilibili.com/blackboard/webplayer/mbplayer.html?...` was delegated as external.
- Diagnosis: the prototype's `TRUST_LIST` uses single-quoted JavaScript-object syntax, while `WebviewController.setUrlTrustList` requires JSON; independently, the policy and intended allowlist contain only `player.bilibili.com`, not the observed `www.bilibili.com` redirect host. Official `setUrlTrustList` documentation requires valid JSON and exact host matching when wildcards are disabled. No corrective code change has been made yet.
- User approved a prototype-only correction: valid JSON replaces the malformed trust-list text, and the observed exact `www.bilibili.com/blackboard/webplayer` redirect path is added without a wildcard or JavaScriptProxy.
- Rebuild and redeploy after the correction succeeded: `devecocli build`, then `devecocli run --module entry --device 127.0.0.1:5555 --skip-build`. The emulator application launched successfully.
- 2026-07-12 HITL retry: user confirmed the Bilibili case works after the correction. The validated allowlist is valid JSON with three exact entries: `river-side.cc`, `player.bilibili.com`, and `www.bilibili.com` constrained to `blackboard/webplayer`. No wildcard, JavaScriptProxy, or external Ability was introduced.
- The disposable source is archived on branch `codex/arkweb-rich-content-prototype` at commit `e11ae0c` and deliberately removed from the main working tree. It is evidence for the policy decision, not code that may be promoted to the production renderer.

## Answer

The API 23 prototype establishes a viable safe ArkWeb boundary for the observed Bilibili player redirect: use an exact, valid-JSON trust list and intercept every other navigation before it reaches a native action. The implementation contract must keep untrusted Post HTML out of native privilege boundaries, register no JavaScript bridge, keep mixed content disabled, cancel SSL-error loads, and route external links through an explicit later policy.

This does not complete production rich-content rendering or prove every embed/provider, long-post layout, or back-stack case. Those must be covered by the feature implementation and its device acceptance tests; this ticket resolves only the security/navigation feasibility decision.
