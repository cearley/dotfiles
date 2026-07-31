## 1. Plugin scaffold (`~/work/zsh-claude-env`, outside chezmoi)

- [x] 1.1 `mkdir -p ~/work/zsh-claude-env && cd ~/work/zsh-claude-env && git init`
- [x] 1.2 Write `zsh-claude-env.plugin.zsh`:
  - Discover environments at load time by globbing `$HOME/.claude-*` directories (e.g. `${(f)"$(print -l $HOME/.claude-*(N/))"}`, stripping the `.claude-` prefix for each basename)
  - Generate one `claude-<name>()` function per discovered environment (source optional `~/.config/claude-env/<name>.env`, then `CLAUDE_CONFIG_DIR=... exec command claude "$@"`)
  - Generate `claude-env()` switcher validating against the same discovered set, printing current/usage as before
  - Generate SpecStory wrapper functions (`claude-spec`, `codex-spec`, `gemini-spec`, `claude-<name>-spec`) and `SESSION_INDEX_PROJECTS` from the same discovered set
  - Define `_claude_env_name`, `_claude_env_git_context`, `_claude_env_build_title`, `_claude_env_titles_are_managed` (Ghostty check), `_claude_env_precmd`/`_claude_env_preexec`
  - Always register `precmd`/`preexec` hooks; each hook body checks `$CLAUDE_ENV_TITLE_HOOKS` (default true) and `_claude_env_titles_are_managed` at invocation time, not registration time
  - At the top of the plugin file (load time), capture the current `CLAUDE_CONFIG_DIR`'s label (via `_claude_env_name`) into an internal variable (e.g. `_claude_env_initial_label`) — this becomes the implicit "default" baseline; no `CLAUDE_ENV_DEFAULT` config variable exists
  - Define `prompt_claude_env`/`instant_prompt_claude_env`, reading `$CLAUDE_ENV_COLORS`/`$CLAUDE_ENV_SHOW_DEFAULT` at render time and comparing against the captured `_claude_env_initial_label`, with safe defaults when unset (no color overrides, show-default true, no-op comparison if no label was captured at load time)
- [x] 1.3 Write `README.md`: description, install instructions, config variable reference (`CLAUDE_ENV_COLORS`, `CLAUDE_ENV_SHOW_DEFAULT`, `CLAUDE_ENV_TITLE_HOOKS` — all optional, all safe to set anywhere since they're read lazily; note there is no `CLAUDE_ENV_DEFAULT` — the plugin captures whatever `CLAUDE_CONFIG_DIR` was already set to at its own load time as the implicit baseline), the `$HOME/.claude-<name>` directory convention, p10k integration notes, Ghostty title-detection caveat, **and an explicit limitation note**: a brand-new environment has no `claude-<name>()` function until its directory exists on disk and a new shell session re-globs — bootstrapping it requires one manual `CLAUDE_CONFIG_DIR=$HOME/.claude-<name> claude` invocation first. (Not an issue in this dotfiles repo's own usage, where `home/dot_claude-<name>/` source directories already guarantee the directory exists before the plugin ever loads — this note is for anyone installing the plugin standalone.)
- [x] 1.4 Write `LICENSE` (MIT, placeholder copyright `Craig Earley`)
- [x] 1.5 `git add -A && git commit -m "Initial plugin scaffold"` (no remote yet)

## 2. Standalone plugin validation (no oh-my-zsh involvement)

