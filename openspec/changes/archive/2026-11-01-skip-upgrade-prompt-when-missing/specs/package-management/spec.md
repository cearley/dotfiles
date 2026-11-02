# Spec Delta

## MODIFIED Requirements

### Requirement: User Confirmation for Additional Packages
Installing a missing package declared in `packages.yaml` SHALL proceed unconditionally and silently in `run_onchange_before_darwin-23-install-packages.sh.tmpl`, regardless of package type. Installing a missing package declared in a machine-specific Brewfile SHALL require explicit user confirmation in `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`, gated on a missing-only `brew bundle check --no-upgrade` against that Brewfile. Upgrading a package that is already installed but outdated SHALL require explicit user confirmation in both scripts. Each script SHALL gate its upgrade prompt on a `brew bundle check` run against its full declared package set after the missing-item step completes, not on whether any package category is non-empty, and SHALL offer that prompt only when a `brew bundle check --no-upgrade` against the same set passes (nothing still missing).

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
- **THEN** darwin-28 SHALL print the missing entries reported by `brew bundle check --no-upgrade --verbose` and prompt the user to confirm installing them, via its own prompt independent of darwin-23
- **AND** SHALL run `brew bundle install --no-upgrade` against that Brewfile only if the user confirms
- **AND** SHALL separately prompt for upgrade confirmation only when a subsequent `brew bundle check` against that Brewfile finds something already-installed but outdated

#### Scenario: Machine Brewfile install declined
- **WHEN** the user declines darwin-28's missing-package install prompt, or stdin is not a TTY
- **THEN** darwin-28 SHALL skip the missing-item install without invoking `brew bundle install`
- **AND** SHALL continue to the upgrade check

#### Scenario: Packages still missing after the install step
- **WHEN** a missing-only `brew bundle check --no-upgrade` still fails after the missing-item step, because an install failed or the user declined darwin-28's install prompt
- **THEN** the script SHALL skip the upgrade prompt and print a `print_message "skip"` notice that packages are still missing
- **AND** SHALL NOT describe the still-missing packages as having updates available

#### Scenario: Confirmation denied
- **WHEN** the user declines a script's confirmation prompt
- **THEN** the script SHALL skip only the step that prompt gated
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
- **THEN** it SHALL display its confirmation prompts again if the corresponding `brew bundle check` still fails at that point
- **AND** SHALL NOT read or write any cached decision from a previous run

#### Scenario: No TTY attached
- **WHEN** stdin is not a TTY when a script reaches any of its confirmation prompts
- **THEN** `read` SHALL return an empty reply immediately
- **AND** the script SHALL treat that as a decline and skip the step that prompt gated
- **AND** SHALL NOT hang waiting for input
