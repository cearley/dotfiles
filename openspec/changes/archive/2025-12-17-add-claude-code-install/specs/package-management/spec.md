# Spec Delta: Package Management

## ADDED Requirements

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
