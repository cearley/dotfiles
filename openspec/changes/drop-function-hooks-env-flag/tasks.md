# Tasks

## 1. Shell rc templates

- [ ] 1.1 Remove the `{{- if has "ai" .tags }}` / `export CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` / `{{- end }}` block from `home/dot_zshrc.tmpl` (after the `CLAUDE_CONFIG_DIR` block, before `plugins=(`); verify `tests/run-template home/dot_zshrc.tmpl | grep -c CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` prints `0` and `tests/lint-shell home/dot_zshrc.tmpl` passes or reports only findings already present before the edit
- [ ] 1.2 Remove the same block from `home/dot_bashrc.tmpl` (between the `ccenv init` line and the `openspecui` alias block); verify `tests/run-template home/dot_bashrc.tmpl | grep -c CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` prints `0`, the rendered file still exports `CLAUDE_CONFIG_DIR` and still evals `ccenv init`, and `tests/lint-shell home/dot_bashrc.tmpl` passes or reports only pre-existing findings
- [ ] 1.3 Confirm no other source references the flag: `grep -rn CLAUDE_CODE_ENABLE_FUNCTION_HOOKS home/ .claude/ README.md CLAUDE.md AGENTS.md` returns nothing (archived changes under `openspec/changes/archive/` are expected to still mention it)

## 2. Externals comment

- [ ] 2.1 In the `jev-model-router` comment block of `home/dot_claude/.chezmoiexternal.toml.tmpl`, add one line after the pinning paragraph: the pinned commit requires Claude Code >= 2.1.287 (mods on by default; no `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS`), and re-check the upstream README's requirements line whenever the SHA moves; verify `tests/run-template home/dot_claude/.chezmoiexternal.toml.tmpl` still renders four `[...]` entries

## 3. Live check

- [ ] 3.1 Open a fresh shell, verify `echo "${CLAUDE_CODE_ENABLE_FUNCTION_HOOKS-unset}"` prints `unset` and `claude --version` is >= 2.1.287
- [ ] 3.2 Run `claude --debug hooks --debug-file /tmp/jev-hooks.log -p 'say ok'` in any `ai`-profile project; verify the log contains `hooks module jev-model-router@skills-dir loaded` and a `[jev-model-router] ready on` line, then delete the log file

## 4. Spec

- [ ] 4.1 Run `openspec validate drop-function-hooks-env-flag --strict`; fix any errors
- [ ] 4.2 After review, `openspec archive drop-function-hooks-env-flag --yes`; verify `openspec/specs/claude-function-hooks-mods/spec.md` no longer contains "Function hooks are enabled machine-wide" and does contain "Mod loading depends on the Claude Code version"
