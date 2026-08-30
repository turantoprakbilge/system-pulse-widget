#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
"$script_dir/build-app.sh"

target="/Applications/System Pulse.app"
backup="/Applications/.System Pulse.previous.app"

pkill -x SystemPulseMac 2>/dev/null || true
rm -rf "$backup"
if [[ -d "$target" ]]; then
  mv "$target" "$backup"
fi
if ! ditto "$script_dir/build/System Pulse.app" "$target"; then
  [[ -d "$backup" ]] && mv "$backup" "$target"
  echo "Installation failed; the previous app was restored." >&2
  exit 1
fi
rm -rf "$backup"
open -n "$target"
echo "Installed and launched: $target"
