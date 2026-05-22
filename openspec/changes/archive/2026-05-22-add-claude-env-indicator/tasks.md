## 1. Partial: Segment Function

- [x] 1.1 Open `home/.chezmoitemplates/claude-environments`. Add a new section after the existing alias definitions, gated on `if [ -n "$ZSH_VERSION" ]; then ... fi`.
- [x] 1.2 Inside the zsh-only block, define `prompt_claude_env`:
  - Read `${CLAUDE_CONFIG_DIR}` and bail out (no `p10k segment` call) if unset/empty.
  - Compute the suffix as `${CLAUDE_CONFIG_DIR##*/}` then strip a leading `claude-` to get the display label.
  - Map the label to a foreground color via a `case` statement: `work`→33, `personal`→76, `bedrock`→208, default→244.
  - Call `p10k segment -f <color> -t '<label>'` with the chosen values.
- [x] 1.3 Define `instant_prompt_claude_env` that simply calls `prompt_claude_env` (matches p10k's instant-prompt convention shown in the existing example block at `dot_p10k.zsh:1697`).
- [x] 1.4 Verify the function bodies use only constructs that bash can syntactically parse (parameter expansions and `case` are fine; `[[ ]]` and `(( ))` are zsh-only when used outside `if`/`while`). Avoid those in the function bodies, OR confirm bash never sources the inner block (the outer `if` is enough so long as the function syntax itself is valid bash, since zsh function syntax is bash-compatible for `name() { ... }`).

## 1b. Partial: Session Switcher Function

- [x] 1b.1 In the partial (before the zsh-only block), define `claude-env`:
  - With no args, print the active env label (`${CLAUDE_CONFIG_DIR##*/}` stripped of `.claude-`) or `(none)`.
  - With `work`, `personal`, or `bedrock`, export `CLAUDE_CONFIG_DIR="$HOME/.claude-<arg>"`.
  - In zsh, call `p10k reload` after switching (guarded with `command -v p10k`).
  - With any other arg, print usage to stderr and return 1.

## 2. Partial: Title Hook

- [x] 2.1 In the partial, add a shell-agnostic helper function `_claude_env_set_title` that prints the OSC-2 sequence:
  - When `CLAUDE_CONFIG_DIR` is set, print `\e]2;<suffix>\a` (same suffix logic as the segment).
  - When unset, print `\e]2;\a` to clear.
  - Use `printf` (not `echo -e`) for portability.
- [x] 2.2 In the zsh-only block, register the helper as a `precmd`:
  - `autoload -Uz add-zsh-hook` (likely already loaded but safe to repeat).
  - `add-zsh-hook precmd _claude_env_set_title`.
- [x] 2.3 In a bash-only block (`if [ -n "$BASH_VERSION" ]; then ... fi`), append the helper to `PROMPT_COMMAND`:
  - `PROMPT_COMMAND="_claude_env_set_title;${PROMPT_COMMAND}"` (preserves existing value).
- [x] 2.4 Test render the partial: `printf '{{ includeTemplate "claude-environments" . }}\n' | chezmoi execute-template` and confirm both branches appear.

## 3. p10k Registration

- [x] 3.1 Edit `home/dot_p10k.zsh`. Locate `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` (line ~47). Find the `aws` entry (~line 82).
- [x] 3.2 Insert immediately after `aws_eb_env`, BEFORE `azure`:
  ```
  # === BEGIN claude-env segment registration (managed by partial) ===
  claude_env             # active Claude Code config dir (chezmoi-managed)
  # === END ===
  ```
- [x] 3.3 Verify position by checking that `claude_env` appears among the cloud/context segments and not buried between version managers.

## 4. Validation

- [x] 4.1 `chezmoi diff` — confirm partial and `dot_p10k.zsh` are the only files affected.
- [x] 4.2 `chezmoi apply`.
- [x] 4.2b Run `claude-env personal` in a zsh shell: confirm prompt segment switches to `personal` (green) immediately without opening a new shell. Run `claude-env` with no args: confirm it prints `personal`. Run `claude-env work` to restore.
- [x] 4.3 Open a fresh zsh shell on MacBook Pro: confirm right prompt shows `work` in blue.
- [ ] 4.4 Open a fresh zsh shell on Mac Studio (when next at it): confirm right prompt shows `personal` in green.
- [x] 4.5 In the same shell, run `claude-bedrock --version` (or any benign invocation): confirm the per-call shadow does NOT change the prompt segment (segment reflects the *exported* default, not the just-finished command's overridden value, which is correct behavior).
- [x] 4.6 In the same shell, run `unset CLAUDE_CONFIG_DIR && p10k reload`: confirm segment disappears.
- [x] 4.7 Open Terminal.app: confirm window title reads `work` (or `personal`).
- [x] 4.8 Open a cmux pane: confirm tab label reflects the env (the OSC-2 emission should populate it).
- [x] 4.9 Open a bash shell: confirm window/tab title updates; the prompt segment is correctly absent (bash, no p10k).
- [x] 4.10 In an instant-prompt scenario (open a new terminal window so instant prompt fires), confirm no warning appears in the p10k console output.

## 5. Documentation

- [x] 5.1 Add a short note to `CLAUDE.md` (project file) under the existing template best-practices section: "The `claude-environments` partial defines the `prompt_claude_env` p10k segment. Its registration in `dot_p10k.zsh` is wrapped in `# === BEGIN/END claude-env segment registration ===` markers — preserve these if regenerating p10k config."
- [x] 5.2 Add an inline comment in the partial near the segment function pointing readers to `openspec/specs/claude-environments/spec.md` for the requirements.

## 6. Commit & Push

- [ ] 6.1 Stage `home/.chezmoitemplates/claude-environments`, `home/dot_p10k.zsh`, and `CLAUDE.md`.
- [ ] 6.2 Commit with a message referencing this change name.
- [ ] 6.3 Push to remote.
