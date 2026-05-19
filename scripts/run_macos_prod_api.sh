#!/bin/bash
# Run the desktop POS against the Railway production API (debug build).
set -euo pipefail
cd "$(dirname "$0")/.."
export POS_API_BASE_URL=https://posapi-production-a6e7.up.railway.app
echo "POS_API_BASE_URL=$POS_API_BASE_URL"
flutter run -d macos
