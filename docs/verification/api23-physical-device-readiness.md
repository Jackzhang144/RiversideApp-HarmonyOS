# API 23 physical-device acceptance readiness

Date: 2026-07-10

## Current machine evidence

- `devecocli device list` reports **no active devices**.
- `devecocli emulator list` reports a stopped `Mate 70 RS` phone emulator on HarmonyOS 6.1.0(23), but starting it fails because that instance's system image is missing.
- `devecocli emulator image list --device-type phone --format json` reports a downloaded HarmonyOS 6.0.31(23) phone image.
- Creating `Riverside API 23` against the downloaded image reports `Device create success`, but the instance does not appear in the emulator list before the tool timeout. DevEco Studio Device Manager must confirm or repair the instance before another CLI start attempt.
- The Stage project now exists under `app/` with bundle name `cc.river_side.app`; both `targetSdkVersion` and `compatibleSdkVersion` are `6.1.0(23)`.
- `devecocli build` completes ArkTS compilation and HAP packaging. `HdsNavigation`, `HdsTabs`, and `HdsSnackBar` compile against the API 23 SDK. HDS visual behavior remains unverified until a device can run the app.
- ArkTS Instrument Test compiles the application and `ohosTest` HAP containing nine AppShell behavior cases and three JSON boundary cases, then stops at device coverage because there is no active device. The tests have not been executed.
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

- No API 23 physical device is connected.
- The API 23 project and bundle name now exist, but no debug signing configuration exists, so deployment cannot be attempted.
- The local API 23 emulator needs manual confirmation in DevEco Studio Device Manager before it can be used for structure and basic-interaction regression.
- No designated disposable RiverSide test account has been supplied.

These are readiness conditions, not reasons to weaken the MVP acceptance bar. The implementation plan must retain all five physical-device cases.

## Sources

- Huawei local documentation: `开发指南/使用本地真机运行应用/ide-run-device` (USB or wireless local-device run).
- Huawei local documentation: `开发指南/配置调试签名/ide-signing` (automatic/manual debug signing).
- HDS API 23 research: [HDS component fit](../research/hds-api23-component-fit.md).
- Authentication research: [User API Key authentication](../research/user-api-key-auth-api23.md).
