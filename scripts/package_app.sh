#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DingDong"
MCP_NAME="dingdong-mcp"
ARCH="${DINGDONG_ARCH:-$(uname -m)}"
VERSION="${DINGDONG_VERSION:-0.1.0}"
BUILD_NUMBER="${DINGDONG_BUILD:-1}"
DIST_DIR="$ROOT_DIR/dist"
OUTPUT_APP_NAME="${DINGDONG_OUTPUT_APP:-$APP_NAME.app}"
BUILD_DIR="$ROOT_DIR/.build/$ARCH-apple-macosx/release"
APP_DIR="$DIST_DIR/$OUTPUT_APP_NAME"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$DIST_DIR/AppIcon.iconset"
ICON_SOURCE="$ROOT_DIR/Assets/AgentToolIcon.png"
MENU_BAR_ICON_SOURCE="$ROOT_DIR/Assets/AgentToolMenuBarIcon.png"
MENU_BAR_HOT_ICON_SOURCE="$ROOT_DIR/Assets/AgentToolMenuBarHotIcon.png"

cd "$ROOT_DIR"

case "$ARCH" in
  arm64|x86_64) ;;
  *)
    echo "Unsupported DINGDONG_ARCH: $ARCH" >&2
    echo "Use arm64 or x86_64." >&2
    exit 1
    ;;
esac

swift build -c release --arch "$ARCH"

rm -rf "$APP_DIR" "$ICONSET_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

cp "$BUILD_DIR/$APP_NAME" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$BUILD_DIR/$MCP_NAME" "$MACOS_DIR/$MCP_NAME"
chmod +x "$MACOS_DIR/$MCP_NAME"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing icon source: $ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$MENU_BAR_ICON_SOURCE" ]]; then
  echo "Missing menu bar icon source: $MENU_BAR_ICON_SOURCE" >&2
  exit 1
fi

if [[ ! -f "$MENU_BAR_HOT_ICON_SOURCE" ]]; then
  echo "Missing menu bar hot icon source: $MENU_BAR_HOT_ICON_SOURCE" >&2
  exit 1
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleExecutable</key>
  <string>DingDong</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>com.temptrip.dingdong</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>DingDong</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSSupportsAutomaticTermination</key>
  <false/>
</dict>
</plist>
PLIST

swift - "$ICONSET_DIR" "$ICON_SOURCE" "$MENU_BAR_ICON_SOURCE" "$MENU_BAR_HOT_ICON_SOURCE" <<'SWIFT'
import AppKit
import Foundation

let iconset = URL(fileURLWithPath: CommandLine.arguments[1])
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
let menuBarSourceURL = URL(fileURLWithPath: CommandLine.arguments[3])
let menuBarHotSourceURL = URL(fileURLWithPath: CommandLine.arguments[4])

guard let sourceIcon = NSImage(contentsOf: sourceURL) else {
    throw NSError(domain: "DingDongIcon", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Could not load icon source at \(sourceURL.path)"
    ])
}

guard let menuBarIcon = NSImage(contentsOf: menuBarSourceURL) else {
    throw NSError(domain: "DingDongIcon", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "Could not load menu bar icon source at \(menuBarSourceURL.path)"
    ])
}

guard let menuBarHotIcon = NSImage(contentsOf: menuBarHotSourceURL) else {
    throw NSError(domain: "DingDongIcon", code: 4, userInfo: [
        NSLocalizedDescriptionKey: "Could not load menu bar hot icon source at \(menuBarHotSourceURL.path)"
    ])
}

func centeredRect(sourceSize: NSSize, in target: NSRect) -> NSRect {
    guard sourceSize.width > 0, sourceSize.height > 0 else {
        return target
    }

    let sourceRatio = sourceSize.width / sourceSize.height
    let targetRatio = target.width / target.height
    var rect = target

    if targetRatio > sourceRatio {
        rect.size.width = target.height * sourceRatio
        rect.origin.x += (target.width - rect.width) / 2
    } else {
        rect.size.height = target.width / sourceRatio
        rect.origin.y += (target.height - rect.height) / 2
    }

    return rect.integral
}

func drawSourceIcon(_ icon: NSImage, size: CGFloat, background: Bool, hot: Bool = false) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))

    image.lockFocus()
    NSGraphicsContext.current?.imageInterpolation = .high

    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size, height: size).fill()

    if background {
        let rect = NSRect(x: 0, y: 0, width: size, height: size)
        let path = NSBezierPath(roundedRect: rect, xRadius: size * 0.22, yRadius: size * 0.22)
        NSColor(red: 0.965, green: 0.948, blue: 0.910, alpha: 1).setFill()
        path.fill()

        NSColor(red: 0.11, green: 0.12, blue: 0.14, alpha: 0.10).setStroke()
        path.lineWidth = max(1, size * 0.010)
        path.stroke()
    } else if hot {
        let rect = NSRect(x: size * 0.06, y: size * 0.06, width: size * 0.88, height: size * 0.88)
        NSColor(red: 0.91, green: 0.33, blue: 0.20, alpha: 0.14).setFill()
        NSBezierPath(roundedRect: rect, xRadius: size * 0.18, yRadius: size * 0.18).fill()
    }

    let inset = background ? size * 0.10 : size * 0.02
    let target = NSRect(x: inset, y: inset, width: size - inset * 2, height: size - inset * 2)
    icon.draw(
        in: centeredRect(sourceSize: icon.size, in: target),
        from: .zero,
        operation: .sourceOver,
        fraction: 1
    )

    image.unlockFocus()
    return image
}

func writePNG(_ image: NSImage, to url: URL) throws {
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "DingDongIcon", code: 1)
    }

    try png.write(to: url)
}

let sizes: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024),
]

for (name, size) in sizes {
    try writePNG(drawSourceIcon(sourceIcon, size: size, background: true), to: iconset.appendingPathComponent(name))
}

try writePNG(drawSourceIcon(menuBarIcon, size: 44, background: false), to: iconset.deletingLastPathComponent().appendingPathComponent("MenuBarIcon.png"))
try writePNG(drawSourceIcon(menuBarHotIcon, size: 44, background: false), to: iconset.deletingLastPathComponent().appendingPathComponent("MenuBarIconHot.png"))
try writePNG(drawSourceIcon(sourceIcon, size: 88, background: false), to: iconset.deletingLastPathComponent().appendingPathComponent("PanelLogoIcon.png"))
SWIFT

iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
cp "$DIST_DIR/MenuBarIcon.png" "$RESOURCES_DIR/MenuBarIcon.png"
cp "$DIST_DIR/MenuBarIconHot.png" "$RESOURCES_DIR/MenuBarIconHot.png"
cp "$DIST_DIR/PanelLogoIcon.png" "$RESOURCES_DIR/PanelLogoIcon.png"
rm -rf "$ICONSET_DIR"

echo "$APP_DIR"
