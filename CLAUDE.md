# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This is a personal dotfiles repository managed by chezmoi, designed to bootstrap and maintain macOS development environments. The repository contains configuration files, shell scripts, and automation for setting up a complete development environment across different Mac machines.

## Architecture

- **chezmoi source directory**: `/Users/$USER/.local/share/chezmoi`
- **Target directory**: User's home directory (`~`)
- **Machine-specific configurations**: Uses templates and conditionals to handle different Mac models (MacBook Pro vs Mac Studio)
- **Custom source directory structure**: This repository uses a customized source directory with `home/` as the root (see https://www.chezmoi.io/user-guide/advanced/customize-your-source-directory/). Data files are located at `home/.chezmoidata/` rather than `.chezmoidata/`

### Key Components

- `home/`: Contains all dotfiles and configuration templates
- `bootstrap_darwin.sh`: Installs KeePassXC on macOS  
- `remote_install.sh`: One-command remote installation script
- `mbp-brewfile` / `studio-brewfile`: Machine-specific Homebrew package lists
- Template files (`.tmpl`): Dynamic configuration using chezmoi templating

### Configuration Structure

- **Shell**: zsh with p10k theme, custom functions in `dot_zfunc/`
- **Security**: SSH config, AWS credentials (templated), git config (templated)
- **Package Management**: Homebrew Brewfiles for different machine types
- **Development Tools**: VS Code extensions, various CLI tools, cloud SDKs

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

### Package Management
```bash
# Install packages based on machine type
brew bundle --file="$brewfile"
```

## Templates and Variables

The repository uses chezmoi's templating system to handle:
- Machine-specific configurations (MacBook Pro vs Mac Studio)
- Secret management (AWS credentials, SSH keys, etc.)
- Dynamic configuration based on system detection

Template files use `.tmpl` extension and leverage Go templating syntax with chezmoi functions.

**Important**: Files in `.chezmoidata` directories cannot be templates because they must be present prior to the start of the template engine (see https://www.chezmoi.io/reference/special-directories/chezmoidata/). Data files must be static JSON/YAML/TOML files.

## Documentation References

When working with chezmoi-specific functionality, templating, or advanced features not covered in this file, refer to the official chezmoi documentation at https://www.chezmoi.io/. Key reference sections include:

- **User Guide**: https://www.chezmoi.io/user-guide/ - Core concepts and workflows
- **Reference Manual**: https://www.chezmoi.io/reference/ - Complete command and template reference
- **How-To Guides**: https://www.chezmoi.io/how-to/ - Specific use cases and examples
- **Templates**: https://www.chezmoi.io/user-guide/templating/ - Template syntax and functions

Use the WebFetch tool to access these docs when encountering unfamiliar chezmoi features or when the user asks about advanced chezmoi functionality.

## Security Considerations

- Private files are prefixed with `private_`
- Sensitive data (credentials, keys) use templating for secure injection
- SSH configuration includes host-specific settings
- Git configuration templates allow for different identities per machine
- Any scripts should be installed to @home/.chezmoiscripts/
- Templates (files with .tmpl suffix) can be tested and debugged with `chezmoi execute-template`. (See https://www.chezmoi.io/user-guide/templating/#testing-templates)
- When troubleshooting or testing template scripts, use the command `cat {name-of-template-script}.tmpl | chezmoi execute-template` and examine the output. The output will produce the actual resolved script that is executed during `chezmoi apply`. Always use this approach to test run scripts.

## Chezmoi Source and Target Locations

- All chezmoi managed dot files, data, scripts, templates, etc. are always placed at the root of the chezmoi codebase, unless a subfolder is specified as the root in @.chezmoiroot

## Development Notes

- **Script Locations**: 
  - run scripts are always placed in .chezmoiscripts/ located in the root folder