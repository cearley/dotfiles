# Dotfiles

[![CI](https://github.com/cearley/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/cearley/dotfiles/actions)
[![macOS](https://img.shields.io/badge/macOS-supported-success)](https://www.apple.com/macos/)
[![chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)](https://www.chezmoi.io/)
[![Homebrew](https://img.shields.io/badge/package%20manager-Homebrew-orange)](https://brew.sh/)
[![GitHub last commit](https://img.shields.io/github/last-commit/cearley/dotfiles)](https://github.com/cearley/dotfiles/commits)

Personal dotfiles and macOS development environment, managed with [chezmoi](https://chezmoi.io).

## Table of Contents

- [Quick Start](#quick-start)
- [Key Features](#key-features)
- [Using This Repository](#using-this-repository)
- [Before Forking](#before-forking)

## Quick Start

Bootstrap a new macOS machine with a single command:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/main/remote_install.sh)"
```

You can also pass arguments to chezmoi by appending them:

```sh
sh -c "$(curl -fsSL https://raw.githubusercontent.com/cearley/dotfiles/main/remote_install.sh)" -- init --apply $GITHUB_USERNAME --keep-going --verbose
```

This automatically installs all dependencies (chezmoi, Git, Homebrew, KeePassXC, etc.) and applies your dotfiles.

**Requirements:** 
- A KeePassXC database file is needed for password management

**Optional:**
- Machine-specific brewfiles for additional package management (will be symlinked to `$HOME/Brewfile` if present)

## Key Features

### Machine Configuration System
- **Pattern-based detection** - Automatically detects machine type via `config.yaml`
- **Reusable templates** - Cross-platform `machine-name` and `machine-config` templates
- **Dot-notation support** - Access nested settings (e.g., `keepassxc_entries.ssh`)
- **Extensible design** - Add new machine-specific properties without template changes

### Script Execution Framework
Scripts in `home/.chezmoiscripts/` use structured naming: `{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl`

**Execution order** (10-point range grouping for logical categorization):
- **00-09**: System Foundation (Rosetta 2)
- **10-19**: Development Toolchains (Rust)
- **20-29**: Package Management (SDKMAN, Homebrew bundles, SDKs, UV tools, machine-specific Brewfiles)
- **30-39**: Environment Managers (uv, nvm)
- **40-49**: Environment Setup (GitHub auth, shell plugins)
- **80-99**: System Configuration (security, VPN, sync services, defaults, validation)

### Shared Utilities
- **Location**: `home/scripts/shared-utils.sh`
- **Functions**: `print_message()`, `command_exists()`, `require_tools()`, `download_file()`, `wait_for_app_installation()`, `prompt_ready()`, `is_icloud_signed_in()`, etc.
- **Consistent patterns**: All installation scripts use identical messaging and error handling

### Development Environment

**Three-layer package management:**
1. **Homebrew packages** (`packages.yaml`) - System packages, apps, CLI tools
2. **UV tools** (`uv-tools.yaml`) - Python CLI tools and utilities
3. **SDKMAN SDKs** (`sdkman-sdks.yaml`) - JVM ecosystem (Java, Gradle, Maven, Kotlin, Scala)
4. **Machine-specific Brewfiles** - Additional packages requiring confirmation

**Environment managers:**
- **SDKMAN**: Java/JVM toolchain management (requires `dev` tag)
- **uv**: Python package and tool management
- **nvm**: Node.js version management
- **conda**: Python environment management (Miniforge)

## Using This Repository

**Common operations:**
```sh
# Edit and apply dotfiles
chezmoi edit --apply ~/.bashrc

# Preview changes before applying
chezmoi diff

# Pull latest changes and apply
chezmoi update

# Add new dotfile
chezmoi add ~/.config/newfile
```

See the [chezmoi documentation](https://www.chezmoi.io/user-guide/daily-operations/) for more details.

## Before Forking

This is a personal configuration reflecting specific workflows and preferences. Consider it a **reference implementation** rather than something to use directly.

**What you'll need to customize:**
- **KeePassXC database** - Set up your own with required entries
- **Machine configurations** - Update `home/.chezmoidata/config.yaml` for your machines
- **Package selections** - Review `home/.chezmoidata/packages.yaml`, `uv-tools.yaml`, `sdkman-sdks.yaml`, and machine-specific Brewfiles
- **Personal tools** - Remove ChronoSync, Syncthing, custom hosts management, etc.
- **SSH/Git settings** - Update for your accounts and preferences

**Initial setup prompts:**
- Full name, GitHub username, GitHub emails
- KeePassXC database path
- Microsoft email (optional, for subscription app installs)
- Machine tags (core, dev, ai, work, personal, data-science, mobile) - controls which tools get installed

**Development focus:** Programming, Cloud (AWS, Azure), AI/ML, macOS-specific tools
