# Consent-gated release updates implementation plan

**Goal:** Detect compatible GitHub releases and download only after explicit approval; installation remains manual.

**Architecture:** A pure release-selection/consent state layer in TileCore, an asynchronous URLSession client, and an AppKit offer/download coordinator. Preview releases are included because current distributions are previews. Network checks run at startup and at most daily; users can check manually or disable automatic checks. Only public GitHub metadata is requested; no runtime credentials.

**Files:**
- `Sources/TileCore/Updates.swift`: semantic versions, release DTOs, strict native asset/URL/digest selection, consent state, file integrity validation.
- `Tests/TileCoreTests/UpdateTests.swift`: version ordering, drafts/previews, CPU matching, trusted URLs, malformed hashes, denied/duplicate approval, SHA/size failures.
- `Sources/CosmicTile/UpdateService.swift`: public HTTPS metadata lookup, bounded download, integrity check and non-overwriting Downloads destination.
- `Sources/CosmicTile/Updater.swift`: main-thread alerts, single-flight scheduling, daily timestamp, ignored version and folder reveal.
- `main.swift` / `QuickControls.swift`: lifecycle, manual check and automatic-check control.

## Execution
- [x] Write selection and consent tests; run `swift test` and observe missing feature failures.
- [x] Implement pure policies and stream SHA-256 validation; verify the tests.
- [x] Implement asynchronous metadata lookup and user-authorized download; automatic checks never fetch assets.
- [x] Integrate version/notes/Download/Later/release-page actions and automatic-check toggle.
- [ ] Add CLI metadata-only smoke check, run actual public API lookup, compile packaged app and verify resources.
- [ ] Review, update English README/changelog and publish v0.4.0.

## Release trust and failure behavior
Select the highest newer valid semantic version from releases, ignoring drafts. Require an exact native ZIP filename, uploaded state, positive size up to 512 MiB, official owner/repository GitHub HTTPS download path and an API-provided 64-hex SHA-256 digest. A checksum provides transfer integrity, not Developer ID signing or notarization. Timeouts, rate limits, wrong sizes or hashes show a manual error and never expose a completed ZIP. Partial files are removed. Existing downloads are not overwritten. No extraction, execution, replacement or restart is performed.
