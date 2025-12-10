# Script Execution System

## Purpose
The script execution system provides structured, ordered execution of setup and maintenance scripts for macOS environment bootstrapping and updates.

## Requirements

### Requirement: Script Naming Convention
Scripts in `home/.chezmoiscripts/` SHALL follow the naming pattern: `{frequency}_{timing}_{os}-{order}-{description}.sh.tmpl`

#### Scenario: Script name parsing
- **WHEN** a script is named `run_once_before_darwin-10-install-rust.sh.tmpl`
- **THEN** chezmoi SHALL execute it once, before applying dotfiles, on darwin (macOS) systems, with execution order 10

#### Scenario: Invalid script name
- **WHEN** a script does not follow the naming convention
- **THEN** the script SHALL be ignored by chezmoi's automatic execution system

### Requirement: Execution Frequency Control
Scripts SHALL support two frequency modes: `run_once_` for initialization tasks and `run_onchange_` for maintenance tasks.

#### Scenario: Run-once initialization
- **WHEN** a script is prefixed with `run_once_`
- **THEN** the script SHALL execute only on the first chezmoi apply
- **AND** SHALL NOT execute on subsequent applies unless state is reset

#### Scenario: Run-onchange maintenance
- **WHEN** a script is prefixed with `run_onchange_`
- **THEN** the script SHALL execute whenever its content hash changes
- **AND** SHALL re-execute after modifications to the script

### Requirement: Execution Timing
Scripts SHALL execute either before or after dotfile application based on timing prefix.

#### Scenario: Before-timing execution
- **WHEN** a script includes `_before_` in its name
- **THEN** the script SHALL execute before chezmoi applies dotfiles to the target directory

#### Scenario: After-timing execution
- **WHEN** a script includes `_after_` in its name
- **THEN** the script SHALL execute after chezmoi applies dotfiles to the target directory

### Requirement: Platform Targeting
Scripts SHALL be conditionally executed based on operating system using template guards.

#### Scenario: Darwin platform script
- **WHEN** a script is wrapped in `{{- if eq .chezmoi.os "darwin" -}}`
- **THEN** the script SHALL only execute on macOS systems
- **AND** SHALL be skipped on other operating systems

#### Scenario: Missing platform guard
- **WHEN** a darwin-targeted script lacks the platform conditional template
- **THEN** the script MAY fail on non-macOS systems

### Requirement: Execution Order
Scripts SHALL execute in ascending numerical order defined by the order component.

#### Scenario: Sequential execution
- **WHEN** multiple scripts exist with orders 05, 10, 15, 20
- **THEN** scripts SHALL execute in numerical order: 05 → 10 → 15 → 20

#### Scenario: Same execution order
- **WHEN** multiple scripts have the same order number
- **THEN** execution order between those scripts is undefined but deterministic

### Requirement: Execution Order Categories
Scripts SHALL use 5-point spacing for logical grouping of related operations.

#### Scenario: System foundation stage (00-09)
- **WHEN** scripts are numbered 00-09
- **THEN** they SHALL handle system-level foundations like Rosetta 2 installation

#### Scenario: Development toolchains stage (10-19)
- **WHEN** scripts are numbered 10-19
- **THEN** they SHALL handle language runtime installations (Rust, Java/JVM)

#### Scenario: Package management stage (20-29)
- **WHEN** scripts are numbered 20-29
- **THEN** they SHALL handle package manager installations and Homebrew bundles

#### Scenario: Environment managers stage (30-39)
- **WHEN** scripts are numbered 30-39
- **THEN** they SHALL handle language-specific environment managers (uv, nvm)

#### Scenario: Environment setup stage (40-49)
- **WHEN** scripts are numbered 40-49
- **THEN** they SHALL handle authentication, conda initialization, and shell plugins

#### Scenario: System configuration stage (80-99)
- **WHEN** scripts are numbered 80-99
- **THEN** they SHALL handle security setup, VPN configuration, authentication services, system defaults, and validation

