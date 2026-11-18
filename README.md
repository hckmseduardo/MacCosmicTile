# MacCosmicTile

A native macOS tiling window manager written in Swift and AppKit, inspired by the window management workflow of [COSMIC](https://system76.com/cosmic/).

**Early prototype · v0.2.0.** Independent project, not affiliated with System76. It manages existing application windows through the macOS Accessibility API; it does not replace the macOS compositor.

## Features

- Independent tiling tree for each monitor.
- Automatic horizontal or vertical splits based on available space.
- Placement near the previously focused window, with a preference for larger regions when the focused tile is crowded.
- Directional focus, window swapping, split rotation, and keyboard resizing.
- Resize mode with an on-screen shortcut guide.
- Toggle individual windows between tiled and floating.
- Move the focused window to the next monitor.
- Adjustable gaps and manual split orientation through a menu bar app.
- Restore original window frames when disabling tiling or quitting normally.
- Detect connected and disconnected monitors.

## Requirements

- macOS 14 or later; broader compatibility has not been tested.
- Swift 6.2 toolchain (Xcode 26 or later).
- Accessibility permission to control other apps' windows.

Built locally with Xcode 26.2 / Swift 6.2.3 on Apple Silicon. No third-party package dependencies. Intel builds have not been validated.

## Build and run

```sh
git clone https://github.com/hckmseduardo/MacCosmicTile.git
cd MacCosmicTile
./build-app.sh
open dist/CosmicTile.app
```

The app starts with tiling **off**. Look for **▦** in the menu bar, then select **Ativar tiling**.

On the first activation, grant access in **System Settings → Privacy & Security → Accessibility**. Quit and reopen the app if needed, then activate tiling again. Keep the app at a stable path to reduce permission issues. Rebuilding a locally signed app may require renewing its Accessibility authorization.

The build script creates a locally ad-hoc signed bundle. It does not produce a Developer ID signed or notarized distribution. Menu text is currently in Portuguese.

## Keyboard shortcuts

`⌃` = Control · `⌥` = Option · `⌘` = Command · `⇧` = Shift.

| Shortcut | Action |
| --- | --- |
| `⌃⌥T` or `⌃⌥Y` | Toggle tiling; restore original frames when disabling |
| `⌃⌥F` or `⌃⌥G` | Toggle focused window floating |
| `⌃⌥← ↑ ↓ →` | Focus a window in that direction |
| `⌃⌥⇧← ↑ ↓ →` | Swap with a window in that direction |
| `⌃⌥R` | Enter/exit resize mode |
| `⌃⌥← / →` in resize mode | Reduce/increase focused window width |
| `⌃⌥↑ / ↓` in resize mode | Reduce/increase focused window height |
| `⌃⌥⌘← ↑ ↓ →` | Resize directly without entering resize mode |
| `⌃⌥O` | Rotate the focused window's immediate split |
| `⌃⌥M` | Move focused window to next monitor |
| `⌃⌥= / -` | Increase/decrease the focused leaf's immediate split proportion |

Resizing adjusts neighboring tiles in the same split. It stops at configured ratio bounds. A direction has no effect if no ancestor split exists on that axis. The menu reports shortcut registration conflicts.

## Development

Open `Package.swift` in Xcode, or use Swift Package Manager:

```sh
swift test
swift build -c release
./build-app.sh
dist/CosmicTile.app/Contents/MacOS/CosmicTile --diagnose
```

Override the output directory if needed:

```sh
COSMICTILE_BUILD_DIR=/path/to/output ./build-app.sh
```

### Architecture

| Component | Responsibility |
| --- | --- |
| `Sources/TileCore/Layout.swift` | Binary layout tree, frame calculation, removal, insertion, swaps, resizing, rotation |
| `Sources/TileCore/Placement.swift` | Focus-aware placement and space heuristics |
| `Sources/CosmicTile/Accessibility.swift` | Enumerate visible standard windows and read/write their frames |
| `Sources/CosmicTile/Controller.swift` | Per-monitor state, reconciliation, focus, floating, restoration |
| `Sources/CosmicTile/Hotkeys.swift` | Global Carbon hotkeys |
| `Sources/CosmicTile/main.swift` | Menu bar lifecycle, controls, resize guide |

## Current limitations

- No tabbed stacks, group selection, drag-and-drop preview, active-window border, or persistent per-app rules yet.
- Layouts are maintained for visible windows on the current macOS Space; there is no independent workspace system or per-Space layout persistence.
- Reconciliation uses 350 ms polling. Frame application pauses during mouse dragging and only occurs when layout membership or monitor geometry changes, or after an explicit layout command.
- Manual mouse resizing does not update stored split proportions.
- Placement uses an approximate minimum of 480 × 300 points per tile. Applications can impose larger minimum sizes, so overlap remains possible in crowded layouts.
- App-specific Accessibility behavior can prevent moving, focusing, or resizing a window. Minimized, fullscreen, nonstandard and hidden windows are excluded.
- Restoring positions is best-effort, particularly after monitor disconnection. Forced termination cannot restore frames.
- Settings are limited: gap size persists, layout trees and floating state do not.

## Validation

Unit tests cover insertion of newly focused windows, missing focus targets, focus-aware placement, crowded tiles, split geometry with negative monitor coordinates, gaps, removal, swapping, axis-specific resizing, and rotation.

A successful build and unit tests do not establish real-window behavior across all apps. Before everyday use, test opening three or more windows, resizing in both axes, transferring across monitors, disconnecting a monitor, changing Spaces, and disabling tiling to restore positions. The initial prototype was tried by the project owner; the v0.2 fixes still need live validation.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for setup and useful bug report details, [CHANGELOG.md](CHANGELOG.md) for changes, and [docs/ROADMAP.md](docs/ROADMAP.md) for planned work.
