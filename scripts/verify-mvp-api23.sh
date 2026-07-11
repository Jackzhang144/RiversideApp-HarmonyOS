#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -ne 2 || -z "${1// }" || ! "$2" =~ ^[a-z]+$ ]]; then
  printf 'Usage: %s <device-serial> <device-kind>\n' "$0" >&2
  exit 2
fi

readonly DEVICE_SERIAL="$1"
readonly EXPECTED_DEVICE_KIND="$2"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly APP_DIR="$PROJECT_ROOT/app"
readonly BUNDLE_NAME="cc.river_side.app"
readonly TEST_MODULE="entry_test"
readonly LOG_COLLECTOR="$PROJECT_ROOT/scripts/collect-sanitized-app-log.sh"
readonly TEST_REPORT_VALIDATOR="$PROJECT_ROOT/scripts/validate-ohos-test-report.sh"

if ! command -v devecocli >/dev/null 2>&1; then
  printf 'devecocli is required but was not found in PATH.\n' >&2
  exit 2
fi

if ! command -v hdc >/dev/null 2>&1; then
  printf 'hdc is required but was not found in PATH.\n' >&2
  exit 2
fi

cd "$APP_DIR"

readonly DEVICE_LIST_OUTPUT="$(devecocli device list)"
readonly DEVICE_ROW="$(grep -F "$DEVICE_SERIAL" <<<"$DEVICE_LIST_OUTPUT" | head -1 || true)"
if [[ -z "$DEVICE_ROW" ]]; then
  printf 'Target device is not connected: %s\n' "$DEVICE_SERIAL" >&2
  exit 1
fi
if ! grep -Eq "[[:space:]]${EXPECTED_DEVICE_KIND}[[:space:]]+phone([[:space:]]|$)" <<<"$DEVICE_ROW"; then
  printf 'Target must be a phone whose Kind is %s: %s\n' "$EXPECTED_DEVICE_KIND" "$DEVICE_ROW" >&2
  exit 1
fi

readonly DEVICE_VIEW_OUTPUT="$(devecocli device view -t "$DEVICE_SERIAL")"
printf '%s\n' "$DEVICE_VIEW_OUTPUT"
if ! grep -Eq 'Device Type:[[:space:]]+phone' <<<"$DEVICE_VIEW_OUTPUT"; then
  printf 'Target is not a phone.\n' >&2
  exit 1
fi
if ! grep -Eq 'OS Version:[[:space:]]+API 23([[:space:]]|\()' <<<"$DEVICE_VIEW_OUTPUT"; then
  printf 'Target is not running API 23.\n' >&2
  exit 1
fi

devecocli build --modules entry@ohosTest
devecocli run --module entry@ohosTest --device "$DEVICE_SERIAL" --skip-build

readonly TEST_OUTPUT="$(
  hdc -t "$DEVICE_SERIAL" shell aa test \
    -b "$BUNDLE_NAME" \
    -m "$TEST_MODULE" \
    -s unittest OpenHarmonyTestRunner \
    -s timeout 60000
)"

if ! "$TEST_REPORT_VALIDATOR" <<<"$TEST_OUTPUT"; then
  printf '%s\n' "$TEST_OUTPUT"
  exit 1
fi

grep -E 'OHOS_REPORT_RESULT:|OHOS_REPORT_CODE:|TestFinished-ResultCode:' <<<"$TEST_OUTPUT"

devecocli build --modules entry
devecocli run --module entry --device "$DEVICE_SERIAL" --skip-build
readonly CRASH_OUTPUT="$("$LOG_COLLECTOR" "$DEVICE_SERIAL" 2m crash)"
if [[ -n "${CRASH_OUTPUT//[[:space:]]/}" ]]; then
  printf '%s\n' "$CRASH_OUTPUT"
  printf 'Application crash output was detected after the regression launch.\n' >&2
  exit 1
fi

printf 'MVP API 23 automated regression passed on %s (%s).\n' \
  "$DEVICE_SERIAL" "$EXPECTED_DEVICE_KIND"
