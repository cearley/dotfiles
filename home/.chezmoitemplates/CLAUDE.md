# Reusable Templates

Available in `home/.chezmoitemplates/`:
- `machine-name` - Cross-platform machine name detection
- `machine-config` - Machine-specific setting lookup (single property)
- `machine-settings` - All machine settings as JSON dict (preferred for multiple lookups)
- `icloud-account-id` - Returns iCloud account ID if signed in (macOS)
- `time-bucket` - Rolling epoch bucket for periodic `run_onchange_*` re-execution; embed in comment near script top
- `claude-environments` - **Source of truth for Claude environment wiring**: per-env shell functions (`claude-bedrock`, `claude-personal`, `claude-work`), `export CLAUDE_CONFIG_DIR` (when `claude_default` is set), and all `*-spec` SpecStory aliases. Gated internally on `ai` tag. Used by both `dot_zshrc.tmpl` and `dot_bashrc.tmpl`.
- `package-layer-items` - Resolves which `packages.yaml` categories are eligible for a given key (e.g. `bun`, `brews`) given the machine's tags, returning an ordered JSON array of `{category, items}` groups. Single source of category/tag eligibility logic for the package-layer scripts (positions 23-27).
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
