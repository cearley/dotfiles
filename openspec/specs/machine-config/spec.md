# Machine Configuration System

## Purpose
The machine configuration system provides centralized, extensible machine-specific settings using pattern-based detection and reusable template components.

## Requirements

### Requirement: Machine Data Storage
Machine-specific settings SHALL be stored in `home/.chezmoidata/machines.yaml` as a static YAML file.

#### Scenario: Machine settings definition
- **WHEN** a new machine "MacBook Pro" is added to `machines.yaml`
- **THEN** the file SHALL contain nested YAML properties for that machine
- **AND** SHALL support arbitrary key-value pairs

#### Scenario: Nested property support
- **WHEN** `machines.yaml` contains nested properties like `keepassxc_entries.ssh`
- **THEN** templates SHALL be able to access nested values using dot-notation

### Requirement: Pattern-Based Machine Detection
The system SHALL match machine names using substring pattern matching.

#### Scenario: Substring pattern match
- **WHEN** the computer name is "Craig's MacBook Pro M4"
- **THEN** the pattern "MacBook Pro" SHALL successfully match
- **AND** SHALL return the associated machine settings

#### Scenario: Multiple pattern match
- **WHEN** multiple patterns could match a machine name
- **THEN** the first matching pattern in `machines.yaml` SHALL be used

#### Scenario: No pattern match
- **WHEN** no pattern matches the computer name
- **THEN** templates SHALL return empty strings
- **AND** scripts SHALL gracefully skip machine-specific operations

### Requirement: Cross-Platform Machine Name Detection
The system SHALL detect machine names across macOS, Linux, and Windows platforms.

#### Scenario: macOS machine name detection
- **WHEN** running on macOS
- **THEN** the `computer-name` template SHALL use `scutil --get "ComputerName"`
- **AND** SHALL return the user-visible computer name

#### Scenario: Linux machine name detection
- **WHEN** running on Linux
- **THEN** the `computer-name` template SHALL use `hostnamectl` to get the static hostname

#### Scenario: Windows machine name detection
- **WHEN** running on Windows
- **THEN** the `computer-name` template SHALL use PowerShell DNS to get the hostname

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

### Requirement: Convenience Wrapper Templates
The system SHALL provide convenience wrappers for common machine lookups.

#### Scenario: Brewfile path wrapper
- **WHEN** `machine-brewfile-path` template is included
- **THEN** it SHALL return the full path to the machine-specific Homebrew Brewfile

#### Scenario: Machine key name wrapper
- **WHEN** `machine-key-name` template is included
- **THEN** it SHALL return the matched machine pattern name from `machines.yaml`

#### Scenario: KeePassXC entry wrapper
- **WHEN** `machine-keepassxc-entry` is called with entry type "ssh"
- **THEN** it SHALL return the KeePassXC entry name for SSH from the matched machine's settings

### Requirement: Extensibility Without Template Changes
Adding new machine-specific properties SHALL NOT require changes to templates.

#### Scenario: New property addition
- **WHEN** a new property `ssh_key_id` is added to a machine in `machines.yaml`
- **THEN** templates can immediately access it via `machine-config`
- **AND** SHALL NOT require modifications to existing templates

#### Scenario: Backward compatibility
- **WHEN** a new property is added to `machines.yaml`
- **THEN** existing machines without that property SHALL return empty string
- **AND** SHALL continue to function normally

### Requirement: Static Data File Requirement
The `machines.yaml` file SHALL be a static file, not a template.

#### Scenario: Template engine dependency
- **WHEN** chezmoi's template engine initializes
- **THEN** `machines.yaml` MUST exist and be readable
- **AND** SHALL NOT have a `.tmpl` suffix

#### Scenario: Data file immutability during templating
- **WHEN** templates are being executed
- **THEN** `machines.yaml` SHALL NOT be modified
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
