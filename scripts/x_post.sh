#!/bin/bash
# Post to X (Twitter) as @wrenwakes via API v2 with OAuth 1.0a user context.
# Usage: x_post.sh "post text (no double quotes)"
# Credentials come from ../.secrets (gitignored, never published).
# NOTE: account is on X's Pay-Per-Use plan — each post costs credits.
# Do not post routinely until the human has approved funding (see memory note).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$DIR/.secrets"
if [ "${X_ACCESS_TOKEN:-PENDING}" = "PENDING" ]; then
  echo "X access token not configured yet" >&2
  exit 1
fi
TEXT="$1"

pct() { # RFC3986 percent-encode
  local s="$1" out="" c i
  for ((i=0; i<${#s}; i++)); do
    c="${s:$i:1}"
    case "$c" in
      [a-zA-Z0-9.~_-]) out+="$c" ;;
      *) out+=$(printf '%%%02X' "'$c") ;;
    esac
  done
  printf '%s' "$out"
}

URL="https://api.x.com/2/tweets"
NONCE=$(openssl rand -hex 16)
TS=$(date +%s)

PARAMS="oauth_consumer_key=$(pct "$X_CONSUMER_KEY")&oauth_nonce=$NONCE&oauth_signature_method=HMAC-SHA1&oauth_timestamp=$TS&oauth_token=$(pct "$X_ACCESS_TOKEN")&oauth_version=1.0"
BASE="POST&$(pct "$URL")&$(pct "$PARAMS")"
KEY="$(pct "$X_CONSUMER_SECRET")&$(pct "$X_ACCESS_TOKEN_SECRET")"
SIG=$(printf '%s' "$BASE" | openssl dgst -sha1 -hmac "$KEY" -binary | openssl base64)

AUTH="OAuth oauth_consumer_key=\"$(pct "$X_CONSUMER_KEY")\", oauth_nonce=\"$NONCE\", oauth_signature=\"$(pct "$SIG")\", oauth_signature_method=\"HMAC-SHA1\", oauth_timestamp=\"$TS\", oauth_token=\"$(pct "$X_ACCESS_TOKEN")\", oauth_version=\"1.0\""

RESULT=$(curl -s -X POST "$URL" \
  -H "Authorization: $AUTH" \
  -H "Content-Type: application/json" \
  -d "{\"text\":\"$TEXT\"}")
printf '%s\n' "$RESULT"
case "$RESULT" in
  *'"id"'*) echo "POST OK" ;;
  *) echo "POST FAILED" >&2; exit 1 ;;
esac
