#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 2 || -z "${1// }" ]]; then
  printf 'Usage: %s <device-serial> [from-offset]\n' "$0" >&2
  exit 2
fi

readonly DEVICE_SERIAL="$1"
readonly FROM_OFFSET="${2:-5m}"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REDACTOR="$PROJECT_ROOT/scripts/redact-sensitive-output.sh"

devecocli log \
  --device "$DEVICE_SERIAL" \
  --bundle-name cc.river_side.app \
  --from "$FROM_OFFSET" \
  --tail 200 \
  2>&1 | "$REDACTOR"
