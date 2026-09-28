# Spec Delta

## MODIFIED Requirements

### Requirement: Active-Tag-Aware Declared Set
The audit SHALL compute the "declared" set of packages using only the chezmoi tags that are active on the invoking machine. For Homebrew formulae, casks, and taps specifically, the declared set SHALL be the union of `packages.yaml`'s tag-gated entries and the machine-specific Brewfile's entries (the Brewfile that `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl` installs), since both are legitimate declaration sources for what the install scripts actually manage on this machine.

#### Scenario: Tags read from chezmoi config
- **WHEN** the audit script runs
- **THEN** it SHALL read the active tag list from `chezmoi data --format=json` (the `.tags` field)
- **AND** it SHALL NOT treat packages under inactive tags as declared

#### Scenario: Inactive-tag packages flagged as orphans
- **WHEN** a package is installed on the machine
- **AND** the package appears in `packages.yaml` only under a tag that is NOT in the active tag set
- **THEN** the audit SHALL list that package as an orphan

#### Scenario: Active-tag packages not flagged
- **WHEN** a package is installed on the machine
- **AND** the package appears under at least one active tag in `packages.yaml`
- **THEN** the audit SHALL NOT list it as an orphan

#### Scenario: Machine Brewfile entries are not reported as orphans
- **WHEN** a Homebrew formula, cask, or tap is declared only in the machine-specific Brewfile (not in `packages.yaml`)
- **AND** that Brewfile is the one installed for the invoking machine
- **THEN** the audit SHALL NOT report that package as an orphan