- [ ] 2.1 In a fresh interactive zsh shell, with at least two `~/.claude-*` directories already present on disk, `source ~/work/zsh-claude-env/zsh-claude-env.plugin.zsh`
- [ ] 2.2 Verify `claude-<name>` functions exist only for directories that actually exist on disk; verify a function is NOT defined for a name that doesn't have a directory yet
- [ ] 2.3 Verify `claude-env` (no args) prints current env / `(none)`; `claude-env <name>` switches, exports `CLAUDE_CONFIG_DIR`, calls `p10k reload`; `claude-env <bogus>` prints usage to stderr and returns 1
- [ ] 2.4 Export `CLAUDE_CONFIG_DIR` to a known env *before* sourcing the plugin (simulating the rc-template default-export snippet), then set `CLAUDE_ENV_COLORS`/`CLAUDE_ENV_SHOW_DEFAULT` *after* the plugin has already loaded (simulating `dot_p10k.zsh`'s later sourcing) and confirm the segment picks up the captured default label and the display settings correctly on the next prompt draw — this is the critical ordering assumption to verify before trusting the design
- [ ] 2.5 Verify show/hide-default behavior and its no-op case when `CLAUDE_CONFIG_DIR` was unset at plugin-load time (no baseline label captured)
- [ ] 2.6 Verify terminal title updates on prompt/command; verify setting `CLAUDE_ENV_TITLE_HOOKS=false` *after* load still suppresses title updates on the next prompt (confirms invocation-time check works); verify `GHOSTTY_SHELL_FEATURES=title` suppresses regardless
- [ ] 2.7 Bootstrap-a-new-env check: create a new `~/.claude-scratchtest` directory, confirm `claude-scratchtest` is still undefined in the current shell, then re-source the plugin in a fresh shell and confirm it now appears

## 3. oh-my-zsh integration test (without touching chezmoi-managed files)

- [ ] 3.1 `chezmoi cat ~/.zshrc > /tmp/test-zshrc`; edit in a `zsh-claude-env` `plugins=()` entry (config vars deliberately NOT set anywhere in this test file, to confirm the plugin's defaults hold)
- [ ] 3.2 `ln -s ~/work/zsh-claude-env ~/.oh-my-zsh/custom/plugins/zsh-claude-env`
- [ ] 3.3 Run the Section 2 checklist via `zsh -c 'source /tmp/test-zshrc'`, additionally sourcing a scratch `~/.p10k.zsh`-style file afterward that sets the `CLAUDE_ENV_*` vars, to fully simulate real load ordering
- [ ] 3.4 Confirm no `chezmoi apply` runs during this window (`.oh-my-zsh` is `exact = true`, would delete the symlink); remove the symlink once done

## 4. Publish the plugin

- [ ] 4.1 Confirm plugin behavior is fully validated (Sections 2-3 pass) before proceeding
- [ ] 4.2 With explicit user confirmation, create the GitHub repository `cearley/zsh-claude-env`
- [ ] 4.3 With explicit user confirmation, push `~/work/zsh-claude-env`'s default branch (`main`)
- [ ] 4.4 Confirm the tarball URL `https://github.com/cearley/zsh-claude-env/archive/main.tar.gz` resolves (e.g. `curl -fsSL -o /dev/null` it) before wiring chezmoi to depend on it

## 5. Chezmoi wiring

- [ ] 5.1 Delete `home/.chezmoitemplates/claude-environments`
- [ ] 5.2 Edit `home/dot_zshrc.tmpl`: remove the `{{ includeTemplate "claude-environments" . }}` call; add, *before* the `plugins=(...)` block, the inline default-export snippet (`{{- $settings := includeTemplate "machine-settings" . | fromJson -}}` / `{{- $claudeDefault := default "" (index $settings "claude_default") -}}` / `{{- if $claudeDefault }}export CLAUDE_CONFIG_DIR="$HOME/.{{ $claudeDefault }}"{{- end }}`); add `zsh-claude-env` to `plugins=(...)` (unconditional, alongside the other custom plugins); add the inline `{{ if has "ai" .tags }}alias openspecui='npx openspecui@latest'{{ end }}` line
- [ ] 5.3 Edit `home/dot_bashrc.tmpl`: remove the `{{ includeTemplate "claude-environments" . }}` call; add the same inline default-export snippet (position doesn't matter here — no plugin-load ordering constraint in bash) and the same inline `openspecui` alias line
- [ ] 5.4 Edit `home/.chezmoiexternal.toml.tmpl`: add the `.oh-my-zsh/custom/plugins/zsh-claude-env` entry (alphabetically between `zsh-autosuggestions` and `zsh-defer`), reusing the `$zshPlugin` dict, pointing at `https://github.com/cearley/zsh-claude-env/archive/main.tar.gz`
- [ ] 5.5 Edit `home/dot_p10k.zsh`: add the `CLAUDE_ENV_COLORS`/`CLAUDE_ENV_SHOW_DEFAULT` settings block near the existing `# === BEGIN/END claude-env segment registration ===` markers; reword the registration comment from `(managed by partial)` to `(managed by plugin)`

## 6. Apply and full end-to-end verification

- [ ] 6.1 `chezmoi diff` and review the rendered delta for `~/.zshrc`, `~/.bashrc`, `~/.p10k.zsh`, and the new external plugin fetch
- [ ] 6.2 `chezmoi apply`
- [ ] 6.3 Open a fresh zsh terminal and re-run the Section 2 checklist against the real chezmoi-managed files
- [ ] 6.4 Confirm bash still exports the correct default `CLAUDE_CONFIG_DIR` on a machine with `claude_default` set, but no longer has any switching functions/aliases (expected — the accepted BREAKING change), and that `openspecui` still works in both shells
- [ ] 6.5 Regression-check subagent/Bash-tool inheritance: from within a real Claude Code session launched from the managed zsh shell, run a Bash-tool command echoing `$CLAUDE_CONFIG_DIR` and confirm it matches the value the launching shell had — same check performed manually during design, now re-verified against the real post-migration rc files
- [ ] 6.6 `openspec validate extract-claude-env-plugin --strict` passes

## 7. Cleanup follow-ups (not executed in this change)

- [ ] 7.1 Decide whether to remove the now-unused `claude_env_colors` key from `home/.chezmoidata/config.yaml` — flagged, deferred. (`claude_envs`/`claude_default` stay — still consumed by the MCP-servers script, the plugins script, `dot_session-index/config.json.tmpl`, and the LaunchAgent.)
