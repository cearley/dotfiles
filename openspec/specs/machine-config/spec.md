# Machine Configuration System

## Purpose
The machine configuration system provides centralized, extensible machine-specific settings using pattern-based detection and reusable template components.

## Requirements

### Requirement: Machine Data Storage
Machine-specific settings SHALL be stored in `home/.chezmoidata/config.yaml` as a static YAML file.

#### Scenario: Machine settings definition
- **WHEN** a new machine "MacBook Pro" is added to `config.yaml`
- **THEN** the file SHALL contain nested YAML properties for that machine
- **AND** SHALL support arbitrary key-value pairs

#### Scenario: Nested property support
- **WHEN** `config.yaml` contains nested properties like `keepassxc_entries.ssh`
- **THEN** templates SHALL be able to access nested values using dot-notation

### Requirement: Pattern-Based Machine Detection
The system SHALL match machine names using substring pattern matching.

#### Scenario: Substring pattern match
- **WHEN** the computer name is "Craig's MacBook Pro M4"
- **THEN** the pattern "MacBook Pro" SHALL successfully match
- **AND** SHALL return the associated machine settings

#### Scenario: Multiple pattern match
- **WHEN** multiple patterns could match a machine name
- **THEN** the first matching pattern in `config.yaml` SHALL be used

#### Scenario: No pattern match
- **WHEN** no pattern matches the computer name
- **THEN** templates SHALL return empty strings
- **AND** scripts SHALL gracefully skip machine-specific operations

### Requirement: Cross-Platform Machine Name Detection
The system SHALL detect machine names across macOS, Linux, and Windows platforms.

#### Scenario: macOS machine name detection
- **WHEN** running on macOS
- **THEN** the `machine-name` template SHALL use `scutil --get "ComputerName"`
- **AND** SHALL return the user-visible computer name

#### Scenario: Linux machine name detection
- **WHEN** running on Linux
- **THEN** the `machine-name` template SHALL use `hostnamectl` to get the static hostname

#### Scenario: Windows machine name detection
- **WHEN** running on Windows
- **THEN** the `machine-name` template SHALL use PowerShell DNS to get the hostname

### Requirement: Generic Configuration Lookup
The `machine-config` template SHALL provide a single source of truth for all machine-specific lookups.

#### Scenario: Setting value retrieval
- **WHEN** `machine-config` is called with `setting: "brewfile"`
- **THEN** the template SHALL return the brewfile value for the matched machine

#### Scenario: Dot-notation nested lookup
- **WHEN** `machine-config` is called with `setting: "keepassxc_entries.ssh"`
- **THEN** the template SHALL traverse the nested YAML structure
- **AND** SHALL return the SSH KeePassXC entry name

#### Scenario: Return matched pattern key
- **WHEN** `machine-config` is called with `return_key: true`
- **THEN** the template SHALL return the matched machine pattern name (e.g., "MacBook Pro")

#### Scenario: Missing setting graceful handling
- **WHEN** a requested setting does not exist for the matched machine
- **THEN** the template SHALL return an empty string
- **AND** SHALL NOT cause template execution failure

### Requirement: Template Composition
Templates SHALL support inclusion of other templates via `includeTemplate`.

#### Scenario: Nested template inclusion
- **WHEN** `machine-brewfile-path` includes `machine-config`
- **THEN** chezmoi SHALL execute both templates in sequence
- **AND** SHALL pass the template context to included templates

#### Scenario: Context preservation
- **WHEN** calling `includeTemplate` with `merge (dict "key" "value") .`
- **THEN** the included template SHALL have access to both the new parameter and the original context

### Requirement: Machine Settings Dict Template
The system SHALL provide a `machine-settings` template that returns all machine configuration as a structured dict.

#### Scenario: JSON-encoded output
- **WHEN** `machine-settings` template is executed
- **THEN** it SHALL return a valid JSON string
- **AND** SHALL be deserializable via `fromJson`

#### Scenario: All properties included
- **WHEN** a machine pattern matches
- **THEN** the returned dict SHALL contain all properties defined for that machine in `config.yaml`
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

#### Scenario: Machine settings dict retrieval
- **WHEN** `machine-settings` template is included
- **THEN** it SHALL return a JSON-encoded dict containing all machine settings
- **AND** SHALL include a special `_machine_key` property with the matched machine pattern name

#### Scenario: Dict deserialization and property access
- **WHEN** the returned JSON is parsed with `fromJson`
- **THEN** templates SHALL access properties using dot-notation
- **AND** SHALL support nested properties like `keepassxc_entries.ssh`

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
- **WHEN** a template needs a KeePassXC entry name
- **THEN** it SHALL get settings via `machine-settings`
- **AND** SHALL access nested entries like `$settings.keepassxc_entries.ssh`

#### Scenario: Machine pattern key retrieval
- **WHEN** a template needs the matched machine pattern name
- **THEN** it SHALL access `$settings._machine_key` from the returned dict
- **AND** SHALL receive the same value as calling `machine-config` with `return_key: true`

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

### Requirement: Extensibility Without Template Changes
Adding new machine-specific properties SHALL NOT require changes to templates.

#### Scenario: New property addition
- **WHEN** a new property `ssh_key_id` is added to a machine in `config.yaml`
- **THEN** templates can immediately access it via `machine-config`
- **AND** SHALL NOT require modifications to existing templates

#### Scenario: Backward compatibility
- **WHEN** a new property is added to `config.yaml`
- **THEN** existing machines without that property SHALL return empty string
- **AND** SHALL continue to function normally

### Requirement: Static Data File Requirement
The `config.yaml` file SHALL be a static file, not a template.

#### Scenario: Template engine dependency
- **WHEN** chezmoi's template engine initializes
- **THEN** `config.yaml` MUST exist and be readable
- **AND** SHALL NOT have a `.tmpl` suffix

#### Scenario: Data file immutability during templating
- **WHEN** templates are being executed
- **THEN** `config.yaml` SHALL NOT be modified
- **AND** SHALL provide consistent data throughout the templating process

## Design Decisions

### Pattern-Based Matching Rationale
Substring matching allows:
- Flexibility in machine naming conventions (e.g., "Craig's MacBook Pro", "Work MacBook Pro")
- No need to update configuration when machines are renamed slightly
- Simple mental model: "if it contains 'MacBook Pro', use MacBook Pro settings"

### Template Composition Architecture
Using `includeTemplate` provides:
- DRY principle: single source of truth for machine detection
- Clean separation of concerns: detection → lookup → path construction
- Reusable components across different template files
- Easy testing of individual template components

### Generic Lookup Design
The `machine-config` template as a generic lookup mechanism enables:
- Single place to update machine detection logic
- No template duplication for different setting types
- Easy extension with new properties
- Consistent error handling across all lookups

### Dot-Notation Support
Supporting nested YAML access via dot-notation allows:
- Logical grouping of related settings (e.g., all KeePassXC entries under `keepassxc_entries`)
- Clear namespace separation
- Easier maintenance of complex configurations
