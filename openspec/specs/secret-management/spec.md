# Secret Management System

## Purpose
The secret management system integrates with KeePassXC to provide secure credential storage and retrieval, eliminating hardcoded secrets from the repository.

## Requirements

### Requirement: KeePassXC Integration
The system SHALL integrate with KeePassXC for secret storage and retrieval via chezmoi template functions.

#### Scenario: Secret retrieval during template execution
- **WHEN** a template uses `keepassxcAttribute "entry-name" "attribute-name"`
- **THEN** chezmoi SHALL query KeePassXC for the specified attribute
- **AND** SHALL inject the secret value into the template

#### Scenario: KeePassXC unavailable
- **WHEN** KeePassXC is not running or accessible during template execution
- **THEN** templates SHOULD fail with an error indicating KeePassXC is required
- **OR** scripts MAY gracefully skip secret-dependent operations

### Requirement: No Hardcoded Secrets
The repository SHALL NOT contain any hardcoded secrets, credentials, or sensitive data.

#### Scenario: Git credential storage
- **WHEN** git configuration requires authentication tokens
- **THEN** tokens SHALL be retrieved from KeePassXC via templates
- **AND** SHALL NOT be committed to the repository

#### Scenario: SSH key passphrases
- **WHEN** SSH keys require passphrases
- **THEN** passphrases SHALL be stored in KeePassXC
- **AND** SHALL be retrieved during SSH configuration

#### Scenario: API tokens
- **WHEN** configuration files require API tokens (AWS, GitHub)
- **THEN** tokens SHALL be retrieved from KeePassXC entries
- **AND** SHALL be injected at template execution time

### Requirement: Machine-Specific KeePassXC Entries
The system SHALL support machine-specific KeePassXC entry names via the machine configuration system.

#### Scenario: SSH key entry mapping
- **WHEN** a machine configuration defines `keepassxc_entries.ssh: "SSH (MacBook Pro)"`
- **THEN** templates SHALL retrieve SSH credentials from the "SSH (MacBook Pro)" KeePassXC entry

#### Scenario: Shared KeePassXC database
- **WHEN** multiple machines share the same KeePassXC database
- **THEN** each machine MAY use different entry names for the same logical credential type
- **AND** SHALL map entry names via `machines.yaml` configuration

### Requirement: Template-Time Secret Injection
Secrets SHALL be injected during template execution, not stored in target files.

#### Scenario: Private file generation
- **WHEN** a template with `private_` prefix includes KeePassXC attributes
- **THEN** the resulting file SHALL contain the secret values
- **AND** SHALL be marked as private by chezmoi

#### Scenario: Secret file permissions
- **WHEN** chezmoi applies a file containing secrets
- **THEN** the file SHALL have restrictive permissions (typically 600 or 700)

### Requirement: Graceful Degradation
Scripts requiring secrets SHALL gracefully skip operations when secrets are unavailable.

#### Scenario: Optional secret-dependent feature
- **WHEN** a script requires a KeePassXC entry that doesn't exist
- **THEN** the script SHALL display a skip message
- **AND** SHALL continue with non-secret-dependent operations

#### Scenario: Required secret missing
- **WHEN** a critical operation requires a secret that's unavailable
- **THEN** the script SHALL exit with an error
- **AND** SHALL display instructions for configuring the required secret

### Requirement: KeePassXC Entry Naming Convention
KeePassXC entries SHALL follow a clear naming convention for easy identification.

#### Scenario: Machine-specific entries
- **WHEN** entries are specific to a machine
- **THEN** they SHALL include the machine identifier in the name (e.g., "SSH (MacBook Pro)")

#### Scenario: Service-specific entries
- **WHEN** entries are for external services
- **THEN** they SHALL be named after the service (e.g., "GitHub Token", "AWS Credentials")

### Requirement: Secure File Marking
Files containing secrets SHALL be prefixed with `private_` in the chezmoi source directory.

#### Scenario: Private file identification
- **WHEN** a file contains secrets retrieved from KeePassXC
- **THEN** the source file SHALL be named with `private_` prefix (e.g., `private_dot_aws_credentials.tmpl`)

#### Scenario: Private file exclusion
- **WHEN** sharing or backing up the chezmoi source directory
- **THEN** `private_` files SHALL be excluded or encrypted
- **AND** SHALL NOT be shared in plaintext

### Requirement: Bootstrap Dependency
KeePassXC SHALL be installed before secret-dependent operations execute.

#### Scenario: Pre-hook KeePassXC installation
- **WHEN** chezmoi's pre-hook runs
- **THEN** it SHALL verify KeePassXC is installed
- **AND** SHALL install it if missing before proceeding

#### Scenario: KeePassXC database access
- **WHEN** templates require KeePassXC access
- **THEN** the KeePassXC database SHALL be unlocked
- **AND** SHALL be accessible to chezmoi's KeePassXC integration

## Design Decisions

### KeePassXC Choice
Using KeePassXC provides:
- Local secret storage (no cloud dependency)
- Open-source and auditable
- Cross-platform support (macOS, Linux, Windows)
- CLI and GUI access to secrets
- Native chezmoi integration via template functions

### Template-Time Injection
Injecting secrets during template execution ensures:
- Secrets never committed to git
- Secrets only exist in target files, not source
- Easy rotation: update KeePassXC, re-apply templates
- Different secrets per machine from same source

### Machine-Specific Entry Mapping
Mapping KeePassXC entries via machine configuration allows:
- Single database for multiple machines
- Different SSH keys per machine
- Clear identification of which machine uses which credentials
- Easy addition of new machines without template changes

### Graceful Degradation Strategy
Allowing scripts to skip secret-dependent operations enables:
- Testing configurations without full secret setup
- Partial bootstraps when some secrets are unavailable
- Clear error messages about missing credentials
- Non-blocking installation of non-secret features
