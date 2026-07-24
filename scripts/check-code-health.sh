#!/usr/bin/env bash

set -Eeuo pipefail

readonly MODE="${1:---all}"
readonly SOURCE_ROOT="app/entry/src/main/ets"
readonly THEME_PALETTE_PATH="$SOURCE_ROOT/settings/AppThemeSettings.ets"
readonly ENVIRONMENT_PATH="$SOURCE_ROOT/core/RiversideEnvironment.ets"

if [[ "$MODE" != "--all" && "$MODE" != "--staged" ]]; then
  printf 'Usage: %s [--all|--staged]\n' "$0" >&2
  exit 2
fi

failed=0

report_matches() {
  local rule="$1"
  local path="$2"
  local pattern="$3"
  local content="$4"
  local matches=""

  if matches="$(grep -En "$pattern" <<<"$content")"; then
    printf 'Code health violation (%s): %s\n' "$rule" "$path" >&2
    printf '%s\n' "$matches" >&2
    failed=1
  fi
}

check_source_file() {
  local path="$1"
  local content="$2"

  report_matches \
    'ArkTS any type' \
    "$path" \
    ':[[:space:]]*any([[:space:];,)=]|$)|<[[:space:]]*any[[:space:]]*>|[[:space:]]as[[:space:]]+any([^[:alnum:]_]|$)|any[[:space:]]*\[\]' \
    "$content"
  report_matches \
    'removed RepositoryResult.failure API' \
    "$path" \
    'RepositoryResult[[:space:]]*\.[[:space:]]*failure[[:space:]]*\(' \
    "$content"
  report_matches \
    'static version in User-Agent' \
    "$path" \
    'RiversideApp/[0-9]' \
    "$content"

  if [[ "$path" != "$THEME_PALETTE_PATH" ]]; then
    report_matches \
      'raw color outside the platform system-bar palette' \
      "$path" \
      '#[[:xdigit:]]{6}([[:xdigit:]]{2})?' \
      "$content"
  fi

  if [[ "$path" != "$ENVIRONMENT_PATH" ]]; then
    report_matches \
      'RiverSide host outside RiversideEnvironment' \
      "$path" \
      "https://[^[:space:]'\"]*river-side\\.cc|['\"]river-side\\.cc['\"]" \
      "$content"
  fi
}

check_metadata_file() {
  local path="$1"
  local content="$2"

  report_matches \
    'template metadata placeholder' \
    "$path" \
    'Please describe the basic information|module description|"value"[[:space:]]*:[[:space:]]*"description"|"vendor"[[:space:]]*:[[:space:]]*"example"' \
    "$content"
}

check_path() {
  local path="$1"
  local content=""

  if [[ "$MODE" == "--staged" ]]; then
    if ! content="$(git show ":$path" 2>/dev/null)"; then
      return
    fi
  else
    if [[ ! -f "$path" ]]; then
      return
    fi
    content="$(<"$path")"
  fi

  if [[ "$path" == *.ets ]]; then
    check_source_file "$path" "$content"
  else
    check_metadata_file "$path" "$content"
  fi
}

if [[ "$MODE" == "--staged" ]]; then
  while IFS= read -r path; do
    [[ -n "$path" ]] && check_path "$path"
  done < <(git diff --cached --name-only --diff-filter=ACMR -- \
    "$SOURCE_ROOT" \
    app/oh-package.json5 \
    app/entry/oh-package.json5 \
    app/AppScope/app.json5 \
    app/entry/src/main/resources/base/element/string.json)
else
  while IFS= read -r path; do
    check_path "$path"
  done < <(find "$SOURCE_ROOT" -type f -name '*.ets' -print | sort)
  check_path app/oh-package.json5
  check_path app/entry/oh-package.json5
  check_path app/AppScope/app.json5
  check_path app/entry/src/main/resources/base/element/string.json
fi

if (( failed != 0 )); then
  printf 'Code health checks failed. Move shared values to the typed foundation before committing.\n' >&2
  exit 1
fi

printf 'Code health checks passed (%s).\n' "$MODE"
