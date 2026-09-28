# Claude Repo Permission Patterns Specification

## Purpose

Provides three reusable, chezmoi-templated Claude Code permission postures (approval-first, curated allow-list, sandboxed full-auto) and an explicit, repeatable way to stamp one into a project repo's local settings, replacing ad hoc accretion of `.claude/settings.local.json`.

## Requirements

### Requirement: Three permission-pattern templates
Chezmoi SHALL provide three reusable templates under `home/.chezmoitemplates/`, one per pattern (A: approval-first, B: curated allow-list, C: sandboxed full-auto), each rendering a JSON object containing only a `permissions` key (`defaultMode`, and `allow`/`ask`/`deny` arrays) in `settings.json`'s own shape. No template SHALL declare `hooks`, `pluginConfigs`, `env`, or any other top-level key outside `permissions`.

#### Scenario: Pattern A renders an approval-first posture
- **WHEN** the Pattern A template is rendered
- **THEN** the output is a JSON object whose `permissions.defaultMode` is a mode that prompts on unlisted actions, with an explicit `deny` list covering destructive operations, and no `allow` entries that bypass that prompting

#### Scenario: Pattern B renders a curated allow-list posture
- **WHEN** the Pattern B template is rendered
- **THEN** the output is a JSON object whose `permissions.allow` lists specific, individually-reasoned safe operations (e.g. test runners, linters, read-only commands) and whose `defaultMode` still prompts for anything not listed

#### Scenario: Pattern C renders a sandboxed full-auto posture
- **WHEN** the Pattern C template is rendered
- **THEN** the output is a JSON object whose `permissions.defaultMode` is `bypassPermissions`

### Requirement: Explicit, repo-local stamping
A stamping mechanism SHALL write one selected pattern's rendered `permissions` block into the current repository's `.claude/settings.local.json`. The mechanism SHALL require an explicit pattern argument (`a`, `b`, or `c`); it SHALL NOT infer a pattern from the working directory, git remote, branch name, or any other automatic signal.

#### Scenario: Explicit selection required
- **WHEN** the stamping mechanism is invoked without a pattern argument
- **THEN** it SHALL fail with an error naming the accepted values, and SHALL NOT write any file

#### Scenario: Stamping a repo with no existing local settings
- **WHEN** the stamping mechanism is invoked with a valid pattern argument in a repository whose `.claude/settings.local.json` does not yet exist
- **THEN** it SHALL create the file containing exactly that pattern's rendered `permissions` block

### Requirement: Non-destructive merge into existing local settings
When `.claude/settings.local.json` already exists, the stamping mechanism SHALL merge the chosen pattern's `permissions.allow`/`ask`/`deny` arrays into the existing arrays as a union (preserving pre-existing entries), and SHALL overwrite only the `permissions.defaultMode` scalar. The mechanism SHALL NOT remove or alter any key outside `permissions` (e.g. `hooks`, `enabledPlugins`) already present in the file.

#### Scenario: Re-applying the same pattern is idempotent
- **WHEN** the stamping mechanism is invoked twice in a row with the same pattern argument
- **THEN** the resulting `.claude/settings.local.json` after the second run is byte-identical in its `permissions` content to after the first run

#### Scenario: Existing unrelated allow entries survive
- **WHEN** `.claude/settings.local.json` already contains `permissions.allow` entries not present in the chosen pattern
- **THEN** after stamping, those entries SHALL still be present in `permissions.allow`

### Requirement: Independence from the persona settings ledger
Applying a permission pattern SHALL NOT read, write, or otherwise affect any persona's `~/.claude*/settings.json`, its `_chezmoiManaged` ledger, or any file under `home/dot_claude*/`. Persona selection (`CLAUDE_CONFIG_DIR`) and permission-pattern selection SHALL remain independent: choosing a persona SHALL NOT imply or constrain which pattern, if any, is stamped into a given repo.

#### Scenario: Stamping does not touch persona settings
- **WHEN** the stamping mechanism is invoked from within any persona (`~/.claude`, `-work`, `-personal`, `-bedrock`)
- **THEN** no file under that persona's `CLAUDE_CONFIG_DIR` is read or modified

### Requirement: Pattern C requires evidence of container isolation
Before writing Pattern C's `permissions` block, the stamping mechanism SHALL check for evidence that the current process is running inside an isolated container (e.g. a container marker file, or an explicit override flag the caller supplies deliberately). When no such evidence is found, the mechanism SHALL refuse to write the Pattern C block and SHALL print a warning explaining that `bypassPermissions` on a bare host is unsafe, referencing the companion container template.

#### Scenario: Pattern C refused on a bare host
- **WHEN** the stamping mechanism is invoked with pattern `c` and no container-isolation evidence is present
- **THEN** it SHALL NOT write `.claude/settings.local.json` and SHALL exit with a non-zero status and an explanatory warning

#### Scenario: Pattern C allowed inside a detected container
- **WHEN** the stamping mechanism is invoked with pattern `c` and container-isolation evidence is present
- **THEN** it SHALL write Pattern C's `permissions` block as normal

### Requirement: Pattern C container template
Chezmoi SHALL provide a reusable container/devcontainer definition template for Pattern C, configured to run as a non-root user, bind-mount only the target repository's working tree, and mount no host credential stores (e.g. `$HOME`, SSH keys, cloud credential directories) by default.

#### Scenario: Container template excludes host credentials
- **WHEN** the Pattern C container template is rendered
- **THEN** its mount/volume configuration includes only the target repository's working tree and excludes `$HOME` and any credential-bearing path

### Requirement: Tag-gated availability
The permission-pattern templates and the stamping mechanism SHALL be available only on machines tagged `ai`, matching the existing gate on persona settings (`claude-settings-ledger`). The Pattern C container template and any container-runtime tooling it depends on SHALL additionally require the `dev` tag.

#### Scenario: Unavailable without the ai tag
- **WHEN** `chezmoi apply` runs on a machine without the `ai` tag
- **THEN** none of the permission-pattern templates or the stamping mechanism are deployed
