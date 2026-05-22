## Context

After `unify-claude-config-dir`, `CLAUDE_CONFIG_DIR` is exported in every interactive shell on machines with `claude_default` set, and mirrored into the GUI session via a LaunchAgent. The user runs Claude Code in three distinct configs (`~/.claude-bedrock`, `~/.claude-personal`, `~/.claude-work`) and uses cmux for parallel agent sessions, but also drops into plain Terminal.app, iTerm, and JetBrains Rider's terminal. Without a visible indicator, it is easy to invoke `claude-personal` in a pane labeled "work" by mistake, or forget which env owns a long-running session.

cmux provides per-pane labels via `cmux.json`, but those are static. They reflect the *intended* env, not the *actual* one — so a mismatch between the label and what is currently exported is exactly the failure mode an indicator should expose. A prompt-side indicator that reads the live `${CLAUDE_CONFIG_DIR}` is therefore complementary to cmux, not redundant.

The user uses Powerlevel10k. p10k supports user-defined segments via `prompt_<name>` and `instant_prompt_<name>` functions plus an entry in `POWERLEVEL9K_*_PROMPT_ELEMENTS`. There is an existing `prompt_example` block in `dot_p10k.zsh` that documents the pattern.

## Goals / Non-Goals

**Goals:**

- Make the active Claude env immediately visible in every interactive shell, regardless of host terminal (cmux, Terminal.app, iTerm, Rider terminal).
- Color-code the indicator so a mismatch (e.g., a personal session in a pane labeled work) is visually obvious.
- Keep the segment self-hiding so non-Claude shells, non-`ai` machines, and shells with `CLAUDE_CONFIG_DIR` unset see no visual change.
- Preserve p10k instant prompt — no flicker, no first-render delay.
- Centralize all Claude-env-related shell wiring in `home/.chezmoitemplates/claude-environments` so future changes do not fragment.

**Non-Goals:**

- Surfacing the env in cmux's sidebar metadata (cmux's sidebar fields are predefined and not user-extensible per current docs).
- A bash prompt segment. Bash gets the OSC-2 title hook only; the prompt segment is zsh/p10k-specific.
- A tmux indicator (not adopted).
- A GUI menu-bar indicator (overkill given the LaunchAgent already handles GUI inheritance correctness).
- Triggering on `CLAUDE_CONFIG_DIR` changes mid-session (the segment recomputes per prompt; that is sufficient).
- A `~/bin` script for switching environments — shell functions are the correct mechanism since subprocess scripts cannot export into the parent shell.

## Decisions

### Decision 1: User-defined p10k segment, not a custom theme override

**Choice:** Add a `prompt_claude_env` function and register `claude_env` in `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`.

**Why:**

- p10k explicitly supports user-defined segments via this pattern. The existing `prompt_example` block in `dot_p10k.zsh:1681` is a working template to follow.
- Putting the segment in the right prompt keeps the (more important) left prompt clean. The right prompt already contains context-flavored entries (`aws`, `kubecontext`, `context`), so `claude_env` fits naturally there.
- A custom theme override would be a much larger change for no extra benefit.

**Alternative considered: edit `POWERLEVEL9K_CUSTOM_*` variables.** That mechanism works but produces less readable code than a real segment function. Rejected for legibility.

### Decision 2: Render the suffix, not the full path

**Choice:** Display `${CLAUDE_CONFIG_DIR##*/}` with the `claude-` prefix stripped (e.g., `claude-work` → `work`).

**Why:**

- The full path is too long for a prompt segment.
- The `claude-` prefix is redundant when every value starts with it. Stripping it reduces visual noise.
- Custom directories not matching `claude-*` (a hypothetical override) fall through to the unknown bucket and render their basename verbatim.

### Decision 3: Color-code by environment

**Choice:** Map each known env to a distinct p10k 256-color foreground:

- `work` → blue (33)
- `personal` → green (76)
- `bedrock` → orange (208)
- unknown / custom → grey (244)

**Why:**

- Color is the highest-bandwidth cue for "is this what I expected?" The text alone requires reading; color is preattentive.
- Picked colors are visually distinct on dark and light terminals, and avoid collisions with p10k's own segment colors (red for status errors, yellow for execution time).
- Grey for unknown ensures custom paths still render but do not visually claim to be a known env.

**Alternative considered: a single neutral color, rely on text only.** Loses the at-a-glance mismatch detection. Rejected.

**Alternative considered: background color (highlight).** More attention-grabbing but easier to misread when the segment is small. Rejected for visual harmony with the rest of the right prompt.

### Decision 4: Title hook via OSC-2 in `precmd` / `PROMPT_COMMAND`

**Choice:** Emit `\e]2;<suffix>\a` from a small zsh `precmd` and from a bash `PROMPT_COMMAND` line, both gated on `${CLAUDE_CONFIG_DIR}` being set.

**Why:**

- OSC-2 is universally honored by macOS Terminal.app, iTerm, Ghostty (and therefore cmux), and JetBrains terminals. One mechanism, broad reach.
- Per-prompt emission means the title tracks `CLAUDE_CONFIG_DIR` changes (e.g., a child shell that inherits a different value) without manual refresh.
- Bash gets the title hook even though it does not get the prompt segment, because Rider's terminal can be bash-flavored and the user explicitly opens bash from time to time.

**Alternative considered: a single zsh-only hook and rely on cmux's `cmux.json` `name` for bash users.** Rejected — bash sessions outside cmux would have no indicator at all.

