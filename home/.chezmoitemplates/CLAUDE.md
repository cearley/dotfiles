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
