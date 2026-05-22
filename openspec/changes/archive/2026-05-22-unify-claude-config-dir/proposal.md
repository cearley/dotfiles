## Why

The current Claude Code multi-environment setup uses an interactive-shell `claude` alias and per-environment shell functions, which (a) fails to propagate to GUI-launched applications like JetBrains Rider, producing inconsistent Claude config across launch surfaces, and (b) duplicates ~30 lines of identical wiring between `dot_zshrc.tmpl` and `dot_bashrc.tmpl`. Standardizing on an exported `CLAUDE_CONFIG_DIR` (mirrored into the GUI session via a LaunchAgent) and a single shared template partial fixes both problems and makes the active environment globally observable for future tooling like prompt indicators.

## What Changes

- Replace the per-shell `claude` alias with an exported `CLAUDE_CONFIG_DIR` environment variable, set to `$HOME/.<claude_default>` when the machine declares a default.
- Extract the duplicated Claude environment block from `dot_zshrc.tmpl` and `dot_bashrc.tmpl` into a new `home/.chezmoitemplates/claude-environments` partial.
- Simplify the `claude-spec` SpecStory wrapper: with `CLAUDE_CONFIG_DIR` exported, the per-default template branch collapses to a single static alias.
- Add a `reverse_dns` prompt to `home/.chezmoi.toml.tmpl` so the user's reverse-DNS prefix lives in personal config (uncommitted) rather than repo data; default to `io.github.<gh_username>` for fresh clones.
- Add a user LaunchAgent at `~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist` that runs `launchctl setenv CLAUDE_CONFIG_DIR ...` at login so Spotlight/Dock/Finder-launched apps inherit the same config dir as terminal-launched ones.
- Add a `run_onchange_after_darwin-38-load-claude-launchagent.sh.tmpl` script that bootstraps the LaunchAgent and runs `launchctl setenv` immediately so the live GUI session updates without a logout.
- Convert `home/.chezmoiignore` to `home/.chezmoiignore.tmpl` and add a stanza that skips the LaunchAgent plist on machines with no `claude_default` (e.g., the Mac mini).
- **BREAKING** for end-user behavior: invoking bare `claude` no longer routes through a `claude-work`/`claude-personal` function. It runs the binary directly with the inherited environment. Behavior is equivalent on machines that declare a `claude_default`, but explicit reliance on the alias chain (e.g., debugging with `type claude`) will see different output.

## Capabilities

### New Capabilities
- `claude-environments`: Centralized definition of Claude Code multi-environment shell wiring, exported `CLAUDE_CONFIG_DIR` semantics, and GUI-session inheritance via LaunchAgent.

### Modified Capabilities
- `machine-config`: Adds `reverse_dns` as a user-prompted identity value sourced from `~/.config/chezmoi/chezmoi.toml` rather than `home/.chezmoidata/config.yaml`. Documents the convention that personal identity constants live outside the repo.

## Impact

- **Affected files**:
  - `home/dot_zshrc.tmpl` — duplicated Claude block replaced with `includeTemplate`.
  - `home/dot_bashrc.tmpl` — same.
  - `home/.chezmoi.toml.tmpl` — new `reverse_dns` prompt and `[data]` line.
  - `home/.chezmoiignore` → `home/.chezmoiignore.tmpl` — rename + conditional stanza.
  - **New**: `home/.chezmoitemplates/claude-environments`, `home/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist.tmpl`, `home/.chezmoiscripts/run_onchange_after_darwin-38-load-claude-launchagent.sh.tmpl`.
- **Affected tags**: `ai` (gates the partial). Machines without the `ai` tag are unaffected.
- **Affected machines**: MacBook Pro (claude-work default), Mac Studio (claude-personal default). Mac mini (no `claude_default`) is unaffected at runtime — the LaunchAgent is skipped via `.chezmoiignore`.
- **GUI app caveat**: already-running GUI apps must be restarted after first apply to inherit the new `CLAUDE_CONFIG_DIR`; flagged via `print_message tip` in the activation script.
- **Security**: no new secrets, no SIP-protected paths. LaunchAgent runs as the user, matches the 644 permissions of all other plists in `~/Library/LaunchAgents/`. Reverse-DNS prefix moves out of the repo to avoid baking personal identifiers into checked-in data.
- **Non-goals**:
  - Visibility/indicator surfacing (prompt segments, tmux status) — unblocked by this change but tracked separately.
  - Cross-validation of `claude_default` against `claude_envs` in `config.yaml` — separate concern.
  - Function/alias asymmetry between `claude-*` and `*-spec` wrappers — separate concern.
  - Layering direnv on top for project-bound contexts — orthogonal mechanism, not pursued here.
