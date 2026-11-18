# Contributing

Build with Swift 6.2 / Xcode 26 or later on macOS. Run `swift test` and `./build-app.sh` before proposing a change. Keep pure layout behavior in TileCore and macOS Accessibility integration in the app target. Add regression tests for layout bugs.

For a window-management bug, include:

- macOS version, app version, and affected application.
- Monitor arrangement, scaling, and which monitor has the menu bar.
- Whether separate Spaces are enabled for displays.
- Exact steps, expected behavior, and actual behavior.
- Whether Accessibility is granted and any shortcut conflicts shown in the menu.

Avoid including private window titles or content in reports. Screenshots are useful when they show layout geometry.
