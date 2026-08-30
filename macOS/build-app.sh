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

# Apply small source-level UI/behavior patches before building.
/usr/bin/python3 - "$source_file" <<'PY'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

# 1) Add All-mode rotation support exactly once.
if "private var allModeActive = false" not in text:
    pattern = re.compile(
        r'(?P<indent>    )var menuBarMode: MenuBarMode \{\n'
        r'(?P<body>.*?\n'
        r'    \})',
        re.S,
    )
    replacement = '''    private var allModeActive = false
    private var allRotationTask: Task<Void, Never>?

    var menuBarMode: MenuBarMode {
        didSet {
            UserDefaults.standard.set(menuBarMode.rawValue, forKey: Self.menuBarModeKey)
            if menuBarMode == .compact && !allModeActive {
                allModeActive = true
                startAllModeRotation()
            }
        }
    }

    func selectMenuBarMode(_ mode: MenuBarMode) {
        if mode == .compact {
            allModeActive = true
            startAllModeRotation()
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
    }'''
    text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise SystemExit("Could not locate menuBarMode property")

# 2) Automatically start rotation when the app was previously left in All mode.
if "if menuBarMode == .compact {\n            allModeActive = true\n            startAllModeRotation()" not in text:
    init_pattern = re.compile(
        r'(let savedMode = UserDefaults\.standard\.string\(forKey: Self\.menuBarModeKey\) \?\? ""\n'
        r'\s*menuBarMode = MenuBarMode\(rawValue: savedMode\) \?\? \.power\n)'
    )
    init_replacement = r'''\1        if menuBarMode == .compact {
            allModeActive = true
            startAllModeRotation()
        }
'''
    text, count = init_pattern.subn(init_replacement, text, count=1)
    if count != 1:
        raise SystemExit("Could not locate menuBarMode initialization")

# 3) Manual mode selection must stop All-mode rotation.
text, count = re.subn(
    r'monitor\.menuBarMode = mode',
    'monitor.selectMenuBarMode(mode)',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Could not locate mode button assignment")

# 4) Show cycle count in Battery card and avoid duplicating it in Power & Fans.
text, count = re.subn(
    r'metric\("Battery", "\\\(monitor\.batteryLevel\) · \\\(monitor\.batteryHealth\) Health", detail: "\\\(monitor\.batteryState\) · Rem: \\\(monitor\.batteryRemaining\)", icon: "battery\.75percent", color: \.green\)',
    'metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining) · Cycles: \\(monitor.batteryCycles)", icon: "battery.75percent", color: .green)',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Could not locate Battery metric")

text, count = re.subn(
    r'metric\("Power & Fans", "\\\(monitor\.powerWatts\) · \\\(monitor\.fanSpeed\)", detail: "\\\(monitor\.powerState\) · \\\(monitor\.batteryCycles\) cycles", icon: "bolt\.fill", color: \.orange\)',
    'metric("Power & Fans", "\\(monitor.powerWatts) · \\(monitor.fanSpeed)", detail: monitor.powerState, icon: "bolt.fill", color: .orange)',
    text,
    count=1,
)
if count != 1:
    raise SystemExit("Could not locate Power & Fans metric")

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
