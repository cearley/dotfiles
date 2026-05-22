## 1. Identity Constant

- [x] 1.1 Edit `home/.chezmoi.toml.tmpl` to add a `promptStringOnce` for `reverse_dns` with default computed as `cat "io.github." $gh_username | nospace`. Place near the other identity prompts (alongside `fullname`, `gh_username`).
- [x] 1.2 In the same file, add `reverse_dns = {{ $reverse_dns | quote }}` to the `[data]` block.
- [x] 1.3 Verify by running `chezmoi execute-template < home/.chezmoi.toml.tmpl` (will use existing answers; no re-prompt expected on this machine).

## 2. Shared Partial

- [x] 2.1 Create `home/.chezmoitemplates/claude-environments` containing the full Claude wiring block, gated internally on `{{- if has "ai" .tags -}}`.
- [x] 2.2 In the partial, define `claude-bedrock`, `claude-personal`, `claude-work` shell functions (each does `CLAUDE_CONFIG_DIR=$HOME/.claude-<env> command claude "$@"`).
- [x] 2.3 In the partial, after the function definitions, look up `claude_default` via `includeTemplate "machine-config" (merge (dict "setting" "claude_default") .)` and emit `export CLAUDE_CONFIG_DIR="$HOME/.<value>"` only when non-empty. Do NOT emit a `claude` alias.
- [x] 2.4 In the partial, define `claude-spec` as a static alias: `alias claude-spec='specstory run claude --no-cloud-sync'`. (No template branch — the export already routes correctly.)
- [x] 2.5 In the partial, define the per-env spec aliases: `claude-bedrock-spec`, `claude-personal-spec`, `claude-work-spec`, each with inline `CLAUDE_CONFIG_DIR=$HOME/.claude-<env>` prefix.
- [x] 2.6 In the partial, define `codex-spec` and `gemini-spec` aliases.
- [x] 2.7 Move the `openspecui` alias (currently in both rc files inside the `ai` block) into the partial.
- [x] 2.8 Test render: `printf '{{ includeTemplate "claude-environments" . }}\n' | chezmoi execute-template` and verify expected output for the current machine.

## 3. rc File Integration

- [x] 3.1 Edit `home/dot_zshrc.tmpl` — replace the entire current Claude block (lines ~132–162) with `{{ includeTemplate "claude-environments" . }}`. Preserve surrounding comments and blank lines.
- [x] 3.2 Edit `home/dot_bashrc.tmpl` — replace the entire current Claude block (lines ~14–48) with `{{ includeTemplate "claude-environments" . }}`. Preserve surrounding comments.
- [x] 3.3 Test render both files with `chezmoi execute-template` and diff against `chezmoi cat` of the live targets to confirm only intended changes (no `claude` alias, new `export CLAUDE_CONFIG_DIR=...`, simplified `claude-spec`).

## 4. LaunchAgent Plist

