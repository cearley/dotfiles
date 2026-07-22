## Context

`home/.chezmoitemplates/claude-environments` currently defines `_claude_env_set_title`, bound to zsh's `precmd` hook and bash's `PROMPT_COMMAND`, which emits `\e]2;<suffix>\e\\` (bare env suffix like `personal`) on every prompt. This partial is the single source of truth for Claude environment shell wiring (per the existing "Centralized Claude Environment Definitions" requirement) and is included by both `dot_zshrc.tmpl` and `dot_bashrc.tmpl`.

The user's zsh setup already runs Powerlevel10k with the `vcs` prompt segment enabled (confirmed in `~/.p10k.zsh`), which uses the bundled `gitstatus` plugin to asynchronously populate `$VCS_STATUS_WORKDIR`, `$VCS_STATUS_LOCAL_BRANCH`, etc. on every prompt already, for the `vcs` segment's own rendering. This state is process-global and safe to read from other code running in the same shell.

Neither iTerm2 nor cmux has any title-composition config in this repo (no iTerm2 shell-integration script; `~/.config/cmux/cmux.json` has no title-related keys set), and plain zsh/bash send no title escape sequences on their own — so absent this partial's hook, both terminals fall back to titling the tab after the foreground process (idle: shell name; running: command name).

cmux embeds Ghostty as its terminal (`cmux.app/Contents/Resources/bin/ghostty`; no font or title keys configured). Critically, **cmux labels its tabs from the OSC icon name and ignores OSC 2 entirely** — see decision 6.

## Goals / Non-Goals

**Goals:**
- Make the title carry enough information to answer "which Claude env, which project/branch, what's running" at a glance, without the user needing to check the p10k prompt segment.
- Disambiguate the env label from a same-named directory (`work` the Claude config vs. `~/work` the folder).
- Preserve terminal default parity (foreground job/command name) rather than replacing it outright — "additive," per user requirement.
- Avoid adding synchronous `git` subprocess forks to every zsh prompt when equivalent data is already computed by gitstatus.
- Keep bash support at feature parity with what's reasonably achievable without a preexec-equivalent hook (idle-only).

**Non-Goals:**
- Live command-name tracking in bash (no low-friction preexec equivalent without pulling in a third-party bash-preexec library — out of scope).
- Any change to the `prompt_claude_env` p10k segment's colour-coding logic or its registration in `dot_p10k.zsh`. (Narrowed mid-change: the segment did gain a visual identifier — see decision 4 — but its colours, registration, and instant-prompt pairing are untouched.)
- Hostname/SSH-awareness in the title (not requested; can be a future increment).
- Deduping/truncating long titles for narrow tab widths — left to the terminal's own truncation behavior, which was confirmed to drop the *tail* (see decision 1), matching what the segment ordering assumes.

## Decisions

**1. Title format:** `✳ <label> · <repo> · <branch> · <job>`, each segment omitted independently when unavailable.
- **Ordering — general to specific.** Env label, then repo, then branch, then job. This sorts by both scope (env contains repo contains branch) and volatility (leftmost changes least often). It is load-bearing rather than cosmetic: tab labels truncate, so keeping identity leftmost means a squeezed tab still answers "which terminal is this?", sacrificing only the most volatile segment. Specific-first would preserve `zsh` and discard the identity — useless for picking a tab.
- **Verified**, not assumed: cmux clips the **tail**, rendering a too-narrow tab as `✳ personal · chezmoi · main ·…` while keeping the full string in the window title bar and hover tooltip. The ordering therefore degrades exactly as intended.
- **Separator — one uniform ` · ` throughout.** Alternative considered: differentiated delimiters (`[env] repo (branch) — job`), which encode that the segments are different *kinds* of thing and preserve the conventional `repo (branch)` git idiom. Rejected because mixed punctuation reads as a set of asides rather than one hierarchy; in particular an em dash before the job segment reads as an afterthought, working against the general-to-specific structure. A single separator makes the hierarchy legible at a glance at the cost of visually flattening genuinely different segment types — an accepted trade.
- **Env marker — `✳`.** Chosen over the earlier `claude:` prefix: it disambiguates the label from a same-named directory in one character instead of seven, and matches the glyph Claude Code itself writes in its OSC-0 title, so shell-set and Claude-set titles read as one family. Cost: less self-describing than the literal word, relying on glyph recognition.

