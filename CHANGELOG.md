# Changelog

## 0.4.0

### Updates
- Detect compatible newer GitHub releases, including current preview releases.
- Add manual update checks and persistent daily/startup automatic-check controls.
- Show version, notes and download size with explicit Download ZIP / Later / Release notes choices.
- Download only after approval; verify architecture, repository HTTPS URL, expected byte length and GitHub SHA-256 digest.
- Stream bounded responses, remove partial files and avoid overwriting existing downloads.
- Reveal the verified ZIP for manual installation; never extract, execute or replace the running app.
- Add selection, consent single-flight and integrity regression tests, plus metadata-only diagnostic.

## 0.3.1

### Branding
- Apply the shared CosmicTile icon to the app bundle, Finder, native settings and quick controls.
- Replace the placeholder menu-bar character with an OS-tinted template of the shared three-window mark.
- Include canonical brand artwork and a packaged-resource verification command.
- Sign in clean staging and create the distribution ZIP before file-provider metadata can be attached.

## 0.3.0

### Added
- Independent tiling switches for every monitor in quick controls and native settings.
- Control + Option + T / Y toggles the focused monitor; Control + Option + Shift + T toggles all connected monitors.
- Click-through active-window outline with persistent enable state, cyan/violet/orange accents and 2/3/5 pt widths.
- Native settings window, illustrative layout preview, keyboard guide and real interface screenshots.
- Temporary unmodified arrow hotkeys during resize mode; Escape and Return end the mode.
- Safe signal handling for normal SIGTERM/SIGINT shutdown and frame restoration.

### Fixed
- Reserve the primary menu-bar top inset on secondary displays when macOS reports their entire frame as usable.
- Disabling a monitor restores only its own managed windows; other monitors remain active.
- Transfers to a disabled monitor leave the window floating.
- Clamp restored frames to the connected monitor's usable bounds.
- Replace the blocking native status menu with a transient popover, outside-click dismissal, explicit close button and Escape handling.
- Exclude modal save/open panels, sheets, dialogs, utility windows and nonresizable auxiliary windows using Accessibility metadata.
- Preserve the selected window for commands invoked from quick controls.

### Documentation
- Expanded English README and Portuguese guide with installation, Accessibility, per-monitor workflows, active hints, shortcuts, troubleshooting and current limits.
- Added release validation notes and 7 monitor/geometry and 5 window-eligibility regression tests (27 tests total).

## 0.2.0

- Fix new windows being omitted from the layout when they already have keyboard focus.
- Add previous-focus placement and automatic split orientation.
- Prefer larger tiles when the focused tile is too crowded to split comfortably.
- Stop reapplying all window frames unconditionally on every polling tick.
- Pause reconciliation during mouse dragging.
- Add axis-specific resizing, resize mode with an on-screen guide, and split rotation.
- Add COSMIC-inspired tiling/floating shortcut aliases.
- Extend regression coverage for placement, resizing and rotation.

## 0.1.0

- Initial Swift/AppKit menu bar prototype.
- Independent monitor layouts, floating windows, global hotkeys, adjustable gaps, and best-effort frame restoration.
