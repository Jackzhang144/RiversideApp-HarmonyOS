# 06 — 决定 HarmonyOS 消息提醒交付契约

Type: grilling
Status: resolved
Assignee: Codex
Blocked by: 02

## Question

How can the HarmonyOS phone client deliver the frozen Flutter notification and chat-reminder behaviour without silently changing the existing RiverSide server contract?

The capability matrix establishes that Flutter `workmanager`-style periodic polling is not a reliable HarmonyOS replacement, while Push Kit requires service-side token registration and sending. Resolve whether an existing server capability can be used, what user-visible degradation (if any) is acceptable, and what explicit authority or server work would be required. The result must preserve the map's current no-server-change boundary unless the user redraws that scope.

## Comments

- Frozen Flutter `push_service.dart` is Android-only. It records the latest notification ID, polls `GET /notifications.json` through WorkManager every 15 minutes, then publishes grouped local notifications; it contains no remote-Push token registration or server-send contract.
- The current ArkTS `SystemNotificationService` is an isolated prototype publisher, not product message delivery.
- The API 23 capability matrix confirms that Push Kit needs a service-side token registration and send path, and that long/periodic background work must not be used as a silent replacement for notification delivery.

## Answer

The user decided not to implement HarmonyOS remote Push delivery in this phase. The current server contract stays unchanged; no Push Kit token registration, server-side send path, periodic-background polling substitute, or permission/configuration work is introduced now.

The in-app notification and activity product flows remain in the client parity scope, including foreground refresh and read-state behaviour. Remote system delivery is explicitly deferred until the user coordinates server-side Huawei Push integration; that future effort must start with the server contract and provider configuration rather than a client-only approximation.
