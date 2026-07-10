# Decide implementation slice and test order

Type: grilling
Status: resolved
Blocked by: 04, 05, 06

## Question

Given the finalized module boundaries, acceptance prerequisites, API contract, and resilience policy, what dependency-ordered implementation slices and test gates should the MVP specification contain? Decide the smallest vertical sequence that reaches API 23 real-device browse, login, and Reply acceptance without building excluded functionality early.

## Answer

Implement in four vertical slices:

1. **Browse foundation:** create the API 23 Stage-model project, then implement AppShell, Home/Category root tabs, the core transport/repository boundary, and HDS compile probes. Build and run structural/basic-interaction regression on the emulator; reserve HDS visual acceptance for a physical device.
2. **Read a Topic:** add Topic detail and segmented Post loading. On the emulator, cover initial load, pagination, empty state, failure state, and retry without authentication.
3. **Authenticate:** add embedded-ArkWeb User API Key login, RSA/nonce validation, HUKS persistence, restoration, logout, and global 401 handling. This slice passes only on API 23 physical-device evidence.
4. **Reply:** add plain-text/Discourse-Markdown Reply. On an API 23 physical device, cover success, validation/limit failure, cancellation, network interruption, timeout confirmation, and explicit retry with no duplicate Reply.

After slice 4, run the full MVP regression across the agreed browsing, session, and Reply flows. Excluded features remain excluded throughout the sequence.
