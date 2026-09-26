# Spec Delta

## Purpose

Lets chezmoi manage Claude Code "mods" — function-hooks plugins that a skills
directory auto-loads, distinct from marketplace-installed plugins — without
depending on a third-party installer CLI that cannot target this machine's
named personas.

## ADDED Requirements

### Requirement: Mod files are vendored via file-type externals
A Claude Code mod's plugin files (`.claude-plugin/plugin.json`,
`hooks/hooks.json`, and every hook module `hooks/hooks.json` names) SHALL be
declared as individual `type = "file"` entries in a `.chezmoiexternal.toml`
source, each targeting a path under `home/dot_claude/skills/<mod-name>/`
that mirrors the file's path within the upstream mod directory. Chezmoi
SHALL NOT invoke the upstream `claude-code-templates` CLI or any other
third-party installer to place these files.

#### Scenario: A mod's files land under the shared skills directory
- **WHEN** `chezmoi apply` runs on a darwin machine with the `ai` tag
- **THEN** every file the mod's `.chezmoiexternal.toml` entries declare
  exists at its declared path under `home/dot_claude/skills/<mod-name>/`,
  fetched directly from its upstream source URL rather than through the
  upstream CLI

#### Scenario: A vendored mod reaches every persona without a persona-specific entry
- **WHEN** a mod's files are vendored under `home/dot_claude/skills/<mod-name>/`
- **THEN** the same files are reachable through every declared persona's
  `skills/` symlink (per the `claude-environments` capability) with no
  additional externals entry required per persona

### Requirement: Function hooks are enabled machine-wide
`home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` SHALL export
`CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` on any machine where mods are vendored,
alongside the existing `CLAUDE_CONFIG_DIR` export, so every persona's
`claude` invocation has the flag mods require to load at all.

#### Scenario: The flag is present for every persona's shell
- **WHEN** a shell sources `dot_zshrc.tmpl` or `dot_bashrc.tmpl` on a machine
  with at least one vendored mod
- **THEN** `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` is exported as `1` in that
  shell's environment, regardless of which persona's `CLAUDE_CONFIG_DIR` is
  active

### Requirement: Each persona declares a vendored mod's non-secret options
For each vendored mod, every declared persona's `.claude-settings.json`
SHALL declare that mod's non-secret `pluginConfigs.<mod-name>.options` —
provider/backend selection, model or tier choices, thresholds, and routing
switches — following the existing `claude-settings-ledger` merge and
retraction semantics. This declaration SHALL be repeated per persona, not
centralized in one shared file, consistent with `settings.json` not being
symlinked across personas.

#### Scenario: A mod's non-secret options are present in every persona's live settings
- **WHEN** `chezmoi apply` runs on a darwin machine with the `ai` tag and a
  mod's options are declared in a persona's `.claude-settings.json`
- **THEN** that persona's live `settings.json` contains a matching
  `pluginConfigs.<mod-name>.options` entry after the run

### Requirement: A mod's secret credentials are never chezmoi-managed
No `.claude-settings.json` source file SHALL declare a value for any
`userConfig` field a mod's `.claude-plugin/plugin.json` marks `sensitive`.
Such a field SHALL be left unset by chezmoi and configured by the user
through Claude Code's own runtime configuration UI, relying on the
`claude-settings-ledger` capability's preservation of runtime-added keys
across `chezmoi apply`.

#### Scenario: Chezmoi apply never introduces or removes a sensitive field
- **WHEN** `chezmoi apply` runs after a user has set a mod's sensitive
  `userConfig` field (e.g. an API key) through Claude Code's `/config`
- **THEN** that field's live value is unchanged by the run, and no
  `.claude-settings.json` source file contains that field or its value
