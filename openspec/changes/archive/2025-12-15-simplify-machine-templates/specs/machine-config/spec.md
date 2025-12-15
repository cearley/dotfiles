# Machine Configuration System (Delta)

## REMOVED Requirements

### Requirement: Convenience Wrapper Templates
~~The system SHALL provide convenience wrappers for common machine lookups.~~

#### Scenario: Brewfile path wrapper
~~- **WHEN** `machine-brewfile-path` template is included~~
~~- **THEN** it SHALL return the full path to the machine-specific Homebrew Brewfile~~

#### Scenario: Machine key name wrapper
~~- **WHEN** `machine-key-name` template is included~~
~~- **THEN** it SHALL return the matched machine pattern name from `machines.yaml`~~

#### Scenario: KeePassXC entry wrapper
~~- **WHEN** `machine-keepassxc-entry` is called with entry type "ssh"~~
~~- **THEN** it SHALL return the KeePassXC entry name for SSH from the matched machine's settings~~

## ADDED Requirements

### Requirement: Machine Settings Dict Template
The system SHALL provide a `machine-settings` template that returns all machine configuration as a structured dict.

#### Scenario: JSON-encoded output
- **WHEN** `machine-settings` template is executed
- **THEN** it SHALL return a valid JSON string
- **AND** SHALL be deserializable via `fromJson`

#### Scenario: All properties included
- **WHEN** a machine pattern matches
- **THEN** the returned dict SHALL contain all properties defined for that machine in `machines.yaml`
- **AND** SHALL preserve nested structures (e.g., `keepassxc_entries`)

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

### Requirement: Call Site Pattern
Templates using machine settings SHALL follow a consistent pattern for dict retrieval and property access.

#### Scenario: Standard dict retrieval pattern
- **WHEN** a template needs machine settings
- **THEN** it SHALL use the pattern: `$settings := includeTemplate "machine-settings" . | fromJson`
- **AND** SHALL check for property existence before using (e.g., `if $settings.brewfile`)

#### Scenario: Property access pattern
- **WHEN** accessing machine properties from the dict
- **THEN** templates SHALL use dot-notation: `$settings.property_name`
- **AND** SHALL use nested access for sub-properties: `$settings.parent.child`

#### Scenario: Path construction pattern
- **WHEN** constructing paths from machine settings
- **THEN** templates SHALL use explicit path construction at call sites
- **AND** SHALL NOT rely on pre-constructed paths from templates

#### Scenario: Conditional usage pattern
- **WHEN** machine settings may be absent
- **THEN** templates SHALL check property existence: `if $settings.property_name`
- **AND** SHALL gracefully handle empty/missing values
