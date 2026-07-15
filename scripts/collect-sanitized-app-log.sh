#!/usr/bin/env bash

set -Eeuo pipefail

if [[ $# -lt 1 || $# -gt 3 || -z "${1// }" ]]; then
  printf 'Usage: %s <device-serial> [from-offset] [app|crash]\n' "$0" >&2
  exit 2
fi

readonly DEVICE_SERIAL="$1"
readonly FROM_OFFSET="${2:-5m}"
readonly LOG_MODE="${3:-app}"
readonly PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
readonly REDACTOR="$PROJECT_ROOT/scripts/redact-sensitive-output.sh"

if [[ "$LOG_MODE" != 'app' && "$LOG_MODE" != 'crash' ]]; then
  printf 'Log mode must be app or crash.\n' >&2
  exit 2
fi

LOG_ARGUMENTS=(
  --device "$DEVICE_SERIAL"
  --bundle-name cc.river_side_hm.app
  --from "$FROM_OFFSET"
  --tail 200
)
if [[ "$LOG_MODE" == 'crash' ]]; then
  LOG_ARGUMENTS+=(--crash)
fi
readonly LOG_ARGUMENTS

devecocli log "${LOG_ARGUMENTS[@]}" 2>&1 | \
  "$REDACTOR" | \
  sed '/Preparing log request/d'
