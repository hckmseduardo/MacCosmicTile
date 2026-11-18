# Changelog

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
