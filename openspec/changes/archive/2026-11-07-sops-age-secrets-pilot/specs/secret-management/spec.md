## ADDED Requirements

### Requirement: Two-Tier Secret Source of Truth
The system SHALL support two secret source-of-truth tiers: KeePassXC for secrets used outside chezmoi-rendered files, and SOPS+age-encrypted files committed to the repository for secrets that exist solely to render chezmoi-managed files.

#### Scenario: Broad-use secret sourced from KeePassXC
- **WHEN** a secret is used by a human, another CLI tool, or a system outside of what chezmoi renders
- **THEN** it SHALL be sourced from KeePassXC
- **AND** SHALL NOT be committed to the repository in any form, encrypted or otherwise

#### Scenario: Repo-scoped secret sourced from SOPS+age
- **WHEN** a secret exists solely to populate the contents of one or more chezmoi-managed files and is never used outside that context
- **THEN** it MAY be sourced from a SOPS+age-encrypted file committed to the repository instead of KeePassXC

### Requirement: Secret Tier Classification
Before a new secret is added to the repository's secret-management system, it SHALL be classified into the KeePassXC tier or the SOPS+age tier based on where it is used.

#### Scenario: Classification default
- **WHEN** it is unclear whether a secret is ever used outside of chezmoi-rendered files
- **THEN** the secret SHALL default to the KeePassXC tier until proven otherwise

#### Scenario: Reclassification
- **WHEN** a secret previously sourced from KeePassXC is confirmed to be used solely within chezmoi-rendered files
- **THEN** it MAY be migrated to the SOPS+age tier as a separate, deliberate change
