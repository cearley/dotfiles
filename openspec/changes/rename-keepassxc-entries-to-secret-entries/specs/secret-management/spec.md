## RENAMED Requirements

- FROM: `### Requirement: Machine-Specific KeePassXC Entries`
- TO: `### Requirement: Machine-Specific Secret Entries`

## MODIFIED Requirements

### Requirement: Machine-Specific Secret Entries
The system SHALL support machine-specific secret entry names via the machine configuration system, using a manager-agnostic `secret_entries` map. Each entry maps a logical secret name (e.g. `ssh`) to the true entry/item name for that secret on the current machine; which secret-storage backend retrieves that entry is a decision made by the consuming template (which function it calls), not by this map.

#### Scenario: SSH key entry mapping
- **WHEN** a machine configuration defines `secret_entries.ssh: "SSH (MacBook Pro)"`
- **THEN** templates SHALL retrieve SSH credentials using the "SSH (MacBook Pro)" entry name

#### Scenario: Shared KeePassXC database
- **WHEN** multiple machines share the same secret store (e.g. a single KeePassXC database)
- **THEN** each machine MAY use different entry names for the same logical credential type
- **AND** SHALL map entry names via `config.yaml` configuration
