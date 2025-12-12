## ADDED Requirements

### Requirement: GitHub Authentication Enhancement Scenarios
The system SHALL support two GitHub authentication scenarios: single-account with package managers (common) and optional multi-account with credential routing (advanced).

#### Scenario: Single account with package managers (Scenario A)
- **WHEN** a user has one GitHub account
- **THEN** the system SHALL use the same credentials for git, GHCR, GitHub CLI, and all package managers
- **AND** MAY use directory-based email changes for different commit identities
- **AND** SHALL NOT require multi-account configuration

#### Scenario: Multiple accounts with credential routing (Scenario B)
- **WHEN** a user explicitly configures both personal and enterprise GitHub accounts
- **THEN** the system SHALL support separate credentials per account
- **AND** SHALL route credentials based on repository directory location
- **AND** SHALL maintain independent authentication for each account

### Requirement: GitHub Multi-Account Authentication (Optional)
The system SHALL optionally support multiple GitHub accounts (personal and enterprise) with independent authentication and directory-based credential routing.

#### Scenario: Personal GitHub authentication
- **WHEN** a machine has the `dev` tag and a KeePassXC entry for personal GitHub
- **THEN** the system SHALL configure git, GitHub CLI, and GHCR authentication for the personal account
- **AND** SHALL use personal credentials as the global default

#### Scenario: Enterprise GitHub authentication
- **WHEN** a machine has the `work` tag and a KeePassXC entry for enterprise GitHub
- **THEN** the system SHALL configure git, GitHub CLI, and GHCR authentication for the enterprise account
- **AND** SHALL use enterprise credentials for repositories in the `~/work/` directory

#### Scenario: Directory-based credential routing
- **WHEN** both personal and enterprise GitHub accounts are configured
- **AND** a git operation occurs in the `~/work/` directory
- **THEN** git SHALL use enterprise GitHub credentials
- **WHEN** a git operation occurs outside the `~/work/` directory
- **THEN** git SHALL use personal GitHub credentials

#### Scenario: Independent PAT rotation
- **WHEN** the personal GitHub PAT is updated in KeePassXC
- **THEN** the personal authentication script SHALL re-execute
- **AND** SHALL NOT trigger re-execution of the enterprise authentication script
- **WHEN** the enterprise GitHub PAT is updated in KeePassXC
- **THEN** the enterprise authentication script SHALL re-execute
- **AND** SHALL NOT trigger re-execution of the personal authentication script

### Requirement: GitHub Packages Authentication
The system SHALL support authentication to GitHub Packages for npm, NuGet, Maven, and Python pip package managers using either single-account or multi-account credentials.

#### Scenario: Single-account package authentication
- **WHEN** a user has GitHub Packages configured with one GitHub account
- **THEN** the system SHALL use the same GitHub PAT for all package manager authentication
- **AND** SHALL configure all requested package managers with the same credentials

#### Scenario: npm GitHub Packages authentication
- **WHEN** a GitHub Packages npm registry is configured
- **THEN** the system SHALL create or update `.npmrc` with GitHub Packages registry URL
- **AND** SHALL configure authentication using the GitHub PAT from KeePassXC

#### Scenario: NuGet GitHub Packages authentication
- **WHEN** a GitHub Packages NuGet source is configured
- **THEN** the system SHALL create or update `NuGet.Config` with GitHub Packages source URL
- **AND** SHALL configure authentication using the GitHub PAT from KeePassXC

#### Scenario: Maven GitHub Packages authentication
- **WHEN** a GitHub Packages Maven repository is configured
- **THEN** the system SHALL create or update Maven `settings.xml` with GitHub Packages repository URL
- **AND** SHALL configure authentication using the GitHub PAT from KeePassXC

#### Scenario: Python pip GitHub Packages authentication
- **WHEN** a GitHub Packages pip index is configured
- **THEN** the system SHALL create or update `pip.conf` with GitHub Packages index URL
- **AND** SHALL configure authentication using the GitHub PAT from KeePassXC

#### Scenario: Optional package manager configuration
- **WHEN** a package manager is not configured (no package owner/repo provided)
- **THEN** the authentication script SHALL skip package manager configuration for that package type
- **AND** SHALL display a skip message

