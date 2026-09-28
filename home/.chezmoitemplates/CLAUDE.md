# Reusable Templates

Available in `home/.chezmoitemplates/`:
- `machine-name` - Cross-platform machine name detection
- `machine-config` - Machine-specific setting lookup (single property)
- `machine-settings` - All machine settings as JSON dict (preferred for multiple lookups)
- `icloud-account-id` - Returns iCloud account ID if signed in (macOS)
- `time-bucket` - Rolling epoch bucket for periodic `run_onchange_*` re-execution; embed in comment near script top
- `package-layer-items` - Resolves which `packages.yaml` categories are eligible for a given key (e.g. `bun`, `brews`) given the machine's tags, returning an ordered JSON array of `{category, items}` groups. Single source of category/tag eligibility logic for the package-layer scripts (positions 23-27).
- `detect-project-type` - Full `detect-project-type.sh` script body: detects Node/Bun, Rust, Python (pyproject.toml or requirements.txt), and Go in the current directory, then runs the matching install or test command. Rendered verbatim (no template variables) into `executable_detect-project-type.sh.tmpl` in both the `parallel-worktrees` and `integrate-worktrees` Claude Skills so the two skills stay in sync without duplicating the bash logic inline in their SKILL.md files.
- `sopsDecrypt` - Decrypts a SOPS+age-encrypted secret (e.g. `private_dot_cloudflared/cert.pem.sops`) and returns its plaintext contents. Defaults to opaque binary handling; pass `type` "json" (or "yaml"/"dotenv"/"ini") for a structured file encrypted with SOPS's native partial-value mode. Used for repo-scoped secrets that are the SOPS+age source of truth instead of KeePassXC — see `openspec/specs/sops-age-encryption/`. Requires `sops` installed and an age private key available (sourced from KeePassXC at bootstrap, never committed).
  ```go-template
  {{ includeTemplate "sopsDecrypt" (merge (dict "file" "private_dot_cloudflared/cert.pem.sops") .) }}
  {{ includeTemplate "sopsDecrypt" (merge (dict "file" "private_dot_cloudflared/foo.json.sops" "type" "json") .) }}
  ```
  ```go-template
  {{- $groups := includeTemplate "package-layer-items" (merge (dict "key" "bun") .) | fromJson -}}
  {{- range $groups }}
  {{- range .items }}
  bun add -g {{ . }}
  {{- end }}
  {{- end }}
  ```
- `claude-settings-modifier` - The whole body of every persona's `modify_settings.json.tmpl` (all four are the identical line `includeTemplate "claude-settings-modifier" .`). It reads the sibling `.claude-settings.json` — that persona's managed settings in `settings.json`'s own shape; edit that file, not the templates — and merges it into the live `settings.json` (objects by key, arrays as an order-preserving union, so runtime additions survive), retracting whatever was removed from source via the string `_chezmoiManaged`. Its header is the full user guide: where to edit, what apply does, and what not to do. Tested by `tests/test-claude-settings-ledger.sh`; see `openspec/specs/claude-settings-ledger/`.
- `claude-pattern-a` / `claude-pattern-b` / `claude-pattern-c` - Three flat `permissions`-only JSON blocks — approval-first (deny-heavy), curated allow-list, and sandboxed full-auto (`bypassPermissions`) respectively — stamped into the *current project repo's* `.claude/settings.local.json` by `apply-claude-pattern` (`home/dot_local/bin/executable_apply-claude-pattern.tmpl`), a second axis independent of persona selection and the settings ledger above. See `openspec/specs/claude-repo-permission-patterns/`.
- `claude-pattern-c-devcontainer` - Companion `devcontainer.json` + `Dockerfile` for Pattern C: non-root user, working-tree-only mount, no host credential paths. Defines the container only; copying it into a repo's `.devcontainer/` and launching it is a manual, separate step. See `openspec/specs/claude-repo-permission-patterns/`.

**Periodic re-execution with time-bucket:**
```go-template
# re-run trigger - changes or every 7 days: {{ includeTemplate "time-bucket" (dict "days" 7) }}
```
Used to force `chezmoi apply` to rerun a script on a schedule even when source files haven't changed.

**Access machine config:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . }}
{{- $sshEntry := includeTemplate "machine-config" (merge (dict "setting" "keepassxc_entries.ssh") .) }}
```

See `openspec/specs/machine-config/` for complete machine configuration system documentation.

## External Dependencies (`.chezmoiexternal.toml.tmpl`)

Not in this directory, but governed by the same "edit the source, not the deployed copy" discipline: `home/.chezmoiexternal.toml.tmpl` (oh-my-zsh plugins/theme, `zsh-llm-suggestions`/`freshbooks-mcp-server`/`zsh-functions`) and `home/dot_claude/.chezmoiexternal.toml.tmpl` (`jev-model-router` mod files). Every entry there is executable or sourced content (shell plugins, hook scripts, an MCP server), so each is pinned to a commit SHA in its URL, never a mutable branch (`master`/`main`) — a plain `chezmoi apply` must not be able to pull in an unreviewed upstream change. `git-repo`-type externals have no native ref-pinning field in chezmoi v2.72.2 (and a periodic `git pull` on `refreshPeriod` would fast-forward past a manual checkout pin anyway), so those are vendored as pinned `archive` tarballs instead. To bump a pin: resolve the new HEAD SHA with `git ls-remote <repo-url> <branch>`, then replace the SHA segment in the affected URL(s). See `openspec/specs/external-dependency-pinning/` for the full requirement.
