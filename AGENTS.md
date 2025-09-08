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
- `scripts/`: Shared utility scripts and functions
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
  - `45` - Install Azul Zulu JDK (development toolchain)
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

**Script Examples:**
- `run_once_before_darwin-00-install-homebrew.sh.tmpl`: System foundation
- `run_once_before_darwin-10-install-rust.sh.tmpl`: Development toolchain (dev tag)
- `run_onchange_before_darwin-20-install-packages.sh.tmpl`: Package management
- `run_once_after_darwin-45-install-azul-zulu-jdk.sh.tmpl`: Environment setup (dev tag)
- `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl`: System validation (triggered by changes)

### Hooks System

- `hooks/pre/bootstrap`: Ensures Homebrew and KeePassXC are installed before chezmoi operations

### Shared Script Utilities

Scripts in `home/.chezmoiscripts/` can leverage shared utility functions to avoid code duplication and ensure consistency:

- **Script Utils File**: `home/scripts/script-utils.sh` provides common functions
- **Usage**: Source with `source "{{ .chezmoi.sourceDir -}}/scripts/script-utils.sh"`
- **Available Functions**:
  - `print_message()`: Consistent messaging with intuitive emoji support (💡 info, ✅ success, ⚠️ warning, ❌ error, ⏩ skip)
  - `command_exists()`: Check if command is available
  - `require_tools()`: Validate required tools are installed
  - `download_file()`: Download with progress indication
  - `ensure_directory()`: Create directories with optional sudo
  - `cleanup_temp_dir()`: Clean up temporary directories
  - `is_app_installed()`: Check if macOS app is installed
  - `get_macos_arch()`: Get consistent architecture string

**Advantages of this approach**:
- **Simple**: Standard bash sourcing, no template complexity
- **Debuggable**: Direct file access for inspection and editing
- **IDE-friendly**: Full syntax highlighting and tooling support
- **Performance**: No template processing overhead
- **Standard**: Uses conventional shell script patterns
- **Clean output**: Utility functions output to stderr to avoid interfering with return values
- **Consistent**: All scripts now use identical messaging formats and utility patterns

**Scripts Using Shared Utilities**:
Scripts have been systematically refactored to use shared utilities for consistency:
- `run_once_after_darwin-45-install-azul-zulu-jdk.sh.tmpl`: JDK installation with jenv integration
- `run_once_after_darwin-60-setup-microsoft-defender.sh.tmpl`: Microsoft Defender setup
- `run_once_before_darwin-10-install-rust.sh.tmpl`: Rust toolchain installation
- `run_once_before_darwin-15-install-uv.sh.tmpl`: Python package manager uv
- `run_once_before_darwin-35-install-nvm.sh.tmpl`: Node Version Manager
- `run_once_after_darwin-65-setup-claude-desktop.sh.tmpl`: Claude Desktop app setup
- `run_onchange_after_darwin-97-test-ssh-github.sh.tmpl`: SSH connectivity testing

### Configuration Structure

- **Shell**: zsh with p10k theme, custom functions in `dot_zfunc/`
- **Security**: SSH config, AWS credentials (templated), git config (templated)
- **Package Management**: Dual approach using both `packages.yaml` data file and machine-specific brewfiles
- **Development Tools**: VS Code extensions, various CLI tools, cloud SDKs
- **System Defaults**: macOS preferences and application settings via `defaults` commands
- **External Dependencies**: Managed via `home/.chezmoiexternal.toml` (Oh My Zsh, plugins, jenv, nvm)

## Key Commands

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

Dual approach for package management:
1. **Essential Packages** (`home/.chezmoidata/packages.yaml`): Tag-based categorization (core, dev, ai, work)
2. **Supplemental Packages** (machine-specific brewfiles): Additional packages requiring user confirmation

## File Naming Conventions

- `private_` prefix: Sensitive or machine-specific files
- `.tmpl` suffix: Template files processed by chezmoi
- `dot_` prefix: Creates dotfiles (hidden files starting with `.`)
- `run_once_` / `run_onchange_`: Script execution frequency
- Numbers in script names: Execution order with 5-point spacing (see Script Execution System above)
- Platform targeting: Scripts targeting specific platforms (e.g., `darwin`) must use conditional templates

## Documentation References

Use the WebFetch tool to access chezmoi documentation at https://www.chezmoi.io/ when encountering unfamiliar features.

## Security Considerations

- Private files are prefixed with `private_`
- Sensitive data (credentials, keys) use templating for secure injection via KeePassXC
- SSH configuration includes host-specific settings
- Git configuration templates allow for different identities per machine
- Scripts should be installed to `home/.chezmoiscripts/`
- Platform-specific scripts must be wrapped in conditional templates (e.g., `{{- if eq .chezmoi.os "darwin" -}}`)
- Templates (files with .tmpl suffix) can be tested and debugged with `chezmoi execute-template`
- Machine-specific SSH keys use reusable template pattern with hardware serial numbers
- **Command validation in templates**: Use `lookPath` function to check command availability without template failure:
  ```go-template
  {{- if and (has "dev" .tags) (lookPath "rustup") }}
  source "$HOME/.cargo/env"
  {{- end }}
  ```
  **Note**: Avoid using `output "command" "-v" "commandname"` as it will cause template execution to fail if the command doesn't exist. Use `lookPath "commandname"` instead, which returns empty string for missing commands.

## Best Practices

### Architecture Detection
**Use `.chezmoi.arch` for consistent, cross-platform architecture detection:**
```bash
# Preferred approach
{{- if and (eq .chezmoi.os "darwin") (eq .chezmoi.arch "arm64") -}}
```

### Emoji Usage
This macOS-focused repository uses intuitive emojis (💡 info, ✅ success, ⚠️ warning, ❌ error, ⏩ skip) with ASCII fallbacks for non-UTF-8 environments via the shared `print_message()` function.

## Recent Improvements

### Script Refactoring and Shared Utilities (2025)

**Major refactoring initiative** to improve code consistency and maintainability:

#### Shared Utility Functions
- **Created**: `home/scripts/script-utils.sh` with common functions for all installation scripts
- **Improved messaging**: Unified emoji set with intuitive icons:
  - 💡 **Info**: Light bulb suggests helpful information
  - ✅ **Success**: Check mark for completed actions  
  - ⚠️ **Warning**: Triangle for caution messages
  - ❌ **Error**: X mark for failures
  - ⏩ **Skip**: Fast forward for skipped operations
- **Stderr output**: All utility functions output to stderr to avoid interfering with function return values

#### SSH Connectivity Testing
- **Converted**: Post-hook SSH test to `run_onchange_after` script
- **Smart triggering**: Re-runs automatically when SSH keys change (uses file hashing)
- **Better diagnostics**: Enhanced error messages and troubleshooting guidance

#### Azul Zulu JDK Installation
- **New script**: `run_once_after_darwin-45-install-azul-zulu-jdk.sh.tmpl`
- **Features**:
  - Dynamic latest LTS version detection via Azul API
  - Architecture-aware downloads (arm64/x64)
  - Automatic jenv integration
  - Proper macOS .jdk directory structure handling
  - Smart existing installation detection

#### Benefits Achieved
- **Consistency**: All scripts use identical messaging and utility patterns
- **Maintainability**: Centralized utility functions reduce duplication
- **Reliability**: Tested shared functions with better error handling
- **User Experience**: More intuitive emoji icons and consistent output formatting
