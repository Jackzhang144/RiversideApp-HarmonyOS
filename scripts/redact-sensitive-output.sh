#!/usr/bin/env bash

set -Eeuo pipefail

awk '
  /-----BEGIN [A-Z ]*PRIVATE KEY-----/ {
    print "<redacted-private-key>"
    inside_private_key = 1
    next
  }
  inside_private_key == 1 {
    if ($0 ~ /-----END [A-Z ]*PRIVATE KEY-----/) {
      inside_private_key = 0
    }
    next
  }
  { print }
' | sed -E \
  -e 's/("?User-Api-Key"?[[:space:]]*[:=][[:space:]]*")[^"]*/\1<redacted>/g' \
  -e 's/(User-Api-Key[[:space:]]*[:=][[:space:]]*)[^[:space:],;"]+/\1<redacted>/g' \
  -e 's/("?User-Api-Client-Id"?[[:space:]]*[:=][[:space:]]*")[^"]*/\1<redacted>/g' \
  -e 's/(User-Api-Client-Id[[:space:]]*[:=][[:space:]]*)[^[:space:],;"]+/\1<redacted>/g' \
  -e 's/([?&](payload|nonce|client_id|public_key)=)[^&[:space:]]+/\1<redacted>/g' \
  -e 's/("(key|ciphertext|encryptedSession)"[[:space:]]*:[[:space:]]*")[^"]+/\1<redacted>/g' \
  -e 's/("?[Pp]assword"?[[:space:]]*[:=][[:space:]]*")[^"]*/\1<redacted>/g' \
  -e 's/([Pp]assword[[:space:]]*[:=][[:space:]]*)[^[:space:],;"]+/\1<redacted>/g'
