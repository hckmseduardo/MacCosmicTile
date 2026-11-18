# GitHub release updates

CosmicTile checks the public GitHub releases list at startup and at most once per 24 hours. **Check for updates…** runs an immediate check, and **Automatically check for updates** can disable scheduled checks. Current preview releases are included. No GitHub account or runtime token is required.

A compatible newer release displays its version, notes and download size. **Later** is the default keyboard action. **Download ZIP** is the only action that authorizes a package request; opening release notes does not authorize a download. Declining suppresses that version's automatic prompt, while manual checks remain available.

## Download and installation

Approved ZIPs are written to `~/Downloads/CosmicTile Updates/`. The app enforces the native architecture filename, repository HTTPS path, uploaded state, positive bounded asset size and a GitHub-provided SHA-256 digest. Metadata and file responses are streamed with cumulative limits; mismatched lengths, checksums, HTTP failures or timeouts discard partial files. A matching existing download is reused; other files are not overwritten.

The completed ZIP is revealed in Finder. Quit CosmicTile, extract the ZIP and replace the app manually. The updater does not extract, execute, replace, relaunch or change permissions automatically. Updating an ad-hoc signed macOS app can require renewed Accessibility permission.

SHA-256 validates downloaded bytes against GitHub metadata; it is not Developer ID signing, notarization or independent publisher authentication. Existing release previews remain locally signed and non-notarized.

## Version and trust policy

- Fetch `/repos/hckmseduardo/MacCosmicTile/releases?per_page=100`, not the stable-only latest endpoint.
- Ignore drafts and use semantic version precedence, including prerelease identifiers.
- Match only `CosmicTile-TAG-macOS-arm64.zip` or the native x86_64 equivalent.
- Require an exact GitHub owner/repository release-download path and `sha256:` digest.
- Reject same/older releases, wrong architecture, incomplete assets, invalid digests and asset sizes over 512 MiB.
- The first 100 published releases are considered. Auto-check failures stay quiet; a manual check reports errors.

## Developer diagnostic

A metadata-only check never downloads a package:

```sh
dist/CosmicTile.app/Contents/MacOS/CosmicTile --check-updates
```

To inspect selection against existing releases without changing the installed app version:

```sh
dist/CosmicTile.app/Contents/MacOS/CosmicTile --check-updates --current-version 0.1.0
```
