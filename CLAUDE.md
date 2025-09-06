# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed by chezmoi, designed to bootstrap and maintain macOS development environments. The repository contains configuration files, shell scripts, and automation for setting up a complete development environment across different Mac machines.

## Architecture

- **chezmoi source directory**: `/Users/$USER/.local/share/chezmoi`
- **Target directory**: User's home directory (`~`)
- **Machine-specific configurations**: Uses templates and conditionals to handle different Mac models (MacBook Pro vs Mac Studio)
- **Custom source directory structure**: This repository uses a customized source directory with `home/` as the root (see `.chezmoiroot` file). Data files are located at `home/.chezmoidata/` rather than `.chezmoidata/`

### Key Components

- `home/`: Contains all dotfiles and configuration templates
- `remote_install.sh`: One-command remote installation script
- `hooks/`: Pre and post hooks for chezmoi operations
- `home/.chezmoiscripts/`: Automated setup scripts with execution ordering
- `home/.chezmoidata/packages.yaml`: Static package definitions for Homebrew
- `home/.chezmoitemplates/`: Reusable template snippets
- Template files (`.tmpl`): Dynamic configuration using chezmoi templating

### Script Execution System

Scripts in `home/.chezmoiscripts/` follow a structured naming convention that controls execution:

#### Naming Pattern: `{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl`

**Frequency Control:**
- `run_once_*`: Execute only once per machine (initialization tasks)
- `run_onchange_*`: Re-execute when script content changes (maintenance tasks)

**Execution Timing:**
- `before`: Run before chezmoi applies dotfiles
- `after`: Run after chezmoi applies dotfiles

**Platform Targeting:**
- `darwin`: macOS-specific scripts

**Execution Order (5-point spacing):**
Scripts use consistent 5-point numbering for logical grouping and future expandability:

- **System Foundation (00-09):**
  - `00` - Install Homebrew (foundation)
  - `05` - Install Rosetta 2 (Apple Silicon compatibility)

- **Development Toolchains (10-19):**
  - `10` - Install Rust (development toolchain)
  - `15` - Install uv (Python package manager)

- **Package Management (20-29):**
  - `20` - Brew bundle install essential packages from packages.yaml
  - `25` - Brew bundle install supplemental packages from machine-specific brewfiles

- **Environment Setup (30-59):**
  - `30` - Install Basic Memory MCP server (AI tools)
  - `35` - Install nvm (Node Version Manager)
  - `50` - Initialize conda (Python environment setup)

- **System Configuration (80-99):**
  - `85` - Configure system defaults (macOS preferences)
  - `90` - Update hosts (system-level modifications)
  - `95` - Restart services (service management)

**Platform-Specific Scripts:**
All darwin-targeted scripts must be wrapped in conditional templates:
```go-template
{{- if eq .chezmoi.os "darwin" -}}
#!/bin/bash
# script content here
{{ end -}}
```

**Current Script Inventory:**
- `run_once_before_darwin-00-install-homebrew.sh.tmpl`: Homebrew installation
- `run_once_before_darwin-05-install-rosetta.sh.tmpl`: Rosetta 2 for Apple Silicon
- `run_once_before_darwin-10-install-rust.sh.tmpl`: Rust toolchain
- `run_once_before_darwin-15-install-uv.sh.tmpl`: Python package manager uv
- `run_onchange_before_darwin-20-install-packages.sh.tmpl`: Essential packages from packages.yaml
- `run_onchange_before_darwin-25-brew-bundle-install.sh.tmpl`: Supplemental packages from machine-specific brewfiles
- `run_once_before_darwin-30-install-basic-memory.sh.tmpl`: Basic Memory MCP server (ai tag only)
- `run_once_before_darwin-35-install-nvm.sh.tmpl`: Node Version Manager (work tag only)
- `run_once_after_darwin-50-initialize-conda.sh.tmpl`: Conda environment setup
- `run_once_after_darwin-60-setup-microsoft-defender.sh.tmpl`: Microsoft Defender installation (conditional on microsoft_email)
- `run_once_after_darwin-65-setup-claude-desktop.sh.tmpl`: Claude Desktop application installation
- `run_once_after_darwin-85-configure-system-defaults.sh.tmpl`: macOS system preferences and iTerm2 settings
- `run_once_after_darwin-88-setup-chronosync-symlinks.sh.tmpl`: ChronoSync symbolic links setup
- `run_onchange_after_darwin-90-update-hosts.sh.tmpl`: Dynamic `/etc/hosts` management
- `run_onchange_after_darwin-95-restart-syncthing.sh.tmpl`: Syncthing service management

