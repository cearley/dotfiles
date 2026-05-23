## 1. Convert wrappers in the partial

- [x] 1.1 In `home/.chezmoitemplates/claude-environments`, replace `alias claude-spec='specstory run claude --no-cloud-sync'` with a `claude-spec()` function whose body is `specstory run claude --no-cloud-sync "$@"`.
- [x] 1.2 Replace the `{{- range $name := $envNames }} alias claude-{{ $name }}-spec=... {{- end }}` block with a `range` that emits a `claude-{{ $name }}-spec()` function. Function body: `CLAUDE_CONFIG_DIR="$HOME/.claude-{{ $name }}" specstory run claude --no-cloud-sync "$@"` (using line continuation for readability).
- [x] 1.3 Replace `alias codex-spec='specstory run codex --no-cloud-sync'` with a `codex-spec()` function. Body: `specstory run codex --no-cloud-sync "$@"`.
- [x] 1.4 Replace `alias gemini-spec='specstory run gemini --no-cloud-sync'` with a `gemini-spec()` function. Body: `specstory run gemini --no-cloud-sync "$@"`.
- [x] 1.5 Confirm `alias openspecui='npx openspecui@latest'` is unchanged.

## 2. Render verification

- [x] 2.1 Run `chezmoi execute-template < home/.chezmoitemplates/claude-environments` in the current machine context and confirm five `*-spec()` functions are emitted (one for `claude-spec`, three for the env names, one each for `codex-spec` and `gemini-spec`) and that no `alias *-spec=` lines remain.
- [x] 2.2 Run `chezmoi diff` for `~/.zshrc` and `~/.bashrc`. Inspect the diff for the converted region; confirm only the `*-spec` block changes and the conversion is exact.

## 3. Apply and runtime verification

- [x] 3.1 Run `chezmoi apply` on the current machine.
- [x] 3.2 Open a fresh interactive zsh. Run `type claude-spec`, `type claude-work-spec`, `type codex-spec`, `type gemini-spec`. Confirm each reports as a function.
- [x] 3.3 In the same shell, run `claude-work-spec --help` (or any specstory-supported flag); confirm the flag is forwarded by inspecting `specstory`'s output or by checking `set -x` trace.
- [x] 3.4 Run `bash -c 'source ~/.bashrc; type claude-work-spec'` and confirm the function resolves under non-interactive bash.

## 4. Rollback readiness

- [x] 4.1 Confirm the prior partial revision is one commit back via `git log --oneline -- home/.chezmoitemplates/claude-environments` so revert is trivial if a regression is found.
