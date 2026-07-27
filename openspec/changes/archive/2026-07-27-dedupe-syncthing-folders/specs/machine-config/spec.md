## ADDED Requirements

### Requirement: Shared Data Top-Level Keys
`home/.chezmoidata/config.yaml` MAY contain top-level keys other than `machines:` to hold literal data shared across multiple machines via YAML anchor/alias (e.g. an identical `syncthing_folders` list reused by more than one machine). Templates that resolve machine settings MUST NOT treat such keys as machine-name patterns.

#### Scenario: Shared data key defined outside machines
- **WHEN** `config.yaml` declares a top-level key such as `syncthing_shared_folders: &anchor [...]` above `machines:`
- **THEN** the `machine-config` template's pattern-matching range SHALL NOT iterate over it, because it only ranges over the contents of `.machines`
- **AND** a machine section MAY reference the shared data via a YAML alias (e.g. `syncthing_folders: *anchor`)

#### Scenario: Shared data key must not be nested inside machines
- **WHEN** a contributor considers adding a non-machine shared-data key
- **THEN** it SHALL be placed as a top-level key outside `machines:`, not as a sibling key nested inside `machines:`
- **BECAUSE** `machine-config` ranges over every key directly under `machines:` and tests each as a hostname substring pattern; a non-machine key nested there risks a spurious match against a real computer name

#### Scenario: YAML anchor must precede its aliases
- **WHEN** a shared-data key is referenced via YAML alias from one or more machine sections
- **THEN** the anchor-defining key SHALL appear lexically earlier in `config.yaml` than any of its aliases
- **BECAUSE** YAML resolves anchors in a single forward pass and a forward-referenced alias fails to parse
