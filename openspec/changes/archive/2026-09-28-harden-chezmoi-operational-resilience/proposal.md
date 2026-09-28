# Proposal

## Why

The Codex CLI review that produced `harden-chezmoi-bootstrap-and-permissions` (2026-09-28) also found seven medium-severity operational-resilience gaps, deliberately left out of that change as a separate follow-up (its proposal's Non-goals section names them explicitly). Re-verified against current source before drafting this proposal (2026-09-28, post-archive): all seven are still present. Each is a correctness or supply-chain gap in an already-shipped mechanism — install-failure handling, package auditing, persona teardown, dependency pinning, and CI coverage — not new functionality.

## What Changes

- **Run_onchange failure propagation**: a `run_onchange_` script that logs a non-critical warning for an individual failed operation (a Homebrew formula, an MCP server registration) currently still exits `0`. Since chezmoi's `run_onchange_` re-execution is gated on the script's own rendered-content hash, not its prior exit status, this makes the scripts' own "run `chezmoi apply` again" advice untruthful — a content-unchanged script that partially failed will not be reattempted. Scripts SHALL exit non-zero when any individual operation failed, so chezmoi's own retry-on-failure behavior actually retries them.
- **Non-destructive resource replacement**: `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` currently removes an existing MCP server registration before confirming the replacement registration succeeds — a failed replacement leaves the server unregistered rather than reverted to its prior working state. Replacement logic SHALL confirm the new registration succeeds before removing the old one, or SHALL restore the prior registration on failure.
- **Private package-index dependency-confusion guard**: `home/private_dot_config/private_pip/private_pip.conf.tmpl` adds GitHub/Azure DevOps private package indexes via `extra-index-url` alongside the implicit default PyPI index — a public package sharing an internal package's name can be resolved from the wrong (public) source. Configuration SHALL prefer an index precedence or scoping mechanism that does not let a public index silently shadow-match a private package name.
- **LaunchAgent teardown on persona removal**: `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl` exits cleanly when `claude_default` is unset, but never unloads a LaunchAgent it previously installed or removes its plist — GUI-launched apps keep inheriting a stale `CLAUDE_CONFIG_DIR` after the machine's `claude_default` is removed. The script SHALL detect and tear down a previously-installed LaunchAgent when `claude_default` is no longer declared.
- **Complete package-audit declaration set**: `audit-packages`'s Homebrew orphan detection reads only `packages.yaml`, excluding the machine-specific Brewfile that `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` also installs — intentionally declared machine-specific packages are reported as orphans. The audit SHALL union both declaration sources before computing Homebrew orphans.
- **Pinned executable externals**: `home/.chezmoiexternal.toml.tmpl` and `home/dot_claude/.chezmoiexternal.toml.tmpl` track `master`/`main` branches by tarball/file URL for zsh plugins, `zsh-functions`, `freshbooks-mcp-server`, and the `jev-model-router` mod files — an upstream compromise or breaking change on any of these branches lands on the next `chezmoi apply` with no review step. Executable/behavior-affecting externals SHALL be pinned to a specific reviewed ref, updated deliberately.
- **CI exercises this checkout's own configuration**: `.github/workflows/ci.yml` sets a `REPO` environment variable that `remote_install.sh` never reads, so CI only verifies a generic bootstrap runs, not that this checkout's actual `packages.yaml`, machine config, or recent template changes render and apply correctly. CI SHALL exercise the actual checkout under test.

**Non-goals**

- No change to the SDKMAN/uv render-before-script-execution ordering gap (Codex finding 4): this is a concrete, already-covered instance of `script-execution`'s existing "Template rendering SHALL NOT assume an unenforced script-ordering dependency" requirement (added by `harden-chezmoi-bootstrap-and-permissions`). No new requirement is needed — fixing scripts 24/25 to comply with that existing requirement is a `tasks.md` item under this change, not a spec change.
- No migration of existing `.chezmoiexternal.toml.tmpl` entries' current commit SHAs is prescribed here beyond "pin to the current HEAD of the tracked branch at implementation time" — ongoing update cadence (how/when to bump a pin) is a process decision for `tasks.md`, not a new automated mechanism.
- No new CI stages beyond making the existing bootstrap-verification job actually target this checkout; broader CI expansion (linting, per-tag matrix builds) is out of scope.
- No change to how KeePassXC-vs-SOPS+age secret tiering works, and no change to the shell-quoting or Pattern C isolation work already shipped in `harden-chezmoi-bootstrap-and-permissions`.

## Capabilities

### New Capabilities
- `external-dependency-pinning`: defines that executable/behavior-affecting chezmoi externals (`.chezmoiexternal.toml.tmpl` entries whose content executes or is sourced, as opposed to purely cosmetic assets) SHALL be pinned to a specific reviewed ref rather than tracking a mutable branch.
- `ci-validation`: defines that this repo's CI SHALL exercise the actual checkout under test (its `packages.yaml`, machine config, and current template state), not a generic/disconnected bootstrap run.

### Modified Capabilities
- `script-execution`: adds a requirement that a `run_onchange_` script experiencing a non-critical individual-operation failure SHALL still exit non-zero overall, so chezmoi's own failure-triggered re-execution actually retries it (extends the existing "Error Handling" requirement). Adds a new requirement that replacing an existing managed resource SHALL NOT remove the existing resource before the replacement is confirmed to succeed.
- `package-management`: adds a requirement that private package-index configuration (pip, and analogous per-ecosystem index configuration) SHALL NOT let a public index silently resolve a name that collides with a private package.
- `claude-environments`: adds a requirement that the LaunchAgent-provisioning script SHALL detect and tear down a previously-installed LaunchAgent (unload + remove plist) when `claude_default` is no longer declared, extending its existing ignore-on-absence requirement.
- `package-audit`: modifies the "declared" set computation for Homebrew formulae/casks/taps to also include the machine-specific Brewfile's contents, not `packages.yaml` alone.

## Impact

- **Affected scripts/templates**: `home/.chezmoiscripts/run_onchange_before_darwin-23-install-packages.sh.tmpl`, `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`, `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl`, `home/private_dot_config/private_pip/private_pip.conf.tmpl`, `home/dot_local/bin/executable_audit-packages.tmpl`, `home/.chezmoiexternal.toml.tmpl`, `home/dot_claude/.chezmoiexternal.toml.tmpl`, `.github/workflows/ci.yml`, `remote_install.sh`.
- **Affected tags**: no new tag introduced; touched scripts already gate on `ai`/`dev`/`work`/`darwin` as they do today.
- **Security implications**: the pip dependency-confusion fix and the externals-pinning fix are both supply-chain hardening with no feature surface change. The LaunchAgent teardown fix closes a privilege-adjacent staleness gap (GUI apps silently keep using a stale `CLAUDE_CONFIG_DIR`, potentially the wrong persona). The run_onchange/replacement fixes are reliability, not security, but reduce the chance of a partially-failed apply going unnoticed and unretried.
- **Excluded from this change**: Codex finding 4 (SDKMAN/uv ordering) — already covered by an existing requirement, see Non-goals.
