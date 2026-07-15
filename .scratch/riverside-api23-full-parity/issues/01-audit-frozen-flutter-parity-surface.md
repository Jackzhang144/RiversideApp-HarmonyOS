# 01 — 审计冻结 Flutter 参考的功能与契约表面

Type: research
Status: resolved
Assignee: Codex

## Question

For frozen Flutter reference commit `9d8b13c`, what is the complete user-visible functional surface that the HarmonyOS phone client must match?

Produce a cited, feature-by-feature parity inventory from the Flutter source, tests, captures, and current RiverSide contracts. For each capability, record:

- owning Flutter screens, services, and test evidence;
- ordinary-user, authenticated-user, and administrator availability;
- required API requests, request/response fields, state transitions, and failure paths;
- dependencies on rich content, files/media, browser/webview, notifications, background execution, device services, or RSC;
- current ArkTS status: implemented, partial, absent, or requiring runtime verification.

The result must distinguish true product behaviour from development tooling and desktop/web-only packaging. Link any generated research artifact from the answer.

## Answer

The cited parity inventory is [Flutter `9d8b13c` 全功能对等清单](../../../docs/research/flutter-9d8b13c-full-parity-inventory.md).

It establishes that the current ArkTS client implements only the forum MVP (latest-reply Home, Category, Topic/Post reading, User API Key session, and safe plain-text/Markdown Reply). The frozen Flutter reference additionally requires complete discovery and authoring, rich content and interaction, Profile, Chat, notifications/activity, RSC, World Cup, and device-integration flows.

The inventory identifies two implementation-level evidence conflicts that later acceptance must decide from current Flutter code and tests: the authenticated-group predicate and Chat Reaction modelling. It also identifies three architectural gates: API 23 rich-content isolation, device/media/notification capability proof, and a separately safe RSC validation path.
