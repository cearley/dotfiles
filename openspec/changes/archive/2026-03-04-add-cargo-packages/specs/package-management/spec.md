## ADDED Requirements

### Requirement: Cargo Package Definition
Cargo packages SHALL be defined within tag categories in `home/.chezmoidata/packages.yaml` using the `cargo` key.

#### Scenario: Package organization structure
- **WHEN** cargo packages are defined in `packages.yaml`
- **THEN** the YAML structure SHALL include `packages.darwin.<tag>.cargo` with lists of install specifications

#### Scenario: Package specification format — crates.io
- **WHEN** a cargo package from crates.io is defined
- **THEN** it SHALL use a bare package name: `"ripgrep"`

#### Scenario: Package specification format — git source
- **WHEN** a cargo package is sourced from a git repository
- **THEN** it SHALL use the full flag string: `"--git https://github.com/org/repo.git"`

### Requirement: Tag-Based Cargo Package Selection
Cargo package installation SHALL be controlled by user-selected tags, with `dev` as a hard prerequisite.

#### Scenario: Dev tag required for any cargo installation
- **WHEN** the `dev` tag is NOT selected
- **THEN** the cargo package installation script SHALL skip execution entirely
- **AND** no `cargo install` commands SHALL run

#### Scenario: Tag-conditional packages
- **WHEN** the `dev` tag is selected and the `ai` tag is also selected
- **THEN** packages in the `ai` tag's `cargo` list SHALL be installed
- **AND** packages in unselected tag categories SHALL be skipped

#### Scenario: Multiple cargo package categories
- **WHEN** a user selects tags `dev,ai,work`
- **THEN** cargo packages from both `ai` and `work` tag categories SHALL be installed
- **AND** packages from unselected categories SHALL be skipped

### Requirement: Cargo Package Installation Script
Cargo packages SHALL be installed via a `run_onchange_after` script at position 27.

#### Scenario: Script execution timing
- **WHEN** chezmoi applies configuration
- **THEN** cargo package installation SHALL run AFTER dotfiles are applied (run_onchange_after)
- **AND** SHALL execute at position 27, between Bun packages (26) and machine-specific Brewfile (28)

#### Scenario: Cargo environment initialization
- **WHEN** the cargo installation script runs
- **THEN** it SHALL source `~/.cargo/env` before invoking any `cargo` commands
- **AND** SHALL ensure the `cargo` binary is on PATH

#### Scenario: Package installation execution
- **WHEN** the cargo installation script runs with eligible packages
- **THEN** it SHALL execute `cargo install <spec>` for each selected package
- **AND** SHALL re-run whenever the script content or `packages.yaml` changes

#### Scenario: Cargo availability check
- **WHEN** the cargo installation script runs
- **THEN** it SHALL validate `cargo` is available using `require_tools cargo`
- **AND** SHALL exit cleanly with an error message if `cargo` is not found

#### Scenario: Package installation idempotency
- **WHEN** a cargo package is already installed at the current version
- **THEN** `cargo install` SHALL report already-installed status
- **AND** SHALL continue with remaining packages without error

### Requirement: Cargo Package Categories
Cargo packages SHALL be organized within the same tag categories as other package types in `packages.yaml`.

#### Scenario: AI package category
- **WHEN** a package is AI-workflow-related (e.g., beads_rust)
- **THEN** it SHALL be placed under the `ai` tag's `cargo` list in `packages.yaml`

#### Scenario: Development package category
- **WHEN** a package is a Rust development tool
- **THEN** it SHALL be placed under the `dev` tag's `cargo` list in `packages.yaml`

## MODIFIED Requirements

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

#### Scenario: Cargo packages require dev tag
- **WHEN** a user does NOT select the `dev` tag
- **THEN** NO cargo packages SHALL be installed, regardless of other selected tags
- **AND** this applies even if other tags (e.g., `ai`) are selected

### Requirement: Complete Installation Sequence
The complete package installation sequence SHALL follow this order:

#### Scenario: Full installation order
- **WHEN** chezmoi applies configuration
- **THEN** the installation sequence SHALL be:
  1. Position 20: Install SDKMAN (if `dev` tag)
  2. Position 23: Install Homebrew packages from packages.yaml
  3. Position 24: Install SDKs via SDKMAN (if `dev` tag)
  4. Position 25: Install tools via UV
  5. Position 26: Install global packages via Bun
  6. Position 28: Install additional machine-specific Homebrew packages
  7. Position 30: Install UV itself
  8. Position 27 (after apply): Install Rust crates via Cargo (if `dev` tag)
