## Why

The terminal/tab title (`OSC 2`) currently shows only the bare Claude environment suffix (e.g. `personal`, `work`). This is ambiguous — it's impossible to tell at a glance whether `work` means the active Claude config (`~/.claude-work`) or a directory named `~/work`. It's also a net loss of information versus the terminals' own default behavior: iTerm2 and cmux (neither of which has any title-composition setup of their own in this repo) would otherwise title the tab after the foreground process (idle shell name, or the running command), while Terminal.app composes a template that already includes the cwd/shell/user around whatever we send. Replacing that signal with a single ambiguous word is a regression in an area we're supposed to be improving.

## What Changes

- The OSC-0 title format changes from bare suffix (`personal`) to a structured, additive string: `✳ <label> · <repo> · <branch> · <job>`, gracefully omitting any segment that isn't available.
  - Segments run general to specific and share one uniform separator (` · `), so the title reads as a flat hierarchy rather than a set of differently-punctuated asides. The ordering is load-bearing: tab labels truncate, and keeping identity leftmost means a squeezed tab still says *which* terminal it is, sacrificing only the most volatile segment.
  - `✳ <label>` disambiguates the env label from a same-named directory, reusing the same glyph Claude Code puts in its own OSC-0 title so the shell-set and Claude-set titles read as one family.
  - `<repo> · <branch>` is included when the shell is inside a git working tree — reusing p10k's already-computed gitstatus variables (`$VCS_STATUS_WORKDIR`, `$VCS_STATUS_LOCAL_BRANCH`) in zsh to avoid extra `git` subprocess forks on every prompt, falling back to a synchronous `git rev-parse --show-toplevel` / `git branch --show-current` when those variables aren't populated (bash, or before gitstatus has run once).
  - `<job>` restores default-terminal parity: the idle shell name (`zsh`/`bash`) or, in zsh only, the actively running command via a new `preexec` hook (bash has no equivalent hook today and is out of scope for live command tracking).
- Bash keeps idle-only title updates (no preexec-driven live command name) but gains the same `✳ <label>` and repo/branch enrichment via the synchronous git fallback.
- **BREAKING**: Any tooling or muscle memory that expects the terminal title to be exactly the bare suffix (e.g. `personal`) will see a longer, structured string instead.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `claude-environments`: The "Terminal Title Hook" requirement changes from "title SHALL be the bare env suffix" to "title SHALL be an additive, structured string combining env label, git repo/branch (when available), and job/command name (idle or running)". New scenarios needed for: repo/branch inclusion, gitstatus-reuse vs. synchronous git fallback, job name inclusion (idle vs. running, zsh vs. bash), graceful omission of unavailable segments, `✳` as the env-label marker, and general-to-specific ordering under one uniform separator. The existing "Title reflects suffix only" scenario is removed/replaced.

## Impact

- `home/.chezmoitemplates/claude-environments`: `_claude_env_set_title` is replaced with a small set of helper functions (`_claude_env_name`, `_claude_env_git_context`, `_claude_env_build_title`) plus a new zsh `preexec` hook registration. Bash's `PROMPT_COMMAND` wiring is updated to call the enriched builder directly (idle-only). The helpers set `REPLY` instead of echoing, which removes two subshell forks per prompt draw (17.6× faster title assembly on the gitstatus path) and lets `claude-env` and `prompt_claude_env` share the env-name derivation they had each duplicated.
- `prompt_claude_env` gains a visual identifier (`p10k segment -i`, nf-md-asterisk `U+F06C4`) so it matches the other right-prompt segments. Its colour-coding, its `instant_prompt_claude_env` pairing, and its registration in `dot_p10k.zsh` are unchanged — **no changes to `dot_p10k.zsh` itself**. (This narrows the original non-goal, which had excluded the segment entirely.)
- The SpecStory wrappers are de-duplicated: the three base `*-spec` functions come from one template loop and the per-env variants delegate to `claude-spec`, so `specstory run … --no-cloud-sync` appears once instead of five times. No behavior change.
- The title hooks stand down where the terminal already manages its own titles (`$GHOSTTY_SHELL_FEATURES` contains `title`, i.e. cmux, which embeds Ghostty). cmux keeps its native behavior — cwd at the prompt, and Claude Code's own title during agent runs, which is what its tab bar is designed around. The `prompt_claude_env` segment and `claude-env` still work there, so the active environment remains visible at the prompt. **This change therefore touches only `home/.chezmoitemplates/claude-environments`**; an earlier revision also modified `home/dot_zshenv.tmpl` to suppress Ghostty's title feature, but that was reversed as fragile cross-file coupling (see design decision 7).
- No new packages, tags, or machine-config keys required. Affects all machines with the `ai` tag (both zsh and bash shells).
- No secrets or SIP-related concerns — this is pure shell/escape-sequence logic operating on already-available git/gitstatus state.
