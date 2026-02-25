
# Chezmoi Dotfiles

Quick reference guide for AI assistants working with this chezmoi dotfiles repository.

## Quick Navigation

### Essential Files
- **OpenSpec specs**: `openspec/specs/` - Capability specifications and design
- **Code style examples**: `.serena/memories/code-style-quick-reference.md` - Extended cookbook

### Key Directories
- `home/.chezmoiscripts/` - Numbered setup scripts (execution order: 00-99)
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

## Chezmoi File Attributes

Prefixes in source filenames control how chezmoi processes them:
- **`private_`** - Sensitive/machine-specific files (restricted permissions)
- **`dot_`** - Creates dotfiles (hidden files starting with `.`)
- **`executable_`** - Creates executable files (chmod +x)
- **`symlink_`** - Creates symbolic links
- **`.tmpl` suffix** - Template files processed by Go template engine

## Source Directory Structure

```
.local/share/chezmoi/
├── home/                           # Root for all managed files (.chezmoiroot)
│   ├── .chezmoidata/              # Static data files (YAML/JSON/TOML)
│   ├── .chezmoitemplates/         # Reusable template snippets
│   ├── .chezmoiscripts/           # Automated setup scripts
│   ├── .chezmoiexternal.toml.tmpl # External dependency definitions
│   ├── .chezmoi.toml.tmpl         # User configuration prompts
│   └── [dotfiles with chezmoi prefixes]
├── scripts/                        # Shared utility scripts
├── hooks/                          # Pre/post operation hooks
├── brewfiles/                      # Machine-specific Homebrew bundles
└── remote_install.sh              # One-command bootstrap script
```

## Practical Quick Reference

### Script Naming Pattern
```
{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl
```

**Examples:**
- `run_once_before_darwin-20-install-sdkman.sh.tmpl` - One-time installation
- `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl` - Re-runs on changes

**Script execution order:**
- **05**: Rosetta 2 | **10**: Rust | **20**: SDKMAN | **23**: Homebrew packages | **24**: SDKMAN SDKs | **25**: UV tools | **26**: Bun packages | **28**: Machine-specific Brewfile
- **30**: UV manager | **35**: nvm | **36**: Claude Code (`ai` tag)
- **45**: GitHub auth | **80**: Microsoft Defender | **82**: Global Protect VPN | **83**: Atuin | **85**: System defaults | **90**: Hosts file | **95**: Syncthing | **97**: SSH test

### Shared Utilities

**Source shared utilities in all scripts:**
```bash
source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"
```

**Common functions:**
- `print_message "info|success|warning|error|skip|tip" "message"` - Consistent output
- `command_exists "command"` - Check availability
- `require_tools "tool1" "tool2"` - Validate dependencies
- `wait_for_app_installation "/path/to/App.app" "App Name"` - Interactive install wait
- `ensure_directory "path" ["sudo"]` - Create directory if missing
- `prompt_ready ["message"]` - User prompt helper

See `.serena/memories/code-style-quick-reference.md` for extended examples and patterns.

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

### Reusable Templates

Available in `home/.chezmoitemplates/`:
- `machine-name` - Cross-platform machine name detection
- `machine-config` - Machine-specific setting lookup (single property)
- `machine-settings` - All machine settings as JSON dict (preferred for multiple lookups)
- `icloud-account-id` - Returns iCloud account ID if signed in (macOS)

**Access machine config:**
```go-template
{{- $brewfilePath := includeTemplate "machine-brewfile-path" . }}
{{- $sshEntry := includeTemplate "machine-config" (merge (dict "setting" "keepassxc_entries.ssh") .) }}
```

See `openspec/specs/machine-config/` for complete machine configuration system documentation.

## Key Principles

1. **No hardcoded secrets** - All credentials via KeePassXC
2. **Data files are static** - Files in `.chezmoidata/` cannot be templates
3. **Four-layer package management** (Homebrew, UV, Bun, SDKMAN) - See `openspec/specs/package-management/`
4. **Consistent messaging** - Always use shared utilities for script output
5. **Platform wrapping** - Darwin scripts must use conditional templates
6. **Script ordering** - Machine-specific Brewfile (position 28) must always be last in the package management group (20-29)

### Platform Requirements
- **Target OS**: macOS 11.0+ (Big Sur or later)
- **Architectures**: ARM64 (Apple Silicon) primary, x64 (Intel) secondary
- **Bootstrap dependencies**: Xcode CLI Tools, KeePassXC (secrets), Homebrew (packages)

### Tag Combinations
- **Minimal**: `core`
- **Developer**: `core,dev,ai`
- **Work machine**: `core,dev,work`
- **Personal machine**: `core,dev,ai,personal,datascience`

## Claude Code Automations

### Hooks (`.claude/settings.json`)
- **Template validation** (PostToolUse): Runs `chezmoi execute-template` on `.tmpl` files after edits
- **Data file protection** (PreToolUse): Blocks `{{ }}` expressions in `.chezmoidata/` files

### Skills
- `/new-script` - Generate a chezmoi script with correct naming, boilerplate, and conventions
- `/apply` - Safe diff-then-apply workflow with confirmation

### Agents
- `template-reviewer` - Scans all templates for convention violations (read-only)

### MCP Server Configuration
- **Global MCP servers**: `home/private_dot_config/claude-extend/tools.json.tmpl` (deployed to `~/.config/claude-extend/tools.json`)
- **Project MCP servers**: `.mcp.json` (if needed)
- GitHub MCP uses `gh auth token` for authentication — no PAT management needed

## When to Reference openspec/

- **Package management** → `openspec/specs/package-management/`
- **Machine config** → `openspec/specs/machine-config/`
- **Secret management** → `openspec/specs/secret-management/`
- **Major changes** → See archived proposals in `openspec/changes/archive/`
