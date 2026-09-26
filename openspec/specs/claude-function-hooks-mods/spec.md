# claude-function-hooks-mods Specification

## Purpose

Lets chezmoi manage Claude Code "mods" — function-hooks plugins that a skills
directory auto-loads, distinct from marketplace-installed plugins — without
depending on a third-party installer CLI that cannot target this machine's
named personas.

## Requirements

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
SHALL declare that mod's non-secret `pluginConfigs."<mod-name>@skills-dir".options`
— provider/backend selection, model or tier choices, thresholds, and routing
switches — following the existing `claude-settings-ledger` merge and
retraction semantics. This declaration SHALL be repeated per persona, not
centralized in one shared file, consistent with `settings.json` not being
symlinked across personas.

**Correction (2026-09-26, post-archive):** the key MUST be the full loaded
plugin id, `<mod-name>@skills-dir` — not the bare `<mod-name>` the original
implementation used. Confirmed via `claude --debug hooks --debug-file
<path>`: Claude Code logs `no pluginConfigs["<name>@<source>"].options in
user, --settings or managed settings` when resolving a plugin's options —
it is keyed by the loaded id, never the bare manifest name. Options
declared under the bare name are silently never read; only a
`/plugin configure`-set sensitive field (stored outside `settings.json`
entirely, see the requirement below) still reaches the mod, which is what
made the bug hard to notice — the mod loads and announces normally, and a
key set via `/plugin configure` still works, but every non-secret override
(base URL, tier models, thresholds) silently falls back to its schema
default. Verified live for `jev-model-router@skills-dir`: renaming the
settings key from `jev-model-router` to `jev-model-router@skills-dir` was
the difference between the mod calling TypeSafe's default endpoint (wrong,
401) and the configured OpenRouter endpoint (right, 200, real routing
decision applied).

#### Scenario: A mod's non-secret options are present in every persona's live settings
- **WHEN** `chezmoi apply` runs on a darwin machine with the `ai` tag and a
  mod's options are declared in a persona's `.claude-settings.json`
- **THEN** that persona's live `settings.json` contains a matching
  `pluginConfigs."<mod-name>@skills-dir".options` entry after the run, and
  the mod's own debug log (`claude --debug hooks`) shows it reading the
  declared values rather than falling back to schema defaults

### Requirement: A mod's secret credentials are never chezmoi-managed
No `.claude-settings.json` source file SHALL declare a value for any
`userConfig` field a mod's `.claude-plugin/plugin.json` marks `sensitive`.
Such a field SHALL be left unset by chezmoi and configured by the user
through Claude Code's `/plugin configure <mod-name>@skills-dir` command,
which stores the value in the OS secure store (e.g. the macOS Keychain),
not in `settings.json` — `/config` does not apply here, since it never
shows a row for any `sensitive`-marked option, for any plugin.

#### Scenario: Chezmoi apply never introduces or removes a sensitive field
- **WHEN** `chezmoi apply` runs after a user has set a mod's sensitive
  `userConfig` field (e.g. an API key) via
  `/plugin configure <mod-name>@skills-dir`
- **THEN** that field's live value (held outside `settings.json`, in the OS
  secure store) is unaffected by the run, and no `.claude-settings.json`
  source file contains that field or its value
