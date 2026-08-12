## MODIFIED Requirements

### Requirement: User Confirmation for Additional Packages
Homebrew cask and Mac App Store (`mas`) package installations SHALL require explicit user confirmation before installation. For the core package set (`run_onchange_before_darwin-23-install-packages.sh.tmpl`), casks and `mas` packages SHALL be confirmed via two independent prompts, so a user can choose either, both, or neither. For machine-specific Brewfile packages (`run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`), a single combined prompt SHALL gate the whole Brewfile, since its contents are not parsed by package type. Homebrew taps and formulae (`brews`) SHALL install unconditionally without prompting, in both scripts.

#### Scenario: Confirmation prompt for core casks
- **WHEN** `packages.yaml` resolves one or more cask entries for the active tag set
- **THEN** the script SHALL prompt the user for confirmation before running the cask `brew bundle` invocation
- **AND** tap and formula installation SHALL proceed without waiting for that confirmation
- **AND** this prompt SHALL be independent of any `mas` confirmation

#### Scenario: Confirmation prompt for core mas
- **WHEN** `packages.yaml` resolves one or more `mas` entries for the active tag set (and the user is signed into iCloud)
- **THEN** the script SHALL prompt the user for confirmation before running the `mas` `brew bundle` invocation
- **AND** tap and formula installation SHALL proceed without waiting for that confirmation
- **AND** this prompt SHALL be independent of any cask confirmation

#### Scenario: Confirmation prompt
- **WHEN** a machine-specific Brewfile contains additional packages
- **THEN** the script SHALL prompt the user for confirmation before running `brew bundle`

#### Scenario: Confirmation denied
- **WHEN** the user declines a cask, mas, or machine-specific installation prompt
- **THEN** the script SHALL skip only that declined installation, independent of any other prompt's answer
- **AND** SHALL continue with other setup tasks
- **AND** SHALL exit 0 so chezmoi records the script as successfully run, not as failed

#### Scenario: Confirmation accepted
- **WHEN** the user confirms a cask, mas, or machine-specific installation prompt
- **THEN** the script SHALL execute the corresponding `brew bundle` command for that prompt only

#### Scenario: No cask packages to install
- **WHEN** the resolved cask bundle for the active tag set is empty
- **THEN** the script SHALL NOT display the cask confirmation prompt
- **AND** SHALL skip the cask bundle step silently

#### Scenario: No mas packages to install
- **WHEN** the resolved `mas` bundle for the active tag set is empty (including when excluded because the user is not signed into iCloud)
- **THEN** the script SHALL NOT display the `mas` confirmation prompt
- **AND** SHALL skip the `mas` bundle step silently

#### Scenario: Confirmation prompts are asked fresh every run
- **WHEN** the script runs on a subsequent `chezmoi apply` invocation
- **THEN** it SHALL display each applicable confirmation prompt again if there is still corresponding work pending
- **AND** SHALL NOT read or write any cached decision from a previous run

#### Scenario: No TTY attached
- **WHEN** stdin is not a TTY when the script reaches a cask or mas confirmation prompt
- **THEN** `read` SHALL return an empty reply immediately
- **AND** the script SHALL treat that as a decline and skip that installation
- **AND** SHALL NOT hang waiting for input

## ADDED Requirements

### Requirement: Homebrew Core Bundle Split
`run_onchange_before_darwin-23-install-packages.sh.tmpl` SHALL install taps and formulae (`brews`) via a `brew bundle` invocation separate from casks, which SHALL in turn be separate from `mas` packages, so formula/tap installation is never gated by either confirmation prompt and a cask answer never affects `mas` installation or vice versa.

#### Scenario: Three independent bundle invocations
- **WHEN** the script resolves taps, brews, casks, and mas entries for the active tag set
- **THEN** it SHALL run one `brew bundle` invocation containing only tap and brew entries, unconditionally
- **AND** SHALL run a second `brew bundle` invocation containing only cask entries, gated by the cask confirmation prompt defined in "User Confirmation for Additional Packages"
- **AND** SHALL run a third `brew bundle` invocation containing only `mas` entries, gated by the independent `mas` confirmation prompt defined in "User Confirmation for Additional Packages"

#### Scenario: Pre-tap step still precedes all three bundles
- **WHEN** the script's existing pre-tap loop runs
- **THEN** it SHALL continue to run before all three bundle invocations, so taps are registered before any bundle checks casks from those taps

#### Scenario: iCloud gating still applies to the mas bundle
- **WHEN** the user is not signed into iCloud
- **THEN** mas entries SHALL continue to be excluded from the generated bundle content via the existing `$icloudSignedIn` gating, independent of the confirmation prompt (and the mas prompt itself is suppressed per "No mas packages to install")

#### Scenario: Each bundle's partial failure is independent
- **WHEN** one of the three `brew bundle` invocations exits non-zero
- **THEN** the script SHALL emit a warning scoped to that bundle only
- **AND** SHALL NOT affect whether the other two bundles run or how their outcomes are reported

## REMOVED Requirements

### Requirement: Homebrew Layer Skip Gate
**Reason**: Replaced by unconditional installation of taps/brews plus an ungated-but-confirmed cask/mas bundle (see "Homebrew Core Bundle Split" and "User Confirmation for Additional Packages"). The generic `homebrew` layer concept no longer exists.
**Migration**: None. Formula/tap installs now always run; cask/mas installs are confirmed fresh every run instead of via a cached layer decision.

### Requirement: SDKMAN Layer Skip Gate
**Reason**: SDKMAN/SDK installs are not expensive enough to warrant a skip mechanism; only Homebrew casks and `mas` installs are.
**Migration**: None. `run_onchange_before_darwin-20-install-sdkman.sh.tmpl` and `run_onchange_before_darwin-24-install-sdks.sh.tmpl` now run unconditionally (still gated by the existing `dev`-tag requirement) with no skip guard.

### Requirement: UV Layer Skip Gate
**Reason**: UV installs/tool installs are not expensive enough to warrant a skip mechanism.
**Migration**: None. `run_onchange_before_darwin-21-install-uv.sh.tmpl` and `run_onchange_before_darwin-25-install-tools.sh.tmpl` now run unconditionally with no skip guard.

### Requirement: Bun Layer Skip Gate
**Reason**: Bun global package installs are not expensive enough to warrant a skip mechanism.
**Migration**: None. `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl` now runs unconditionally with no skip guard.

### Requirement: Cargo Layer Skip Gate
**Reason**: Cargo installs are not expensive enough to warrant a skip mechanism.
**Migration**: None. `run_onchange_before_darwin-27-install-cargo-packages.sh.tmpl` now runs unconditionally (still gated by the existing `dev`-tag requirement) with no skip guard.

### Requirement: Claude Skills/MCP/Plugins Layer Skip Gate
**Reason**: Claude skills/MCP/plugin installs are not expensive enough to warrant a skip mechanism.
**Migration**: None. Positions 37, 38, and 39 now run unconditionally (still gated by the existing `ai`-tag requirement) with no skip guard.

### Requirement: Skip Gates Do Not Affect Script Success Status
**Reason**: This requirement described the generic multi-layer skip-gate exit contract, which no longer exists. Its one surviving concern — that declining the cask/mas confirmation exits 0, not as a failure — is now covered by "User Confirmation for Additional Packages" (Scenario: Confirmation denied).
**Migration**: None.
