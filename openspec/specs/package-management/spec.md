# Package Management System

## Purpose
The package management system provides a unified approach for installing packages across different ecosystems, all defined in a single `packages.yaml` file:
- **Homebrew**: System packages, applications, and CLI tools (essential tag-based + machine-specific)
- **UV Tools**: Python-based CLI tools and utilities (tag-based, within `packages.yaml`)
- **SDKMAN SDKs**: JVM ecosystem SDKs and build tools (tag-based, within `packages.yaml`, requires `dev` tag)

## Requirements
### Requirement: Central Package Definition
All packages SHALL be defined in `home/.chezmoidata/packages.yaml` organized by platform and tag.

#### Scenario: Platform-based package organization
- **WHEN** packages are defined for the darwin platform
- **THEN** the YAML structure SHALL include `packages.darwin` with nested tag categories

#### Scenario: Tag-based package categories
- **WHEN** packages are categorized by tags (core, dev, ai, work, personal, datascience, mobile)
- **THEN** each tag SHALL contain separate lists for `taps`, `brews`, `casks`, `mas`, `sdkman`, and `uv` packages

### Requirement: Tag-Based Package Selection
Package installation SHALL be controlled by user-selected tags during chezmoi initialization.

#### Scenario: Core packages always installed
- **WHEN** chezmoi applies configuration
- **THEN** packages in the `core` tag SHALL be installed regardless of other selected tags

#### Scenario: Optional tag packages
- **WHEN** a user selects the `dev` tag
- **THEN** only packages in `core` and `dev` tags SHALL be installed
- **AND** packages in unselected tags SHALL be skipped

#### Scenario: Multiple tag selection
- **WHEN** a user selects tags `core,dev,ai,personal`
- **THEN** packages from all four tag categories SHALL be installed

### Requirement: Homebrew Package Types
The system SHALL support all Homebrew package types: taps, brews (formulae), casks, and Mac App Store apps.

#### Scenario: Homebrew tap installation
- **WHEN** a tap is defined in `packages.yaml` under the `taps` key
- **THEN** the tap SHALL be added via `brew tap` before installing packages from that tap

#### Scenario: Formula installation
- **WHEN** a package is listed under `brews`
- **THEN** it SHALL be installed via `brew install <package>`

#### Scenario: Cask installation
- **WHEN** an application is listed under `casks`
- **THEN** it SHALL be installed via `brew install --cask <package>`

#### Scenario: Mac App Store installation
- **WHEN** an app is listed under `mas` with format `"App Name", id: 123456`
- **THEN** it SHALL be installed via `mas install 123456`

### Requirement: Machine-Specific Brewfiles
Additional packages SHALL be defined in machine-specific Brewfiles located in the `brewfiles/` directory.

#### Scenario: Machine-specific Brewfile location
- **WHEN** the machine configuration specifies `brewfile: mbp-brewfile`
- **THEN** the system SHALL use `brewfiles/mbp-brewfile` for additional packages

#### Scenario: Brewfile symlinking
- **WHEN** chezmoi applies configuration
- **THEN** the machine-specific Brewfile SHALL be symlinked to `~/Brewfile`
- **AND** SHALL be accessible for manual `brew bundle` operations

### Requirement: User Confirmation for Additional Packages
Machine-specific Brewfile packages SHALL require explicit user confirmation before installation.

#### Scenario: Confirmation prompt
- **WHEN** a machine-specific Brewfile contains additional packages
- **THEN** the script SHALL prompt the user for confirmation before running `brew bundle`

#### Scenario: Confirmation denied
- **WHEN** the user declines the Brewfile installation prompt
- **THEN** the script SHALL skip Brewfile installation
- **AND** SHALL continue with other setup tasks

#### Scenario: Confirmation accepted
- **WHEN** the user confirms the Brewfile installation prompt
- **THEN** the script SHALL execute `brew bundle --file ~/Brewfile`

### Requirement: Idempotent Package Installation
Package installation SHALL be idempotent and safe to re-run.

#### Scenario: Already installed package
- **WHEN** a package is already installed
- **THEN** `brew install` SHALL skip reinstallation
- **AND** SHALL display that the package is already installed

