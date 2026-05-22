## ADDED Requirements

### Requirement: Personal Identity Constants Outside Repo
Personal identity values that would leak into a publicly checked-in repo (e.g., a user's reverse-DNS prefix) SHALL be sourced from the user's chezmoi config (`~/.config/chezmoi/chezmoi.toml`) rather than from `home/.chezmoidata/`.

#### Scenario: Reverse-DNS prefix prompt
- **WHEN** `home/.chezmoi.toml.tmpl` is rendered during `chezmoi init`
- **THEN** the user SHALL be prompted via `promptStringOnce` for a `reverse_dns` value
- **AND** the default SHALL be computed as `io.github.<gh_username>` where `<gh_username>` is the previously-prompted GitHub username

#### Scenario: Persistent across re-renders
- **WHEN** `chezmoi apply` re-runs after the initial init
- **THEN** `promptStringOnce` SHALL NOT re-prompt the user
- **AND** the previously-stored value SHALL be reused

#### Scenario: Available as template data
- **WHEN** any chezmoi template references `{{ .reverse_dns }}`
- **THEN** it SHALL resolve to the value stored in `~/.config/chezmoi/chezmoi.toml`
- **AND** SHALL NOT require additional template helper calls

#### Scenario: No leakage into checked-in files
- **WHEN** the user's reverse-DNS value is `software.craigearley`
- **THEN** the value SHALL exist only in the user-local chezmoi config file
- **AND** SHALL NOT appear as a literal string in `home/.chezmoidata/` or any other checked-in repo file