### Hooks System

- `hooks/pre/bootstrap`: Ensures Homebrew and KeePassXC are installed before chezmoi operations
- `hooks/post/test-ssh-github.sh`: Verifies SSH GitHub connection (runs only with "work" tag)

### Configuration Structure

- **Shell**: zsh with p10k theme, custom functions in `dot_zfunc/`
- **Security**: SSH config, AWS credentials (templated), git config (templated)
- **Package Management**: Dual approach using both `packages.yaml` data file and machine-specific brewfiles
- **Development Tools**: VS Code extensions, various CLI tools, cloud SDKs
- **System Defaults**: macOS preferences and application settings via `defaults` commands
- **External Dependencies**: Managed via `home/.chezmoiexternal.toml` (Oh My Zsh, plugins, jenv, nvm)

## Common Commands

### Chezmoi Operations
```bash
# Edit a dotfile
chezmoi edit $FILENAME

# Edit and auto-apply changes
chezmoi edit --apply $FILENAME

# Edit with auto-apply on save
chezmoi edit --watch $FILENAME

# Update from remote and apply
chezmoi update

# Preview changes without applying
chezmoi git pull -- --autostash --rebase && chezmoi diff

# Apply previewed changes
chezmoi apply
```

### Remote Installation
```bash
# One-command setup on new machine
sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/chezmoi/remote_install.sh)"
```

### Template Testing and Debugging
```bash
# Test template execution
chezmoi execute-template < filename.tmpl

# Debug template scripts
cat {name-of-template-script}.tmpl | chezmoi execute-template
```

## Templates and Variables

The repository uses chezmoi's templating system extensively:

### Machine Detection
- Uses `system_profiler` output to detect Mac model (MacBook Pro vs Mac Studio)
- Templates conditionally apply configurations based on `scutil --get ComputerName`

### Secret Management
- Integrates with KeePassXC via `keepassxcAttribute` template function
- No secrets stored in repository - all fetched at apply time
- Reusable template `ssh_secret` constructs machine-specific KeePassXC entries

### User Configuration
- `home/.chezmoi.toml.tmpl` prompts for user data on first run
- Uses `promptStringOnce` and `promptMultichoiceOnce` for setup
- Data stored in `.chezmoi.data.json` for template reuse

**Important**: Files in `.chezmoidata` directories cannot be templates because they must be present prior to the start of the template engine. Data files must be static JSON/YAML/TOML files.

### Package Management Strategy

The repository uses a dual approach for package management:

1. **Essential Packages** (`packages.yaml`): Static, categorized packages that are fundamental to the development environment
   - `core`: Always-installed packages (git, iTerm2, syncthing, etc.)
   - `dev`: Development tools (Go, Docker, VS Code, etc.) - requires "dev" tag
   - `ai`: AI/ML packages (ollama, miniforge, etc.) - requires "ai" tag
   - `work`: Work-specific packages (Teams, Zoom, .NET SDKs, etc.) - requires "work" tag

2. **Supplemental Packages** (machine-specific brewfiles): Additional packages that extend beyond the essentials
   - `mbp-brewfile`: Packages specific to MacBook Pro machines
   - `studio-brewfile`: Packages specific to Mac Studio machines
   - Updated via: `brew bundle dump --file=$HOME/.brewfiles/{machine-specific-brewfile} --force`
   - Installed via prompted script that asks user permission

