# Proposal

## Why

Chezmoi currently owns every persona's user-level `CLAUDE.md`. It renders `~/.claude/CLAUDE.md` from `home/dot_claude/CLAUDE.md.tmpl` and symlinks `~/.claude-<name>/CLAUDE.md` to that file. Third-party tooling also treats this file as its own install target. `omc setup` (oh-my-claudecode) rewrites the whole file and refuses outright to write through a symlink (`Refusing symlink`, `dist/installer/claude-md-transaction.js:50` in OMC 5.4.0). The result is a tug-of-war that has already caused damage:

- In persona dirs, `omc setup` aborts on the symlink. A deterministic installer can't be told to "edit the real file instead", the way an LLM can.
- In the unnamed default (`~/.claude`), where the file is real, `omc setup` succeeded. On 2026-09-15 it replaced the chezmoi-rendered Global Preferences with the OMC block only. Since then, every persona has silently loaded *no* chezmoi preferences: no commit/push permission gates, no persona notes, no Basic Memory rules. `chezmoi status` shows `MM .claude/CLAUDE.md`. The original content survives only in `~/.claude/CLAUDE.md.backup.2026-09-15T13-07-17-*`.
- The next `chezmoi apply` would restore the preferences and wipe out the OMC block. The next `omc setup` would reverse that again.

The root cause is two owners for one file. Symlinks make it worse by collapsing all personas onto that one contested file.

## What Changes

- **Move** the chezmoi-managed global preferences out of `CLAUDE.md` and into a user-level rule: `home/dot_claude/rules/global-preferences.md.tmpl`, deployed to `~/.claude/rules/global-preferences.md`. Every persona already receives it through the existing `rules/` symlink. The rule has no `paths:` frontmatter, so it loads unconditionally at session start, as `CLAUDE.md` did.
- **BREAKING (ownership):** Chezmoi SHALL NOT manage any user-level `CLAUDE.md`, whether in `~/.claude` or in any `~/.claude-<name>`. Remove `home/dot_claude/CLAUDE.md.tmpl`, the three `home/dot_claude-<name>/symlink_CLAUDE.md.tmpl` files, and the `!.claude/CLAUDE.md` re-include in `home/.chezmoiignore.tmpl`. Each persona's `CLAUDE.md` becomes a real, tool-owned file (OMC, or anything else), or it stays absent.
- **Add** a darwin `run_onchange_after` migration script that deletes a persona's `CLAUDE.md` **only if it is a symlink** pointing at `~/.claude/CLAUDE.md`. Removing a `symlink_` source does not delete the deployed target, and `.chezmoiremove` would also delete a legitimate, tool-written real file.
- **Update** `claude-tooling.md.tmpl` so it describes only the steady state: `skills/` and `rules/` are shared, `CLAUDE.md` is per-persona, and the edit target for global preferences is `dot_claude/rules/global-preferences.md.tmpl`. Agent-read files make no mention of symlinked `CLAUDE.md` or of the migration, because that state never exists going forward and describing it would add noise to every session.
- **Document** a one-time, per-machine manual migration: apply, confirm the symlinks are gone, then re-run `omc setup` in each persona that uses OMC.

## Non-goals

- Changing the `skills/` or `rules/` directory symlinks. OMC doesn't write into them, and they're working.
- Managing or merging OMC's `CLAUDE.md` block from chezmoi. That means no `modify_CLAUDE.md` marker protocol and no use of OMC's `global-preserve` mode. The block belongs to OMC.
- Project-level `CLAUDE.md`/`AGENTS.md` files in repos.
- Automating `omc setup` per persona. It remains a manual, per-machine step.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
- `claude-environments`: add requirements that (a) global preferences are delivered as a shared user-level rule, (b) chezmoi does not manage any persona `CLAUDE.md`, and (c) legacy `CLAUDE.md` symlinks are removed without touching real files.
- `claude-tooling-rule`: the "persona sharing model" coverage changes from `skills/`, `rules/`, `CLAUDE.md` to `skills/` and `rules/` only, with `CLAUDE.md` classified as per-persona and tool-owned. The `sourceDir` convention reference moves from `CLAUDE.md.tmpl` to `global-preferences.md.tmpl`. The Path-Scoped Auto-Load Trigger gains `rules/`, and gets globs that actually match the `dot_claude`/`dot_claude-*` source trees, closing a spec-vs-frontmatter mismatch that predates this change.

## Impact

- **Tags:** `ai` only. Machines without `ai` are unaffected. Every machine with a non-empty `claude_envs` list (MacBook Pro, Mac Studio) runs the migration script.
- **Files:**
  - `home/dot_claude/CLAUDE.md.tmpl` is deleted, and its content moves to `home/dot_claude/rules/global-preferences.md.tmpl`.
  - `home/dot_claude-{personal,work,bedrock}/symlink_CLAUDE.md.tmpl` are deleted.
  - In `home/.chezmoiignore.tmpl`, the `!.claude/CLAUDE.md` line is removed.
  - `home/.chezmoiscripts/run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl` is new.
  - `home/dot_claude/rules/claude-tooling.md.tmpl` is edited.
  - In `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`, the header comment is edited and `CLAUDE.md` is dropped from its Bash-command pattern.
- **Live state:** Existing `~/.claude/CLAUDE.md` content (currently the OMC block) is left in place and becomes unmanaged. Persona `CLAUDE.md` symlinks are deleted. Personas without OMC end up with no `CLAUDE.md`, which is valid.
- **Behavior:** Global preferences start loading again in every persona, fixing the current silent loss. OMC's `CLAUDE.md` block now loads only in personas where `omc setup` has been run.
- **Security:** No secrets are involved. The migration script deletes only symlinks whose target is exactly `~/.claude/CLAUDE.md`. It never deletes regular files.
