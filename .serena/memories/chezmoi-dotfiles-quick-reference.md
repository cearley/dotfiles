# Chezmoi Dotfiles Quick Reference

> **For complete specifications and architecture**, see:
> - [`openspec/project.md`](../../openspec/project.md) - Complete project documentation
> - [`openspec/specs/`](../../openspec/specs/) - Capability specifications
> - [`docs/`](../../docs/) - Command references and guides

---

## Quick Navigation

### Key Directories
- **Specs**: `openspec/specs/` - Authoritative requirements and design
- **Docs**: `docs/` - Command references and macOS utilities
- **Scripts**: `home/.chezmoiscripts/` - Numbered setup scripts (10-point range grouping)
- **Utilities**: `home/scripts/shared-utils.sh` - Common script functions
- **Templates**: `home/.chezmoitemplates/` - Reusable template components
- **Data**: `home/.chezmoidata/` - Static configuration files (packages.yaml, config.yaml)

### Essential Files
- `openspec/project.md` - Complete project context, tech stack, conventions
- `docs/command-reference.md` - Daily command cheat sheet
- `home/.chezmoidata/config.yaml` - Machine-specific settings
- `home/.chezmoidata/packages.yaml` - All package definitions (Homebrew, UV tools, SDKMAN SDKs)

---

## Recent Minor Optimizations (2025)

### Script Refactoring
- Consolidated common functions into `shared-utils.sh`
- Standardized emoji messaging across all scripts
- Improved error handling and cleanup functions

### SSH Connectivity Testing
- Migrated post-hook SSH test to `run_onchange_after` script
- Automatic re-validation when SSH keys change (file hashing)
- Enhanced diagnostic messages and troubleshooting guidance

### Template Reusability
- Centralized machine-specific logic in generic templates
- Dot-notation support for nested YAML properties
- DRY principle applied to machine configuration lookups

---

## Major Architectural Changes

For details on major system changes, see archived change proposals:
- [`openspec/changes/archive/2025-10-10-sdkman-integration/`](../../openspec/changes/archive/2025-10-10-sdkman-integration/) - SDKMAN replacing jenv (Oct 10, 2025)
- [`openspec/changes/archive/2025-10-24-three-layer-package-management/`](../../openspec/changes/archive/2025-10-24-three-layer-package-management/) - Added UV tools and SDKMAN layers (Oct 24, 2025)

---

## Quick Script Lookup

### Script Execution Order (10-point range grouping)
- **05**: Rosetta 2 (System Foundation)
- **10**: Rust (Development Toolchains)
- **20**: SDKMAN (Package Management - JVM)
- **23**: Homebrew packages (Package Management - Essential)
- **24**: SDKs via SDKMAN (Package Management - JVM SDKs)
- **25**: UV tools (Package Management - Python tools)
- **26**: Machine-specific Brewfile (Package Management - Additional)
- **30**: UV package manager (Environment Managers)
- **35**: nvm (Environment Managers)
- **36**: Claude Code (AI Development Tools - requires `ai` tag)
- **45**: GitHub authentication (Environment Setup)
- **80**: Microsoft Defender (System Configuration - Security)
- **82**: Global Protect VPN (System Configuration - Work)
- **83**: Atuin sync login (System Configuration - Shell)
- **85**: System defaults (System Configuration - macOS)
- **90**: Hosts file update (System Configuration - Network)
- **95**: Syncthing restart (System Configuration - File Sync)
- **97**: SSH GitHub connectivity test (System Configuration - Validation)

### Shared Utility Functions
Available in `home/scripts/shared-utils.sh`:
- `print_message()` - Consistent emoji messaging
- `command_exists()` - Check command availability
- `require_tools()` - Validate dependencies
- `wait_for_app_installation()` - Interactive app installation wait
- `prompt_ready()` - User prompt helper
- `is_icloud_signed_in()` - **DEPRECATED**: Use `includeTemplate "icloud-account-id"` instead
- `is_root()` - Root privilege check

### Reusable Templates
Available in `home/.chezmoitemplates/`:
- `machine-name` - Cross-platform machine name detection
- `machine-config` - Machine-specific setting lookup
- `machine-settings` - Returns all machine settings as JSON dict
- `icloud-account-id` - Returns iCloud account ID if signed in (macOS)

---

## Testing & Validation

### Template Testing
```bash
# Test template execution
chezmoi execute-template < filename.tmpl

# Debug template scripts
cat script-name.tmpl | chezmoi execute-template
```

### Command References
See [`docs/command-reference.md`](../../docs/command-reference.md) for daily command cheat sheet.

---

## Memory Note

This is a quick reference memory for AI agents and human users. For authoritative specifications, requirements, and architectural documentation, always consult [`openspec/`](../../openspec/).
