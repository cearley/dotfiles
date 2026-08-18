## Why

Claude Code tooling knowledge (the packages.yaml cross-check model, native-vs-external skill sources, MCP/plugin install model, persona symlink model) currently lives in `home/dot_claude/skills/CLAUDE.md`, a chezmoi-ignored, source-tree-only file. It only reaches the model via Claude Code's directory-scoped auto-load, which fires solely when Claude happens to read a file under `home/dot_claude/skills/` in the source tree — a narrow trigger that rarely coincides with the actual moments this knowledge is needed (diagnosing installation health, editing `settings.json`/`.claude.json`, running `/doctor`). Claude Code's native user-level rules mechanism (`~/.claude/rules/`, `paths:`-scoped frontmatter, same symlink-sharing model already used for `skills/`) can trigger reliably on the files that actually signal this kind of work, on every persona, in every project — not just when editing the skill source itself.

## What Changes

- Add `home/dot_claude/rules/claude-tooling.md.tmpl`, deployed to `~/.claude/rules/claude-tooling.md` and shared across personas via symlink (mirroring `skills/`). Content is migrated from `home/dot_claude/skills/CLAUDE.md` plus the "before disabling anything" bullet currently in `home/dot_claude/CLAUDE.md.tmpl`, rewritten to use `{{ .chezmoi.sourceDir }}` for path references.
- The new rule's `paths:` frontmatter scopes its auto-load to files that signal installation-health/diagnosis work: `settings.json`, `.claude.json`, `packages.yaml`, deployed `skills/`/`plugins/`/`CLAUDE.md`, and the `dot_claude/`/`dot_claude-*/` source trees — a broader and more reliable trigger set than the current "happens to be reading skills source" behavior.
- Trim `home/dot_claude/CLAUDE.md.tmpl`: remove the "before disabling anything" bullet (now covered by the rule) and the trailing pointer sentence in the persona-awareness block that references `skills/CLAUDE.md`. The persona-awareness paragraph itself stays always-loaded — unchanged.
- Add `symlink_rules.tmpl` (pointing at `{{ .chezmoi.homeDir }}/.claude/rules`) to each of `home/dot_claude-personal/`, `home/dot_claude-work/`, `home/dot_claude-bedrock/`, mirroring the existing `symlink_skills.tmpl` in each.
- Update `home/.chezmoiignore.tmpl`: add `!.claude/rules/` to the `.claude/*` allow-list so the new directory deploys; remove the now-unneeded `.claude/skills/CLAUDE.md` ignore line.
- Delete `home/dot_claude/skills/CLAUDE.md`.
- No hook of any kind is introduced. (An earlier version of this proposal considered a `UserPromptSubmit` hook triggered on `/doctor`; research during design confirmed `UserPromptSubmit` hooks support no `matcher`, and the `hookify` plugin has no file-content-injection capability, so the native path-scoped rules mechanism replaces that idea entirely.)

## Capabilities

### New Capabilities
- `claude-tooling-rule`: The user-level Claude Code rule that surfaces installation-health/skill-MCP-plugin diagnostic guidance, including its `paths:`-scoped trigger conditions and required content coverage.

### Modified Capabilities
- `claude-environments`: Adds a "Shared Rules Directory via Symlink" requirement mirroring the existing "Shared Skills Directory via Symlink" requirement — every declared Claude environment directory gets a `rules/` symlink to `~/.claude/rules/`, not just `skills/`.

## Impact

- **New**: `home/dot_claude/rules/claude-tooling.md.tmpl`, `home/dot_claude-personal/symlink_rules.tmpl`, `home/dot_claude-work/symlink_rules.tmpl`, `home/dot_claude-bedrock/symlink_rules.tmpl`
- **Modified**: `home/dot_claude/CLAUDE.md.tmpl`, `home/.chezmoiignore.tmpl`
- **Deleted**: `home/dot_claude/skills/CLAUDE.md`
- **Tags affected**: `ai` only (same gating as the rest of this tree) — no new tag, no `packages.yaml` change, no new secrets, no SIP/permission implications.
- **Personas affected**: all three (`dot_claude-personal`, `dot_claude-work`, `dot_claude-bedrock`) plus the unnamed default `~/.claude`, consistent with how `skills/` is already shared.
