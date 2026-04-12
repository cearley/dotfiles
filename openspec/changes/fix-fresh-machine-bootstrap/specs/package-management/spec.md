## MODIFIED Requirements

### Requirement: UV Installation
The `uv` package manager SHALL be installed before UV tools are installed.

#### Scenario: UV not present
- **WHEN** chezmoi applies configuration and `uv` is not installed
- **THEN** the system SHALL install `uv` via the official Astral.sh installer
- **AND** SHALL run at position 21 in the script execution order
- **AND** SHALL run before Homebrew package installation (position 23) and UV tool installation (position 25)

#### Scenario: UV already installed
- **WHEN** `uv` is already present on the system
- **THEN** the installation script SHALL skip reinstallation and self-update instead

### Requirement: Package Manager Installation Order
Package managers SHALL be installed before their respective packages, following the numbered script execution sequence.

#### Scenario: SDKMAN before SDKs
- **WHEN** scripts execute in order
- **THEN** SDKMAN installation (position 20) SHALL run before SDK installation (position 24)

#### Scenario: Homebrew before packages
- **WHEN** scripts execute in order
- **THEN** Homebrew installation (pre-hook) SHALL run before package installation (position 23)

#### Scenario: UV before UV tools
- **WHEN** scripts execute in order
- **THEN** UV installation (position 21) SHALL run before UV tool installation (position 25)

#### Scenario: Bun global package installation timing
- **WHEN** scripts execute in order
- **THEN** Bun global package installation (position 26) SHALL run after Homebrew package installation (position 23)
- **NOTE**: Bun is installed via Homebrew as a core brew (`oven-sh/bun/bun`)

#### Scenario: Machine-specific Brewfile always last in before-phase
- **WHEN** scripts execute in order
- **THEN** machine-specific Brewfile installation (position 28) SHALL be the last `run_onchange_before` script in the package management group (20-29)

#### Scenario: Cargo packages run after apply
- **WHEN** scripts execute in order
- **THEN** cargo package installation (position 27, `run_onchange_after`) SHALL run after chezmoi applies dotfiles
- **AND** SHALL run only when the `dev` tag is selected

### Requirement: Complete Installation Sequence
The complete package installation sequence SHALL follow this order:

#### Scenario: Full installation order
- **WHEN** chezmoi applies configuration
- **THEN** the installation sequence SHALL be:
  1. Position 20: Install SDKMAN (if `dev` tag)
  2. Position 21: Install UV package manager
  3. Position 23: Install Homebrew packages from packages.yaml
  4. Position 24: Install SDKs via SDKMAN (if `dev` tag)
  5. Position 25: Install tools via UV
  6. Position 26: Install global packages via Bun
  7. Position 28: Install additional machine-specific Homebrew packages
  8. Position 27 (after apply): Install Rust crates via Cargo (if `dev` tag)

## ADDED Requirements

### Requirement: Brew Bundle Failure Propagation
The Homebrew package installation script SHALL exit with a non-zero status when `brew bundle` fails, so chezmoi treats the script as failed and does not mark it as successfully completed.

#### Scenario: brew bundle exits non-zero
- **WHEN** `brew bundle` fails due to an invalid or unavailable package
- **THEN** the install-packages script SHALL exit with the same non-zero exit code
- **AND** chezmoi SHALL NOT mark the script as successfully run
- **AND** the failure SHALL be visible to the user via `print_message "error"`

#### Scenario: brew bundle succeeds
- **WHEN** `brew bundle` exits with code 0
- **THEN** the script SHALL continue normally and exit 0

### Requirement: Valid Cask References
All cask identifiers in `packages.yaml` SHALL reference casks that exist in the configured taps.

#### Scenario: Invalid cask removed
- **WHEN** a cask identifier does not exist in any configured Homebrew tap
- **THEN** it SHALL be removed from `packages.yaml`
- **AND** a valid alternative identifier SHALL be substituted if one exists

#### Scenario: dotnet-sdk10 replaces dotnet-sdk10-0-200
- **WHEN** the `dev` tag packages are installed
- **THEN** `dotnet-sdk10` SHALL be the only .NET 10 cask installed
- **AND** `dotnet-sdk10-0-200` SHALL NOT appear in the cask list
