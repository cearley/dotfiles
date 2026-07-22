# Delta: Package Management — Extract Package-Layer Iteration Partial

## ADDED Requirements

### Requirement: Single Source of Category Eligibility Resolution
Category/tag eligibility resolution — determining which `packages.yaml` categories contribute items for a given key on this machine — SHALL be implemented in exactly one reusable template partial, `home/.chezmoitemplates/package-layer-items`. The partial SHALL accept a `key` parameter (the `packages.yaml` key to resolve, e.g. `bun`, `uv`, `sdkman`, `cargo`, `taps`, `brews`, `casks`, `mas`, `brew_env`) and an optional `includeCore` parameter (default `true`), and SHALL return a JSON array of `{"category": <name>, "items": <value>}` objects.

#### Scenario: Eligible categories resolved with core included
- **WHEN** the partial is invoked with `includeCore` true (or omitted)
- **THEN** it SHALL iterate `core` followed by `.tag_choices` in order
- **AND** SHALL include a category's entry when the category is `core` or is present in the machine's selected `.tags`
- **AND** SHALL include only categories where the requested key exists and its value is non-empty

#### Scenario: Core excluded for layers without core packages
- **WHEN** the partial is invoked with `includeCore` false
- **THEN** it SHALL iterate `.tag_choices` only
- **AND** SHALL include a category's entry only when the category is present in the machine's selected `.tags`

#### Scenario: Category order is deterministic
- **WHEN** the partial returns multiple category groups
- **THEN** the JSON array order SHALL match iteration order (`core` first when included, then `.tag_choices` order)
- **AND** items within each group SHALL preserve their `packages.yaml` order

#### Scenario: Values pass through unmodified
- **WHEN** the requested key holds a list (e.g. `brews`) or a mapping (e.g. `brew_env`)
- **THEN** the partial SHALL emit the value as-is in the `items` field without transforming entries

### Requirement: Package-Layer Scripts Consume the Shared Partial
All package-layer installation scripts (positions 23–27) SHALL obtain their per-category package items exclusively via the `package-layer-items` partial. Scripts SHALL NOT inline the category/tag eligibility iteration. Per-layer concerns — install command, tool bootstrap, skip-layer gating, and output line format (including Brewfile `trusted:` annotations and iCloud-gated `mas` entries) — SHALL remain in the individual scripts.

#### Scenario: Simple layers range over partial output
- **WHEN** the SDKMAN (24), UV (25), Bun (26), or Cargo (27) script renders install commands
- **THEN** it SHALL call the partial with its layer key (`cargo` with `includeCore` false; others with the default)
- **AND** SHALL render one install command per item from the returned groups, preserving the per-category comment headers

#### Scenario: Homebrew script uses the partial for every category iteration
- **WHEN** the Homebrew script (23) renders category-scoped taps, brews, casks, mas entries, or merges `brew_env`
- **THEN** each of those sections SHALL consume the partial's output rather than an inline category loop
- **AND** layer-specific rendering (`trusted: true` annotations, Brewfile syntax, skipping `mas` when not signed into iCloud) SHALL be applied by the script when ranging the returned items

#### Scenario: Refactor preserves rendered output
- **WHEN** the refactored scripts are rendered via `tests/run-template` for the machine's current tag set
- **THEN** the generated shell output SHALL be byte-identical to the pre-refactor baseline