#### Scenario: Package updates
- **WHEN** running `brew bundle` with existing packages
- **THEN** Homebrew SHALL upgrade outdated packages if specified in Brewfile options

### Requirement: Homebrew Bootstrap
Homebrew itself SHALL be installed via a pre-hook if not already present.

#### Scenario: Homebrew missing
- **WHEN** chezmoi's pre-hook runs and Homebrew is not installed
- **THEN** the hook SHALL install Homebrew before proceeding

#### Scenario: Homebrew exists
- **WHEN** Homebrew is already installed
- **THEN** the pre-hook SHALL skip installation and continue

### Requirement: Package Categories
Packages SHALL be organized into logical categories based on their purpose.

#### Scenario: Core packages
- **WHEN** packages are essential for basic system operation
- **THEN** they SHALL be placed in the `core` tag category

#### Scenario: Development packages
- **WHEN** packages are development tools (docker, IDEs, language tools)
- **THEN** they SHALL be placed in the `dev` tag category

#### Scenario: AI/ML packages
- **WHEN** packages are AI or machine learning related (Claude, Ollama, LM Studio)
- **THEN** they SHALL be placed in the `ai` tag category

#### Scenario: Work packages
- **WHEN** packages are enterprise or work-specific tools (Teams, Workspaces)
- **THEN** they SHALL be placed in the `work` tag category

#### Scenario: Personal packages
- **WHEN** packages are personal productivity tools (Syncthing, ChronoSync)
- **THEN** they SHALL be placed in the `personal` tag category

#### Scenario: Data science packages
- **WHEN** packages are data analysis tools (R, RStudio, csvkit)
- **THEN** they SHALL be placed in the `datascience` tag category

#### Scenario: Mobile/network packages
- **WHEN** packages are VPN or network tools (Tunnelblick, WireGuard)
- **THEN** they SHALL be placed in the `mobile` tag category

### Requirement: Static Package Data File
The `packages.yaml` file SHALL be a static file, not a template.

#### Scenario: Pre-template availability
- **WHEN** chezmoi's template engine initializes
- **THEN** `packages.yaml` MUST exist and be parseable
- **AND** SHALL NOT require template processing

