# Wayfinder map: Riverside API 23 native MVP

## Destination

Produce an implementation-ready specification and dependency-ordered ticket plan for a Chinese-mainland, API 23 native HarmonyOS phone MVP of the RiverSide Discourse client. The MVP is installable and verifiable on an API 23 physical device, but this map does not implement it.

## Notes

- Read `CONTEXT.md` and applicable ADRs before working a ticket.
- Use ArkTS + ArkUI. Prefer UI Design Kit (HDS); fall back to ArkUI base components only when HDS does not cover the need or is not verified for API 23.
- Confirm every selected HDS component's API 23 support. HDS immersive visual acceptance is physical-device only; emulator work is limited to structure and base interaction regression.
- The distribution scope is Chinese mainland only.
- Reuse the existing RiverSide/Discourse API contract and User API Key authentication; server changes are out of scope.
- The MVP user journey is home/categories → topic list → topic detail → login → plain-text or Discourse-Markdown reply. Images, attachments, mentions, emoji panels, rich editing, search, notifications, chat, publishing new topics, wallet features, and push are out of scope.
- Reference implementation: `/Users/jackzhang/Code/DevEcoStudioProjects/RiversideApp`.
- Use `devecocli` for HarmonyOS documentation, scaffolding, build, device, emulator, run, and logs.

## Decisions so far

- [Verify HDS API 23 component fit](issues/01-verify-hds-api23-component-fit.md) — all five requested components are candidates; adopt HdsNavigation and HdsSnackBar first, make HdsTabs conditional, and require an accessible prototype before HdsListItem adoption.
- [Verify User API Key authentication on API 23](issues/02-verify-user-api-key-auth-on-api23.md) — reuse the existing protocol through embedded ArkWeb, in-memory RSA/nonce validation, and a HUKS-encrypted persisted Authenticated Session; API 23 physical-device proof remains mandatory.
- [Map the MVP contract from the reference client](issues/03-map-mvp-contract-from-reference-client.md) — browse, Category, Topic/Post, session, and Reply endpoints can be reused; only 401 invalidates the session, while reply recovery requires real-device verification.
- [Decide native module and navigation boundaries](issues/04-decide-native-module-and-navigation-boundaries.md) — AppShell owns tabs, navigation, and session; page state models use separate forum/auth repositories behind one transport client and only AppShell handles global 401 logout.
- [Prepare API 23 physical-device acceptance](issues/05-prepare-api23-physical-device-acceptance.md) — the emulator is available only for basic regression; true-device acceptance requires an API 23 phone, debug signing, RiverSide network access, and a disposable test account.
- [Decide MVP resilience and session policy](issues/06-decide-mvp-resilience-and-session-policy.md) — cache only Categories with stale-while-revalidate; make loading, empty, error, and pagination states explicit; preserve only in-memory Reply text through a 401; never automatically retry an uncertain Reply.
- [Decide implementation slice and test order](issues/07-decide-implementation-slice-and-test-order.md) — build browse foundation, Topic reading, authentication, then Reply; emulator verifies structure/read flows, while API 23 physical-device gates HDS visuals, authentication, and Reply.

## Not yet specified

<!-- No additional planning fog is currently known. -->

## Out of scope

- RiverSide/Discourse server changes — the MVP consumes the existing API contract.
- Distribution outside Chinese mainland — HDS is constrained to the mainland scope for this effort.
- Pixel-for-pixel Flutter reproduction — preserve information architecture and interaction semantics instead.
- Search, notifications, chat, new-topic publishing, image or attachment uploading, @mentions, emoji panels, rich editing, wallet features, and push notifications — excluded from the MVP.
