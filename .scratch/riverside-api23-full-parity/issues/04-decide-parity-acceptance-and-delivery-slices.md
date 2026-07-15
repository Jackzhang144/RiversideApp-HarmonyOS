# 04 — 决定完整对等的验收标准与交付切片

Type: grilling
Status: resolved
Blocked by: 01, 02, 03, 05, 06, 07, 08

## Question

Given the frozen parity inventory, API 23 capability matrix, and live-service acceptance prerequisites, what constitutes complete functional parity for each feature, and how should the work be sliced into independently verifiable implementation tickets?

Resolve the acceptance evidence for ordinary and administrator flows, emulator versus physical-phone boundaries, server-side observations, regression tests, and safe handling of RSC operations. Define a dependency order that permits small commits and preserves current working behaviour. The answer should be sufficient to transition this effort into `/to-spec` and `/to-tickets`.

## Decisions resolved

- 2026-07-12: adopt layered acceptance. Every small commit must pass build and relevant automated tests; each business slice must pass a live-service emulator smoke test with the ordinary account; ArkWeb, PhotoPicker, gallery save, system share, and other device-facing capabilities require physical-phone acceptance before the feature is marked complete; administrator capabilities are verified separately in final regression.
- 2026-07-12: deliver as independently verifiable vertical user-flow slices, in this order: forum core and search; rich content and media; profile, drafts, and social; chat; notifications and foreground refresh; administrator actions; RSC; World Cup and specialised links. Do not pause for a cross-cutting rewrite before a slice can be accepted.
- 2026-07-12: real writes to the two designated test accounts are authorised for profile editing, avatar, and profile-background verification. Use disposable media. Email add/delete/resend/confirmation remains read-only until the user supplies a dedicated test mailbox; Category `111` remains the only location for forum writes and test data is retained for the user to clean manually.
- 2026-07-12: every feature slice retains only the minimum release evidence: relevant automated-test and build result plus a concise live-service verification checklist recording the account role, emulator or physical-phone target, main path, and representative failure path. Do not generate process documents for each small change beyond that evidence.
- 2026-07-12: administrator verification may exercise move, close, archive, hide, delete, and pin actions only on Topic/Post content created for this test in Category `111`. It must not affect other categories, pre-existing content, or site-wide settings.
- 2026-07-12: HarmonyOS remote Push remains a separate deferred delivery, pending a server-side Huawei Push token and send contract. It is not a blocker for the current phase; the in-app notification centre and foreground refresh remain required.

## Answer

Complete the current phase through vertical, independently verifiable user-flow slices while preserving the existing AppShell, Authenticated Session, repository, and centralized transport boundaries. Each slice has a small-commit automated/build gate, ordinary-account live emulator smoke gate, minimal verification evidence, and a physical-phone gate where it touches device capabilities. Administrator actions stay contained to test-created Category `111` content; profile media changes are allowed on the two test accounts; email mutations await a dedicated test mailbox; RSC state or asset changes remain individually user-authorised.

Remote Push is the only frozen Flutter capability deferred from this phase because it cannot be truthfully implemented without the server Huawei-Push contract. The remaining decisions are ready to synthesize into a product specification and dependency-ordered implementation tickets.
