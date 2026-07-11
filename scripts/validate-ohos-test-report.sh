#!/usr/bin/env bash

set -Eeuo pipefail

readonly REPORT="$(cat)"
readonly REQUIRED_SUITES=(
  'AppShell browse composition'
  'User API Key authorization boundary'
  'AuthRepository session lifecycle'
  'AuthRepository authorization lifecycle'
  'Discourse ForumRepository contract'
  'Discourse authenticated request headers'
  'JSON boundary decoding'
  'Reply request boundary'
  'Discourse Reply transport payload'
  'HUKS Authenticated Session storage'
  'AppShell Topic reading'
)

if ! grep -Fq 'OHOS_REPORT_CODE: 0' <<<"$REPORT"; then
  printf 'Device tests did not report OHOS_REPORT_CODE: 0.\n' >&2
  exit 1
fi

readonly SUMMARY="$(
  grep -E 'Tests run: [0-9]+, Failure: [0-9]+, Error: [0-9]+, Pass: [0-9]+, Ignore: [0-9]+' \
    <<<"$REPORT" | tail -1 || true
)"
if [[ -z "$SUMMARY" ]]; then
  printf 'Device test summary is missing.\n' >&2
  exit 1
fi

readonly TESTS_RUN="$(sed -nE 's/.*Tests run: ([0-9]+),.*/\1/p' <<<"$SUMMARY")"
readonly PASS_COUNT="$(sed -nE 's/.*Pass: ([0-9]+),.*/\1/p' <<<"$SUMMARY")"
if [[ "$TESTS_RUN" -le 0 || "$PASS_COUNT" -ne "$TESTS_RUN" ]]; then
  printf 'Device test report must contain at least one test and every test must pass.\n' >&2
  exit 1
fi

if ! grep -Eq 'Failure: 0, Error: 0, Pass: [1-9][0-9]*, Ignore: 0' <<<"$SUMMARY"; then
  printf 'Device test summary contains a failure, error, or ignored test.\n' >&2
  exit 1
fi

for suite in "${REQUIRED_SUITES[@]}"; do
  if ! grep -Fq "OHOS_REPORT_STATUS: class=$suite" <<<"$REPORT"; then
    printf 'Required device test suite is missing: %s\n' "$suite" >&2
    exit 1
  fi
done

printf 'Validated %s device tests across %s required suites.\n' "$TESTS_RUN" "${#REQUIRED_SUITES[@]}"
