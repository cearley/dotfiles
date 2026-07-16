## Why

Every `chezmoi apply` re-runs the `run_onchange_*` package scripts (positions 20-28, 37-39) whenever their content or `packages.yaml` changes, even when the user only wants to fix one dotfile. Steps like `brew bundle` (network-checks + upgrades every formula/cask), SDKMAN SDK installs, UV/Bun/Cargo tool installs, and Claude Code skills/plugin installs can take several minutes each. There is currently no way to run a fast apply that skips these update-checking steps — the user must wait for all six layers every time, even on machines they touch daily just for shell/config tweaks.

## What Changes

- Add a global environment variable (e.g. `CHEZMOI_SKIP_PACKAGE_UPDATES=1`) that, when set, skips every long-running package-update layer for the run with no prompt at all — the fast path for power users, repeat runs, and scripted/CI contexts.
- When that env var is **unset**, fall back to an interactive prompt, shown once near the start of the apply run, that lets the user skip individual layers (Homebrew, SDKMAN, UV, Bun, Cargo, Claude skills/plugins/MCP) with per-layer granularity rather than only an all-or-nothing toggle.
- Because each layer is a separate `run_onchange_*` script running as its own chezmoi subprocess, the resolved skip decision (env var short-circuit, or the prompt's per-layer answers) SHALL be computed once and shared across scripts for the duration of a single `chezmoi apply` invocation via a small cached-decision file (written by whichever layer script runs first, read and reused by the rest).
- Each affected script (positions 20/21/23/24/25/26/27/28/37/38/39) SHALL consult the shared decision for its own layer and exit early with `print_message "skip"` when that layer is skipped.
- Skipping SHALL NOT mark the script as failed to chezmoi — the script exits 0 so subsequent scripts still run.
- Non-interactive shells (no TTY, e.g. automated/CI invocations) with the env var unset SHALL NOT hang on a prompt — they SHALL default to running every layer, identical to today's behavior.
- Default behavior (env var unset, TTY prompt declined for a layer, or prompt not reached) SHALL be unchanged: that layer runs as it does today.

## Capabilities

### New Capabilities
- `package-update-skip`: Layered mechanism to skip long-running package-update layers on a given `chezmoi apply` run — a global env-var short-circuit (skip everything, no prompt) that falls back to a per-layer interactive prompt when unset, with the resolved decision cached and shared across the separate per-layer scripts for that run.

### Modified Capabilities
- `package-management`: Each package installation script (SDKMAN, UV, Homebrew, SDKs, UV tools, Bun, Cargo, machine Brewfile, Claude skills/MCP/plugins) gains a precondition check — it SHALL consult the shared skip decision for its layer before performing its install/upgrade work, and SHALL exit cleanly (status 0, `skip` message) when that layer is skipped.

## Impact

- **Affected scripts**: `run_onchange_before_darwin-20-install-sdkman.sh.tmpl`, `run_onchange_before_darwin-21-install-uv.sh.tmpl`, `run_onchange_before_darwin-23-install-packages.sh.tmpl`, `run_onchange_before_darwin-24-install-sdks.sh.tmpl`, `run_onchange_before_darwin-25-install-tools.sh.tmpl`, `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl`, `run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl`, `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, and the Claude Code skills/MCP/plugins scripts (37/38/39).
- **New shared utility**: a new helper in `home/scripts/shared-utils.sh` (e.g. `resolve_package_update_skip <layer-name>`) that:
  - Returns "skip" immediately for every layer if `CHEZMOI_SKIP_PACKAGE_UPDATES` is set, without touching the cache file or prompting.
  - Otherwise checks a per-run cached-decision file (e.g. under `$TMPDIR` or `~/.cache/chezmoi/`, keyed so a stale file from a previous run isn't reused — for example keyed by the parent `chezmoi apply` process ID or a short-lived timestamp window); if present, reuses the cached per-layer answers.
  - Otherwise, only if a TTY is attached, prompts once for per-layer skip choices and writes the answers to the cache file before returning the decision for the requesting layer.
  - Defaults to "run" (no skip) for any layer when no TTY is attached and the env var is unset.
- **Cache file lifecycle**: written by whichever layer script runs first in a given apply invocation; read by subsequent layer scripts; SHALL NOT persist across separate `chezmoi apply` invocations (stale decisions must not silently suppress a later run's updates).
- **Config surface**: one new environment variable (`CHEZMOI_SKIP_PACKAGE_UPDATES`) and one new transient cache file; no changes to `home/.chezmoidata/packages.yaml` schema.
- **Security implications**: none — no secrets involved; the skip decision only affects whether update commands run, not what is installed. Declining an update does not bypass any confirmation currently required for machine-specific Brewfile installs (that scenario is separate and unaffected). The cache file contains only layer names/booleans, no sensitive data.
- **Non-goals**: this change does not add per-package skip control (only per-layer), does not change what tags install on first run, and does not change the one-time `promptMultichoiceOnce` tag-selection prompts in `.chezmoi.toml.tmpl`.
