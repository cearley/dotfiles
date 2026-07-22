## ADDED Requirements

### Requirement: Conda Shell Integration
Conda (installed via the `miniforge` cask under the `datascience` tag) SHALL be initialized in shell profiles only when the `datascience` tag is selected.

#### Scenario: Shell profile conda initialization
- **WHEN** the `datascience` tag is selected
- **THEN** `home/dot_zshrc.tmpl` SHALL initialize the Conda shell hook (source `conda.sh` or evaluate the `conda shell.zsh hook` output)

#### Scenario: Conditional shell integration
- **WHEN** the `datascience` tag is not selected
- **THEN** Conda initialization SHALL NOT be included in shell profiles
- **AND** this SHALL hold even when the `dev` tag is selected without `datascience`
