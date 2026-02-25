# Change: Add Bun Global Package Installation

## Why
Bun is now a core Homebrew package, but there's no mechanism to install global bun packages (e.g., `ralph-tui`) from `packages.yaml`. The `bun` key already exists in the data file under the `ai` tag but nothing consumes it — mirroring a gap that UV tools once had before their installation script was added.

## What Changes
- Add a `run_onchange_before` installation script at position 26 that installs bun global packages from `packages.yaml`
- Rename `run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` to position 28 so the machine-specific Brewfile script remains last in the package management group (20-29)
- Update the package-management spec to document the `bun` key and its installation behavior
- Update the tag reference table and installation sequence to include bun
- Update the central package definition requirement to include `bun` as a recognized package type

## Impact
- Affected specs: `package-management`
- Affected code:
  - `home/.chezmoiscripts/run_onchange_before_darwin-26-install-bun-packages.sh.tmpl` (new)
  - `home/.chezmoiscripts/run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` → renamed to `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`
  - `home/.chezmoidata/packages.yaml` (already has `bun` key — no changes needed)
