# Proposal

## Why

`2026-10-31-decouple-package-install-and-upgrade` made both Homebrew scripts install missing packages unconditionally. That fits `packages.yaml` (darwin-23), but the machine-specific Brewfile (darwin-28) holds App Store apps and VS Code extensions whose installs are slower, need App Store/iCloud state, and fail in ways outside our control (e.g. Apple reissuing iWork ADAM IDs, VS Code bundling `github.copilot-chat` as a built-in). The README already documents machine-specific Brewfiles as "Additional packages requiring confirmation"; the 2026-10-31 change silently removed that gate, and on 2026-11-01 an unprompted darwin-28 run failed and aborted `chezmoi update`.

## What Changes

- darwin-28 runs `brew bundle check --no-upgrade --verbose` after its early full-check skip; when it fails, the script prints the missing entries and asks "Install missing packages from your brewfile? (y/N)". Only on yes does it run `brew bundle install --no-upgrade`. Non-TTY defaults to no.
- The existing check-gated upgrade prompt in darwin-28 is unchanged.
- darwin-23 is unchanged: `packages.yaml` installs remain unconditional.

## Impact

- **Affected specs**: `package-management` — "User Confirmation for Additional Packages" (intro and darwin-28 scenarios).
- **Affected scripts**: `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`.
- **Non-goals**: failure propagation (`exit 1` aborting `chezmoi apply`) is tracked separately.