### Requirement: Script Templates
All scripts SHALL be templates (`.tmpl` suffix) to enable dynamic configuration.

#### Scenario: Template variable access
- **WHEN** a script uses `{{ .chezmoi.os }}` or `{{ .chezmoi.arch }}`
- **THEN** chezmoi SHALL substitute the appropriate runtime values during template execution

#### Scenario: Conditional script content
- **WHEN** a script uses `{{- if has "dev" .tags -}}`
- **THEN** the script content SHALL be conditionally included based on user-selected tags

### Requirement: Script Utilities Integration
Scripts SHALL source shared utilities for consistent functionality and messaging.

#### Scenario: Sourcing shared utilities
- **WHEN** a script includes `source "{{ .chezmoi.sourceDir -}}/scripts/shared-utils.sh"`
- **THEN** the script SHALL have access to `print_message()`, `command_exists()`, and other shared functions

#### Scenario: Consistent messaging
- **WHEN** a script calls `print_message "info" "Installing package"`
- **THEN** output SHALL use consistent emoji formatting (💡 for info)

### Requirement: Error Handling
Scripts SHALL handle errors gracefully and provide meaningful exit codes.

#### Scenario: Non-critical error continuation
- **WHEN** a script encounters a non-critical error
- **THEN** the script SHALL log a warning and continue execution

#### Scenario: Critical error termination
- **WHEN** a script encounters a critical error (e.g., missing prerequisites)
- **THEN** the script SHALL exit with a non-zero status code
- **AND** SHALL display an error message indicating the failure

### Requirement: Idempotency
Scripts SHALL be safe to re-run without causing unintended side effects.

#### Scenario: Already installed check
- **WHEN** a script checks if a tool is already installed
- **THEN** the script SHALL skip installation if the tool exists
- **AND** SHALL display a skip message

#### Scenario: Multiple executions
- **WHEN** a run_once script is executed multiple times (after state reset)
- **THEN** the script SHALL produce the same result without breaking the system

## Design Decisions

### 5-Point Spacing Rationale
The 5-point spacing system (05, 10, 15, 20, etc.) provides:
- Clear logical grouping of related scripts
- Room for future insertions between existing scripts
- Visual clarity in directory listings

### Current Script Inventory
The following scripts are currently implemented (as of baseline):

**System Foundation (00-09):**
- `05`: Install Rosetta 2 (Apple Silicon compatibility)

**Development Toolchains (10-19):**
- `10`: Install Rust (programming language runtime)

**Package Management (20-29):**
- `20`: Install SDKMAN (Java SDK manager)
- `23`: Brew bundle install essential packages from packages.yaml
- `24`: Install SDKs via SDKMAN
- `25`: Install UV tools from tools.yaml
- `26`: Brew bundle install machine-specific packages

**Environment Managers (30-39):**
- `30`: Install uv (Python package manager)
- `35`: Install nvm (Node Version Manager)

**Environment Setup (40-49):**
- `45`: Setup GitHub authentication (git, GHCR, GitHub CLI)

**System Configuration (80-99):**
- `80`: Setup Microsoft Defender (security configuration)
- `82`: Setup Global Protect VPN (work tag, manual installation)
- `83`: Login to Atuin shell history sync (requires KeePassXC)
- `85`: Configure system defaults (macOS preferences including iTerm2)
- `90`: Update hosts file (system-level modifications)
- `95`: Restart Syncthing (file synchronization service)
- `97`: Test SSH GitHub connectivity (system validation)

### Template-Based Scripts
All scripts are templates to enable:
- Platform-specific conditional logic
- Tag-based selective execution
- Access to chezmoi variables and functions
- Dynamic configuration based on machine state

### Separate Before/After Execution
Scripts can execute before or after dotfile application to:
- Install prerequisites before files are written (e.g., Homebrew)
- Configure applications after dotfiles are in place (e.g., system defaults)
- Ensure proper dependency ordering
