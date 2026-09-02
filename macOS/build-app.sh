#!/bin/zsh
set -euo pipefail

script_dir="${0:A:h}"
app_dir="$script_dir/build/System Pulse.app"
binary_dir="$app_dir/Contents/MacOS"
resources_dir="$app_dir/Contents/Resources"
macmon_bin="/opt/homebrew/bin/macmon"
macmon_license="/opt/homebrew/opt/macmon/LICENSE"
source_file="$script_dir/Sources/SystemPulseMac/SystemPulseMac.swift"
icon_work_dir="$script_dir/build/icon-work"
icon_png="$icon_work_dir/AppIcon-1024.png"
iconset_dir="$icon_work_dir/AppIcon.iconset"
icon_icns="$icon_work_dir/AppIcon.icns"

cd "$script_dir"

# Apply source patches idempotently.
/usr/bin/python3 - "$source_file" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
text = path.read_text(encoding="utf-8")

text = text.replace(
    "                            monitor.menuBarMode = mode\n",
    "                            monitor.selectMenuBarMode(mode)\n",
    1,
)

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

old_battery = '''                metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining)", icon: "battery.75percent", color: .green)
'''
new_battery = '''                metric("Battery", "\\(monitor.batteryLevel) · \\(monitor.batteryHealth) Health", detail: "\\(monitor.batteryState) · Rem: \\(monitor.batteryRemaining) · Cycles: \\(monitor.batteryCycles)", icon: "battery.75percent", color: .green)
'''
if old_battery in text:
    text = text.replace(old_battery, new_battery, 1)

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

# Generate a simple System Pulse icon directly from code.
rm -rf "$icon_work_dir"
mkdir -p "$icon_work_dir" "$iconset_dir"
cat > "$icon_work_dir/make-icon.swift" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)
let image = NSImage(size: size)
image.lockFocus()

guard let ctx = NSGraphicsContext.current?.cgContext else { fatalError("No graphics context") }
ctx.setAllowsAntialiasing(true)
ctx.setShouldAntialias(true)

let bounds = NSRect(origin: .zero, size: size)
let outer = NSBezierPath(roundedRect: bounds.insetBy(dx: 56, dy: 56), xRadius: 210, yRadius: 210)
NSColor(calibratedRed: 0.035, green: 0.055, blue: 0.075, alpha: 1).setFill()
outer.fill()

let ringRect = bounds.insetBy(dx: 205, dy: 205)
let ring = NSBezierPath(ovalIn: ringRect)
ring.lineWidth = 44
NSColor(calibratedRed: 0.12, green: 0.88, blue: 0.95, alpha: 1).setStroke()
ring.stroke()

let pulse = NSBezierPath()
pulse.lineWidth = 46
pulse.lineCapStyle = .round
pulse.lineJoinStyle = .round
pulse.move(to: NSPoint(x: 255, y: 500))
pulse.line(to: NSPoint(x: 385, y: 500))
pulse.line(to: NSPoint(x: 442, y: 405))
pulse.line(to: NSPoint(x: 514, y: 665))
pulse.line(to: NSPoint(x: 585, y: 450))
pulse.line(to: NSPoint(x: 642, y: 545))
pulse.line(to: NSPoint(x: 770, y: 545))
NSColor(calibratedRed: 0.22, green: 0.96, blue: 0.46, alpha: 1).setStroke()
pulse.stroke()

image.unlockFocus()

guard let tiff = image.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:]) else {
    fatalError("Could not create PNG")
}
try png.write(to: URL(fileURLWithPath: output))
SWIFT

xcrun swift "$icon_work_dir/make-icon.swift" "$icon_png"

for spec in \
  "16 icon_16x16.png" \
  "32 icon_16x16@2x.png" \
  "32 icon_32x32.png" \
  "64 icon_32x32@2x.png" \
  "128 icon_128x128.png" \
  "256 icon_128x128@2x.png" \
  "256 icon_256x256.png" \
  "512 icon_256x256@2x.png" \
  "512 icon_512x512.png" \
  "1024 icon_512x512@2x.png"
do
  px="${spec%% *}"
  name="${spec#* }"
  sips -z "$px" "$px" "$icon_png" --out "$iconset_dir/$name" >/dev/null
 done

iconutil -c icns "$iconset_dir" -o "$icon_icns"

rm -rf "$app_dir"
mkdir -p "$binary_dir" "$resources_dir"
cp "$script_dir/.build/release/SystemPulseMac" "$binary_dir/SystemPulseMac"
cp "$macmon_bin" "$resources_dir/macmon"
cp "$macmon_license" "$resources_dir/macmon-LICENSE"
cp "$icon_icns" "$resources_dir/AppIcon.icns"
cp "$script_dir/Info.plist" "$app_dir/Contents/Info.plist"
codesign --force --deep --sign - "$app_dir"
echo "Created: $app_dir"
