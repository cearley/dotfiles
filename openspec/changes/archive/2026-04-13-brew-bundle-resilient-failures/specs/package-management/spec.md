## ADDED Requirements

### Requirement: Homebrew Bundle Partial Failure Resilience
The Homebrew package installation script SHALL continue installing successfully-downloadable packages even when one or more packages fail to download or install.

#### Scenario: Single package download failure
- **WHEN** `brew bundle` exits with a non-zero status because one package fails to download
- **THEN** the script SHALL NOT abort
- **AND** all packages that were successfully downloaded SHALL be installed
- **AND** the script SHALL emit a warning via `print_message "warning"` indicating partial failure

#### Scenario: Warning message on partial failure
- **WHEN** `brew bundle` exits with a non-zero status
- **THEN** the script SHALL display a warning message using `print_message "warning"`
- **AND** the message SHALL direct the user to run `chezmoi apply` again after resolving the issue

#### Scenario: Clean run is unaffected
- **WHEN** all packages download and install successfully
- **THEN** `brew bundle` exits with status 0
- **AND** no warning is emitted
- **AND** behavior is identical to the previous implementation
