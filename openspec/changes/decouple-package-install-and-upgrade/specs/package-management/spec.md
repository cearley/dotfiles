# Spec Delta

## MODIFIED Requirements

### Requirement: User Confirmation for Additional Packages
Only upgrading a package that is already installed but outdated requires explicit user confirmation. Installing a package that is currently missing SHALL proceed unconditionally and silently in both `run_onchange_before_darwin-23-install-packages.sh.tmpl` and `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, regardless of package type. Each script SHALL gate its own single combined upgrade prompt on the result of a `brew bundle check` run against its full declared package set after missing-item installation completes, not on whether any package category is non-empty.

#### Scenario: Confirmation prompt for core casks
- **WHEN** `packages.yaml` resolves one or more cask entries for the active tag set
- **THEN** the script SHALL install them via `brew bundle install --no-upgrade` without displaying a dedicated cask confirmation prompt
- **AND** any such cask found outdated (already installed, not current) by the combined `brew bundle check` SHALL be covered only by darwin-23's single combined upgrade prompt, shared with taps, formulae, and mas — not an independent cask-only prompt
- **AND** WHEN that combined check instead passes (nothing in any category outdated) THEN no prompt SHALL be displayed at all

#### Scenario: Confirmation prompt for core mas
- **WHEN** `packages.yaml` resolves one or more `mas` entries for the active tag set (and the user is signed into iCloud)
- **THEN** the script SHALL install them via `brew bundle install --no-upgrade` without displaying a dedicated `mas` confirmation prompt
- **AND** any such `mas` entry found outdated by the combined `brew bundle check` SHALL be covered only by darwin-23's single combined upgrade prompt, shared with taps, formulae, and casks — not an independent mas-only prompt

#### Scenario: Confirmation prompt
- **WHEN** a machine-specific Brewfile contains entries that are not yet installed
- **THEN** the script SHALL install them via `brew bundle install --no-upgrade` without prompting
- **AND** SHALL prompt the user for confirmation, via its own single prompt independent of darwin-23's prompt, only when a subsequent `brew bundle check` against that Brewfile finds something already-installed but outdated

#### Scenario: Confirmation denied
- **WHEN** the user declines a script's upgrade confirmation prompt
- **THEN** the script SHALL skip only the upgrade step
- **AND** SHALL continue with other setup tasks
- **AND** SHALL exit 0 so chezmoi records the script as successfully run, not as failed

#### Scenario: Confirmation accepted
- **WHEN** the user confirms a script's upgrade confirmation prompt
- **THEN** the script SHALL run `brew bundle install --upgrade` against that script's full declared set

#### Scenario: No cask packages to install
- **WHEN** the resolved cask bundle for the active tag set is empty
- **THEN** the script SHALL skip the cask install step silently, without attempting a `brew bundle` invocation
- **AND** that empty bundle SHALL contribute nothing to the combined upgrade check

#### Scenario: No mas packages to install
- **WHEN** the resolved `mas` bundle for the active tag set is empty (including when excluded because the user is not signed into iCloud)
- **THEN** the script SHALL skip the `mas` install step silently, without attempting a `brew bundle` invocation
- **AND** that empty bundle SHALL contribute nothing to the combined upgrade check

#### Scenario: Confirmation prompts are asked fresh every run
- **WHEN** a script runs on a subsequent `chezmoi apply` invocation
- **THEN** it SHALL display its upgrade confirmation prompt again if `brew bundle check` still fails at that point
- **AND** SHALL NOT read or write any cached decision from a previous run

#### Scenario: No TTY attached
- **WHEN** stdin is not a TTY when a script reaches its upgrade confirmation prompt
- **THEN** `read` SHALL return an empty reply immediately
- **AND** the script SHALL treat that as a decline and skip the upgrade step
- **AND** SHALL NOT hang waiting for input

### Requirement: Homebrew Core Bundle Split
`run_onchange_before_darwin-23-install-packages.sh.tmpl` SHALL install taps, formulae (`brews`), casks, and `mas` packages via separate `brew bundle install --no-upgrade` invocations — taps+formulae unconditionally, casks only when the active tag set declares any, `mas` only when declared and the user is signed into iCloud — none of them gated by a confirmation prompt. After those complete, it SHALL run one combined `brew bundle check` across everything declared, and conditionally one combined `brew bundle install --upgrade` across the same set, gated by the prompt defined in "User Confirmation for Additional Packages".

#### Scenario: Three independent bundle invocations
- **WHEN** the script resolves taps, brews, casks, and mas entries for the active tag set
- **THEN** it SHALL run one `brew bundle install --no-upgrade` invocation containing only tap and brew entries, unconditionally
- **AND** SHALL run a second `brew bundle install --no-upgrade` invocation containing only cask entries, when the cask bundle is non-empty
- **AND** SHALL run a third `brew bundle install --no-upgrade` invocation containing only `mas` entries, when the mas bundle is non-empty and the user is signed into iCloud
- **AND** none of these three invocations SHALL be gated by a confirmation prompt

#### Scenario: Pre-tap step still precedes all three bundles
- **WHEN** the script's existing pre-tap loop runs
- **THEN** it SHALL continue to run before every `brew bundle` invocation — the three missing-item installs, the combined check, and the conditional combined upgrade — so taps are registered before any of them checks or installs casks from those taps

#### Scenario: iCloud gating still applies to the mas bundle
- **WHEN** the user is not signed into iCloud
- **THEN** mas entries SHALL continue to be excluded from the generated bundle content via the existing `$icloudSignedIn` gating, across the missing-item install, the combined check, and the conditional combined upgrade alike

#### Scenario: Each bundle's partial failure is independent
- **WHEN** one of the script's `brew bundle` invocations (the three missing-item installs or the conditional combined upgrade) exits non-zero
- **THEN** the script SHALL emit a warning scoped to that invocation only
- **AND** SHALL NOT affect whether the other invocations run or how their outcomes are reported
- **AND** the combined `brew bundle check` exiting non-zero SHALL NOT itself be treated as a failure — that exit code only signals that the upgrade prompt should be shown

#### Scenario: Combined check runs after missing-item installs
- **WHEN** the script's missing-item install steps (taps+brews, casks, mas) have all completed
- **THEN** the script SHALL run one `brew bundle check --verbose` across the full combined declared set (taps+brews+casks+mas) before deciding whether to display the upgrade confirmation prompt

### Requirement: Idempotent Package Installation
Package installation SHALL be idempotent and safe to re-run.

#### Scenario: Already installed package
- **WHEN** a package is already installed
- **THEN** `brew install` SHALL skip reinstallation
- **AND** SHALL display that the package is already installed

#### Scenario: Package updates
- **WHEN** a package declared in `packages.yaml` or a machine-specific Brewfile is already installed but outdated
- **THEN** it SHALL NOT be upgraded automatically as a side effect of installing missing packages
- **AND** SHALL only be upgraded after its script's combined upgrade confirmation prompt (defined in "User Confirmation for Additional Packages") is accepted
