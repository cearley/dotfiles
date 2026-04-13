## Why

When `brew bundle` fails to download a single cask (e.g., `postman` due to a transient DNS failure for `dl.pstmn.io`), it exits non-zero and the script's `set -euo pipefail` aborts the entire install — before a single package is actually installed. All ~90 successfully pre-fetched packages are discarded because of one unavailable cask, leaving a fresh machine with nothing installed.

## What Changes

- Modify `darwin-23-install-packages.sh.tmpl` so that `brew bundle` failures emit a warning instead of aborting the script. Packages that downloaded successfully will still be installed; only the failed ones are skipped.
- After a partial failure, print a clear message directing the user to run `chezmoi apply` again after resolving the issue (e.g., restoring network access or removing a broken cask entry).

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `package-management`: Add a requirement that Homebrew bundle installation SHALL be resilient to individual package download failures — a single cask failure MUST NOT prevent successfully-downloaded packages from being installed.

## Impact

- **Affected file**: `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl` (line 40 — the `brew bundle` call)
- **Spec delta**: `openspec/specs/package-management/spec.md` — new requirement added
- **Tags affected**: All tags (the `brew bundle` call is not tag-gated)
- **Breaking**: No — this relaxes a failure condition; existing behavior on clean runs is unchanged
- **Security**: No implications — package installation is unchanged; only the error handling path changes
- **Non-goals**: Does not retry failed packages automatically. Does not remove or skip known-broken packages from `packages.yaml`. Does not add network connectivity checks.
