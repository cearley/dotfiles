---
paths:
  - "home/**"
---

# Working in home/ (chezmoi source for dotfiles)

Guidance specific to editing scripts and templates under this directory.

### Script Naming Pattern

Naming grammar and position assignment are covered by the `/new-script` skill. Current execution order is authoritative in the filenames themselves — run `ls home/.chezmoiscripts/` rather than trusting a hand-maintained table (one drifted out of sync in commit `6f3790c`). Each position number must be unique.

### Shared Utilities

**Source shared utilities in all scripts:**
```bash
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"
```

See the "Code Style Quick Reference" note in the `chezmoi` basic-memory project for the function reference and extended examples.

### Template Testing
```bash
# Test any template (works with or without keepassxcAttribute calls)
tests/run-template home/private_dot_zsh_secrets.tmpl
tests/run-template --inline '{{ keepassxcAttribute "GitHub" "Access Token" }}'

# Raw chezmoi (only use for templates with no keepassxcAttribute calls)
chezmoi execute-template < filename.tmpl
```

### Shell Linting
Run `tests/lint-shell <file>` on every shell file or template you create or modify, and fix all failures before reporting done.
- Three layers run in order: syntax (`bash -n`), lint (shellcheck), format (shfmt). A syntax failure stops the later layers.
- Templates are rendered first (via `tests/run-template`, using this machine's tags), so results reflect this machine only. Line numbers refer to the **rendered** output; run `tests/run-template <file>` to see it.
- Fix template format diffs (e.g. stray blank lines from `{{ if }}`/`{{ end }}`) with whitespace control (`{{-` / `-}}`). **Never** run shfmt on a template — it corrupts the template syntax.
- `make fmt` (shfmt -w) is for plain `*.sh` files only.
- `tests/lint-shell-exclude.txt` lists known-failing files that `make lint` (`--all`) skips; files you name are always checked in full. Remove a file from the list once it is fixed; never add files to it.
- The pre-commit hook (`make hooks` to enable) runs `tests/lint-shell` on staged `home/` files and enforces this on commit.

### Template Best Practices

The `prompt_claude_env` p10k segment is defined by the external `zsh-claude-env` oh-my-zsh plugin (https://github.com/cearley/zsh-claude-env), pulled via `.chezmoiexternal.toml.tmpl`. Its registration in `dot_p10k.zsh` is wrapped in `# === BEGIN/END claude-env segment registration ===` markers — preserve these if regenerating p10k config. The plugin's own `CLAUDE_ENV_COLORS`/`CLAUDE_ENV_SHOW_DEFAULT` settings live as plain hand-edited `typeset` lines just below that array, not chezmoi-templated.

**Partial file management (modify_ scripts):**
Use `modify_` prefix for files where you only manage specific keys (e.g., JSON configs modified by applications at runtime).
- `modify_<filename>.tmpl` — bash script receiving current file on stdin, outputs merged result
- Use jq for JSON merging: `echo "$existing" | jq --argjson servers "$managed" '.mcpServers = $servers'`
- `modify_` scripts CAN use `.tmpl` extension (for chezmoi template expansion)
- `chezmoi:modify-template` directive files must NOT use `.tmpl` extension (different mechanism)
- Example: `modify_claude_desktop_config.json.tmpl` manages only `mcpServers`, preserves app-managed `preferences`

**Command validation:**
```go-template
{{- if lookPath "rustup" }}
  source "$HOME/.cargo/env"
{{- end }}
```
⚠️ **Never** use `output "command" "-v"` - it fails if command doesn't exist. Use `lookPath` instead.
