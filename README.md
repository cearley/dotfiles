# Dotfiles

[![CI](https://github.com/cearley/dotfiles/actions/workflows/ci.yml/badge.svg)](https://github.com/cearley/dotfiles/actions)
[![macOS](https://img.shields.io/badge/macOS-supported-success)](https://www.apple.com/macos/)
[![chezmoi](https://img.shields.io/badge/managed%20with-chezmoi-blue)](https://www.chezmoi.io/)
[![Homebrew](https://img.shields.io/badge/package%20manager-Homebrew-orange)](https://brew.sh/)
[![GitHub last commit](https://img.shields.io/github/last-commit/cearley/dotfiles)](https://github.com/cearley/dotfiles/commits)

Personal dotfiles and macOS development environment, managed with [chezmoi](https://chezmoi.io).

## Table of Contents

- [Why You Might Find This Useful](#why-you-might-find-this-useful)
- [Quick Start](#quick-start)
- [Key Features](#key-features)
- [Using This Repository](#using-this-repository)
- [Before Forking](#before-forking)

## Why You Might Find This Useful

This repository demonstrates several advanced chezmoi patterns for managing macOS dotfiles and development environments:

- **Secure secret management** - KeePassXC integration with no hardcoded credentials
- **Generic machine configuration system** - Data-driven, pattern-matched machine-specific settings
- **Reusable template components** - DRY templating with `includeTemplate` for cross-platform support
- **Shared utility functions** - Centralized script utilities for consistent error handling and messaging
- **Tag-based execution** - Customize installations for different use cases (dev, personal, ai, work)
- **Structured script execution** - Ordered, frequency-controlled scripts with 5-point spacing convention
- **System-wide configuration** - Manage files outside home directory (`/etc/hosts`, system defaults)
- **Comprehensive validation** - Automated checks for SSH keys, GitHub access, Homebrew installation

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
- **Pattern-based detection** - Automatically detects machine type via `machines.yaml`
- **Reusable templates** - Cross-platform `computer-name` and `machine-config` templates
- **Dot-notation support** - Access nested settings (e.g., `keepassxc_entries.ssh`)
- **Extensible design** - Add new machine-specific properties without template changes

### Script Execution Framework
Scripts in `home/.chezmoiscripts/` use structured naming: `{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl`

**Execution order** (5-point spacing for logical grouping):
- **00-09**: System Foundation (Rosetta 2)
- **10-19**: Development Toolchains (Rust)
- **20-29**: Package Management (SDKMAN, Homebrew bundles, SDKs, UV tools, machine-specific Brewfiles)
- **30-39**: Environment Managers (uv, nvm)
- **40-49**: Environment Setup (GitHub auth, shell plugins)
- **80-99**: System Configuration (security, VPN, sync services, defaults, validation)

### Shared Utilities
- **Location**: `home/scripts/shared-utils.sh`
- **Functions**: `print_message()`, `command_exists()`, `require_tools()`, `download_file()`, `wait_for_app_installation()`, `prompt_ready()`, `is_icloud_signed_in()`, etc.
- **Intuitive emojis**: 🔵 info, ✅ success, ⚠️ warning, ❌ error, ⏭️ skip, 💡 tip
- **Consistent patterns**: All installation scripts use identical messaging and error handling

### Development Environment

**Three-layer package management:**
1. **Homebrew packages** (`packages.yaml`) - System packages, apps, CLI tools
2. **UV tools** (`tools.yaml`) - Python CLI tools and utilities
3. **SDKMAN SDKs** (`sdks.yaml`) - JVM ecosystem (Java, Gradle, Maven, Kotlin, Scala)
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
- **Machine configurations** - Update `home/.chezmoidata/machines.yaml` for your machines
- **Package selections** - Review `home/.chezmoidata/packages.yaml`, `tools.yaml`, `sdks.yaml`, and machine-specific Brewfiles
- **Personal tools** - Remove ChronoSync, Syncthing, custom hosts management, etc.
- **SSH/Git settings** - Update for your accounts and preferences

**Initial setup prompts:**
- Full name, GitHub username, GitHub emails
- KeePassXC database path
- Microsoft email (optional, for subscription app installs)
- Machine tags (core, dev, ai, work, personal, datascience, mobile) - controls which tools get installed

**Development focus:** Cloud (AWS, Azure), AI/ML, macOS-specific tools
