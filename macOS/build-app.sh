#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
app_dir="$script_dir/build/System Pulse.app"
binary_dir="$app_dir/Contents/MacOS"
resources_dir="$app_dir/Contents/Resources"
macmon_bin="/opt/homebrew/bin/macmon"
macmon_license="/opt/homebrew/opt/macmon/LICENSE"
source_file="$script_dir/Sources/SystemPulseMac/SystemPulseMac.swift"

cd "$script_dir"

# Apply source patches idempotently. These replacements are intentionally
# exact-string based so repeated builds do not fail when a patch is already present.
/usr/bin/python3 - "$source_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# 1) Footer button should route through the selection helper.
text = text.replace(
    "                            monitor.menuBarMode = mode\n",
    "                            monitor.selectMenuBarMode(mode)\n",
    1,
)

# 2) Add All-mode rotation support once.
if "func selectMenuBarMode(_ mode: MenuBarMode)" not in text:
    old = '''    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
        }
    }
'''
    new = '''    private var allModeActive = false
    private var allRotationTask: Task<Void, Never>?

    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
        }
    }

    func selectMenuBarMode(_ mode: MenuBarMode) {
        if mode == .compact {
            allModeActive = true
            allRotationTask?.cancel()

            let sequence: [MenuBarMode] = [.power, .cpuRam, .cpuTemp, .network]
            menuBarMode = sequence[0]

            allRotationTask = Task { @MainActor [weak self] in
                guard let self else { return }
                var index = 1

                while self.allModeActive && !Task.isCancelled {
                    do {
                        try await Task.sleep(for: .seconds(5))
                    } catch {
                        return
                    }

                    guard self.allModeActive, !Task.isCancelled else { return }
                    self.menuBarMode = sequence[index]
                    index = (index + 1) % sequence.count
                }
            }
        } else {
            allModeActive = false
            allRotationTask?.cancel()
            allRotationTask = nil
            menuBarMode = mode
        }
    }
'''
    if old not in text:
        raise SystemExit("Could not locate SystemMonitor.menuBarMode property")
    text = text.replace(old, new, 1)

# 3) Put cycle count on the Battery card.
old_battery = '''                metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining)", icon: "battery.75percent", color: .green)
'''
new_battery = '''                metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining) · Cycles: \\(monitor.batteryCycles)", icon: "battery.75percent", color: .green)
'''
if old_battery in text:
    text = text.replace(old_battery, new_battery, 1)

# 4) Avoid showing cycle count twice.
old_power = '''                metric("Power & Fans", "\\(monitor.powerWatts) · \\(monitor.fanSpeed)", detail: "\\(monitor.powerState) · \\(monitor.batteryCycles) cycles", icon: "bolt.fill", color: .orange)
'''
new_power = '''                metric("Power & Fans", "\\(monitor.powerWatts) · \\(monitor.fanSpeed)", detail: monitor.powerState, icon: "bolt.fill", color: .orange)
'''
if old_power in text:
    text = text.replace(old_power, new_power, 1)

path.write_text(text, encoding="utf-8")
PY

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
