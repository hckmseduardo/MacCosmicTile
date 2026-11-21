# GitHub release updates

CosmicTile checks the public GitHub releases list at startup and at most once per 24 hours. **Check for updates…** runs an immediate check, and **Automatically check for updates** can disable scheduled checks. Current preview releases are included. No GitHub account or runtime token is required.

A compatible newer release displays its version, notes and download size. **Later** is the default keyboard action. **Install and Restart** authorizes the download and installation. Declining suppresses that version's automatic prompt, while manual checks remain available.

## Download and installation

CosmicTile downloads the approved ZIP to a private staging directory beside the installed app. The updater enforces the native architecture filename, repository HTTPS path, uploaded state, bounded asset size and a GitHub-provided SHA-256 digest. It validates the extracted bundle's identifier, version, executable architecture and code signature before quitting.

A helper waits for CosmicTile to quit, then atomically exchanges the staged and installed bundles. It opens the new version from the original path and retains the old bundle until the new version finishes starting. If startup fails, it swaps the previous bundle back and reopens it. If automatic recovery is blocked, the error gives the path to the preserved copy.

After a forced quit or power loss during an update, a hidden `.<app name>.app.update` directory may remain beside the installed app. If no update is running, move that directory aside before retrying. Keep any app bundle under its `payload` folder until the installed version opens successfully.

The updater needs write access to the app's folder. Install in Applications or ~/Applications. Updating from v0.4.1 or earlier requires one final manual replacement. The bundle identifier stays the same, preserving saved preferences. Apple may require renewed Accessibility permission after replacing an ad-hoc signed bundle.

SHA-256 validates downloaded bytes against GitHub metadata. Code signature verification checks the integrity of the extracted bundle. Preview builds use ad-hoc signing. They are distributed without Apple notarization.

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
