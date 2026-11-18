# v0.3 validation

## Automated

- `swift test`: 22 tests, zero failures.
- `./build-app.sh`: release bundle built on Apple Silicon, Swift 6.2.3 / Xcode 26.2.
- `codesign --verify --strict dist/CosmicTile.app`: verify local ad-hoc signature.
- `plutil -lint dist/CosmicTile.app/Contents/Info.plist`: verify bundle metadata.

## Native UI

The native settings window was opened and inspected through Accessibility. Both monitor switches, highlight controls, keyboard guide and key explanations were visible. Documentation screenshots capture only this app's native window. The embedded layout illustration does not demonstrate external window control.

The original native NSMenu became unresponsive to external inspection while tracking. v0.3 replaces it with transient NSPopover quick controls and explicit Escape/close handling. The final running bundle was inspected with the quick controls open; sending Escape dismissed the panel and returned to the settings window. Outside-click behavior uses NSPopover.transient; it has not been isolated in an automated regression test.

## Geometry evidence

On the development setup the primary usable frame reserves a 30 pt top menu bar; the secondary visibleFrame covers its entire 1920 × 1080 pt display while actual windows begin at y = 40 pt with a 10 pt gap. The new geometry reserves that menu inset on secondary screens too. Regression tests include a display above the primary and negative coordinates.

## Remaining manual checks

Validate enabled/disabled monitors independently using actual application windows, resize mode registration and cleanup, outline following focus, apps with restrictive minimum sizes, display disconnect/reconnect, Spaces, auto-hidden menu bars, and restoration. Replacing an ad-hoc signed bundle can require renewed Accessibility permission. Do not treat the automated geometry tests as end-to-end validation of these scenarios.
