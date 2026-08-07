#!/bin/bash
# Post to Bluesky as the Six Wakes agent.
# Usage: bsky_post.sh "post text (ASCII, no double quotes)" [url-to-link]
# Credentials come from ../.secrets (gitignored, never published).
set -euo pipefail
DIR="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck disable=SC1091
source "$DIR/.secrets"
TEXT="$1"
URL="${2:-}"

SESSION=$(curl -s -X POST https://bsky.social/xrpc/com.atproto.server.createSession \
  -H "Content-Type: application/json" \
  -d "{\"identifier\":\"$BSKY_HANDLE\",\"password\":\"$BSKY_APP_PASSWORD\"}")
JWT=$(printf '%s' "$SESSION" | sed -n 's/.*"accessJwt":"\([^"]*\)".*/\1/p')
DID=$(printf '%s' "$SESSION" | sed -n 's/.*"did":"\([^"]*\)".*/\1/p' | head -1)
if [ -z "$JWT" ] || [ -z "$DID" ]; then
  echo "LOGIN FAILED: $SESSION" >&2
  exit 1
fi

NOW=$(date -u +%Y-%m-%dT%H:%M:%SZ)
FACETS=""
if [ -n "$URL" ]; then
  IDX=$(printf '%s' "$TEXT" | awk -v u="$URL" '{print index($0, u)}')
  if [ "$IDX" -gt 0 ]; then
    START=$((IDX - 1))
    END=$((START + ${#URL}))
    FACETS=",\"facets\":[{\"index\":{\"byteStart\":$START,\"byteEnd\":$END},\"features\":[{\"\$type\":\"app.bsky.richtext.facet#link\",\"uri\":\"$URL\"}]}]"
  fi
fi

RECORD="{\"repo\":\"$DID\",\"collection\":\"app.bsky.feed.post\",\"record\":{\"\$type\":\"app.bsky.feed.post\",\"text\":\"$TEXT\",\"createdAt\":\"$NOW\",\"langs\":[\"en\"]$FACETS}}"
RESULT=$(curl -s -X POST https://bsky.social/xrpc/com.atproto.repo.createRecord \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $JWT" \
  -d "$RECORD")
printf '%s\n' "$RESULT"
case "$RESULT" in
  *'"uri"'*) echo "POST OK" ;;
  *) echo "POST FAILED" >&2; exit 1 ;;
esac
