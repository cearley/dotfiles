# Package Management System

## Purpose
The package management system provides a comprehensive three-layer approach for installing packages across different ecosystems:
- **Homebrew**: System packages, applications, and CLI tools (essential tag-based + machine-specific)
- **UV Tools**: Python-based CLI tools and utilities (tag-based)
- **SDKMAN**: JVM ecosystem SDKs and build tools (tag-based, requires `dev` tag)

## Requirements

### Requirement: Central Package Definition
Essential packages SHALL be defined in `home/.chezmoidata/packages.yaml` organized by platform and tag.

#### Scenario: Platform-based package organization
- **WHEN** packages are defined for the darwin platform
- **THEN** the YAML structure SHALL include `packages.darwin` with nested tag categories

#### Scenario: Tag-based package categories
- **WHEN** packages are categorized by tags (core, dev, ai, work, personal, datascience, mobile)
- **THEN** each tag SHALL contain separate lists for `taps`, `brews`, `casks`, and `mas` packages

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
UV tools SHALL be defined in `home/.chezmoidata/tools.yaml` organized by tag category.

#### Scenario: Tool organization structure
- **WHEN** tools are defined in `tools.yaml`
- **THEN** the YAML structure SHALL include `tools.<category>` with lists of tool specifications

#### Scenario: Tool specification formats
- **WHEN** a tool is defined
- **THEN** it SHALL use one of these formats:
  - Simple package name: `"package-name"`
  - Git repository: `"git+https://github.com/org/repo"`
  - Version-pinned: `"package-name==1.0.0"`

### Requirement: Tag-Based UV Tool Selection
UV tool installation SHALL be controlled by user-selected tags, with `core` tools always installed.

#### Scenario: Core tools always installed
- **WHEN** chezmoi applies configuration
- **THEN** tools in the `core` category SHALL be installed regardless of other selected tags

#### Scenario: Tag-conditional tools
- **WHEN** a user selects the `ai` tag
- **THEN** tools in the `ai` category SHALL be installed
- **AND** tools in unselected categories SHALL be skipped

#### Scenario: Multiple tool categories
- **WHEN** a user selects tags `core,dev,ai`
- **THEN** tools from all three categories SHALL be installed via `uv tool install`

### Requirement: UV Tool Installation Script
UV tools SHALL be installed via a `run_onchange_before` script at position 25.

#### Scenario: Tool installation execution
- **WHEN** the tool installation script runs
- **THEN** it SHALL execute `uv tool install <tool>` for each selected tool
- **AND** SHALL re-run whenever the script content or `tools.yaml` changes

#### Scenario: Tool installation idempotency
- **WHEN** a tool is already installed
- **THEN** `uv tool install` SHALL skip reinstallation or upgrade the tool
- **AND** SHALL continue with remaining tools

### Requirement: UV Tool Categories
UV tools SHALL be organized into the same logical categories as Homebrew packages.

#### Scenario: AI tool category
- **WHEN** a tool is AI-related (claude-monitor, zsh-llm-suggestions)
- **THEN** it SHALL be placed in the `ai` category in `tools.yaml`

#### Scenario: Development tool category
- **WHEN** a tool is development-related (linters, formatters, build tools)
- **THEN** it SHALL be placed in the `dev` category in `tools.yaml`

#### Scenario: Core tool category
- **WHEN** a tool is essential for basic operations
- **THEN** it SHALL be placed in the `core` category in `tools.yaml`

### Requirement: Static UV Tools Data File
The `tools.yaml` file SHALL be a static file, not a template.

#### Scenario: Pre-template availability
- **WHEN** chezmoi's template engine initializes
- **THEN** `tools.yaml` MUST exist and be parseable
- **AND** SHALL NOT require template processing

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
SDKs SHALL be defined in `home/.chezmoidata/sdks.yaml` organized by platform and category.

#### Scenario: Platform-based SDK organization
- **WHEN** SDKs are defined for macOS
- **THEN** the YAML structure SHALL include `sdks.darwin.<category>` with lists of SDK specifications

