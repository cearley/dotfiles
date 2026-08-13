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

#### Scenario: Attachment retrieval during template execution
- **WHEN** a template uses `keepassxcAttachment "entry-name" "attachment-name"`
- **THEN** chezmoi SHALL query KeePassXC for the specified file attachment on that entry
- **AND** SHALL inject the attachment's raw file contents into the template output
- **AND** the containing template file SHALL use the `private_` prefix so the resulting file receives restrictive permissions

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
- **AND** SHALL map entry names via `config.yaml` configuration

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

### Requirement: Azure DevOps Multi-Account Authentication
The system SHALL support automated authentication to Azure DevOps Services for multiple accounts (work and personal) using Personal Access Tokens stored in KeePassXC.

#### Scenario: Work account PAT retrieval
- **WHEN** work account Azure DevOps authentication script executes
- **THEN** the PAT SHALL be retrieved from KeePassXC entry "Azure DevOps (Willdan)" attribute "Access Token"
- **AND** SHALL be used for git, Azure CLI, ACR, and Artifacts authentication

#### Scenario: Personal account PAT retrieval
- **WHEN** personal account Azure DevOps authentication script executes
- **THEN** the PAT SHALL be retrieved from KeePassXC entry "Azure DevOps (CES)" attribute "Access Token"
- **AND** SHALL be used for git and optionally Azure CLI authentication

#### Scenario: Git credential helper for work repositories
- **WHEN** git operations access dev.azure.com or *.visualstudio.com from ~/work/ directory
- **THEN** work account credentials SHALL be retrieved from macOS Keychain
- **AND** SHALL have been pre-populated from KeePassXC entry "Azure DevOps (Willdan)"

#### Scenario: Git credential helper for personal repositories
- **WHEN** git operations access dev.azure.com or *.visualstudio.com from ~/personal/azure/ directory
- **THEN** personal account credentials SHALL be retrieved from macOS Keychain
- **AND** SHALL have been pre-populated from KeePassXC entry "Azure DevOps (CES)"

#### Scenario: Directory-based credential routing
- **WHEN** git operations occur in directories other than ~/work/ or ~/personal/azure/
- **THEN** work account credentials SHALL be used as the global default

#### Scenario: Azure CLI DevOps extension authentication for work account
- **WHEN** Azure DevOps CLI commands execute for work organization
- **THEN** the work PAT SHALL be available via `AZURE_DEVOPS_EXT_PAT` environment variable
- **AND** SHALL authenticate to the configured work Azure DevOps organization

#### Scenario: Azure CLI DevOps extension authentication for personal account
- **WHEN** Azure DevOps CLI commands execute for personal organization
- **THEN** the personal PAT MAY be available via `AZURE_DEVOPS_EXT_PAT_PERSONAL` environment variable
- **AND** MAY authenticate to the configured personal Azure DevOps organization

#### Scenario: Azure Container Registry authentication
- **WHEN** users pull or push container images to Azure Container Registry
- **THEN** authentication SHALL use `az acr login` with Azure AD credentials
- **AND** SHALL require one-time `az login` for Azure AD authentication

#### Scenario: Azure Artifacts package authentication
- **WHEN** package managers (npm, NuGet, Maven, pip) access Azure Artifacts feeds
- **THEN** the PAT SHALL be injected into package manager configuration files
- **AND** SHALL authenticate automatically without prompts

#### Scenario: Work account PAT rotation
- **WHEN** the work Azure DevOps PAT is updated in KeePassXC entry "Azure DevOps (Willdan)"
- **THEN** running `chezmoi apply` SHALL detect the change via hash comparison
- **AND** SHALL re-execute the work authentication setup script automatically
- **AND** SHALL NOT trigger re-execution of the personal authentication script

#### Scenario: Personal account PAT rotation
- **WHEN** the personal Azure DevOps PAT is updated in KeePassXC entry "Azure DevOps (CES)"
- **THEN** running `chezmoi apply` SHALL detect the change via hash comparison
- **AND** SHALL re-execute the personal authentication setup script automatically
- **AND** SHALL NOT trigger re-execution of the work authentication script

#### Scenario: Independent script execution
- **WHEN** either work or personal PAT changes
- **THEN** only the corresponding authentication script SHALL re-execute
- **AND** the other account SHALL remain unaffected

### Requirement: Azure DevOps PAT Scopes
The Azure DevOps Personal Access Token SHALL have appropriate scopes for all required operations.

#### Scenario: Required PAT scopes
- **WHEN** creating an Azure DevOps PAT for chezmoi usage
- **THEN** the PAT SHALL include Code (Read & Write) scope for git operations
- **AND** SHALL include Packaging (Read & Write) scope for Azure Artifacts
- **AND** MAY include Build (Read) scope for pipeline access
- **AND** MAY include Project and Team (Read) scope for az devops commands

#### Scenario: Insufficient PAT scopes
- **WHEN** operations fail due to insufficient PAT permissions
- **THEN** error messages SHALL indicate the operation attempted
- **AND** SHALL provide guidance on required scopes

### Requirement: Azure DevOps Configuration Gating
Azure DevOps work account authentication SHALL be gated by the `work` tag, while personal account authentication SHALL be gated by the `dev` tag.

#### Scenario: Work account requires work tag
- **WHEN** chezmoi applies configuration
- **THEN** work account authentication script SHALL only execute if the `work` tag is present
- **AND** SHALL skip execution on machines without the work tag

#### Scenario: Personal account requires dev tag
- **WHEN** chezmoi applies configuration on any machine
- **THEN** personal account authentication script SHALL only execute if the `dev` tag is present
- **AND** SHALL skip execution on machines without the dev tag

#### Scenario: Both accounts require KeePassXC
- **WHEN** either Azure DevOps authentication script executes
- **THEN** they SHALL only proceed if KeePassXC database is available
- **AND** SHALL gracefully skip if KeePassXC is not configured

#### Scenario: Staged account adoption
- **WHEN** only work account is configured (personal variables empty)
- **THEN** only work authentication script SHALL execute
- **WHEN** only personal account is configured (work tag not present)
- **THEN** only personal authentication script SHALL execute

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