#### Scenario: Multi-account package manager authentication
- **WHEN** both personal and enterprise GitHub accounts are configured
- **AND** both accounts have package manager configuration
- **THEN** the system SHALL configure package manager authentication for both accounts
- **AND** SHALL use appropriate credentials for each account's package feeds

### Requirement: GitHub Environment Variable Exports
The system SHALL export GitHub PATs as environment variables for CLI tools and scripts, supporting both single-account and multi-account configurations.

#### Scenario: Single-account token export
- **WHEN** GitHub authentication is configured with one account
- **THEN** the system SHALL export `GITHUB_TOKEN` environment variable
- **AND** SHALL set the value to the GitHub PAT from the "GitHub" KeePassXC entry

#### Scenario: Personal GitHub token export (multi-account)
- **WHEN** personal GitHub authentication is configured with the `dev` tag
- **THEN** the system SHALL export `GITHUB_TOKEN` environment variable
- **AND** SHALL set the value to the personal GitHub PAT from KeePassXC

#### Scenario: Enterprise GitHub token export
- **WHEN** enterprise GitHub authentication is configured with the `work` tag
- **THEN** the system SHALL export `GITHUB_TOKEN_ENTERPRISE` environment variable
- **AND** SHALL set the value to the enterprise GitHub PAT from KeePassXC

#### Scenario: Multi-account token exports
- **WHEN** both personal and enterprise GitHub accounts are configured
- **THEN** both `GITHUB_TOKEN` and `GITHUB_TOKEN_ENTERPRISE` environment variables SHALL be exported
- **AND** tools MAY use either variable as appropriate for their context

### Requirement: GitHub Tag-Based Gating
The system SHALL gate GitHub authentication scripts using tags for selective deployment.

#### Scenario: Personal account gating
- **WHEN** a machine has the `dev` tag
- **THEN** the personal GitHub authentication script SHALL execute
- **WHEN** a machine does not have the `dev` tag
- **THEN** the personal GitHub authentication script SHALL NOT execute

#### Scenario: Enterprise account gating
- **WHEN** a machine has the `work` tag
- **THEN** the enterprise GitHub authentication script SHALL execute
- **WHEN** a machine does not have the `work` tag
- **THEN** the enterprise GitHub authentication script SHALL NOT execute

#### Scenario: Backward compatibility with existing installations
- **WHEN** a machine has KeePassXC configured but no tags defined
- **THEN** the personal GitHub authentication script SHALL execute (fallback behavior)
- **AND** SHALL maintain backward compatibility with existing single-account setups

### Requirement: GitHub Enterprise Domain Support
The system SHALL support authentication to both github.com and GitHub Enterprise custom domains.

#### Scenario: GitHub.com authentication
- **WHEN** personal GitHub account is configured without a custom domain
- **THEN** the system SHALL configure authentication for github.com

#### Scenario: GitHub Enterprise custom domain authentication
- **WHEN** enterprise GitHub account is configured with a custom domain
- **THEN** the system SHALL configure authentication for the specified enterprise domain
- **AND** SHALL configure gh CLI with the `--hostname` flag for the enterprise domain

#### Scenario: Multi-domain git credential helper
- **WHEN** both github.com and GitHub Enterprise are configured
- **THEN** git credential helper SHALL be configured for both domains
- **AND** SHALL use appropriate credentials for each domain

### Requirement: GitHub KeePassXC Entry Naming
KeePassXC entries for GitHub SHALL follow a clear naming convention to distinguish between personal and enterprise accounts.

#### Scenario: Personal account entry
- **WHEN** configuring personal GitHub authentication
- **THEN** the system SHALL retrieve credentials from a KeePassXC entry named "GitHub" or "GitHub (Personal)"

#### Scenario: Enterprise account entry
- **WHEN** configuring enterprise GitHub authentication
- **THEN** the system SHALL retrieve credentials from a KeePassXC entry named "GitHub (Enterprise)" or "GitHub (Work)"

#### Scenario: Entry attribute structure
- **WHEN** retrieving GitHub credentials from KeePassXC
- **THEN** the system SHALL use the "Access Token" attribute for the PAT value
- **AND** MAY use "username" attribute for the GitHub username if needed