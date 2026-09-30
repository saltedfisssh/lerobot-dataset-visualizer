#!/bin/bash
set -euo pipefail

if [[ $# -ne 1 || ! -f "$1" ]]; then
  echo "Usage: bash scripts/smoke-test-macos-dmg.sh <package.dmg>" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/lerobot-macos-smoke.XXXXXX")"
mount_dir="$test_dir/mount"
app_path="$test_dir/LeRobot Dataset Visualizer.app"
mounted=false

cleanup() {
  if [[ "$mounted" == true ]]; then
    hdiutil detach "$mount_dir" -quiet || true
  fi
  rm -rf "$test_dir"
}
trap cleanup EXIT

hdiutil attach -readonly -nobrowse -mountpoint "$mount_dir" "$1"
mounted=true
ditto "$mount_dir/LeRobot Dataset Visualizer.app" "$app_path"
hdiutil detach "$mount_dir" -quiet
mounted=false

# Validate the app users actually install, including nested helpers/frameworks.
codesign --verify --deep --strict --verbose=2 "$app_path"
codesign --display --verbose=2 "$app_path"
if [[ "${MACOS_REQUIRE_NOTARIZATION:-false}" == true ]]; then
  xcrun stapler validate "$app_path"
  spctl --assess --type execute --verbose=2 "$app_path"
fi

node "$script_dir/smoke-test-packaged-app.mjs" \
  "$app_path/Contents/MacOS/LeRobot Dataset Visualizer"

# Starting the embedded Next.js server must not invalidate the resource seal.
codesign --verify --deep --strict --verbose=2 "$app_path"
