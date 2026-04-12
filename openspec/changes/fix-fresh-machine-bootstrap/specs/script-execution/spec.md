## MODIFIED Requirements

### Requirement: Execution Order Categories
Scripts SHALL use 10-point range grouping (00-09, 10-19, 20-29, etc.) for logical categorization, with flexible spacing within each range.

#### Scenario: System foundation stage (00-09)
- **WHEN** scripts are numbered 00-09
- **THEN** they SHALL handle system-level foundations like Rosetta 2 installation

#### Scenario: Development toolchains stage (10-19)
- **WHEN** scripts are numbered 10-19
- **THEN** they SHALL handle language runtime installations (Rust, Java/JVM)

#### Scenario: Package management stage (20-29)
- **WHEN** scripts are numbered 20-29
- **THEN** they SHALL handle package manager installations and Homebrew bundles
- **AND** SHALL include the uv package manager installer at position 21

#### Scenario: Environment managers stage (30-39)
- **WHEN** scripts are numbered 30-39
- **THEN** they SHALL handle language-specific environment managers (nvm)
- **NOTE**: uv is NOT in this range; it moved to position 21 (package management stage)

#### Scenario: Environment setup stage (40-49)
- **WHEN** scripts are numbered 40-49
- **THEN** they SHALL handle authentication, conda initialization, and shell plugins

#### Scenario: System configuration stage (80-99)
- **WHEN** scripts are numbered 80-99
- **THEN** they SHALL handle security setup, VPN configuration, authentication services, system defaults, and validation

## ADDED Requirements

### Requirement: Bootstrap Documentation Clarity
The bootstrap command example in README SHALL use placeholder text that does not conflict with shell metacharacters.

#### Scenario: Safe placeholder format
- **WHEN** the README shows the bootstrap command with a username placeholder
- **THEN** the placeholder SHALL use uppercase-no-brackets format (e.g., `YOUR_GITHUB_USERNAME`)
- **AND** SHALL NOT use angle-bracket format (`<your-github-username>`) which zsh interprets as a redirect operator
