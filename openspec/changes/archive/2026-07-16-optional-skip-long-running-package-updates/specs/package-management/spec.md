## ADDED Requirements

### Requirement: Homebrew Layer Skip Gate
The Homebrew package installation scripts (`run_onchange_before_darwin-23-install-packages.sh.tmpl` and `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`) SHALL consult the shared package-update skip decision for the `homebrew` layer before performing any tap, install, or upgrade work.

#### Scenario: Homebrew layer skipped
- **WHEN** the shared skip decision indicates the `homebrew` layer should be skipped
- **THEN** the script SHALL emit a `print_message "skip"` message
- **AND** SHALL exit 0 without running `brew update`, `brew tap`, or `brew bundle`

#### Scenario: Homebrew layer not skipped
- **WHEN** the shared skip decision indicates the `homebrew` layer should run
- **THEN** the script SHALL proceed exactly as it does today

#### Scenario: Skip gate precedes the existing Brewfile confirmation prompt
- **WHEN** `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` runs
- **AND** the `homebrew` layer is marked skipped
- **THEN** the script SHALL exit before reaching its existing "Install additional packages from your brewfile? (y/N)" confirmation prompt

### Requirement: SDKMAN Layer Skip Gate
The SDKMAN scripts (`run_onchange_before_darwin-20-install-sdkman.sh.tmpl` and `run_onchange_before_darwin-24-install-sdks.sh.tmpl`) SHALL consult the shared package-update skip decision for the `sdkman` layer before installing SDKMAN itself or any SDK.

#### Scenario: SDKMAN layer skipped
- **WHEN** the shared skip decision indicates the `sdkman` layer should be skipped
- **THEN** the script SHALL emit a `print_message "skip"` message and exit 0
- **AND** SHALL NOT invoke the SDKMAN installer or `sdk install`

#### Scenario: SDKMAN layer not skipped
- **WHEN** the shared skip decision indicates the `sdkman` layer should run
- **THEN** the script SHALL proceed exactly as it does today, including the existing `dev`-tag gating

### Requirement: UV Layer Skip Gate
The UV scripts (`run_onchange_before_darwin-21-install-uv.sh.tmpl` and `run_onchange_before_darwin-25-install-tools.sh.tmpl`) SHALL consult the shared package-update skip decision for the `uv` layer before installing or upgrading `uv` itself or any UV tool.

#### Scenario: UV layer skipped
- **WHEN** the shared skip decision indicates the `uv` layer should be skipped
- **THEN** the script SHALL emit a `print_message "skip"` message and exit 0
- **AND** SHALL NOT invoke the UV installer or `uv tool install`

#### Scenario: UV layer not skipped
- **WHEN** the shared skip decision indicates the `uv` layer should run
- **THEN** the script SHALL proceed exactly as it does today

### Requirement: Bun Layer Skip Gate
The Bun global package installation script (`run_onchange_before_darwin-26-install-bun-packages.sh.tmpl`) SHALL consult the shared package-update skip decision for the `bun` layer before installing any package.

#### Scenario: Bun layer skipped
- **WHEN** the shared skip decision indicates the `bun` layer should be skipped
- **THEN** the script SHALL emit a `print_message "skip"` message and exit 0
- **AND** SHALL NOT invoke `bun install -g`

#### Scenario: Bun layer not skipped
- **WHEN** the shared skip decision indicates the `bun` layer should run
- **THEN** the script SHALL proceed exactly as it does today

### Requirement: Cargo Layer Skip Gate
The Cargo package installation script (`run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl`) SHALL consult the shared package-update skip decision for the `cargo` layer before installing any crate.

#### Scenario: Cargo layer skipped
- **WHEN** the shared skip decision indicates the `cargo` layer should be skipped
- **THEN** the script SHALL emit a `print_message "skip"` message and exit 0
- **AND** SHALL NOT invoke `cargo install`

#### Scenario: Cargo layer not skipped
- **WHEN** the shared skip decision indicates the `cargo` layer should run
- **THEN** the script SHALL proceed exactly as it does today, including the existing `dev`-tag requirement

### Requirement: Claude Skills/MCP/Plugins Layer Skip Gate
The Claude Code skills, MCP server, and plugins installation scripts (positions 37, 38, and 39) SHALL consult the shared package-update skip decision for the `claude` layer before installing or registering any skill, MCP server, or plugin.

#### Scenario: Claude layer skipped
- **WHEN** the shared skip decision indicates the `claude` layer should be skipped
- **THEN** each of the three scripts SHALL emit a `print_message "skip"` message and exit 0
- **AND** SHALL NOT install skills, register MCP servers, or install plugins

#### Scenario: Claude layer not skipped
- **WHEN** the shared skip decision indicates the `claude` layer should run
- **THEN** each script SHALL proceed exactly as it does today, including existing `ai`-tag gating

### Requirement: Skip Gates Do Not Affect Script Success Status
Exiting early due to a layer skip gate SHALL be treated as a successful script run by chezmoi, distinct from an actual failure.

#### Scenario: Skipped script still marked successful
- **WHEN** a script exits early because its layer is marked skipped
- **THEN** it SHALL exit with status 0
- **AND** chezmoi SHALL record the script as successfully run, not as failed
