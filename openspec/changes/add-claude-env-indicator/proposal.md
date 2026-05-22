## Why

The `unify-claude-config-dir` change made `CLAUDE_CONFIG_DIR` globally observable, but no surface displays which Claude environment is active. With three configs in regular use (`claude-bedrock`, `claude-personal`, `claude-work`) and a per-machine default that ships with the LaunchAgent, it is easy to lose track of context — particularly when running parallel agent sessions in cmux or dropping into a non-cmux terminal where there is no tab label to fall back on. A subtle, color-coded prompt segment (visible in every interactive shell) plus a tab/window title (visible to host terminals that surface it) closes the gap with near-zero overhead.

## What Changes

- Add a Powerlevel10k user-defined right-prompt segment `claude_env` that:
  - Renders the suffix of `${CLAUDE_CONFIG_DIR##*/}` (e.g., `claude-work` → `work`) when set.
  - Color-codes by environment: work=blue, personal=green, bedrock=orange, unknown/custom=neutral grey.
  - Hides itself entirely when `CLAUDE_CONFIG_DIR` is unset (Mac mini case, or non-`ai` shells).
  - Provides an `instant_prompt_*` companion so the segment appears in p10k's instant prompt without flicker.
- Add a small zsh `precmd` hook that emits an OSC-2 sequence to set the terminal window/tab title to the same suffix when `CLAUDE_CONFIG_DIR` is set. This populates cmux tab labels, Terminal.app title bars, iTerm titles, and any future terminal that honors OSC-2.
- Wire the segment into `home/dot_p10k.zsh` in the `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` list, positioned near other context-style segments (`aws`, `kubecontext`, `context`).
- Add a `claude-env` shell function that switches `CLAUDE_CONFIG_DIR` for the current shell session and immediately refreshes the prompt (`p10k reload` in zsh). With no argument it prints the active environment name. This complements the existing per-invocation functions (`claude-work`, `claude-personal`, etc.) by making a persistent, session-wide switch easy.
- Bash receives the OSC-2 hook via a `PROMPT_COMMAND` addition in the shared partial; it does NOT receive the p10k segment (bash users see the title bar, not a prompt segment).
- All of the above live in `home/.chezmoitemplates/claude-environments` (zsh-only blocks gated via shell detection). This keeps every Claude-env-related shell concern in one file.

## Capabilities

### New Capabilities

None. The behavior extends an existing capability rather than introducing a new one.

### Modified Capabilities

- `claude-environments`: Adds requirements for a Powerlevel10k right-prompt segment that displays the active Claude environment, a zsh/bash `precmd`/`PROMPT_COMMAND` hook that emits an OSC-2 terminal title with the same value, and a `claude-env` shell function for switching the active environment within a session.

## Impact

- **Affected files**:
  - `home/.chezmoitemplates/claude-environments` — adds the prompt-segment function (zsh-only branch), the OSC-2 title hook for both shells, and the `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` registration.
  - `home/dot_p10k.zsh` — adds `claude_env` to `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` (logical insertion point: between `aws` and `context`).
- **Affected tags**: `ai` only. Non-`ai` machines get no segment and no title hook.
- **Affected machines**:
  - MacBook Pro: shows `work` in blue (matches `claude_default: claude-work`).
  - Mac Studio: shows `personal` in green (matches `claude_default: claude-personal`).
  - Mac mini: no segment rendered; no title set; baseline behavior unchanged.
- **Performance**: prompt segment is a single string parameter expansion plus a `case` on the suffix. OSC-2 emission is a one-line `print -n` per prompt. Both are below measurable cost.
- **Compatibility**:
  - Powerlevel10k instant prompt is preserved via a paired `instant_prompt_claude_env` function.
  - The segment uses `${CLAUDE_CONFIG_DIR}` directly (no shell-out), so it is safe to run during `POWERLEVEL9K_INSTANT_PROMPT=verbose`.
- **Non-goals**:
  - cmux `cmux.json` workspace layouts are project-scoped artifacts and are not added to the dotfiles repo. (A note in `CLAUDE.md` about the pattern is acceptable but not part of this change.)
  - tmux integration (the user has not adopted tmux).
  - Indicators for non-Claude AI tools (codex, gemini). Their `*-spec` aliases set `CLAUDE_CONFIG_DIR` only when applicable; the segment naturally remains hidden when running `gemini` directly.
  - Resolution of thread 3 (`claude_default` ↔ `claude_envs` cross-check) or thread 4 (function/alias asymmetry).
