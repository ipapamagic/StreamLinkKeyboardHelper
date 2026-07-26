#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="Steam Link Keyboard Helper.app"

"$ROOT/scripts/build-app.sh"
rm -rf "/Applications/$APP_NAME"
cp -R "$ROOT/build/$APP_NAME" "/Applications/$APP_NAME"
open "/Applications/$APP_NAME"

echo "Installed and opened /Applications/$APP_NAME"
