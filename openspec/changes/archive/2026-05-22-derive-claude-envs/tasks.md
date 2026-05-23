## 1. Validation guard in the partial

- [x] 1.1 In `home/.chezmoitemplates/claude-environments`, after the existing `if has "ai" .tags` gate, load `claude_envs` and `claude_default` from `machine-settings`.
- [x] 1.2 Derive `$envNames` by iterating `claude_envs`; for each entry, fail via `{{- fail (printf ...) }}` when the entry does not start with `~/.claude-`; otherwise append the trimmed name to `$envNames`.
- [x] 1.3 When `claude_default` is non-empty, fail via `{{- fail (printf ...) }}` if `trimPrefix "claude-" $claudeDefault` is not in `$envNames`. The message must include `claude_default`, its current value, and `$envNames`.
- [x] 1.4 Render the partial via `chezmoi execute-template < home/.chezmoitemplates/claude-environments` (with appropriate context) on the current machine to confirm the guard does not trip on valid config.

## 2. Generate per-env functions and `*-spec` aliases

- [x] 2.1 Replace the three hardcoded `claude-bedrock`/`claude-personal`/`claude-work` function definitions with a `{{- range $name := $envNames }}` loop emitting `claude-{{ $name }}() { CLAUDE_CONFIG_DIR="$HOME/.claude-{{ $name }}" command claude "$@"; }`.
- [x] 2.2 Replace the three hardcoded `claude-*-spec` alias lines with a `{{- range $name := $envNames }}` loop emitting `alias claude-{{ $name }}-spec='CLAUDE_CONFIG_DIR=$HOME/.claude-{{ $name }} specstory run claude --no-cloud-sync'`.
- [x] 2.3 Leave the non-env-specific `claude-spec`, `codex-spec`, `gemini-spec`, and `openspecui` aliases unchanged.

## 3. Generalize the `claude-env` switcher

- [x] 3.1 Replace `case "$1" in work|personal|bedrock)` with `case "$1" in {{ join "|" $envNames }})`.
- [x] 3.2 Replace the hardcoded usage string `Usage: claude-env [work|personal|bedrock]` with `Usage: claude-env [{{ join "|" $envNames }}]`.
- [x] 3.3 Confirm the empty-`claude_envs` case renders the case branch as `case "$1" in )` — if Go template `join` produces no output for an empty list, restructure the case to skip the name branch entirely (e.g., wrap the name branch in `{{- if $envNames }}...{{- end }}`).

## 4. Render verification

- [x] 4.1 Run `chezmoi cat ~/.zshrc | grep -A1 'claude-env()'` on the current machine and confirm the case statement matches the machine's `claude_envs`.
- [x] 4.2 Run `chezmoi cat ~/.zshrc | grep '^claude-' ` on the current machine; confirm one function per `claude_envs` entry, and that `claude-spec`, `codex-spec`, `gemini-spec`, `openspecui` are still present.
- [x] 4.3 On the same machine, run `chezmoi diff` for `~/.zshrc` and `~/.bashrc` and confirm the rendered output is functionally equivalent to the prior version (no behavior change for an `ai` machine whose `claude_envs` matches today's `bedrock|personal|work`).
- [x] 4.4 Render the partial against a synthetic Mac Studio machine context (`claude_envs: [~/.claude-personal, ~/.claude-work]`) using `chezmoi execute-template` and confirm `claude-bedrock`, `claude-bedrock-spec`, and the `bedrock` alternative in the case statement are all absent.

## 5. Validation negative tests

- [x] 5.1 On a scratch branch, edit `home/.chezmoidata/config.yaml` to set `claude_default: claude-wrok` for the current machine. Run `chezmoi diff`. Confirm the apply fails with a message naming `claude_default`, `claude-wrok`, and the derived list. Revert.
- [x] 5.2 On a scratch branch, edit `home/.chezmoidata/config.yaml` to add a non-conforming entry (e.g., `'~/claude-bedrock'` without the leading dot). Run `chezmoi diff`. Confirm the apply fails with a message naming `claude_envs` and the offending entry. Revert.

## 6. Documentation and apply

- [x] 6.1 Update the `claude_default` comment block in `home/.chezmoidata/config.yaml` to document that `claude_envs` paths MUST match `~/.claude-<name>` and that `claude_default` MUST equal `claude-<name>` for an entry in `claude_envs`.
- [x] 6.2 Run `chezmoi apply` on the current machine. Confirm `~/.zshrc` and `~/.bashrc` are updated, and that opening a new shell, running `claude-env work`, then `claude-env`, prints `work`.
