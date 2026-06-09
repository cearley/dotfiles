## ADDED Requirements

### Requirement: Syncthing Folders Machine Property
The machine configuration schema SHALL support an optional `syncthing_folders` key in each machine section of `config.yaml`, declaring Syncthing shared folders to configure on that machine.

#### Scenario: syncthing_folders key is optional per machine
- **WHEN** a machine section in `config.yaml` omits `syncthing_folders`
- **THEN** templates and scripts SHALL treat it as an empty list
- **AND** SHALL NOT fail or error

#### Scenario: syncthing_folders list accessed in template
- **WHEN** a chezmoi template accesses `syncthing_folders` for the current machine
- **THEN** it SHALL return the declared list of folder objects
- **AND** each object SHALL contain at minimum `id`, `label`, and `path`

#### Scenario: Optional versioning key within folder entry
- **WHEN** a folder entry in `syncthing_folders` includes a `versioning` map
- **THEN** the map SHALL contain a `type` string and an optional map of string params
- **WHEN** the folder entry omits `versioning`
- **THEN** the script SHALL leave existing Syncthing versioning configuration unchanged

#### Scenario: Optional ignores key within folder entry
- **WHEN** a folder entry in `syncthing_folders` includes an `ignores` list
- **THEN** each entry SHALL be a Syncthing ignore pattern string
- **WHEN** the folder entry omits `ignores`
- **THEN** the script SHALL leave the existing `.stignore` file unchanged
