#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
app_dir="$script_dir/build/System Pulse.app"
binary_dir="$app_dir/Contents/MacOS"
resources_dir="$app_dir/Contents/Resources"
macmon_bin="/opt/homebrew/bin/macmon"
macmon_license="/opt/homebrew/opt/macmon/LICENSE"

cd "$script_dir"
swift build -c release
if [[ ! -x "$macmon_bin" ]]; then
  echo "macmon is required to build System Pulse. Install it with: brew install macmon" >&2
  exit 1
fi

rm -rf "$app_dir"
mkdir -p "$binary_dir" "$resources_dir"
cp "$script_dir/.build/release/SystemPulseMac" "$binary_dir/SystemPulseMac"
cp "$macmon_bin" "$resources_dir/macmon"
cp "$macmon_license" "$resources_dir/macmon-LICENSE"
cp "$script_dir/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"
echo "Created: $app_dir"
