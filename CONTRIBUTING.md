# Contributing

Build with Swift 6.2 / Xcode 26 or later on macOS. Run `./build-app.sh` and `COSMICTILE_TEST_APP="$PWD/dist/CosmicTile.app" swift test` before proposing a change. The bundled app is used for the native updater tests. Keep pure layout behavior in TileCore and macOS Accessibility integration in the app target. Add regression tests for layout bugs.

To verify login behavior, install the packaged app in Applications, enable **Ajustes → Geral → Abrir ao iniciar sessão**, then sign out and back in. Check that CosmicTile opens in the menu bar. Repeat after an in-place update, then turn the option off and confirm that the app stays closed at the next login.

For a window-management bug, include:

- macOS version, app version, and affected application.
- Monitor arrangement, scaling, and which monitor has the menu bar.
- Whether separate Spaces are enabled for displays.
- Exact steps, expected behavior, and actual behavior.
- Whether Accessibility is granted and any shortcut conflicts shown in the menu.

Avoid including private window titles or content in reports. Screenshots are useful when they show layout geometry.
