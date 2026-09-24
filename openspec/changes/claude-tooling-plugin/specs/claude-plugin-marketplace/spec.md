# Spec Delta

## ADDED Requirements

### Requirement: Self-authored plugins may be installed in every persona
A self-authored plugin in the marketplace MAY be declared in `packages.yaml`'s
`claude_code.plugins` list, in which case the plugin install script SHALL install it at user
scope in every declared persona and the unnamed default. Registering the marketplace alone
SHALL still enable no plugin; only a `packages.yaml` declaration does.

#### Scenario: Declared plugin installed everywhere
- **WHEN** `claude-tooling@chezmoi-personal` is declared in `packages.yaml`
- **AND** `chezmoi apply` runs on a darwin machine tagged `ai`
- **THEN** every persona SHALL list the plugin as installed at user scope

#### Scenario: Undeclared self-authored plugin stays opt-in
- **WHEN** a self-authored plugin such as `serena` is not declared in `packages.yaml`
- **THEN** no persona's user-scope `enabledPlugins` SHALL include it as a side effect of
  `chezmoi apply`

### Requirement: Self-authored plugins may use a content-derived version
A self-authored plugin MAY derive its `plugin.json` `version` from a hash of its source
files, via the shared `plugin-content-hash` template. A plugin that does SHALL also be
updated in each persona where it is installed whenever that hash changes. Plugins that do
not SHALL keep a manually bumped version.

#### Scenario: Content change reaches installed personas
- **WHEN** a file in a content-hash-versioned plugin changes
- **AND** `chezmoi apply` runs
- **THEN** each persona where the plugin is installed SHALL record the new version in its
  `installed_plugins.json`

#### Scenario: Manually versioned plugins unaffected
- **WHEN** a manually versioned plugin such as `browser-tools` has an unchanged `version`
- **THEN** `chezmoi apply` SHALL NOT update it in any persona
