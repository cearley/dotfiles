# Proposal

## Why

`brew bundle check` reports missing and outdated entries alike ("needs to be installed or updated"). darwin-23 and darwin-28 gate their upgrade prompt on that check alone, so after a failed install, or after the user declines darwin-28's install prompt, they ask "Packages ... have updates available — install them now?" when nothing is outdated. Seen during the 2026-11-01 live test of `non-fatal-brew-failures`.

## What Changes

- darwin-23 and darwin-28 first run `brew bundle check --no-upgrade`. If anything is still missing they print a skip notice and don't offer upgrades. Otherwise the existing full check decides whether to show the upgrade prompt.
- darwin-23 writes its combined Brewfile to one temp file shared by both checks and the upgrade, replacing two identical heredocs.

## Impact

- **Affected specs**: `package-management` — "User Confirmation for Additional Packages".
- **Affected scripts**: darwin-23, darwin-28.
- **Trade-off**: while any declared package stays missing, upgrades aren't offered for that script. Install it or remove it from the declared set.
