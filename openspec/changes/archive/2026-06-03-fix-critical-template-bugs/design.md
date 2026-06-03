## Context

Four independent point bugs were identified by the template-reviewer agent during a routine template audit. Each is a self-contained fix in a single file with no cross-cutting interactions. The changes are surgical: no new abstractions, no refactoring, just correcting the wrong character/string in the right place.

Current state of each bug:
1. `run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl:35` — `ech0 ""` is unreachable in the success path but executes in the cancel/timeout branch, crashing that path with `command not found`.
2. `dot_zshrc.tmpl:102` — `{{- .chezmoi.homeDir -}}//bin` produces `/Users/craig//bin` due to the right-side whitespace trimmer consuming nothing while the literal `//` remains. Most shells accept double-slash in PATH silently, but it is unintentional.
3. `dot_zshrc.tmpl:202` — `fpath=("/Users/craig/.oh-my-zsh/custom/completions" $fpath)` hardcodes the author's username. On any other machine the fpath entry points to a non-existent directory, silently breaking oh-my-zsh completions.
4. `home/private_dot_config/claude-extend/tools.json.tmpl:51,53` — Two `command` and path values hardcode `/Users/craig/.nvm/versions/node/v24.7.0/bin/node` and `/Users/craig/work/whimsical-mcp-server/dist/index.js`. The nvm path also pins a specific node version, so any node upgrade silently breaks the MCP server.

## Goals / Non-Goals

**Goals:**
- Eliminate the `ech0` runtime crash
- Produce a single-slash PATH entry for `~/bin`
- Make the oh-my-zsh fpath entry portable across usernames
- Make the MCP server paths portable across usernames and node versions

**Non-Goals:**
- Addressing the philosophy-of-software-design issues (Claude env loop duplication, iCloud leakage, color mapping in `claude-environments`) — separate change
- Adding dynamic node-version detection to `tools.json.tmpl` — that requires a config.yaml entry or runtime lookup, out of scope for a bug-fix change
- Fixing the `set -euo pipefail` gaps, warning-level issues, or syncthing `output` fragility

## Decisions

**D1: Fix `ech0` as a direct one-character edit, not a `print_message` migration**

Replacing with `echo ""` matches the surrounding code style (the rest of that function uses bare `echo` for empty lines). Migrating to `print_message` would be a refactor beyond the bug-fix scope and is tracked separately under the template review warnings.

**D2: Fix the double-slash by removing the right-side whitespace trimmer (`-}}`)**

The left-side trimmer `{{-` is correct (removes whitespace before the expression). The right-side trimmer `-}}` is the culprit — it eats no whitespace but the literal `//` still follows. Changing `-}}` to `}}` restores the single slash. Alternative considered: change `//bin` to `/bin` — this works but is less clear about intent; removing the trimmer is the cleaner fix.

**D3: Replace hardcoded `/Users/craig/` with `{{ .chezmoi.homeDir }}/` using the project-standard template variable**

`{{ .chezmoi.homeDir }}` is the established convention used throughout the repo for home-relative paths. Consistent with all other path constructions in `dot_zshrc.tmpl`.

**D4: Replace hardcoded nvm node path with `{{ .chezmoi.homeDir }}/.nvm/versions/node/$(node --version)/bin/node` runtime expansion — or a simpler `node` command if available on PATH**

The surrounding MCP server entries use `node` or `npx` directly (relying on PATH at runtime). The simplest portable fix is to use just `node` and rely on nvm's PATH shim, matching how other entries in the file work. This avoids pinning a version. The whimsical project path uses `{{ .chezmoi.homeDir }}/work/...` to match the home-relative convention.

## Risks / Trade-offs

- **[Risk] `node` command in tools.json.tmpl**: Using bare `node` requires nvm's shim to be on PATH when the MCP host launches. If the MCP host is launched before nvm is initialized (e.g., from a LaunchAgent), `node` may not resolve. → **Mitigation**: This is the same risk as all other `node`-based MCP entries in the file; changing the hardcoded path to bare `node` does not increase risk versus the current state (which would also fail if the pinned version were removed).
- **[Risk] `dot_zshrc.tmpl` PATH change**: Removing the right-side trimmer changes whitespace in the rendered output. The expression `{{- .chezmoi.homeDir }}` (without right trimmer) will leave a newline after the homeDir value if the line ends there. → **Mitigation**: Inspect the surrounding context to confirm the trimmer change produces exactly `/Users/craig/bin` with no extra whitespace.
- **No rollback needed**: All four fixes are individually verifiable with `chezmoi execute-template` or `chezmoi cat`. If a fix introduces a regression, reverting one line restores the previous state.
