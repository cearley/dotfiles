## MODIFIED Requirements

### Requirement: Shared Data Top-Level Keys
Any file under `home/.chezmoidata/` MAY declare a top-level key to hold literal data shared across multiple machines (e.g. a `syncthing_shared_folders` list reused by more than one machine). A machine section under `machines:` MAY reference that shared data either via a YAML anchor/alias (when both live in the same file) or via a bare string value equal to the shared key's name, resolved dynamically by the consuming template/script at render time (works regardless of which `.chezmoidata/` file declares the shared data). Templates that resolve machine settings MUST NOT treat top-level shared-data keys as machine-name patterns.

#### Scenario: Shared data key defined outside machines
- **WHEN** a file under `home/.chezmoidata/` declares a top-level key such as `shared_data: &anchor [...]` above (or separate from) `machines:`
- **THEN** the `machine-config` template's pattern-matching range SHALL NOT iterate over it, because it only ranges over the contents of `.machines`
- **AND** a machine section in the same file MAY reference the shared data via a YAML alias (e.g. `some_property: *anchor`)
- **AND** the key SHALL be available to any template as a root-level property (e.g. `.shared_data`) regardless of which `.chezmoidata/` file declared it, because chezmoi merges all such files into one data namespace

#### Scenario: Shared data key must not be nested inside machines
- **WHEN** a contributor considers adding a non-machine shared-data key
- **THEN** it SHALL be placed as a top-level key outside `machines:`, not as a sibling key nested inside `machines:`
- **BECAUSE** `machine-config` ranges over every key directly under `machines:` and tests each as a hostname substring pattern; a non-machine key nested there risks a spurious match against a real computer name

#### Scenario: YAML anchor must precede its aliases
- **WHEN** a shared-data key is referenced via YAML alias from one or more machine sections in the same file
- **THEN** the anchor-defining key SHALL appear lexically earlier in that file than any of its aliases
- **BECAUSE** YAML resolves anchors in a single forward pass within one document and a forward-referenced alias fails to parse; this constraint is also why cross-file sharing requires the name-based string reference instead, since anchors cannot span separate `.chezmoidata/` files

#### Scenario: Machine references shared data by name
- **WHEN** a machine section sets a property (e.g. `syncthing_folders`) to a bare string value
- **THEN** the consuming script SHALL treat that string as the name of a top-level chezmoi data key and SHALL resolve it by looking up the root template data for a key of that name
- **AND WHEN** the property is instead a list
- **THEN** the consuming script SHALL use that list directly as inline, machine-specific data without attempting name resolution

#### Scenario: Unresolvable reference fails the render
- **WHEN** a machine property's string value does not match any top-level chezmoi data key
- **THEN** the consuming script SHALL fail template rendering with an error naming the missing key
- **AND** SHALL NOT silently skip the operation that depends on the referenced data