### Requirement: Claude Code Native Installation
The system SHALL support native installation of Claude Code (Anthropic's AI coding assistant) when the `ai` tag is selected.

#### Scenario: Fresh Claude Code installation on macOS
- **WHEN** chezmoi applies configuration on macOS
- **AND** the `ai` tag is selected
- **AND** Claude Code is not already installed
- **THEN** the installation script SHALL execute `curl -fsSL https://claude.ai/install.sh | bash`
- **AND** SHALL verify installation by running `claude --version`
- **AND** SHALL display success message upon completion

#### Scenario: Claude Code already installed
- **WHEN** the installation script runs
- **AND** the `claude` command is already available in PATH
- **THEN** the script SHALL skip installation
- **AND** SHALL display a skip message indicating Claude Code is already present
- **AND** SHALL exit successfully without errors

#### Scenario: Installation without ai tag
- **WHEN** chezmoi applies configuration
- **AND** the `ai` tag is NOT selected
- **THEN** the Claude Code installation script SHALL not execute
- **AND** no Claude Code installation SHALL occur

#### Scenario: Platform detection for installation
- **WHEN** the installation script runs
- **AND** the platform is macOS (darwin)
- **THEN** the script SHALL use the native install command for Unix-like systems
- **AND** SHALL install the binary to `~/.local/bin/claude`

#### Scenario: Linux/WSL installation support
- **WHEN** the installation script runs
- **AND** the platform is Linux or WSL
- **THEN** the script SHALL use the same native install command
- **AND** SHALL support Ubuntu 20.04+, Debian 10+, and compatible distributions
- **AND** SHALL install the binary to `~/.local/bin/claude`

#### Scenario: Installation failure handling
- **WHEN** the Claude Code installation command fails
- **THEN** the script SHALL display an error message using `print_message "error"`
- **AND** SHALL exit with a non-zero status code
- **AND** SHALL provide troubleshooting guidance

#### Scenario: Post-installation verification
- **WHEN** Claude Code installation completes successfully
- **THEN** the script SHALL verify the `claude` command is available
- **AND** SHALL run `claude --version` to confirm successful installation
- **AND** SHALL display the installed version number

### Requirement: Claude Code Script Execution Order
The Claude Code installation script SHALL execute in the proper sequence within the development toolchain setup.

#### Scenario: Script execution order
- **WHEN** chezmoi runs installation scripts
- **THEN** Claude Code installation (order 36) SHALL execute:
  - **AFTER** nvm installation (order 35)
  - **BEFORE** shell plugins and authentication (order 40+)
- **AND** SHALL be positioned in the "Environment Managers" category (30-39)

#### Scenario: Installation dependencies
- **WHEN** the Claude Code installation script executes
- **THEN** the system SHALL have curl available (from core packages)
- **AND** SHALL have bash available (system default)
- **AND** SHALL NOT require Node.js or other language runtimes

### Requirement: Claude Code Integration with Shared Utilities
The Claude Code installation script SHALL use the shared utility functions for consistent messaging and behavior.

#### Scenario: Shared utility usage
- **WHEN** the Claude Code installation script executes
- **THEN** it SHALL source `scripts/shared-utils.sh`
- **AND** SHALL use `print_message()` for all user-facing output
- **AND** SHALL follow standard messaging conventions (info, success, warning, error, skip)

#### Scenario: Idempotent execution
- **WHEN** the Claude Code installation script runs multiple times
- **THEN** it SHALL safely detect existing installations
- **AND** SHALL not cause errors or duplicate installations
- **AND** SHALL maintain system stability

### Requirement: Claude Code Configuration Management
The system SHALL provide Claude Code with proper configuration and state management.

#### Scenario: Installation directory structure
- **WHEN** Claude Code is installed via the native method
- **THEN** the binary SHALL be placed at `~/.local/bin/claude`
- **AND** configuration SHALL be stored in `~/.claude-code/`
- **AND** user settings SHALL be stored in `~/.claude/`

#### Scenario: Auto-update behavior
- **WHEN** Claude Code is installed
- **THEN** auto-updates SHALL be enabled by default
- **AND** updates SHALL check on startup and periodically while running
- **AND** users MAY disable auto-updates via `DISABLE_AUTOUPDATER=1` environment variable

#### Scenario: PATH configuration
- **WHEN** Claude Code is installed to `~/.local/bin/`
- **THEN** the directory SHALL be included in the user's PATH
- **AND** the `claude` command SHALL be immediately accessible
- **AND** SHALL work without requiring shell restart

## UV Tool Management

### Requirement: UV Installation
The `uv` package manager SHALL be installed before UV tools are installed.

#### Scenario: UV not present
- **WHEN** chezmoi applies configuration and `uv` is not installed
- **THEN** the system SHALL install `uv` via the official Astral.sh installer
- **AND** SHALL run at position 30 in the script execution order

#### Scenario: UV already installed
- **WHEN** `uv` is already present on the system
- **THEN** the installation script SHALL skip reinstallation

### Requirement: UV Tool Definition
UV tools SHALL be defined within tag categories in `home/.chezmoidata/packages.yaml` using the `uv` key.

#### Scenario: Tool organization structure
- **WHEN** tools are defined in `packages.yaml`
- **THEN** the YAML structure SHALL include `packages.darwin.<tag>.uv` with lists of tool specifications

#### Scenario: Tool specification formats
- **WHEN** a tool is defined
- **THEN** it SHALL use one of these formats:
  - Simple package name: `"package-name"`
  - Git repository: `"git+https://github.com/org/repo@latest"`
  - Version-pinned: `"package-name==1.0.0"`

### Requirement: Tag-Based UV Tool Selection
UV tool installation SHALL be controlled by user-selected tags.

#### Scenario: Tag-conditional tools
- **WHEN** a user selects the `ai` tag
- **THEN** tools in the `ai` tag's `uv` list SHALL be installed
- **AND** tools in unselected tag categories SHALL be skipped

#### Scenario: Multiple tool categories
- **WHEN** a user selects tags `core,dev,ai`
- **THEN** UV tools from all three tag categories SHALL be installed via `uv tool install`

### Requirement: UV Tool Installation Script
UV tools SHALL be installed via a `run_onchange_before` script at position 25.

#### Scenario: Tool installation execution
- **WHEN** the tool installation script runs
- **THEN** it SHALL execute `uv tool install <tool>` for each selected tool
- **AND** SHALL re-run whenever the script content or `packages.yaml` changes

#### Scenario: Tool installation idempotency
- **WHEN** a tool is already installed
- **THEN** `uv tool install` SHALL skip reinstallation or upgrade the tool
- **AND** SHALL continue with remaining tools

### Requirement: UV Tool Categories
UV tools SHALL be organized within the same tag categories as Homebrew packages in `packages.yaml`.

#### Scenario: AI tool category
- **WHEN** a tool is AI-related (claude-monitor, zsh-llm-suggestions)
- **THEN** it SHALL be placed under the `ai` tag's `uv` list in `packages.yaml`

#### Scenario: Development tool category
- **WHEN** a tool is development-related (linters, formatters, build tools)
- **THEN** it SHALL be placed under the `dev` tag's `uv` list in `packages.yaml`

#### Scenario: Core tool category
- **WHEN** a tool is essential for basic operations
- **THEN** it SHALL be placed under the `core` tag's `uv` list in `packages.yaml`

## SDKMAN SDK Management

### Requirement: SDKMAN Installation
SDKMAN SHALL be installed before SDKs are installed, and only on machines with the `dev` tag.

#### Scenario: SDKMAN installation with dev tag
- **WHEN** chezmoi applies configuration with the `dev` tag selected
- **THEN** the system SHALL install SDKMAN via the official installer
- **AND** SHALL run at position 20 in the script execution order

#### Scenario: SDKMAN skipped without dev tag
- **WHEN** the `dev` tag is not selected
- **THEN** SDKMAN installation SHALL be skipped entirely

#### Scenario: SDKMAN already installed
- **WHEN** SDKMAN is already present on the system
- **THEN** the installation script SHALL skip reinstallation

### Requirement: SDK Definition
SDKs SHALL be defined within the `dev` tag in `home/.chezmoidata/packages.yaml` using the `sdkman` key.

#### Scenario: SDK organization structure
- **WHEN** SDKs are defined in `packages.yaml`
- **THEN** the YAML structure SHALL include `packages.darwin.dev.sdkman` with a list of SDK specifications

#### Scenario: SDK specification format
- **WHEN** an SDK is defined
- **THEN** it SHALL use the format: `"sdk-name version-identifier"`
- **EXAMPLE**: `"java 25-tem"`, `"java 8.0.462-zulu"`, `"liquibase"`

### Requirement: Tag-Based SDK Selection
SDK installation SHALL require the `dev` tag.

#### Scenario: Dev tag required
- **WHEN** SDKs are being installed
- **THEN** the `dev` tag MUST be selected
- **AND** the installation script SHALL skip execution if `dev` tag is not present

#### Scenario: Development SDK category
- **WHEN** SDKs are listed under `packages.darwin.dev.sdkman`
- **THEN** they SHALL be installed when the `dev` tag is selected

### Requirement: SDK Installation Script
SDKs SHALL be installed via a `run_onchange_before` script at position 24.

#### Scenario: SDK installation execution
- **WHEN** the SDK installation script runs with `dev` tag
- **THEN** it SHALL execute `sdk install <sdk> <version>` for each defined SDK
- **AND** SHALL re-run whenever the script content or `packages.yaml` changes

#### Scenario: SDK installation idempotency
- **WHEN** an SDK version is already installed
- **THEN** `sdk install` SHALL skip reinstallation
- **AND** SHALL display that the SDK is already installed

### Requirement: SDKMAN Shell Integration
SDKMAN SHALL be initialized in shell profiles to make SDKs available in interactive sessions.

#### Scenario: Shell profile initialization
- **WHEN** a shell profile (.bash_profile, .zshrc) is loaded
- **THEN** it SHALL source `~/.sdkman/bin/sdkman-init.sh` if it exists
- **AND** SHALL set `SDKMAN_DIR` environment variable

#### Scenario: Conditional shell integration
- **WHEN** the `dev` tag is not selected
- **THEN** SDKMAN initialization SHALL NOT be included in shell profiles

### Requirement: SDK Categories
SDKs SHALL be defined under the `dev` tag's `sdkman` key in `packages.yaml`.

#### Scenario: Java SDK versions
- **WHEN** multiple Java versions are needed
- **THEN** they SHALL be defined separately under `packages.darwin.dev.sdkman`
- **EXAMPLE**: `"java 25-tem"` and `"java 8.0.462-zulu"`

#### Scenario: Build tools
- **WHEN** JVM build tools are needed (Liquibase, Gradle, Maven)
- **THEN** they SHALL be placed under `packages.darwin.dev.sdkman` in `packages.yaml`

## Script Execution Order

### Requirement: Package Manager Installation Order
Package managers SHALL be installed before their respective packages, following the numbered script execution sequence.

#### Scenario: SDKMAN before SDKs
- **WHEN** scripts execute in order
- **THEN** SDKMAN installation (position 20) SHALL run before SDK installation (position 24)

#### Scenario: Homebrew before packages
- **WHEN** scripts execute in order
- **THEN** Homebrew installation (pre-hook) SHALL run before package installation (position 23)

#### Scenario: UV tool installation timing
- **WHEN** scripts execute in order
- **THEN** UV tool installation (position 25) runs before UV installation (position 30)
- **NOTE**: This assumes UV is available through another mechanism (e.g., Homebrew in packages.yaml)

### Requirement: Complete Installation Sequence
The complete package installation sequence SHALL follow this order:

#### Scenario: Full installation order
- **WHEN** chezmoi applies configuration
- **THEN** the installation sequence SHALL be:
  1. Position 20: Install SDKMAN (if `dev` tag)
  2. Position 23: Install Homebrew packages from packages.yaml
  3. Position 24: Install SDKs via SDKMAN (if `dev` tag)
  4. Position 25: Install tools via UV
  5. Position 26: Install additional machine-specific Homebrew packages
  6. Position 30: Install UV itself

## Design Decisions

### Three-Layer Package Management Rationale
Using three complementary package management systems provides ecosystem-specific optimization:

#### Homebrew (System Layer)
- **Purpose**: System packages, GUI applications, fonts, CLI utilities
- **Strengths**: Native macOS integration, wide package availability, cask support for applications
- **Dual approach**: Essential tag-based packages + machine-specific Brewfiles
- **Flexibility**: Users can add machine-specific packages without modifying the main repository

#### UV Tools (Python Ecosystem)
- **Purpose**: Python-based CLI tools and utilities
- **Strengths**: Fast, modern Python package manager; isolated tool installations
- **Pattern**: Tag-based selection with `core` always installed
- **Use cases**: AI tools (claude-monitor), shell utilities (zsh-llm-suggestions), Python dev tools

#### SDKMAN (JVM Ecosystem)
- **Purpose**: Java SDKs, build tools, and JVM-related packages
- **Strengths**: Version management for multiple Java installations, JVM ecosystem focus
- **Pattern**: Requires `dev` tag, platform-specific definitions
- **Use cases**: Multiple Java versions, Gradle, Maven, Liquibase, other JVM tools

### Ecosystem Separation Benefits
Separating package management by ecosystem provides:
- **Optimized tools**: Each package manager specializes in its ecosystem
- **Version isolation**: Multiple Java versions (SDKMAN), isolated Python tools (UV)
- **Reduced conflicts**: System packages don't interfere with language-specific tools
- **Clear responsibility**: Each layer has a well-defined purpose

### Tag-Based Installation
Using tags for package selection enables:
- Customized installations for different machine purposes (work vs. personal vs. development)
- Easy addition of new package categories
- Minimal setup reduces installation time and disk usage
- Clear categorization of package purposes

### Machine-Specific Brewfiles
Separate Brewfiles per machine allow:
- Machine-specific tools without cluttering the main package list
- User confirmation before installing potentially large or unwanted packages
- Easy experimentation with new tools on one machine
- Brewfile symlink enables manual `brew bundle` commands

### Static Data File
Making the package data file (`packages.yaml`) static ensures:
- Available before template engine runs
- Simple YAML editing without template syntax
- Clear separation between data and logic
- Easier for tools to parse and validate
- Single source of truth for all package definitions

### Script Execution Order Design
The numbered script execution order (20, 23, 24, 25, 26, 30) uses 10-point range grouping:
- **Categorical grouping**: Scripts in 20-29 range handle package management, 30-39 handle environment managers
- **Flexible spacing**: Within each range, scripts use 1-5 point spacing as needed (20, 23, 24, 25, 26)
- **Future expansion**: Gaps within ranges allow inserting new scripts without renumbering
- **Dependency management**: Package managers install before their packages
- **Predictable order**: Clear, documented sequence for troubleshooting

**Note on UV timing**: Position 25 (UV tools) runs before position 30 (UV installation). This implies UV must be available through another mechanism (e.g., installed via Homebrew in packages.yaml).

## Tag Reference

### Tag Usage Across Package Managers

This table shows which tags control package installation across all three package management systems:

| Tag | Homebrew | UV Tools | SDKMAN | Description |
|-----|----------|----------|--------|-------------|
| `core` | ✅ Always | ✅ Always | ❌ | Essential packages for basic system operation |
| `dev` | ✅ Optional | ✅ Optional | ✅ **Required** | Development tools, IDEs, language toolchains |
| `ai` | ✅ Optional | ✅ Optional | ❌ | AI/ML tools (Claude, Ollama, LM Studio) |
| `work` | ✅ Optional | ✅ Optional | ❌ | Enterprise/work tools (Teams, Workspaces) |
| `personal` | ✅ Optional | ✅ Optional | ❌ | Personal productivity (Syncthing, ChronoSync) |
| `datascience` | ✅ Optional | ✅ Optional | ❌ | Data analysis tools (R, RStudio, csvkit) |
| `mobile` | ✅ Optional | ✅ Optional | ❌ | VPN and network tools (Tunnelblick, WireGuard) |

### Tag Selection Behavior

#### Core Tag (Always Active)
- **Homebrew**: Core packages always installed
- **UV Tools**: Core tools always installed
- **SDKMAN**: Not applicable (requires `dev` tag)

#### Development Tag (dev)
- **Homebrew**: Installs development packages (Docker, IDEs, etc.)
- **UV Tools**: Installs development tools
- **SDKMAN**: **Required** - SDKMAN itself and all SDKs only install with `dev` tag

#### Other Tags (ai, work, personal, datascience, mobile)
- **Homebrew**: Each tag installs corresponding category packages
- **UV Tools**: Each tag installs corresponding category tools
- **SDKMAN**: Not used (only `dev` category exists)

### Data File Structure

#### packages.yaml (Unified Package Definition)
```yaml
packages:
  darwin:
    taps:
    - 'isen-ng/dotnet-sdk-versions'
    - 'buo/cask-upgrade'

    core:
      taps: [...]
      brews: [...]
      casks: [...]
      mas: [...]

    dev:
      taps: [...]
      brews: [...]
      casks: [...]
      mas: [...]
      sdkman:       # SDKMAN SDKs (only in dev tag)
      - "java 25-tem"
      - "java 8.0.462-zulu"
      - "liquibase"

    ai:
      taps: [...]
      brews: [...]
      casks: [...]
      uv:           # UV Python tools (can be in any tag)
      - "basic-memory"
      - "claude-monitor"
      - "git+https://github.com/org/repo@latest"

    # ... other tags (work, personal, datascience, mobile)
```

### Installation Scripts

| Script | Position | Frequency | Purpose |
|--------|----------|-----------|---------|
| `run_once_before_darwin-20-install-sdkman.sh.tmpl` | 20 | Once | Install SDKMAN (requires `dev` tag) |
| `run_onchange_before_darwin-23-install-packages.sh.tmpl` | 23 | On change | Install Homebrew packages from packages.yaml |
| `run_onchange_before_darwin-24-install-sdks.sh.tmpl` | 24 | On change | Install SDKs via SDKMAN from packages.yaml (requires `dev` tag) |
| `run_onchange_before_darwin-25-install-tools.sh.tmpl` | 25 | On change | Install UV tools from packages.yaml |
| `run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` | 26 | On change | Install machine-specific Homebrew packages |
| `run_once_before_darwin-30-install-uv.sh.tmpl` | 30 | Once | Install UV package manager |
