<!-- OPENSPEC:START -->
# OpenSpec Instructions

These instructions are for AI assistants working in this project.

Always open `@/openspec/AGENTS.md` when the request:
- Mentions planning or proposals (words like proposal, spec, change, plan)
- Introduces new capabilities, breaking changes, architecture shifts, or big performance/security work
- Sounds ambiguous and you need the authoritative spec before coding

Use `@/openspec/AGENTS.md` to learn:
- How to create and apply change proposals
- Spec format and conventions
- Project structure and guidelines

Keep this managed block so 'openspec update' can refresh the instructions.

<!-- OPENSPEC:END -->

# Chezmoi Dotfiles

Quick reference guide for AI assistants working with this chezmoi dotfiles repository.

**📚 Source of Truth**: For comprehensive architecture, design decisions, and requirements, see [`openspec/project.md`](openspec/project.md).

## Quick Navigation

### Essential Files
- **Complete specs**: `openspec/project.md` - Authoritative project documentation
- **Daily commands**: `docs/command-reference.md` - Common chezmoi operations
- **Quick reference**: `.serena/memories/chezmoi-dotfiles-quick-reference.md` - Fast lookup

### Key Directories
- `home/.chezmoiscripts/` - Numbered setup scripts (see openspec/project.md for execution order)
- `home/.chezmoidata/` - Static data files (packages.yaml, config.yaml)
- `home/.chezmoitemplates/` - Reusable template components
- `home/scripts/shared-utils.sh` - Common script functions

## Common Commands

```bash
chezmoi apply                  # Apply changes to home directory
chezmoi diff                   # Preview changes before applying
chezmoi update                 # Pull latest from repo and apply
chezmoi status                 # Show files that would change
chezmoi add ~/.<file>          # Add a dotfile to source state
chezmoi edit ~/.<file>         # Edit the source version of a file
chezmoi cd                     # Open shell in source directory
chezmoi managed                # List all managed files
chezmoi cat ~/path/to/file     # Preview generated file content (verify templates/modify_ scripts)
```

## Practical Quick Reference

### Script Naming Pattern
```
{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl
```

**Examples:**
- `run_once_before_darwin-20-install-sdkman.sh.tmpl` - One-time installation
- `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl` - Re-runs on changes

**Execution order**: See `openspec/project.md` for complete script execution order and categories.

### Shared Utilities

**Source shared utilities in all scripts:**
```bash
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"
```

**Common functions:**
- `print_message "info|success|warning|error|skip|tip" "message"` - Consistent output
- `command_exists "command"` - Check availability
- `require_tools "tool1" "tool2"` - Validate dependencies

See `.serena/memories/code-style-quick-reference.md` for complete function list and usage examples.

### Template Testing
```bash
# Test template execution
chezmoi execute-template < filename.tmpl

# Debug template scripts
cat script-name.tmpl | chezmoi execute-template
```

### Template Best Practices

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

**Architecture detection:**
```go-template
{{- if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "arm64") -}}
```

**Platform-specific scripts:**
```go-template
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash
# script content
{{ end -}}
```

### Machine-Specific Settings

**Access machine config:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . }}
{{- $sshEntry := includeTemplate "machine-config" (merge (dict "setting" "keepassxc_entries.ssh") .) }}
```

See `openspec/specs/machine-config/` for complete machine configuration system documentation.

## Key Principles

1. **No hardcoded secrets** - All credentials via KeePassXC
2. **Data files are static** - Files in `.chezmoidata/` cannot be templates
3. **Three-layer package management** - See `openspec/specs/package-management/` for architecture
4. **Consistent messaging** - Always use shared utilities for script output
5. **Platform wrapping** - Darwin scripts must use conditional templates

## When to Reference openspec/

- **Architecture questions** → `openspec/project.md`
- **Package management** → `openspec/specs/package-management/`
- **Machine config** → `openspec/specs/machine-config/`
- **Script execution order** → `openspec/project.md` section "Code Style"
- **Major changes** → See archived proposals in `openspec/changes/archive/`

For comprehensive documentation, conventions, and design rationale, **always consult `openspec/project.md` first**.