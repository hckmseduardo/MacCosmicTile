#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
bundle="${COSMICTILE_BUILD_DIR:-dist}/CosmicTile.app"
mkdir -p "$bundle/Contents/MacOS"
cp .build/release/CosmicTile "$bundle/Contents/MacOS/CosmicTile"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.cosmictile.mac</string>
<key>CFBundleName</key><string>CosmicTile</string>
<key>CFBundleExecutable</key><string>CosmicTile</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.3.0</string>
<key>CFBundleVersion</key><string>3</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
echo "App gerado: $bundle"