### Decision 5b: Session-wide env switcher as a shell function, not a `~/bin` script

**Choice:** Add a `claude-env [work|personal|bedrock]` shell function to the partial. With no argument it prints the active environment name.

**Why:**

- A `~/bin` script runs in a subprocess and cannot modify the parent shell's `CLAUDE_CONFIG_DIR`. Only a shell function can `export` into the current session.
- Placing it in the partial keeps all Claude-env shell wiring in one file, consistent with Decision 5.
- The function calls `p10k reload` (zsh only, guarded with `command -v`) so the prompt segment updates immediately without opening a new shell.
- Calling without arguments acts as a cheap `claude-env status`, more memorable than inspecting `$CLAUDE_CONFIG_DIR` directly.

**Alternative considered: a `~/bin/claude-env` script that prints a usage note.** Adds discoverability via `PATH` lookup but the actual switch still requires a function. Rejected as redundant without upside.

### Decision 5: Place segment definition in the partial, not in `dot_p10k.zsh`

**Choice:** The `prompt_claude_env` and `instant_prompt_claude_env` functions live in `home/.chezmoitemplates/claude-environments` (zsh-only branch). Only the *registration* (the entry in `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS`) lives in `dot_p10k.zsh`.

**Why:**

- All Claude-env-related shell wiring stays in one place.
- `dot_p10k.zsh` is generated by `p10k configure` and is risky to edit broadly. The single-line list addition is the minimal touch.
- The partial is sourced after `dot_p10k.zsh` is read but before the prompt is first drawn (zshrc:226 sources `~/.p10k.zsh` near the end), so segment functions defined later in zshrc are still in scope by the time the prompt renders.

**Risk:** if `dot_p10k.zsh` is regenerated by `p10k configure`, the registration line is lost. **Mitigation:** add a clearly marked block comment around the registration so it is obvious to preserve, and document the pattern in `CLAUDE.md`.

### Decision 6: Bash detection inside the partial

**Choice:** Detect zsh vs bash via `$ZSH_VERSION` / `$BASH_VERSION` inside the partial and conditionally emit zsh-only sections.

**Why:**

- The partial is included by both `dot_zshrc.tmpl` and `dot_bashrc.tmpl`. zsh-specific syntax (`precmd`, `typeset -g`, p10k segment functions) would error in bash.
- Runtime detection is cleaner than splitting into two partials, since the bulk of the wiring (functions, exports, aliases) is shared.

## Risks / Trade-offs

- **[Risk]** A zsh syntax error in the partial breaks bash sourcing.
  **→ Mitigation:** Wrap zsh-only blocks in `if [ -n "$ZSH_VERSION" ]; then ... fi`. Bash parses the `if` block but skips its contents; zsh-only constructs inside are protected from bash's parser only at execution time, so any syntax that *bash cannot parse* (e.g., `(( ))` inside a function body) must be eval'd or sourced from a separate file. We avoid all such constructs by keeping the segment function pure parameter expansion + `case`.

- **[Risk]** `p10k configure` regenerates `dot_p10k.zsh` and drops the registration line.
  **→ Mitigation:** Block comment markers `# === BEGIN claude-env segment registration ===` / `# === END ===` make the addition discoverable. CLAUDE.md notes the convention. Re-adding takes one minute.

- **[Risk]** Color choices conflict with the user's terminal theme.
  **→ Mitigation:** Picked p10k 256-color codes that are visible on both dark and light backgrounds. If the user later changes themes and finds a color hard to read, the codes are one-line swaps in the partial.

- **[Risk]** OSC-2 emission interferes with terminal multiplexers that pass titles through (e.g., a future tmux setup might want to use `pane_title` as a status field).
  **→ Mitigation:** OSC-2 sets the *window* title, not the pane title (OSC-0 sets both). Choosing OSC-2 leaves pane titles available for tmux-style customization later.

- **[Trade-off]** The segment recomputes per prompt. If the user runs many fast commands, this adds a microscopic but nonzero cost. In practice this is below the noise floor of every other p10k segment in use.

- **[Trade-off]** Bash gets only the title, not a prompt indicator. This was a deliberate scope decision — bash is a fallback shell for the user, not the primary interactive surface.

## Migration Plan

1. Edit `home/.chezmoitemplates/claude-environments`: add the segment functions (zsh-only), add the OSC-2 hooks (zsh `precmd` and bash `PROMPT_COMMAND`), add the `claude-env` session switcher function.
2. Edit `home/dot_p10k.zsh`: add `claude_env` to `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` between `aws` and `context`. Wrap the addition in marker comments.
3. Run `chezmoi apply`.
4. Open a fresh zsh shell; verify the segment appears with the expected color.
5. Force-reload p10k in an existing shell via `p10k reload` if needed.
6. Open a bash shell; verify the terminal window/tab title updates to the env suffix.
7. Test the unset case: `unset CLAUDE_CONFIG_DIR` in a subshell, verify segment disappears and title becomes empty.

**Rollback:**

- Remove the segment functions and OSC-2 hooks from the partial.
- Remove `claude_env` from `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` in `dot_p10k.zsh`.
- `chezmoi apply`.

## Open Questions

None. All design choices resolved during discussion:

- Display value: suffix-only, prefix stripped.
- Colors: blue/green/orange/grey for work/personal/bedrock/unknown.
- Position: right prompt, between `aws` and `context`.
- Title mechanism: OSC-2 in `precmd` / `PROMPT_COMMAND`.
- Definition location: partial owns the function; `dot_p10k.zsh` owns only the registration.
