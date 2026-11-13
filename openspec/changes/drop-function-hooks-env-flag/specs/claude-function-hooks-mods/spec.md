# claude-function-hooks-mods Specification (Delta)

## REMOVED Requirements

### Requirement: Function hooks are enabled machine-wide
~~`home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` SHALL export `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` on any machine where mods are vendored, alongside the existing `CLAUDE_CONFIG_DIR` export, so every profile's `claude` invocation has the flag mods require to load at all.~~

**Reason:** Claude Code loads function-hooks mods by default from 2.1.287; the rollout flag is ignored. Upstream `jev-model-router` dropped it from its requirements in `davila7/claude-code-templates` PR #1083 (2026-10-04), which the pinned SHA `9b6d5eb8` includes.

#### Scenario: The flag is present for every profile's shell
~~- **WHEN** a shell sources `dot_zshrc.tmpl` or `dot_bashrc.tmpl` on a machine with at least one vendored mod~~
~~- **THEN** `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` is exported as `1` in that shell's environment, regardless of which profile's `CLAUDE_CONFIG_DIR` is active~~

## ADDED Requirements

### Requirement: Mod loading depends on the Claude Code version, not an environment flag

The shell rc templates SHALL NOT export `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS`. The comment block above a vendored mod's entries in `home/dot_claude/.chezmoiexternal.toml.tmpl` SHALL state the minimum Claude Code version the pinned upstream commit documents, and the SHA-update procedure in `external-dependency-pinning` SHALL include re-checking that version when the pin moves.

#### Scenario: No rollout flag in any profile's shell
- **WHEN** `tests/run-template home/dot_zshrc.tmpl` or `tests/run-template home/dot_bashrc.tmpl` renders on an `ai`-tagged machine
- **THEN** the rendered output contains no `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` line

#### Scenario: A vendored mod still loads without the flag
- **WHEN** `claude --debug hooks` starts on a machine running Claude Code >= 2.1.287 with `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS` unset
- **THEN** the debug log reports `hooks module jev-model-router@skills-dir loaded` and the mod prints its `ready on` line on the first prompt

#### Scenario: The minimum version is recorded beside the pin
- **WHEN** the `$modBase` SHA in `home/dot_claude/.chezmoiexternal.toml.tmpl` is updated
- **THEN** the comment block above the mod's entries names the minimum Claude Code version that commit's README or hook header states
