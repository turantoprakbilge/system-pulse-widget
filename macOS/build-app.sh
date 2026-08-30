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

# Apply small source-level UI/behavior patches before building. Keeping these
# transformations here lets the checked-in app source stay readable while the
# local build always contains the current UI behavior.
/usr/bin/python3 - "$source_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

old_property = '''    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
        }
    }
'''
new_property = '''    private var allModeActive = false
    private var allRotationTask: Task<Void, Never>?

    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
            if menuBarMode == .compact {
                allModeActive = true
                startAllModeRotation()
            }
        }
    }

    func selectMenuBarMode(_ mode: MenuBarMode) {
        if mode == .compact {
            allModeActive = true
            menuBarMode = .compact
        } else {
            allModeActive = false
            allRotationTask?.cancel()
            allRotationTask = nil
            menuBarMode = mode
        }
    }

    private func startAllModeRotation() {
        allRotationTask?.cancel()
        allRotationTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let sequence: [MenuBarMode] = [.power, .cpuRam, .cpuTemp, .network]
            var index = 0

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
    }
'''
if old_property not in text:
    raise SystemExit("menuBarMode block not found")
text = text.replace(old_property, new_property, 1)

old_init = '''        menuBarMode = MenuBarMode(rawValue: savedMode) ?? .power

        restartMonitoring()
'''
new_init = '''        menuBarMode = MenuBarMode(rawValue: savedMode) ?? .power
        if menuBarMode == .compact {
            allModeActive = true
            startAllModeRotation()
        }

        restartMonitoring()
'''
if old_init not in text:
    raise SystemExit("init block not found")
text = text.replace(old_init, new_init, 1)

old_button = '''                            monitor.menuBarMode = mode
'''
new_button = '''                            monitor.selectMenuBarMode(mode)
'''
if old_button not in text:
    raise SystemExit("mode button assignment not found")
text = text.replace(old_button, new_button, 1)

old_battery = '''metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining)", icon: "battery.75percent", color: .green)
'''
new_battery = '''metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining) · Cycles: \\(monitor.batteryCycles)", icon: "battery.75percent", color: .green)
'''
if old_battery not in text:
    raise SystemExit("battery metric line not found")
text = text.replace(old_battery, new_battery, 1)

old_power_detail = '''metric("Power & Fans", "\\(monitor.powerWatts) · \\(monitor.fanSpeed)", detail: "\\(monitor.powerState) · \\(monitor.batteryCycles) cycles", icon: "bolt.fill", color: .orange)
'''
new_power_detail = '''metric("Power & Fans", "\\(monitor.powerWatts) · \\(monitor.fanSpeed)", detail: monitor.powerState, icon: "bolt.fill", color: .orange)
'''
if old_power_detail not in text:
    raise SystemExit("power metric line not found")
text = text.replace(old_power_detail, new_power_detail, 1)

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
