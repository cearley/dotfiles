# Design

## Context

See proposal.md, "Why", for the ownership conflict and the current damage. Two constraints shape the approach:

- Claude Code loads every user-level `rules/*.md` that has no `paths:` frontmatter at session start, at the same user-memory tier as `CLAUDE.md`. Each persona already reaches `~/.claude/rules/` through `symlink_rules.tmpl`. `claude-tooling.md` is delivered this way today (it's path-scoped, but it proves that directory-symlink resolution works).
- Chezmoi deletes nothing when a `symlink_` source file is removed. The deployed link simply becomes unmanaged. `.chezmoiremove` would delete the path whatever it is, including a real `CLAUDE.md` that OMC writes later.

## Goals / Non-Goals

**Goals:**
- Give every Claude Code config directory exactly one owner per file: chezmoi owns `rules/global-preferences.md`, and tools own `CLAUDE.md`.
- Make the migration safe to run repeatedly, and make sure it never destroys a tool-written file.

**Non-Goals:**
- Recovering OMC's block into personas automatically. That's a manual `omc setup` per persona.
- Deduplicating OMC content across personas.

## Decisions

### D1. Deliver preferences as `rules/global-preferences.md`, not an `@import` in CLAUDE.md
- **Chosen:** Move the template body verbatim (including the `has "ai" .tags` guard and the `claudeEnvs`/`sourceDir` variables) to `home/dot_claude/rules/global-preferences.md.tmpl`, with no frontmatter.
- **Alternative: a chezmoi-owned `CLAUDE.md` containing `@~/.claude/global-preferences.md`.** Rejected. It still puts chezmoi and OMC on the same file, and OMC's overwrite mode reorders or rewrites the file.
- **Alternative: `modify_CLAUDE.md.tmpl` managing a marker block.** Rejected. It requires a merge protocol against a tool that also rewrites the file wholesale. Every OMC upgrade would risk the two tools fighting over the file again.
- **Alternative: OMC `global-preserve` mode (`CLAUDE-omc.md` plus an import).** Rejected. It still writes the main `CLAUDE.md`, still refuses symlinks, and still conflicts with chezmoi's ownership.

### D2. Stop managing `~/.claude/CLAUDE.md` too, not only the persona symlinks
- The unnamed default is where the actual clobbering happened. Leaving it chezmoi-managed would keep the `MM` tug-of-war running there.
- Removing `!.claude/CLAUDE.md` from `.chezmoiignore.tmpl` makes `.claude/*` ignore the path, which is belt-and-braces. Removing the template makes it unmanaged anyway, but the ignore also prevents an accidental `chezmoi add` from re-managing it.
- The live file's current content (the OMC block) stays in place untouched.

### D3. A symlink-only removal script instead of `.chezmoiremove`
- New file: `run_onchange_after_darwin-44-migrate-claude-md-symlinks.sh.tmpl`. Position 44 is free, and it sits after the Claude block (36–41).
- The script is wrapped in the darwin conditional and the `ai` tag, and it follows the shared-utilities messaging convention.
- It loops over `claude_envs` from `machine-settings`. For each entry, it removes `<dir>/CLAUDE.md` only when `[ -L ]` is true and `readlink` equals `$HOME/.claude/CLAUDE.md`. Anything else is logged and skipped.
- It uses `run_onchange_`, keyed on the rendered persona list, so it re-runs when a persona is added. It's idempotent.
- **Alternative: `.chezmoiremove`.** Rejected, because it can't tell a symlink from a real file. After OMC writes a real file, the next apply would delete it.

### D4. No ongoing detector for a symlinked `CLAUDE.md`
- **Chosen:** Script 44 does the one-time migration, and nothing checks for the old layout afterwards.
- **Alternative: a `claude-md-symlink` drift kind in `check-claude-overrides`.** This was implemented and then removed during apply. It guarded only against a regression of this migration, so in the steady state it would never fire. Its code, help text, `--fix` branch and rule documentation would still be present in every session. That's speculative scope.

### D5. Text updates that follow from the move
- `claude-tooling.md.tmpl` changes in several places:
  - **Intro (line 14):** The ownership claim currently names "CLAUDE.md" among the chezmoi-managed items. Replace that with the global-preferences rule, and add that each persona's `CLAUDE.md` is tool-owned.
  - **"Personas Share Skills, Rules, and CLAUDE.md via Symlink":** Rename the section to "Personas Share Skills and Rules via Symlink", and update the line-32 cross-reference to match.
  - **Writing principle for agent-read text:** describe only the steady state. Keep a sentence only if an agent would act wrongly without it in that state. No history, no symlink or migration talk, and no guards against states that never occur.
  - **"Not a local file" paragraph:** Delete it. It existed only because a symlink made checked-in content look local. Without that symlink there's no misleading case to explain.
  - **Edit target:** One sentence in the intro, "Global preferences are the rule `rules/global-preferences.md`; edit `…/global-preferences.md.tmpl`, not any `CLAUDE.md`", plus one generic line saying the source under `dot_claude/` is the edit target for deployed `skills/` and `rules/`. This fact passes the writing test, because without it an agent would naturally edit `~/.claude/CLAUDE.md`.
  - **"What's not shared" list:** Add `CLAUDE.md`.
  - **`paths:` frontmatter:**
    - Keep `**/.claude*/CLAUDE.md`, so touching a persona's `CLAUDE.md` still loads the rule that explains who owns it.
    - Add `**/.claude*/rules/**`. An agent editing the deployed `global-preferences.md` then loads the rule and gets redirected to the source template.
    - Add `**/dot_claude/**` and `**/dot_claude-*/**`. This closes a spec/implementation mismatch that predates this change: the spec already requires the rule to load for the chezmoi source trees, but no existing glob matches them, because `.claude*` doesn't match `dot_claude`.
    - Add `**/.chezmoidata/packages.yaml`. The spec lists `packages.yaml` as a trigger, but no glob matched it, which is the same kind of mismatch as the source trees. It was found during apply.
    - Trade-off: `**/.claude*/rules/**` also matches project-level `.claude/rules/` directories, such as this repo's own. The existing `**/.claude*/settings.json` glob already has that behavior, and the cost is a little extra context. Accepted.
- In `global-preferences.md.tmpl`, the persona bullet drops `CLAUDE.md` from the symlinked set and adds it to the per-persona list. Nothing else changes.
- In `executable_claude-tooling-write-guard.tmpl`, the header comment lists `rules/` in place of `CLAUDE.md`, and adds no explanation. Its behavior already resolves paths via `chezmoi managed`, so an unmanaged `CLAUDE.md` simply isn't guarded, which is the intended outcome. Its Bash `broad_pattern` also drops `CLAUDE\.md`. Otherwise the once-per-session nudge would call a tool-owned file chezmoi-managed. This was found during apply.

## Risks / Trade-offs

- **[Risk]** Rule-loading semantics differ subtly from `CLAUDE.md`, for example in ordering or in how `/memory` displays them. → **Mitigation:** Verify with `/memory` or `/context` in one persona after apply that `global-preferences.md` is listed as loaded.
- **[Risk]** A persona without OMC ends up with no `CLAUDE.md`. → This is intended. Preferences come from the rule.
- **[Risk]** OMC's `CLAUDE.md` content is duplicated per persona, and upgrades require `omc setup` in each one. → This is accepted. That's the cost of letting the tool own its file, and it's a rare manual step.
- **[Risk]** Someone recreates the symlink by hand. → Accepted without a detector (D4). `omc setup` fails loudly on a symlink, so the regression can't go unnoticed.
- **[Trade-off]** The loss of preferences since 2026-09-15 isn't repaired until this change is applied. → The migration plan below includes the apply, and a stop-gap is available.

## Migration Plan

Run these steps once on each machine (MacBook Pro, Mac Studio):

1. `chezmoi apply`. This deploys `rules/global-preferences.md` and runs script 44, which removes the persona `CLAUDE.md` symlinks. `~/.claude/CLAUDE.md` becomes unmanaged, and its content is untouched.
2. Verify:
   - `chezmoi managed | grep CLAUDE.md` returns nothing.
   - `find ~/.claude-* -maxdepth 1 -name CLAUDE.md -type l` returns nothing.
3. In each persona that uses OMC, start `claude` under that `CLAUDE_CONFIG_DIR` and run `/oh-my-claudecode:omc-setup`. It now writes a real per-persona `CLAUDE.md`.
4. Optionally, delete `~/.claude/CLAUDE.md.backup.2026-09-15T13-07-17-*` once `global-preferences.md` is confirmed loaded.
5. On persona dirs, `CLAUDE.md.bak.*` files such as `~/.claude-bedrock/CLAUDE.md.bak.5.4.0` are OMC leftovers. Leave them; they're harmless.

**Rollback:** `git revert` the change, then `chezmoi apply`. That restores the template and symlinks. For any persona where OMC wrote a real `CLAUDE.md`, the `symlink_` apply would prompt or fail, so delete that file first.