This separation allows for:
- **Consistent essentials**: Core packages are version-controlled and predictable
- **Machine flexibility**: Different machines can have different supplemental packages
- **User control**: Supplemental packages require user confirmation before installation
- **Easy maintenance**: Brewfiles can be regenerated from current system state

## File Naming Conventions

- `private_` prefix: Sensitive or machine-specific files
- `.tmpl` suffix: Template files processed by chezmoi
- `dot_` prefix: Creates dotfiles (hidden files starting with `.`)
- `run_once_` / `run_onchange_`: Script execution frequency
- Numbers in script names: Execution order with 5-point spacing (see Script Execution System above)
- Platform targeting: Scripts targeting specific platforms (e.g., `darwin`) must use conditional templates

## Documentation References

When working with chezmoi-specific functionality, templating, or advanced features not covered in this file, refer to the official chezmoi documentation at https://www.chezmoi.io/. Key reference sections include:

- **User Guide**: https://www.chezmoi.io/user-guide/ - Core concepts and workflows
- **Reference Manual**: https://www.chezmoi.io/reference/ - Complete command and template reference
- **How-To Guides**: https://www.chezmoi.io/how-to/ - Specific use cases and examples
- **Templates**: https://www.chezmoi.io/user-guide/templating/ - Template syntax and functions

Use the WebFetch tool to access these docs when encountering unfamiliar chezmoi features or when the user asks about advanced chezmoi functionality.

## Security Considerations

- Private files are prefixed with `private_`
- Sensitive data (credentials, keys) use templating for secure injection via KeePassXC
- SSH configuration includes host-specific settings
- Git configuration templates allow for different identities per machine
- Scripts should be installed to `home/.chezmoiscripts/`
- Platform-specific scripts must be wrapped in conditional templates (e.g., `{{- if eq .chezmoi.os "darwin" -}}`)
- Templates (files with .tmpl suffix) can be tested and debugged with `chezmoi execute-template`
- Machine-specific SSH keys use reusable template pattern with hardware serial numbers

## Portability Considerations

### Emoji Usage in Scripts
Current scripts use emoji icons in output messages (e.g., `🍺 Installing packages using Homebrew...`). This enhances user experience on modern macOS but has portability implications:

**Current Status (Good for macOS-focused repository):**
- ✅ Modern macOS terminals (Terminal.app, iTerm2) have excellent emoji support
- ✅ UTF-8 environments render emojis correctly
- ✅ Improves script output readability and user engagement

**Potential Issues for Diverse Environments:**
- ⚠️ Older systems may not render emojis correctly
- ⚠️ Non-UTF-8 locales could display as question marks or boxes
- ⚠️ Minimal terminals might not support emojis
- ⚠️ CI/CD environments may not render emojis in build logs
- ⚠️ SSH sessions depend on client terminal capabilities

**Recommendations for Broader Compatibility:**
If targeting diverse environments, consider these alternatives:

```bash
# Option 1: ASCII-safe prefixes
echo "[INFO] Installing packages using Homebrew..."
echo "[SUCCESS] Installation completed"

# Option 2: Simple symbols  
echo "* Installing packages using Homebrew..."
echo "+ Installation completed"

# Option 3: Conditional emojis
if [ "${LANG}" != "${LANG%UTF-8*}" ]; then
    echo "🍺 Installing packages using Homebrew..."
else
    echo "Installing packages using Homebrew..."
fi
```

### Architecture Detection
Scripts use chezmoi's built-in architecture detection for conditional execution:

```bash
# Apple Silicon specific (current approach)
{{- if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "arm64") -}}

# Alternative methods:
{{- if eq .chezmoi.kernel.machine "arm64" -}}
{{- if eq (output "uname" "-m") "arm64" -}}
```

**Best Practice:** Use `.chezmoi.arch` for consistent, cross-platform architecture detection.
