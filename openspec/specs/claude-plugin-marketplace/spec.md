# claude-plugin-marketplace Specification

## Purpose
Registers a local Claude Code plugin marketplace pointing at this repo's own chezmoi source tree, so plugins defined inside this repo become installable and enablable without publishing anywhere or deploying their content through chezmoi's `home/` apply mechanism.
## Requirements
### Requirement: Marketplace source is a plain local path, not a published repo
The marketplace SHALL be declared as `.claude-plugin/marketplace.json` at the chezmoi source root, listing plugins by relative path within the repo, and SHALL NOT require a separate published git repository.

#### Scenario: Marketplace manifest resolves plugins by relative path
- **WHEN** `.claude-plugin/marketplace.json` lists the `basic-memory-workflow` plugin
- **THEN** its `source` is a relative path (e.g. `./plugins/basic-memory-workflow`) resolved against the marketplace root, not a git or npm source

### Requirement: Marketplace and plugin content are not chezmoi-templated
Files under `.claude-plugin/` and `plugins/` at the chezmoi source root SHALL be plain, non-templated repo content — chezmoi SHALL NOT apply, render, or otherwise deploy them into `$HOME`.

#### Scenario: chezmoi apply leaves plugin content untouched
- **WHEN** `chezmoi apply` runs on a machine with this repo as its source
- **THEN** `.claude-plugin/marketplace.json` and everything under `plugins/` are left exactly as they exist in the source tree — no rendering, no `executable_` handling, no copy into `$HOME`

### Requirement: Marketplace registration is chezmoi-bootstrapped and idempotent
A chezmoi `run_onchange_` script SHALL register the local marketplace with Claude Code by ensuring the chezmoi source directory's absolute path is present in the user-scope marketplace registry, without producing duplicate entries on repeated runs.

#### Scenario: First run on a machine
- **WHEN** the bootstrap script runs on a machine where the marketplace is not yet registered
- **THEN** it adds an entry for this repo's source path to the user-scope registry

#### Scenario: Re-run on an already-registered machine
- **WHEN** the bootstrap script runs again (e.g. after an unrelated `chezmoi apply`)
- **THEN** it detects the existing registration and makes no changes, producing no duplicate entry

### Requirement: Per-project plugin enablement is a separate, manual step
Registering the marketplace SHALL make the plugin installable, but SHALL NOT itself enable the plugin for any project — enabling a specific project happens independently, per the `setup-memory-workflow` capability's opt-in requirement.

#### Scenario: Marketplace registered but no project enabled
- **WHEN** the bootstrap script has registered the marketplace on a machine
- **THEN** no project's `enabledPlugins` is modified as a side effect — every project remains opted out until a human explicitly opts it in

