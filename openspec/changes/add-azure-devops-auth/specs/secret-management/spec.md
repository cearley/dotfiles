## ADDED Requirements

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
