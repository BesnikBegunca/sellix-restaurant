#!/bin/bash
# Verifies release/app_config.json exists and points at a non-localhost HTTPS API.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/release/app_config.json"
EXAMPLE="$ROOT/release/app_config.example.json"

if [[ ! -f "$CONFIG" ]]; then
  echo "ERROR: missing $CONFIG"
  echo "Hint: cp release/app_config.example.json release/app_config.json"
  if [[ -f "$EXAMPLE" ]]; then
    echo "      then set apiBaseUrl to your production Railway URL."
  fi
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required to parse JSON"
  exit 1
fi

URL="$(python3 - <<'PY' "$CONFIG"
import json, sys
with open(sys.argv[1]) as f:
    print(json.load(f).get("apiBaseUrl", "").strip())
PY
)"

if [[ -z "$URL" ]]; then
  echo "ERROR: apiBaseUrl is empty in $CONFIG"
  exit 1
fi

LOWER="$(printf '%s' "$URL" | tr '[:upper:]' '[:lower:]')"
if [[ "$LOWER" == *localhost* ]] || [[ "$LOWER" == *127.0.0.1* ]]; then
  echo "ERROR: apiBaseUrl must not be localhost: $URL"
  exit 1
fi

if [[ "$URL" != https://* ]]; then
  echo "ERROR: apiBaseUrl must start with https:// (got: $URL)"
  exit 1
fi

echo "OK: release/app_config.json"
echo "    apiBaseUrl=$URL"
