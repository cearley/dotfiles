# syncthing-folder-setup Specification

## Purpose
TBD - created by archiving change syncthing-folder-setup. Update Purpose after archive.
## Requirements
### Requirement: Declarative Folder Configuration
The system SHALL allow Syncthing shared folders to be declared in `home/.chezmoidata/config.yaml` under each machine's `syncthing_folders` key, and SHALL apply that configuration to the running Syncthing instance during `chezmoi apply`.

#### Scenario: Folder declared in config is created on first apply
- **WHEN** a folder ID is listed under `syncthing_folders` for the current machine
- **AND** that folder ID does not yet exist in Syncthing
- **THEN** the script SHALL create the folder using `syncthing cli config folders add-json`
- **AND** SHALL create the local directory at the declared path if it does not exist
- **AND** SHALL set versioning and ignore patterns as declared

#### Scenario: Folder already exists — label, versioning and ignores reconciled, devices preserved
- **WHEN** a folder ID listed in `syncthing_folders` already exists in Syncthing
- **THEN** the script SHALL update the folder label, versioning type, versioning params, and ignore patterns
- **AND** SHALL NOT modify the folder's `devices` list
- **AND** SHALL NOT modify any other folder property not declared in `syncthing_folders`

#### Scenario: Syncthing daemon is not running
- **WHEN** the script runs but Syncthing is not reachable via `syncthing cli`
- **THEN** the script SHALL print a warning and exit with code 0
- **AND** `chezmoi apply` SHALL complete without error

### Requirement: Versioning Policy
The script SHALL configure folder versioning according to the `versioning` key in each folder's config entry.

#### Scenario: Versioning type and params applied
- **WHEN** a folder entry has a `versioning.type` set to `simple`
- **THEN** the script SHALL set `versioning type` to `simple`
- **AND** SHALL set each key in `versioning.params` via `versioning params set`

#### Scenario: Versioning cleared when type is none
- **WHEN** a folder entry has `versioning.type: none`
- **THEN** the script SHALL set `versioning type` to `""` (empty string), disabling versioning

#### Scenario: Versioning unchanged when key absent
- **WHEN** a folder entry has no `versioning` key
- **THEN** the script SHALL NOT modify the folder's existing versioning configuration

### Requirement: Ignore Patterns
The script SHALL configure per-folder ignore patterns using the Syncthing REST API.

#### Scenario: Ignore patterns applied via REST API
- **WHEN** a folder entry has a non-empty `ignores` list
- **THEN** the script SHALL POST to `/rest/db/ignores?folder=<id>` with the declared patterns
- **AND** the API key SHALL be extracted at runtime from `~/Library/Application Support/Syncthing/config.xml`
- **AND** the patterns SHALL replace (not append to) any existing `.stignore` contents

#### Scenario: Ignore patterns unchanged when key absent
- **WHEN** a folder entry has no `ignores` key
- **THEN** the script SHALL NOT modify the folder's existing `.stignore` file

### Requirement: Idempotency
The script SHALL be safe to run multiple times with identical results.

#### Scenario: Re-run with unchanged config produces no harmful side effects
- **WHEN** `chezmoi apply` is run a second time with no config changes
- **THEN** the script SHALL set the same versioning and ignore values it already set
- **AND** SHALL NOT alter folder state in any other way

#### Scenario: chezmoi run_onchange_after triggers only on config change
- **WHEN** `config.yaml` changes in a way affecting the current machine's `syncthing_folders`
- **THEN** chezmoi SHALL re-run the script on next `chezmoi apply`
- **AND** the script SHALL reconcile all declared folders to their declared state

### Requirement: Non-Destructive Operation
The script SHALL never remove Syncthing folders, even if a folder is removed from `syncthing_folders` in config.

#### Scenario: Folder removed from config but present in Syncthing
- **WHEN** a folder ID is removed from `syncthing_folders` in `config.yaml`
- **THEN** the script SHALL leave that folder untouched in Syncthing
- **AND** SHALL NOT delete the folder or its local files

