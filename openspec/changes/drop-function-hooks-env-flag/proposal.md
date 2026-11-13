# Proposal

## Why

`home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` export `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1` on `ai`-tagged machines because the `claude-function-hooks-mods` spec requires it: when `jev-model-router` was first vendored (2026-09-26), Claude Code only loaded function-hooks mods behind that rollout flag (2.1.259+).

That is no longer true. Mods are on by default from Claude Code 2.1.287, and the upstream mod's README and header comment were updated accordingly in `davila7/claude-code-templates` PR #1083 (2026-10-04): the flag no longer appears in its setup instructions, and the only requirement is `claude` >= 2.1.287. The pinned SHA in `home/dot_claude/.chezmoiexternal.toml.tmpl` was moved to `9b6d5eb8` (HEAD of `main` on 2026-11-13), which carries that change, and this machine runs Claude Code 2.1.323.

The export is now dead configuration. It is harmless today, but it keeps a stale requirement alive in the spec, misleads anyone reading the shell rc files about what mods need, and would mask a real loading problem (a reader would check the flag first instead of the Claude Code version).

## What Changes

- Remove the `{{- if has "ai" .tags }} export CLAUDE_CODE_ENABLE_FUNCTION_HOOKS=1 {{- end }}` block from `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl`.
- Remove the "Function hooks are enabled machine-wide" requirement from `openspec/specs/claude-function-hooks-mods/spec.md` and replace it with a requirement that records the actual precondition: a minimum Claude Code version, stated next to the mod's externals entry so the SHA-update procedure keeps it current.
- Add a one-line note to the `jev-model-router` comment block in `home/dot_claude/.chezmoiexternal.toml.tmpl` naming the minimum Claude Code version the pinned upstream commit documents (2.1.287 as of SHA `9b6d5eb8`).

## Non-goals

- Changing which mods are vendored, their pinned SHA (already updated separately), or their `pluginConfigs` options.
- Supporting Claude Code builds older than 2.1.287. Claude Code self-updates; no `ai`-tagged machine is expected to run an older build, and the mod simply does not load there.
- Touching the `CLAUDE_CONFIG_DIR` export or the `ccenv` profile manager that sits next to the removed block.
- Removing the flag from the archived change `2026-09-26-chezmoi-manage-jev-model-router`; archives are history.

## Capabilities

### Modified Capabilities
- `claude-function-hooks-mods`: drops the machine-wide environment-flag requirement; adds a Claude Code minimum-version requirement tied to the externals entry.

## Impact

- **Modified:** `home/dot_zshrc.tmpl`, `home/dot_bashrc.tmpl`, `home/dot_claude/.chezmoiexternal.toml.tmpl` (comment only), `openspec/specs/claude-function-hooks-mods/spec.md` (via this change's delta on archive).
- **Tags:** `ai` only. Machines without the tag never rendered the block.
- **Rollback:** if a machine on Claude Code < 2.1.287 is found, `claude update` is the fix, not re-adding the export.
- **Security:** none. The flag gated loading of code that is already vendored and pinned; removing the export does not change what runs, only removes a no-op variable from every interactive shell.
