## Why

The `package-update-skip` capability (shipped 2026-07-16) gates six layers — Homebrew, SDKMAN, uv, Bun, Cargo, and Claude skills/MCP/plugins — behind a single cached, two-step interactive prompt shared across 12 scripts. In practice this is more mechanism than the problem needs: only Homebrew cask and `mas` (Mac App Store) installs are slow enough to be worth an install/skip choice — the other five layers are fast and don't warrant gating at all. Worse, the cache is keyed by `$PPID` with a 1-hour TTL, and macOS PID reuse means a `chezmoi apply` run minutes apart from a previous one can silently inherit a stale decision instead of asking fresh — the opposite of what a "skip this run" prompt should do. The user wants the same choice presented every single `chezmoi apply`, with no memory between runs, and only for the two genuinely expensive install types.

## What Changes

- **BREAKING**: Remove the `package_layer_should_skip()` skip-decision guard entirely from the non-Homebrew layers (SDKMAN, uv, Bun, Cargo, Claude skills/MCP/plugins) — these scripts now always run unconditionally, with no prompt and no skip path.
- **BREAKING**: Remove the `CHEZMOI_SKIP_PACKAGE_UPDATES` environment variable and the `${TMPDIR:-/tmp}/chezmoi-package-update-skip.$PPID` cache file mechanism entirely, along with the two-step "skip all / select layers" prompt.
- Delete `package_layer_should_skip()`, `_package_update_skip_load_or_prompt()`, and `_package_update_skip_resolve_and_cache()` from `home/scripts/shared-utils.sh`.
- Split the Homebrew core installer (`run_onchange_before_darwin-23-install-packages.sh.tmpl`) into two separate `brew bundle` invocations: taps + brews run unconditionally (fast, no prompt); casks + mas run only after a fresh `read -p` install/skip prompt, asked every run with no caching, and only attempted when that bundle would be non-empty.
- Remove the now-redundant `package_layer_should_skip("homebrew")` guard from `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` — its existing `read -p "Install additional packages from your brewfile?"` prompt (predates the layered mechanism, confirmed via `git show 61139b3`) is untouched and already provides the desired behavior.
- No TTY guard on either Homebrew prompt: when stdin isn't a terminal, `read` returns empty and the script falls through to "skip" — matching script 28's existing behavior today. This is a deliberate simplification, not an oversight; unattended/CI applies will no longer install casks/mas without an explicit interactive answer.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `package-update-skip`: Requirements rewritten from a 6-layer cached/env-var-driven mechanism to a single ungated, uncached inline prompt scoped to Homebrew casks/mas only.
- `package-management`: Install scripts for SDKMAN, uv, Bun, Cargo, and Claude skills/MCP/plugins lose their skip precondition and always run. The core Homebrew installer's single `brew bundle` step becomes two steps (unconditional formulae/taps, gated casks/mas).

## Impact

- **Affected scripts**: `run_onchange_before_darwin-20-install-sdkman.sh.tmpl`, `run_onchange_before_darwin-21-install-uv.sh.tmpl`, `run_onchange_before_darwin-23-install-packages.sh.tmpl`, `run_onchange_before_darwin-24-install-sdks.sh.tmpl`, `run_onchange_before_darwin-25-install-tools.sh.tmpl`, `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl`, `run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl`, `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`, `run_onchange_after_darwin-44-register-claude-plugin-marketplace.sh.tmpl`.
- **Modified utility**: `home/scripts/shared-utils.sh` loses three functions and gains no replacement helper — the surviving Homebrew prompts are plain inline `read -p` calls, matching script 28's pre-existing style.
- **Tags**: not tag-specific — every tag profile (core, dev, ai, work, personal, datascience, mobile) goes through script 23's Homebrew bundle and is affected by the split; the non-Homebrew layers affect whichever tags pull SDKMAN/uv/Bun/Cargo/Claude packages.
- **Security implications**: none. No secrets involved; the change only affects whether/when install commands run interactively, not what gets installed or how credentials are handled. The existing `warn_icloud_not_signed_in` / `HOMEBREW_BUNDLE_MAS_SKIP` iCloud guard for `mas` installs is unaffected.
- **Non-goals**: this does not add per-package skip control (still per-bundle, not per-item), does not change tag-selection prompts in `.chezmoi.toml.tmpl`, and does not change what `run_onchange` triggers on (content hash / 7-day bucket triggers are untouched — only what happens once a script is triggered changes).
