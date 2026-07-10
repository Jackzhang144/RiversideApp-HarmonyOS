# Prepare API 23 physical-device acceptance

Type: task
Status: resolved
Blocked by: none

## Question

What physical device, system version, signing, network, and test-account conditions are required to validate HDS visuals plus the login-and-reply journey on API 23? Record an executable readiness checklist and any human-only actions that block device acceptance.

## Answer

The readiness checklist and required physical-device acceptance cases are recorded in [API 23 physical-device readiness](../../../docs/verification/api23-physical-device-readiness.md). The local API 23 emulator/image is available for basic regression, but `devecocli device list` found no active physical device, no project signing exists, and no disposable test account is designated. Those are explicit human-only prerequisites for later implementation acceptance, not grounds to lower the real-device bar.
