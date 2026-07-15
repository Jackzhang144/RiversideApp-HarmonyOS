#!/usr/bin/env bash

set -Eeuo pipefail

readonly SIGNING_CONFIG_PATH="app/build-profile.json5"

if ! git diff --cached --name-only --diff-filter=ACMR -- "$SIGNING_CONFIG_PATH" | grep -q .; then
  exit 0
fi

readonly STAGED_CONFIG="$(git show ":$SIGNING_CONFIG_PATH")"

if grep -Eq '"(keyPassword|storePassword|certpath|profile|storeFile)"[[:space:]]*:' <<<"$STAGED_CONFIG"; then
  printf 'Blocked commit: %s contains local signing material.\n' "$SIGNING_CONFIG_PATH" >&2
  printf 'Keep signing material only in the working tree and unstage this file before committing.\n' >&2
  exit 1
fi

if grep -Eq '(/Users/|[A-Za-z]:\\\\)' <<<"$STAGED_CONFIG"; then
  printf 'Blocked commit: %s contains an absolute machine-local path.\n' "$SIGNING_CONFIG_PATH" >&2
  exit 1
fi
