## Why

Four information-hiding and change-amplification problems were identified during a Philosophy of Software Design review of the template system. The Claude AI tooling scripts (37/38/39) share iteration logic that is copy-pasted verbatim, the iCloud skip-and-warn pattern is duplicated across two package-management scripts, the `claude-environments` partial hardcodes an env→color mapping that should be driven by data, and script 40 still uses the deprecated `machine-config` single-lookup pattern instead of `machine-settings`. These issues compound every time a new Claude environment or operation is added.

## What Changes

- **Add `for_each_claude_env` to `shared-utils.sh`**: A function that iterates configured Claude environment directories, handles `~` expansion, and skips missing dirs — eliminating the copy-pasted block in scripts 37, 38, and 39.
- **Add `require_icloud_signed_in` to `shared-utils.sh`**: A function that checks iCloud sign-in state, prints the standard skip warning, and returns non-zero — collapsing the duplicated guard in scripts 23 and 28 to one line each.
- **Make `claude-environments` color mapping data-driven**: Move the `work → 33 / personal → 76 / bedrock → 208` color map out of the partial and into `config.yaml` as `claude_env_colors`, with a hardcoded fallback default. The partial reads the map at render time.
- **Migrate script 40 to `machine-settings`**: Replace the two separate `machine-config` calls in `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl` with a single `machine-settings` lookup, consistent with all other scripts.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `shared-utilities`: Adding two new required functions (`for_each_claude_env`, `require_icloud_signed_in`) that callers depend on for correctness.
- `claude-environments`: The env-to-color mapping requirement changes from hardcoded to data-driven; adding new environments no longer requires editing the partial.

## Impact

- **Affected scripts**: `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`, `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`, `run_onchange_before_darwin-23-install-packages.sh.tmpl`, `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl`
- **Affected shared files**: `scripts/shared-utils.sh`, `home/.chezmoitemplates/claude-environments`
- **Affected data files**: `home/.chezmoidata/config.yaml` (new optional `claude_env_colors` key per machine)
- **Tags affected**: `ai` (Claude scripts and claude-environments), `core` (iCloud guard in package scripts)
- **Security**: No secrets involved. `config.yaml` additions are non-sensitive color codes.
- **Non-goals**: Does not address `set -euo pipefail` gaps, the syncthing `output` fragility, or the `echo` vs `print_message` inconsistencies in Defender/GlobalProtect scripts — those are separate concerns. Does not redesign the `machine-config` / `machine-settings` API itself.
- **Breaking changes**: None — `for_each_claude_env` replaces inline logic with identical behavior; `require_icloud_signed_in` replaces duplicated guards; color fallback ensures unspecified envs still render.
