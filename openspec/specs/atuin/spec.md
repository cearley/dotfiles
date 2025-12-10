# Atuin Shell History Sync

## Purpose
The Atuin integration provides encrypted shell history synchronization across machines using the Atuin cloud service, with credentials managed through KeePassXC.

## Requirements

### Requirement: Atuin Installation
Atuin SHALL be installed as a core package via Homebrew.

#### Scenario: Package installation
- **WHEN** Homebrew packages are installed from packages.yaml
- **THEN** the `atuin` package SHALL be included in the core tag
- **AND** SHALL be available in PATH after installation

### Requirement: Atuin Login Script
The system SHALL automatically log in to Atuin sync on machines with KeePassXC database access.

#### Scenario: Automatic login on first apply
- **WHEN** chezmoi applies configuration and `atuin` is installed
- **THEN** the script at position 83 SHALL execute
- **AND** SHALL retrieve credentials from KeePassXC entry "atuin"
- **AND** SHALL log in to Atuin sync service

#### Scenario: Skip when KeePassXC unavailable
- **WHEN** the `has_keepassxc_db` flag is false
- **THEN** the Atuin login script SHALL NOT be executed
- **AND** SHALL be skipped via template conditional

### Requirement: Atuin Credentials Management
Atuin credentials SHALL be retrieved from KeePassXC at login time.

#### Scenario: Retrieve username and password
- **WHEN** the login script executes
- **THEN** it SHALL retrieve username from KeePassXC entry "atuin" UserName field
- **AND** SHALL retrieve password from KeePassXC entry "atuin" Password field
- **AND** SHALL retrieve encryption key from KeePassXC entry "atuin" "key" attribute

### Requirement: Atuin Session Validation
The system SHALL verify existing Atuin sessions before attempting login.

#### Scenario: Valid existing session
- **WHEN** a session file exists at `~/.local/share/atuin/session`
- **AND** `atuin doctor` confirms cloud sync is enabled
- **THEN** the script SHALL skip login
- **AND** SHALL display the last sync time if available

#### Scenario: Invalid session file
- **WHEN** a session file exists but `atuin doctor` indicates the session is invalid
- **THEN** the script SHALL attempt a fresh login

### Requirement: Atuin Store Rekeying
The system SHALL rekey the Atuin store if the encryption key changes.

#### Scenario: Key mismatch detected
- **WHEN** the current encryption key differs from the KeePassXC stored key
- **THEN** the script SHALL purge the local Atuin store
- **AND** SHALL rekey the store with the correct encryption key
- **AND** SHALL proceed with login

### Requirement: Initial Sync
After successful login, the system SHALL perform an initial sync.

#### Scenario: Sync after login
- **WHEN** Atuin login succeeds
- **THEN** the script SHALL execute `atuin sync`
- **AND** SHALL display success or warning messages

#### Scenario: Sync failure handling
- **WHEN** the initial sync fails
- **THEN** the script SHALL display a warning
- **AND** SHALL NOT fail the overall setup
- **AND** SHALL note that sync will retry automatically

### Requirement: Error Handling
Login failures SHALL be reported with actionable error messages.

#### Scenario: Login failure
- **WHEN** `atuin login` fails
- **THEN** the script SHALL exit with a non-zero status code
- **AND** SHALL display the error output
- **AND** SHALL provide instructions for manual login

### Requirement: Execution Order
The Atuin login script SHALL execute after core package installation.

#### Scenario: Script position
- **WHEN** scripts execute in order
- **THEN** the Atuin login script at position 83 SHALL run after Homebrew package installation (position 23)
- **AND** SHALL ensure `atuin` command is available

## Design Decisions

### KeePassXC Integration
Storing Atuin credentials in KeePassXC provides:
- Secure credential storage without committing secrets to git
- Consistent secret management pattern with other services
- Ability to rotate credentials by updating KeePassXC entry
- Automatic credential injection on all machines

### Session Validation Before Login
Checking existing sessions prevents:
- Unnecessary login attempts when already authenticated
- Potential rate limiting from repeated logins
- Disruption of existing sync state
- Wasted time during chezmoi apply

### Store Rekeying Strategy
Automatic rekeying ensures:
- Encryption key changes are applied seamlessly
- Local history can be re-encrypted with new key
- No manual intervention required
- Consistent encryption across machines

### Position 83 Execution Order
Placing the script at position 83 ensures:
- Atuin is already installed via Homebrew (position 23)
- User environment is mostly configured
- Other core tools are available
- Login happens late enough to avoid dependency issues
