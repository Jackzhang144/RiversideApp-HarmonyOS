# API 23 physical-device acceptance readiness

Date: 2026-07-10

## Current machine evidence

- `devecocli device list` reports a running `Riverside API 23` phone emulator at `127.0.0.1:5555`, HarmonyOS 6.1.0(23).
- The Stage project now exists under `app/` with bundle name `cc.river_side.app`; both `targetSdkVersion` and `compatibleSdkVersion` are `6.1.0(23)`.
- DevEco automatic debug signing was applied locally for verification. The local signing paths and passwords are not committed to Git.
- `devecocli run` builds, signs, installs, and launches the app on the emulator. `HdsNavigation`, `HdsTabs`, and `HdsSnackBar` compile against the API 23 SDK.
- Home and Category render real RiverSide data. HdsTabs switching works, and Category manual refresh completes two real requests with HTTP 200 responses.
- Simulator verification exposed overlapping HDS/page titles; the navigation title bar was then hidden and both Home and Category were visually rechecked without overlap.
- ArkTS Instrument Test executes nine AppShell behavior cases and three JSON boundary cases on the API 23 emulator: `Tests run: 12, Failure: 0, Error: 0, Pass: 12, Ignore: 0`.
- The emulator is suitable only for structural and basic-interaction regression. It is not acceptable evidence for HDS immersion effects, User API Key authorization, HUKS persistence, or final visual acceptance.

## Human preparation checklist

1. Provide a Chinese-mainland HarmonyOS phone on API 23 (HarmonyOS 6.1.0(23)); record the model, build version, and serial after connection.
2. Enable developer mode and USB debugging on the phone, connect it by USB, accept the computer/debugging trust prompt, then verify it appears in `devecocli device list`.
3. Configure a debug signing identity for the project in `app/` with DevEco Studio. Automatic debug signing is acceptable for local verification; do not use production signing material. Build and deploy with `devecocli run --device <serial>`.
4. Confirm the device has ordinary network access to `https://river-side.cc` and a dedicated non-production RiverSide test account that is allowed to grant `read,write,session_info` User API Key access and create a disposable Reply.
5. Do not place the test account password, User API Key, private key, or signing material in the repository or planning documents.

## Required physical-device acceptance cases

1. **HDS UI:** verify HdsNavigation and HdsSnackBar, and any selected HdsTabs/HdsListItem/HdsActionBar, on API 23 hardware. Judge immersion effects only here, never from emulator screenshots.
2. **Authorization:** complete in-ArkWeb User API Key authorization; verify strict callback interception, RSA PKCS#1 payload decryption, nonce validation, and receipt of both authentication headers.
3. **Session lifecycle:** restart the app to verify HUKS-encrypted session restoration; log out and verify ciphertext plus HUKS alias cleanup; provoke a 401 and verify only that condition triggers global logout.
4. **Reply:** submit a disposable plain-text or Discourse-Markdown Reply, then verify success handling. Exercise cancellation, server validation/limit error, network interruption, and timeout recovery without duplicating a Reply.
5. **Diagnostics:** when a failure occurs, use `devecocli log --device <serial> --bundle-name <bundle-name> --from 5m --tail 200` and capture only sanitized error evidence.

## Human-only blockers today

- No API 23 physical device is connected, so HDS immersion and final visual acceptance remain blocked.
- No designated disposable RiverSide test account has been supplied.

These are readiness conditions, not reasons to weaken the MVP acceptance bar. The implementation plan must retain all five physical-device cases.

## Sources

- Huawei local documentation: `开发指南/使用本地真机运行应用/ide-run-device` (USB or wireless local-device run).
- Huawei local documentation: `开发指南/配置调试签名/ide-signing` (automatic/manual debug signing).
- HDS API 23 research: [HDS component fit](../research/hds-api23-component-fit.md).
- Authentication research: [User API Key authentication](../research/user-api-key-auth-api23.md).
