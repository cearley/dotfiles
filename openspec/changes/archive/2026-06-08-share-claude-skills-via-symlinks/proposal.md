## Why

Chezmoi-managed local skills (in `home/dot_claude/skills/`) are only deployed to `~/.claude/skills/`, so they are invisible to the `~/.claude-bedrock`, `~/.claude-personal`, and `~/.claude-work` environments. The existing npm-skills install script loops over all environments, but that loop is also redundant once skills directories are shared — all installs land in the same place.

## What Changes

- **New**: Add `symlink_skills.tmpl` to `home/dot_claude-bedrock/`, `home/dot_claude-personal/`, and `home/dot_claude-work/`, each pointing to `~/.claude/skills`. This mirrors the existing CLAUDE.md symlink pattern already used across all three env dirs.
- **Modified**: Simplify `run_onchange_after_darwin-37-install-claude-skills.sh.tmpl` — remove the per-environment loop for skill installation, since all `skills/` dirs will resolve to the same location. Install npm skills once (to `~/.claude`) instead of once per environment.
- **Transition**: A `run_onchange_before` script (or documented manual step) removes the existing real `skills/` directories in the env dirs so chezmoi can place the symlinks.

## Capabilities

### New Capabilities

None. This is a structural change to how an existing capability is implemented.

### Modified Capabilities

- `claude-environments`: Add requirement that the `skills/` directory in every declared Claude environment SHALL be a symlink to `~/.claude/skills/`, ensuring local and npm-installed skills are shared across all environments.
- `package-management`: Update the skills installation scenario to reflect that npm skills are installed once (to `~/.claude`) rather than once per environment, since the symlink structure makes per-env installation redundant.

## Non-goals

- Environment-specific skill sets (all environments continue to share the same skill pool).
- Changes to plugin installation (plugins use a different per-env mechanism and are unaffected).
- Changes to MCP server registration (per-env registration via `claude mcp add` is explicitly required and remains per-env).
- Support for non-Darwin platforms.

## Impact

- **`home/dot_claude-bedrock/`**, **`home/dot_claude-personal/`**, **`home/dot_claude-work/`**: Each gains a `symlink_skills.tmpl` source file.
- **`home/.chezmoiscripts/run_onchange_after_darwin-37-install-claude-skills.sh.tmpl`**: Per-env loop removed; `npx skills` commands target `~/.claude` only.
- **Transition**: Existing `~/.claude-personal/skills/` and `~/.claude-work/skills/` are real directories and must be removed before `chezmoi apply` can place symlinks. A `run_onchange_before` script handles this automatically.
- **No secret or permission implications**: Skills are read-only markdown/YAML files; the symlink target is user-owned.
- **Tags affected**: `ai` only (all affected scripts and structures are gated on the `ai` tag).
