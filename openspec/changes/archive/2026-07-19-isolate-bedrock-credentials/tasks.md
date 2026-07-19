## 1. Template Change

- [x] 1.1 Update `home/.chezmoitemplates/claude-environments`: wrap each generated `claude-{{ $name }}()` function body in a subshell that, if `~/.config/claude-env/{{ $name }}.env` exists, sources it before `exec`-ing `command claude "$@"` with `CLAUDE_CONFIG_DIR` set (per `design.md`'s subshell/source/exec pattern). Leave `claude-{{ $name }}-spec` functions untouched — the env-file sourcing is scoped only to the plain `claude-<name>()` functions per the spec delta.
- [x] 1.2 Render the partial (e.g. `chezmoi execute-template` against `dot_zshrc.tmpl` or `tests/run-template`) and confirm the generated `claude-bedrock()`, `claude-work()`, and `claude-personal()` function bodies match the new shape.
- [x] 1.3 Run `chezmoi diff` to preview the resulting `.zshrc`/`.bashrc` changes before applying.
- [x] 1.4 Run `chezmoi apply` to regenerate `.zshrc`/`.bashrc` with the updated functions.

## 2. Bedrock Credential Migration (manual, machine-local)

- [x] 2.1 Create `~/.config/claude-env/bedrock.env` (untracked, not chezmoi source state) with `export AWS_PROFILE=...` and `export AWS_CREDENTIAL_PROCESS=...`, copying the current values from `~/.claude-bedrock/settings.json`'s `env` block.
- [x] 2.2 Set restrictive permissions on the new file (`chmod 600 ~/.config/claude-env/bedrock.env`).
- [x] 2.3 Edit `~/.claude-bedrock/settings.json` directly to remove the `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` keys from its `env` block, leaving all other keys (`AWS_REGION`, model overrides, OTEL config, etc.) untouched.

## 3. Verification

- [x] 3.1 Open a new interactive shell and run `claude-bedrock` (or a quick no-op invocation) to confirm Bedrock auth still succeeds with the relocated values.
- [x] 3.2 In that same shell, after the `claude-bedrock` invocation exits, confirm `AWS_PROFILE` and `AWS_CREDENTIAL_PROCESS` are unset in the parent shell's environment (e.g. `echo $AWS_PROFILE` is empty).
- [x] 3.3 Confirm `claude-work` and `claude-personal` still launch normally and unaffected, since neither has a matching `~/.config/claude-env/<name>.env` file.
- [x] 3.4 Confirm `openspec validate isolate-bedrock-credentials --strict` still passes after any final edits.
