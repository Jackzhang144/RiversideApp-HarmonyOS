# 03 — 准备真实账户与测试 Category 验收条件

Type: task
Status: resolved
Assignee: Codex

## Question

What exact acceptance prerequisites and safety rules must be in place before testing full parity against the live RiverSide service?

Confirm the ordinary and administrator test accounts, their role-visible capabilities, the designated test Category, test-data cleanup conventions, notification-device prerequisites, and the acceptable RSC test path. Record which actions remain blocked pending explicit user authorization, especially any operation that may create or transfer real assets.

This ticket does not perform irreversible production actions. Its answer is the concrete checklist and the facts later acceptance tickets may rely on.

## Comments

- Existing MVP evidence records one ordinary-account Reply in the designated “测试专用” Category, currently documented as Category `111`; it does not prove present administrator capability or replace a fresh full-parity acceptance setup.
- User confirmed that all future write acceptance stays in the designated “测试专用” Category `111`.
- Test Topics, Posts, media and other data in Category `111` are retained as test evidence by default. The user will manually clean them if and when cleanup is needed.
- The user will sign an ordinary or administrator account into the emulator interactively for testing. Credentials and session secrets remain outside this repository and conversation; account switching is a user-operated acceptance step.
- `devecocli device list` currently reports no active target. The existing documentation distinguishes emulator regression from mandatory physical-phone acceptance for ArkWeb, HUKS, media, notification and HDS evidence.

## Answer

The acceptance prerequisites and safety rules are now fixed:

- The user owns one ordinary and one administrator account. The user logs either account in interactively on the emulator; credentials, User API keys, session payloads, private keys and RSC tokens are never recorded by the project or shared in chat.
- All forum writes, uploads and role tests use only the designated “测试专用” Category `111`. Each scenario carries a unique marker for later observation. Test data remains there until the user manually chooses to clean it.
- Emulator testing can cover structural regression and live-service flows. API 23 physical-phone evidence remains mandatory before declaring HDS, ArkWeb, HUKS, media, notification or system-integration acceptance complete; no active device is currently attached.
- RSC read-only capability may be tested normally. Every state-changing or asset-affecting operation—transfer, tip, red-packet creation or closure—requires the user's explicit per-operation approval immediately before it is sent.
- Do not place passwords, User API keys, session payloads, private keys, or RSC tokens in this ticket, repository, or chat. Each account is to authenticate interactively on the target phone.
