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

Scripts in `home/.chezmoiscripts/` follow a naming convention that controls execution:
- `run_once_*`: Execute only once per machine
- `run_onchange_*`: Execute when script content changes
- Numbers in filenames (e.g., `-05-`, `-10-`) control execution order
- Key scripts:
  - `run_once_before_darwin-05-install-rosetta.sh.tmpl`: Installs Rosetta 2 on Apple Silicon
  - `run_once_before_darwin-10-install-rust.sh.tmpl`: Installs Rust toolchain
  - `run_once_before_darwin-20-install-uv.sh.tmpl`: Installs Python package manager
  - `run_onchange_before_darwin-30-install-packages.sh.tmpl`: Main package installation
  - `run_onchange_after_darwin-100-update-hosts.sh.tmpl`: Dynamic `/etc/hosts` management

### Hooks System

- `hooks/pre/bootstrap`: Ensures Homebrew and KeePassXC are installed before chezmoi operations
- `hooks/post/test-ssh-github.sh`: Verifies SSH GitHub connection (runs only with "work" tag)

### Configuration Structure

- **Shell**: zsh with p10k theme, custom functions in `dot_zfunc/`
- **Security**: SSH config, AWS credentials (templated), git config (templated)
- **Package Management**: Uses `packages.yaml` data file with brew bundle
- **Development Tools**: VS Code extensions, various CLI tools, cloud SDKs
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
- Templates conditionally apply configurations based on `.chezmoi.fqdnHostname`

### Secret Management
- Integrates with KeePassXC via `keepassxcAttribute` template function
- No secrets stored in repository - all fetched at apply time
- Reusable template `ssh_secret` constructs machine-specific KeePassXC entries

### User Configuration
- `home/.chezmoi.toml.tmpl` prompts for user data on first run
- Uses `promptStringOnce` and `promptMultichoiceOnce` for setup
- Data stored in `.chezmoi.data.json` for template reuse

**Important**: Files in `.chezmoidata` directories cannot be templates because they must be present prior to the start of the template engine. Data files must be static JSON/YAML/TOML files.

## File Naming Conventions

- `private_` prefix: Sensitive or machine-specific files
- `.tmpl` suffix: Template files processed by chezmoi
- `dot_` prefix: Creates dotfiles (hidden files starting with `.`)
- `run_once_` / `run_onchange_`: Script execution frequency
- Numbers in script names: Execution order (`-05-`, `-10-`, etc.)

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
- Templates (files with .tmpl suffix) can be tested and debugged with `chezmoi execute-template`
- Machine-specific SSH keys use reusable template pattern with hardware serial numbers