**2. Git context source — reuse gitstatus, fall back to `git` subprocess:**
- In zsh, check `$VCS_STATUS_WORKDIR` first (repo root, already computed for the `vcs` p10k segment) and `$VCS_STATUS_LOCAL_BRANCH`. If `$VCS_STATUS_WORKDIR` is empty (gitstatus hasn't run yet this session, user disabled the `vcs` segment, or bash), fall back to `git rev-parse --show-toplevel` + `git branch --show-current`.
- Alternative considered: always shell out to `git` directly (simpler code, no p10k coupling). Rejected because it reintroduces exactly the synchronous-git-in-every-prompt cost that gitstatus/p10k was adopted to avoid; reusing already-computed state is free.
- Alternative considered: parsing p10k's rendered segment text instead of gitstatus variables. Rejected — more fragile (depends on formatting/icons), whereas `VCS_STATUS_*` is gitstatus's documented public interface.
- Risk accepted: this creates a soft coupling to gitstatus's variable names, mitigated by the synchronous fallback always being correct on its own.

**3. Job/command name — new zsh `preexec` hook, idle-only for bash:**
- zsh: add a `preexec` hook (via `add-zsh-hook preexec ...`) that captures the first word of the about-to-run command line; a separate `precmd`-driven idle title shows the shell name when no command is running.
- bash: no `preexec` hook exists without extra tooling (e.g. `bash-preexec`), so bash keeps idle-only (`bash`) — an accepted scope limit rather than pulling in a new dependency for a nice-to-have.

**4. Shared helper functions instead of one monolithic function:**
- Split into `_claude_env_name`, `_claude_env_git_context`, and `_claude_env_build_title <job>`, called from both the zsh `precmd`/`preexec` hooks and the bash `PROMPT_COMMAND` wiring. Keeps the git/label logic single-sourced across both shells rather than duplicated.
- **Helpers set `REPLY` rather than echoing.** Command substitution forks a subshell, and these run on every prompt draw. An earlier revision assembled the title via `for part in "$(_helper_a)" "$(_helper_b)" …`, which cost two forks per prompt to read state already held in memory — directly contradicting decision 2's whole reason for reusing gitstatus. Measured on the gitstatus path: 1.6448 ms/prompt with forks vs 0.0937 ms/prompt with `REPLY` (2000 iterations, 17.6×). Cost: `REPLY` is a global unless declared, so every caller must declare `local REPLY` — the one piece of subtlety this buys, noted at the definition site.
- `_claude_env_name` is shared with `claude-env` and `prompt_claude_env`, which had each grown their own copy of the same suffix-stripping expansion.

**5. p10k segment visual identifier — `nf-md-asterisk` (`U+F06C4`), not `✳` (`U+2733`):**
- Passed via `p10k segment -i` so placement obeys `POWERLEVEL9K_ICON_BEFORE_CONTENT` (unset → icons trail content in the right prompt) exactly like the other segments, rather than being concatenated into the `-t` text.
- Nerd Fonts ships **no** Claude or Anthropic glyph — verified against the full cmap of 3.4.0 (`claude`, `anthropic`, `ai_`: zero hits). `md-asterisk` is the closest available mark.
- Deliberately differs from the title's `✳`. The window title is drawn by the application's UI chrome with the full system font-fallback stack, so `U+2733` renders there regardless of terminal font. The p10k segment renders in the **terminal grid font**, where no such fallback applies: `U+2733` is missing from 6 of 42 installed upright faces (all of Hack) and **all 42 italic faces**, whereas PUA icons are guaranteed by `POWERLEVEL9K_MODE=nerdfont-v3`.
- Residual risk: Material Design codepoints have shifted across Nerd Font major versions before, so this glyph is worth re-checking on a major upgrade.

**6. Emit OSC 0 (title + icon name), not OSC 2 (window title only):**
- OSC 0 sets both the icon name and the window title in one sequence; OSC 2 sets only the window title. cmux labels tabs from the icon name, and OSC 0 is also what Claude Code itself emits, so this keeps the shell-set and Claude-set titles consistent. Universally supported by the terminals in play. One-character change: `\033]2;` → `\033]0;`.
- **Correction:** this was initially adopted as *the* fix for the cmux failures, on the theory that cmux ignored OSC 2 entirely. That diagnosis was wrong — see decision 7. OSC 0 is still the right sequence to emit, but it was not sufficient on its own, and it was not the root cause.

**7. Stand down where the terminal already manages its own titles (supersedes the Ghostty opt-out):**
- **Final decision.** The partial registers no title hooks when `$GHOSTTY_SHELL_FEATURES` contains `title` — i.e. when another writer is demonstrably active. iTerm2, Terminal.app, and any terminal without its own title management are unaffected; cmux keeps its native behaviour.
- The test matches the *feature flag that turns those writes on*, not the terminal. If Ghostty's title integration is disabled, nobody else is writing and this partial takes over as normal — the condition is "is someone else already doing this", not "is this cmux".
- Rationale for reversing the opt-out below: in cmux our title only ever appears at a shell prompt, because Claude Code takes the title for itself during agent runs — which is the behaviour cmux's tab bar is designed around, and the more useful one. So the opt-out fought the terminal by design for a narrow slice of value, and needed cross-file coordination (`.zshenv` → partial) to win a race it could still silently lose. One writer per terminal is simpler and more predictable.
- Cost accepted: cmux tabs are no longer scannable by Claude env from the tab bar. Partially mitigated — the `prompt_claude_env` p10k segment still shows the env at the prompt, and cmux's own cwd title is informative. Both were verified to still work under the guard.
- The earlier opt-out is retained below as rejected-alternative history, since it was implemented and verified before being reversed.

**7a. REJECTED (implemented, verified, then reversed): opt out of Ghostty's shell-integration title feature:**
- Root cause of the cmux failures, found by reading `cmux.app/Contents/Resources/shell-integration/ghostty-integration.zsh`. When `$GHOSTTY_SHELL_FEATURES` contains `title`, the integration appends its own title writes to its prompt hooks:
  - `precmd` → `\e]2;` with `${(%):-%(4~|…/%3~|%~)}` (the abbreviated cwd)
  - `preexec` → `\e]2;` with `${1//[[:cntrl:]]}` (the **raw command line**)
- Both observed symptoms match this exactly, not a missing-icon-name theory: the tab read `chezmoi update` while a command ran (the raw command line — our version emits only the first word, so it could not have produced that string), and `…/.local/share/chezmoi` when idle. Evaluating that zsh prompt expansion for the test directory reproduces `…/.local/share/chezmoi` byte-for-byte.
- So cmux was never ignoring our sequence; a second writer was overwriting it every prompt. Racing it by hook ordering is unreliable — the integration notes its own precmd can be re-invoked from zle, out of `precmd_functions` order. The competing writer has to be removed, not out-ordered.
- Fix as implemented at the time: strip the `title` token from `$GHOSTTY_SHELL_FEATURES` in `home/dot_zshenv.tmpl`. It had to be `.zshenv` because the integration reads the variable when sourced, at the `.zshrc` stage. The token had to be *removed*, not rewritten to `no-title`: the integration tests `== *"title"*`, which `no-title` still matches.
- **Why reversed:** the mechanism worked but was action at a distance — `.zshenv` disabling a third-party feature so a different, later-loaded file could win, with neither site referencing the other, a silent failure mode (title quietly reverts to cwd), and a dependency on cmux's env var name, substring test, and file load order. Worth checking before assuming it hid anything, though: the gate covers *only* those two title writes. OSC 7 cwd reporting sits outside it, and cmux tab-status/agent integration (OSC 21337) has zero references in the shell integration — it is driven by cmux and Claude Code directly. So the opt-out suppressed no agent features; it was reversed on coupling and fragility grounds, not capability loss.
- Alternative considered: emit OSC 1 (icon name) alongside OSC 2 so the tab label and window title could differ and Ghostty would only clobber the latter. Rejected — more complexity, and it leaves a stale competing writer on the window title.
- **Verified in cmux.** Running `chezmoi apply` now titles the tab `✳ personal · chezmoi · main · chezmoi` — the first word only, where Ghostty would have written the raw `chezmoi apply`. So `~/.zshenv` is read before the integration is sourced, and the earlier `ZDOTDIR` concern does not apply here. The fallback (neutralising Ghostty's hook functions from the partial) was not needed.

## Risks / Trade-offs

- **[Risk] Extra `git` forks on every prompt when gitstatus state isn't available** (bash, or the zsh fallback path) → *Mitigation*: the check is a single `git rev-parse --show-toplevel` (fails fast, cheap, outside a repo) followed by one more call only when inside a repo; this matches the cost profile of common non-async git-in-prompt setups and only applies on the fallback path.
- **[Risk] Coupling to Powerlevel10k/gitstatus internals (`$VCS_STATUS_*`) which are undocumented-outside-gitstatus variables** → *Mitigation*: fallback path guarantees correctness even if those variables disappear or change name in a future p10k/gitstatus upgrade; worst case is a silent drop to the (still-correct) subprocess path.
- **[Risk] Longer title string may get truncated in narrow tabs, hiding the job name at the end** → *Mitigation*: accepted — env label and repo/branch (the higher-value, more stable info) are placed first; per the Non-Goals, truncation handling is left to the terminal.
- **[Risk] Detached HEAD or bare repos yield no branch** → *Mitigation*: branch segment is simply omitted (`<repo>` alone), same graceful-omission pattern as other missing segments.

## Migration Plan

- Single-commit change to `home/.chezmoitemplates/claude-environments`; no data migration, no machine-config changes, no external dependencies to install.
- Rollout is via `chezmoi apply` on next login/new shell per machine; no restart of already-open terminal tabs is required for new tabs opened after apply (existing open tabs keep showing the old title until their next prompt cycle picks up the redefined function on shell restart).
- Rollback: revert the template commit and re-apply.
