# 02 — 映射 API 23 原生能力与安全边界

Type: research
Status: resolved
Assignee: Codex

## Question

Which HarmonyOS API 23 phone capabilities, permissions, and platform constraints determine a safe native implementation for the frozen Flutter feature set?

Establish primary-source evidence for ArkTS/ArkUI or ArkWeb implementations of rich Post rendering and navigation, image selection/upload, download/save/share, links and embeds, local and push notifications, background work, secure storage, and any required system permissions. Identify unsupported or risky Flutter dependency equivalents, required real-device checks, and the security boundary for untrusted HTML/content and external intents.

Link a concise capability matrix as the research artifact. Do not select a product fallback without recording the evidence and trade-off.

## Answer

The primary-source matrix is [API 23 原生能力与安全边界矩阵](../../../docs/research/api23-native-capability-security-matrix.md).

It establishes an API 23-native path for rich content, media, local notification, transfer, and HUKS-backed session storage; it also sets the mandatory ArkWeb trust/bridge/SSL boundary and confirms that the current manifest's `INTERNET` permission is sufficient only for the existing MVP.

It does not approve a direct replacement for Flutter `workmanager`: reliable Push Kit delivery needs an existing service-side token registration and sending contract. Media sharing also requires a small native API spike before an equivalent behaviour is promised.
