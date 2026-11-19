#!/bin/zsh
set -euo pipefail
cd "${0:A:h}"
swift build -c release
output_bundle="${COSMICTILE_BUILD_DIR:-dist}/CosmicTile.app"
# A non-synced staging directory keeps Finder/file-provider metadata out of signing.
bundle=".build/app-package.nosync/CosmicTile.app"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp Sources/CosmicTile/Resources/* "$bundle/Contents/Resources/"
cp .build/release/CosmicTile "$bundle/Contents/MacOS/CosmicTile"
cat > "$bundle/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>dev.cosmictile.mac</string>
<key>CFBundleName</key><string>CosmicTile</string>
<key>CFBundleExecutable</key><string>CosmicTile</string>
<key>CFBundleIconFile</key><string>CosmicTile.icns</string>
<key>CFBundleDisplayName</key><string>CosmicTile</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.4.1</string>
<key>CFBundleVersion</key><string>6</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>LSUIElement</key><true/>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$bundle"
codesign --force --sign - "$bundle"
codesign --verify --strict "$bundle"
mkdir -p "${output_bundle:h}"
ditto -c -k --keepParent --norsrc "$bundle" "${output_bundle%.app}.zip"
ditto --noextattr "$bundle" "$output_bundle"
echo "Built app: $output_bundle"
echo "Clean distribution archive: ${output_bundle%.app}.zip"
