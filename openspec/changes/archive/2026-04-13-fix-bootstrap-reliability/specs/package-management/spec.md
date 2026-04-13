## MODIFIED Requirements

### Requirement: Homebrew Bootstrap
Homebrew itself SHALL be installed via `remote_install.sh` if not already present. Detection SHALL use the absolute path `$HOMEBREW_PREFIX/bin/brew` rather than `command -v brew`, so the check is PATH-independent. The final `exec` to chezmoi SHALL also use an absolute path.

#### Scenario: Homebrew missing — first run
- **WHEN** `remote_install.sh` runs and `/opt/homebrew/bin/brew` (ARM) or `/usr/local/bin/brew` (Intel) does not exist
- **THEN** the script SHALL install Homebrew via the official installer
- **AND** SHALL add `eval "$(brew shellenv)"` to `~/.zprofile`

#### Scenario: Homebrew exists — repeated run
- **WHEN** `remote_install.sh` is invoked again in the same terminal session (before restarting the shell)
- **THEN** `test -x "$HOMEBREW_PREFIX/bin/brew"` SHALL succeed
- **AND** the script SHALL skip Homebrew installation entirely without re-running the installer

#### Scenario: chezmoi invocation uses absolute path
- **WHEN** `remote_install.sh` reaches the final exec
- **THEN** it SHALL exec `$HOMEBREW_PREFIX/bin/chezmoi` rather than relying on PATH resolution
- **AND** SHALL pass all arguments through unmodified

### Requirement: SDKMAN Installation
SDKMAN SHALL be installed before SDKs are installed, and only on machines with the `dev` tag. Because macOS ships Bash 3.2 and SDKMAN's installer requires Bash 4+, a modern Bash SHALL be provisioned inline before invoking the SDKMAN installer.

#### Scenario: SDKMAN installation with dev tag
- **WHEN** chezmoi applies configuration with the `dev` tag selected
- **THEN** the system SHALL install SDKMAN via the official installer
- **AND** SHALL run at position 20 in the script execution order

#### Scenario: Modern bash provisioned before SDKMAN installer
- **WHEN** the SDKMAN install script runs on a fresh macOS machine
- **AND** `/opt/homebrew/bin/bash` does not exist
- **THEN** the script SHALL run `brew install bash` before invoking the SDKMAN installer
- **AND** SHALL pipe the SDKMAN installer to `/opt/homebrew/bin/bash`

#### Scenario: Modern bash already present
- **WHEN** `/opt/homebrew/bin/bash` already exists
- **THEN** the script SHALL skip `brew install bash`
- **AND** SHALL pipe the SDKMAN installer to `/opt/homebrew/bin/bash`

#### Scenario: SDKMAN skipped without dev tag
- **WHEN** the `dev` tag is not selected
- **THEN** SDKMAN installation SHALL be skipped entirely

#### Scenario: SDKMAN already installed
- **WHEN** SDKMAN is already present on the system
- **THEN** the installation script SHALL skip reinstallation
