## MODIFIED Requirements

### Requirement: Central Package Definition
All packages SHALL be defined in `home/.chezmoidata/packages.yaml` organized by platform and tag.

#### Scenario: Platform-based package organization
- **WHEN** packages are defined for the darwin platform
- **THEN** the YAML structure SHALL include `packages.darwin` with nested tag categories

#### Scenario: Tag-based package categories
- **WHEN** packages are categorized by tags (core, dev, ai, work, personal, datascience, mobile)
- **THEN** each tag SHALL contain separate lists for `taps`, `brews`, `casks`, `mas`, `sdkman`, `uv`, and `bun` packages

## ADDED Requirements

### Requirement: Bun Global Package Definition
Bun global packages SHALL be defined within tag categories in `home/.chezmoidata/packages.yaml` using the `bun` key.

#### Scenario: Package organization structure
- **WHEN** bun packages are defined in `packages.yaml`
- **THEN** the YAML structure SHALL include `packages.darwin.<tag>.bun` with lists of package names

#### Scenario: Package specification format
- **WHEN** a bun package is defined
- **THEN** it SHALL use a simple package name format: `"package-name"`

### Requirement: Tag-Based Bun Package Selection
Bun global package installation SHALL be controlled by user-selected tags.

#### Scenario: Tag-conditional packages
- **WHEN** a user selects the `ai` tag
- **THEN** packages in the `ai` tag's `bun` list SHALL be installed
- **AND** packages in unselected tag categories SHALL be skipped

#### Scenario: Multiple package categories
- **WHEN** a user selects tags `core,dev,ai`
- **THEN** bun packages from all three tag categories SHALL be installed via `bun install -g`

### Requirement: Bun Global Package Installation Script
Bun global packages SHALL be installed via a `run_onchange_before` script at position 26.

#### Scenario: Package installation execution
- **WHEN** the bun package installation script runs
- **THEN** it SHALL execute `bun install -g <package>` for each selected package
- **AND** SHALL re-run whenever the script content or `packages.yaml` changes

#### Scenario: Package installation idempotency
- **WHEN** a package is already installed globally
- **THEN** `bun install -g` SHALL skip reinstallation or upgrade the package
- **AND** SHALL continue with remaining packages

#### Scenario: Bun availability
- **WHEN** the bun package installation script runs
- **THEN** bun SHALL already be available via Homebrew (installed at position 23 as a core brew)
- **AND** the script SHALL validate bun is present using `require_tools`

### Requirement: Bun Package Categories
Bun packages SHALL be organized within the same tag categories as other package types in `packages.yaml`.

#### Scenario: AI package category
- **WHEN** a package is AI-related (ralph-tui)
- **THEN** it SHALL be placed under the `ai` tag's `bun` list in `packages.yaml`

#### Scenario: Development package category
- **WHEN** a package is development-related
- **THEN** it SHALL be placed under the `dev` tag's `bun` list in `packages.yaml`

#### Scenario: Core package category
- **WHEN** a package is essential for basic operations
- **THEN** it SHALL be placed under the `core` tag's `bun` list in `packages.yaml`

## MODIFIED Requirements

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

#### Scenario: Bun global package installation timing
- **WHEN** scripts execute in order
- **THEN** Bun global package installation (position 26) SHALL run after Homebrew package installation (position 23)
- **NOTE**: Bun is installed via Homebrew as a core brew (`oven-sh/bun/bun`)

#### Scenario: Machine-specific Brewfile always last
- **WHEN** scripts execute in order
- **THEN** machine-specific Brewfile installation (position 28) SHALL be the last script in the package management group (20-29)

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
