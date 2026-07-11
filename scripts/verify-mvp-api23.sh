#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 1 || -z "${1// }" ]]; then
  printf 'Usage: %s <device-serial>\n' "$0" >&2
  exit 2
fi

readonly DEVICE_SERIAL="$1"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_DIR="$PROJECT_ROOT/app"
readonly BUNDLE_NAME="cc.river_side.app"
readonly TEST_MODULE="entry_test"

if ! command -v devecocli >/dev/null 2>&1; then
  printf 'devecocli is required but was not found in PATH.\n' >&2
  exit 2
fi

if ! command -v hdc >/dev/null 2>&1; then
  printf 'hdc is required but was not found in PATH.\n' >&2
  exit 2
fi

cd "$APP_DIR"

devecocli device view -t "$DEVICE_SERIAL"
devecocli build --modules entry@ohosTest
devecocli run --module entry@ohosTest --device "$DEVICE_SERIAL" --skip-build

readonly TEST_OUTPUT="$(
  hdc -t "$DEVICE_SERIAL" shell aa test \
    -b "$BUNDLE_NAME" \
    -m "$TEST_MODULE" \
    -s unittest OpenHarmonyTestRunner \
    -s timeout 60000
)"

if ! grep -Fq 'OHOS_REPORT_CODE: 0' <<<"$TEST_OUTPUT"; then
  printf '%s\n' "$TEST_OUTPUT"
  printf 'Device tests did not report OHOS_REPORT_CODE: 0.\n' >&2
  exit 1
fi

if ! grep -Eq 'Tests run: [0-9]+, Failure: 0, Error: 0, Pass: [0-9]+, Ignore: 0' <<<"$TEST_OUTPUT"; then
  printf '%s\n' "$TEST_OUTPUT"
  printf 'Device test summary is missing or contains a failure, error, or ignored test.\n' >&2
  exit 1
fi

grep -E 'OHOS_REPORT_RESULT:|OHOS_REPORT_CODE:|TestFinished-ResultCode:' <<<"$TEST_OUTPUT"

devecocli build --modules entry
devecocli run --module entry --device "$DEVICE_SERIAL" --skip-build
devecocli log \
  --device "$DEVICE_SERIAL" \
  --bundle-name "$BUNDLE_NAME" \
  --crash \
  --from 2m \
  --tail 80

printf 'MVP API 23 automated regression passed on %s.\n' "$DEVICE_SERIAL"