#### Scenario: SDK specification format
- **WHEN** an SDK is defined
- **THEN** it SHALL use the format: `"sdk-name version-identifier"`
- **EXAMPLE**: `"java 25-tem"`, `"java 8.0.462-zulu"`, `"liquibase"`

### Requirement: Tag-Based SDK Selection
SDK installation SHALL require the `dev` tag and support category-based selection.

#### Scenario: Dev tag required
- **WHEN** SDKs are being installed
- **THEN** the `dev` tag MUST be selected
- **AND** the installation script SHALL skip execution if `dev` tag is not present

#### Scenario: Development SDK category
- **WHEN** SDKs are in the `dev` category
- **THEN** they SHALL be installed when the `dev` tag is selected

### Requirement: SDK Installation Script
SDKs SHALL be installed via a `run_onchange_before` script at position 24.

#### Scenario: SDK installation execution
- **WHEN** the SDK installation script runs with `dev` tag
- **THEN** it SHALL execute `sdk install <sdk> <version>` for each defined SDK
- **AND** SHALL re-run whenever the script content or `sdks.yaml` changes

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
SDKs SHALL be organized into logical categories, currently only `dev` is used.

#### Scenario: Java SDK versions
- **WHEN** multiple Java versions are needed
- **THEN** they SHALL be defined separately in the `dev` category
- **EXAMPLE**: `"java 25-tem"` and `"java 8.0.462-zulu"`

#### Scenario: Build tools
- **WHEN** JVM build tools are needed (Liquibase, Gradle, Maven)
- **THEN** they SHALL be placed in the `dev` category in `sdks.yaml`

### Requirement: Static SDK Data File
The `sdks.yaml` file SHALL be a static file, not a template.

#### Scenario: Pre-template availability
- **WHEN** chezmoi's template engine initializes
- **THEN** `sdks.yaml` MUST exist and be parseable
- **AND** SHALL NOT require template processing

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

### Static Data Files
Making package data files (`packages.yaml`, `tools.yaml`, `sdks.yaml`) static ensures:
- Available before template engine runs
- Simple YAML editing without template syntax
- Clear separation between data and logic
- Easier for tools to parse and validate
- Consistent pattern across all three package management layers

### Script Execution Order Design
The numbered script execution order (20, 23, 24, 25, 26, 30) with 5-point spacing provides:
- **Logical grouping**: Related operations are numerically close
- **Future expansion**: 5-point gaps allow inserting new scripts without renumbering
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

#### packages.yaml (Homebrew)
```yaml
packages:
  darwin:
    core:
      taps: [...]
      brews: [...]
      casks: [...]
      mas: [...]
    dev:
      taps: [...]
      # ... etc
```

#### tools.yaml (UV)
```yaml
tools:
  core:
    - "package-name"
  ai:
    - "claude-monitor"
    - "git+https://github.com/org/repo"
  # ... etc
```

#### sdks.yaml (SDKMAN)
```yaml
sdks:
  darwin:
    dev:
      - "java 25-tem"
      - "java 8.0.462-zulu"
      - "liquibase"
```

### Installation Scripts

| Script | Position | Frequency | Purpose |
|--------|----------|-----------|---------|
| `run_once_before_darwin-20-install-sdkman.sh.tmpl` | 20 | Once | Install SDKMAN (requires `dev` tag) |
| `run_onchange_before_darwin-23-install-packages.sh.tmpl` | 23 | On change | Install Homebrew packages from packages.yaml |
| `run_onchange_before_darwin-24-install-sdks.sh.tmpl` | 24 | On change | Install SDKs via SDKMAN (requires `dev` tag) |
| `run_onchange_before_darwin-25-install-tools.sh.tmpl` | 25 | On change | Install UV tools from tools.yaml |
| `run_onchange_before_darwin-26-brew-bundle-install.sh.tmpl` | 26 | On change | Install machine-specific Homebrew packages |
| `run_once_before_darwin-30-install-uv.sh.tmpl` | 30 | Once | Install UV package manager |
