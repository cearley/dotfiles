## MODIFIED Requirements

### Requirement: Machine Data Storage
Machine-specific settings SHALL be stored in `home/.chezmoidata/config.yaml` as a static YAML file, with all machine-name-pattern entries nested under a single top-level `machines:` key.

#### Scenario: Machine settings definition
- **WHEN** a new machine "MacBook Pro" is added to `config.yaml`
- **THEN** the file SHALL contain the pattern as a key under `machines:`, with nested YAML properties as its value
- **AND** SHALL support arbitrary key-value pairs

#### Scenario: Nested property support
- **WHEN** `config.yaml` contains nested properties like `secret_entries.ssh`
- **THEN** templates SHALL be able to access nested values using dot-notation

### Requirement: Generic Configuration Lookup
The `machine-config` template SHALL provide a single source of truth for all machine-specific lookups.

#### Scenario: Setting value retrieval
- **WHEN** `machine-config` is called with `setting: "brewfile"`
- **THEN** the template SHALL return the brewfile value for the matched machine

#### Scenario: Dot-notation nested lookup
- **WHEN** `machine-config` is called with `setting: "secret_entries.ssh"`
- **THEN** the template SHALL traverse the nested YAML structure
- **AND** SHALL return the SSH secret entry name

#### Scenario: Return matched pattern key
- **WHEN** `machine-config` is called with `return_key: true`
- **THEN** the template SHALL return the matched machine pattern name (e.g., "MacBook Pro")

#### Scenario: Missing setting graceful handling
- **WHEN** a requested setting does not exist for the matched machine
- **THEN** the template SHALL return an empty string
- **AND** SHALL NOT cause template execution failure

### Requirement: Machine Settings Dict Template
The system SHALL provide a `machine-settings` template that returns all machine configuration as a structured dict.

#### Scenario: JSON-encoded output
- **WHEN** `machine-settings` template is executed
- **THEN** it SHALL return a valid JSON string
- **AND** SHALL be deserializable via `fromJson`

#### Scenario: All properties included
- **WHEN** a machine pattern matches
- **THEN** the returned dict SHALL contain all properties defined for that machine in `config.yaml`
- **AND** SHALL preserve nested structures (e.g., `secret_entries`)

#### Scenario: Special machine key property
- **WHEN** `machine-settings` returns a dict
- **THEN** it SHALL include a `_machine_key` property
- **AND** the value SHALL be the matched machine pattern name (e.g., "MacBook Pro")

#### Scenario: Performance optimization
- **WHEN** a template needs multiple machine properties
- **THEN** using `machine-settings` SHALL require only one pattern matching operation
- **AND** SHALL be more efficient than multiple individual `machine-config` calls

#### Scenario: Backward compatibility with machine-config
- **WHEN** templates use the new `machine-settings` approach
- **THEN** the core `machine-config` template SHALL remain unchanged
- **AND** SHALL continue to work for any existing direct usage

#### Scenario: Machine settings dict retrieval
- **WHEN** `machine-settings` template is included
- **THEN** it SHALL return a JSON-encoded dict containing all machine settings
- **AND** SHALL include a special `_machine_key` property with the matched machine pattern name

#### Scenario: Dict deserialization and property access
- **WHEN** the returned JSON is parsed with `fromJson`
- **THEN** templates SHALL access properties using dot-notation
- **AND** SHALL support nested properties like `secret_entries.ssh`

#### Scenario: Empty machine settings
- **WHEN** no machine pattern matches the current computer name
- **THEN** `machine-settings` SHALL return an empty JSON dict `{}`
- **AND** property access SHALL return nil/empty values

#### Scenario: Single template include for multiple settings
- **WHEN** a template needs multiple machine properties
- **THEN** it SHALL call `machine-settings` once
- **AND** SHALL access all needed properties from the returned dict
- **AND** SHALL NOT require multiple `includeTemplate` calls

#### Scenario: Brewfile path construction
- **WHEN** a template needs the Brewfile path
- **THEN** it SHALL get settings via `machine-settings`
- **AND** SHALL construct the path using `printf "%s/brewfiles/%s" .chezmoi.sourceDir $settings.brewfile`

#### Scenario: KeePassXC entry retrieval
- **WHEN** a template needs a secret entry name
- **THEN** it SHALL get settings via `machine-settings`
- **AND** SHALL access nested entries like `$settings.secret_entries.ssh`

#### Scenario: Machine pattern key retrieval
- **WHEN** a template needs the matched machine pattern name
- **THEN** it SHALL access `$settings._machine_key` from the returned dict
- **AND** SHALL receive the same value as calling `machine-config` with `return_key: true`
