# Design

## Context

Two independent, low-risk gaps surfaced by the `pilot-native-bm-checkpoint-chezmoi` pilot (see proposal.md - Why): `bm-checkpoint` has no `basicMemory.sessionProfile: coding` configuration for this project, so it writes prose instead of structured `coding_session` frontmatter; and `memory-doctor`, though installed and proven clean in the pilot, isn't called from anywhere routine. Both `bm-checkpoint` and `bm-orient` already document the config precedence they read (`${CLAUDE_CONFIG_DIR:-~/.claude}/settings.json`, then this project's `.claude/settings.json`, then `.claude/settings.local.json`, each overriding per key) and the exact keys (`primaryProject`, `sessionProfile`, `repository`, `placementConventions`, plus `secondaryProjects`/`recallTimeframe` for `bm-orient`). This project's own `.claude/settings.json` already exists, tracked in git, hand-authored directly — it is not rendered by any chezmoi `home/` template (that machinery targets deployed per-profile settings under `$HOME`, a different file). `save-session-maintenance` is a per-project rendered copy of `home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`, kept in sync across projects via `check-drift.sh update` and a `setup-memory-workflow-version:N` marker (currently `SMW_VERSION=20`).

## Goals / Non-Goals

**Goals:**
- Give `bm-checkpoint`/`bm-orient` enough project configuration to use the `coding` session profile correctly on `chezmoi`.
- Make `memory-doctor` a routine, zero-cost part of maintenance rather than a one-off pilot action.
- Keep both changes inside the existing ownership boundaries: hand-authored settings (never `bm-setup`), and a version-markered template change repairable via the existing `check-drift.sh update` path.

**Non-Goals:**
- Defining the exact JSON shape every project should use for `placementConventions` fleet-wide — this change only configures `chezmoi`'s own value.
- Rolling the `basicMemory` block out to any other installed project — each adopts it independently if it wants the `coding` profile.
- Changing `bm-orient`'s query model, or dual-tagging/migrating existing session-log notes so `bm-orient` can see them — that remains the deferred, bigger decision from the pilot findings.

## Decisions

**1. Config location: tracked `.claude/settings.json`, not `.claude/settings.local.json`.**
`repository` and `placementConventions` are facts about the project itself (its identity and note-placement conventions), not machine-local secrets or permissions — the same category of content already in that file (hooks, `enabledPlugins`). `.claude/settings.local.json` is gitignored and machine-specific; putting project identity there would mean every clone/machine has to re-derive it independently, with no shared source of truth. Alternative considered: `.claude/settings.local.json` — rejected because it doesn't travel with the repo.

**2. `primaryProject` is set explicitly, not left to auto-discovery.**
`bm-checkpoint`'s own instructions say to "discover and explicitly select the listed default or sole project when absent" — this project's basic-memory project is unambiguously `chezmoi`, so setting `primaryProject: chezmoi` explicitly removes a discovery step and matches how `bm-orient` scopes its queries (`primaryProject`, passed as `project`).

**3. `repository` value is the GitHub `owner/repo` slug, `cearley/dotfiles`.**
This matches the identifier already used in `reference/bm-1-workflow-implementation-handoff-2026-11-13` for commit URLs (`github.com/cearley/dotfiles/commit/...`), confirmed against `git remote get-url origin` (`https://github.com/cearley/dotfiles.git`). It is stable across clones (unlike a local path) and is what `bm-orient`'s coding-session query filters on.

**4. `memory-doctor` runs first in `save-session-maintenance`, as a new Step 0, and never blocks the rest of maintenance.**
Running it before the log-rollover/status-triage steps surfaces index problems that might otherwise make a mid-maintenance read look falsely short or stale. It stays strictly observational: per `memory-doctor`'s own skill contract, suggested fix commands are only run after separate user agreement, which is outside this already-bounded maintenance scope (the maintenance skill's own preflight already forbids expanding scope without asking) — so a finding is reported in the completion summary, not acted on.

**5. Version bump: `SMW_VERSION` 20 -> 21.**
Follows the existing mechanism exactly (same as the prior 18->19 and 19->20 bumps): bump the constant in `executable_check-drift.sh`, update the version marker the template embeds, and rely on `check-drift.sh update` to repair already-rendered per-project copies.

## Risks / Trade-offs

- [Risk] `placementConventions`'s value shape isn't fully documented upstream beyond "optional" (confirmed by reading the installed `bm-checkpoint`/`bm-orient` skill files; no schema is enumerated). -> Mitigation: write it as a short descriptive string of this project's actual conventions (checkpoints/sessions under `sessions/`, reference material under `reference/`, status under `status/`); since the skills already handle "no config" as a valid absent case, a plain descriptive value degrades safely even if the consuming skill does nothing more structured with it today.
- [Risk] Bumping `SMW_VERSION` touches a shared template whose drift-repair path (`check-drift.sh update`) also applies to every other project that installed this workflow, not just `chezmoi`. -> Mitigation: this is the same mechanism already exercised for the v20 bump; the change only adds a step to the template, it doesn't remove or restructure existing steps, so `update` in an unrelated project is low-risk. No other project is touched by this change itself — each applies `update` on its own schedule.
- [Risk] `memory-doctor` depends on the `bm`/`basic-memory` CLI being on `PATH`, same as the rest of this workflow's BM-dependent steps. -> Mitigation: the maintenance skill's existing preflight already stops on missing/incompatible prerequisites (installed CLI major 1, connected BM 1.x tools) before Step 1; the new Step 0 relies on that same preflight rather than duplicating its own check.

## Migration Plan

1. Commit the `basicMemory` block directly into this repo's `.claude/settings.json` (hand edit, no template involved).
2. Edit the canonical template (`assets/save-session-maintenance-skill.md.template`) to add the Step 0 `memory-doctor` check; bump `SMW_VERSION` in `executable_check-drift.sh`.
3. Run `check-drift.sh update` in this project (`chezmoi`) to repair its own already-rendered `.claude/skills/save-session-maintenance/SKILL.md` to the new version — same step already demonstrated for the v20 repair (commit `62b69ee`).
4. No rollback beyond reverting the commit(s): both changes are additive (a new optional config block, a new non-blocking maintenance step) with no consent, hook, or data-model change.
5. Other installed projects pick up the template bump whenever their own `check-drift.sh update` next runs; none is run as part of this change.