- [x] 4.1 Create directory `home/Library/LaunchAgents/` if it does not yet exist (chezmoi will create the target directory automatically; the source dir must exist for the file to live in).
- [x] 4.2 Create `home/Library/LaunchAgents/{{ .reverse_dns }}.claude-config-dir.plist.tmpl` with the standard plist XML containing: `Label = {{ .reverse_dns }}.claude-config-dir`, `ProgramArguments = ["/bin/launchctl", "setenv", "CLAUDE_CONFIG_DIR", "{{ .chezmoi.homeDir }}/.<claude_default>"]`, `RunAtLoad = true`. Resolve `<claude_default>` via the `machine-config` template.
- [x] 4.3 Do NOT use the `private_` filename prefix — keep mode 644 to match other plists in `~/Library/LaunchAgents/`.
- [x] 4.4 Test render: `chezmoi execute-template < home/Library/LaunchAgents/{{ .reverse_dns }}.claude-config-dir.plist.tmpl` (you'll need to invoke via `chezmoi cat` on the target path) and confirm a well-formed plist with the user's values.

## 5. Conditional Ignore

- [x] 5.1 Rename `home/.chezmoiignore` → `home/.chezmoiignore.tmpl`.
- [x] 5.2 Append a stanza to the new template that, when `claude_default` is empty, ignores the LaunchAgent path. Use `{{ .reverse_dns }}` to construct the path and `includeTemplate "machine-config"` to check the default.
- [x] 5.3 Test by running `chezmoi managed | grep -i launchagent` on a machine with `claude_default` set (should appear) and confirm the same command on the Mac mini scenario would not list it (can be verified via `chezmoi execute-template` against a hypothetical context).

## 6. Activation Script

- [x] 6.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-39-load-claude-launchagent.sh.tmpl` with a Darwin guard. (Note: position 39 used — 38 already taken by install-claude-plugins)
- [x] 6.2 Source `shared-utils.sh` at the top of the script.
- [x] 6.3 Compute `claude_default` via `machine-config`; if empty, exit 0 with a `print_message skip` line.
- [x] 6.4 Run `launchctl bootout gui/$(id -u)/{{ .reverse_dns }}.claude-config-dir 2>/dev/null || true` to clear any prior load.
- [x] 6.5 Run `launchctl bootstrap gui/$(id -u) "$HOME/Library/LaunchAgents/{{ .reverse_dns }}.claude-config-dir.plist"` and check exit code with `print_message error` on failure.
- [x] 6.6 Run `launchctl setenv CLAUDE_CONFIG_DIR "$HOME/.<claude_default>"` to update the live GUI session.
- [x] 6.7 Print a `print_message tip` reminding the user to restart already-running GUI apps (Rider, etc.) to inherit the new env.
- [x] 6.8 Add a comment block at the top documenting rollback steps: `launchctl bootout gui/$(id -u)/<label>`, `launchctl unsetenv CLAUDE_CONFIG_DIR`, `rm ~/Library/LaunchAgents/<plist>`.

## 7. Validation

- [x] 7.1 Run `chezmoi diff` on the active MacBook Pro / Mac Studio: confirm rc files lose the `claude` alias and gain `export CLAUDE_CONFIG_DIR`, the partial is referenced, the plist is added, and the activation script is queued.
- [x] 7.2 Run `chezmoi apply`. Verify `launchctl getenv CLAUDE_CONFIG_DIR` returns the expected path immediately (without logout).
- [x] 7.3 Open a fresh terminal: `echo $CLAUDE_CONFIG_DIR` should return the per-machine default.
- [x] 7.4 Restart JetBrains Rider; verify it sees the new `CLAUDE_CONFIG_DIR` (whatever introspection the user prefers — `ps eww` of the Rider PID, env-var-aware Claude integration logs, etc.).
- [x] 7.5 Run `claude-bedrock --help` (or any benign invocation) and confirm it uses `~/.claude-bedrock` despite the exported default pointing elsewhere — the per-call shadow continues to work.
- [x] 7.6 Verify `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` produce byte-identical Claude wiring (extract just the Claude region from each and `diff`).
- [x] 7.7 Hypothetically validate Mac mini behavior: confirm via template render with `claude_default = ""` that the plist is ignored and the partial emits no `export` line.

## 8. Documentation Hygiene

- [x] 8.1 Update `CLAUDE.md` (project file, not user-global) under the existing template-best-practices section to mention the `claude-environments` partial as the source of truth for Claude environment wiring.
- [x] 8.2 Add a short note to the activation script's header comments documenting the BREAKING behavior change (`claude` is no longer aliased).

## 9. Commit & Push

- [ ] 9.1 Stage all new/modified files: partial, rc files, `.chezmoi.toml.tmpl`, `.chezmoiignore.tmpl` (renamed), plist, activation script.
- [ ] 9.2 Commit with a clear message referencing this change name.
- [ ] 9.3 Push to remote.
