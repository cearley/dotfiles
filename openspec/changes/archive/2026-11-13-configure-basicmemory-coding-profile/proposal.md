# Proposal

## Why

Stage 2 (`pilot-native-bm-checkpoint-chezmoi`, archived) installed upstream's `bm-checkpoint`, `bm-orient` and `memory-doctor` skills and ran a real pilot on the `chezmoi` project itself. The pilot's write-up (`reference/pilot-native-bm-checkpoint-chezmoi-findings-2026-11-14` in the `chezmoi` basic-memory project) found two concrete, low-risk gaps worth closing now, independent of the larger open question (whether `bm-orient` can ever see this project's existing session-log/status-note backlog): `bm-checkpoint` defaulted to its `general` profile and wrote git/branch/SHA context as prose, because no `basicMemory.sessionProfile: coding` configuration exists for this project; and `memory-doctor`'s clean, zero-cost pilot run was never actually wired into any recurring workflow step, so nothing routinely benefits from it going forward.

## What Changes

- Add a `basicMemory` configuration block to this project's tracked `.claude/settings.json` (`sessionProfile: coding`, `repository`, `placementConventions`), hand-authored and committed like the rest of that file — not written by BM's `bm-setup` skill, per the boundary `pilot-native-bm-checkpoint-chezmoi` already established. This lets `bm-checkpoint` write structured `coding_session` frontmatter (`repository`, `repo_root`, `branch`, `git_sha`, etc.) instead of prose, for any future checkpoint on this project.
- Add a `memory-doctor` health-check step to the canonical `save-session-maintenance` skill template (`home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`), run unconditionally and read-only, with its findings reported alongside the rest of the maintenance summary. Bump `SMW_VERSION` so `check-drift.sh update` repairs existing per-project rendered copies (as already demonstrated for the v20 bump).
- Record, as a spec requirement, that this is additive configuration/tooling only: it does not change what `save-session`/`save-session-maintenance` capture today, does not touch the existing status-note/session-log convention, and does not change `bm-orient`'s query model or this project's note taxonomy.

## Capabilities

### New Capabilities
(none — this extends the existing memory-workflow capability)

### Modified Capabilities
- `setup-memory-workflow`: adds a requirement that a project may declare a `basicMemory` coding-profile configuration block in its own `.claude/settings.json`/`.claude/settings.local.json` (hand-authored, never via `bm-setup`), and a requirement that the rendered `save-session-maintenance` skill include an unconditional, read-only `memory-doctor` check as part of its maintenance summary.

## Impact

- `.claude/settings.json` (this repo's own project-local Claude Code settings, tracked in git): add a `basicMemory` block. This file is hand-maintained directly in this repo, not rendered by any chezmoi `home/` template — confirmed by inspecting `home/dot_claude*/.claude-settings.json` (those back deployed *profile* settings under `$HOME`, a different mechanism) and the `claude-settings-ledger` spec, neither of which govern this repo's own `.claude/settings.json`.
- `home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`: add the `memory-doctor` step; bump `SMW_VERSION` in `executable_check-drift.sh`.
- `openspec/specs/setup-memory-workflow/spec.md`: new requirements as above.
- Rollout: after merge, run `check-drift.sh update` in this project (and any other installed project, on its own schedule) to deploy the version-bumped maintenance skill — same mechanism already used for the v20 repair (commit `62b69ee`).
- Affected tags: `ai` profile only; no new package declarations (no change to `packages.yaml`).
- Security/permissions: none. `memory-doctor` is read-only; the `basicMemory` config block contains no secrets (repository identifiers and placement conventions only, consistent with other non-secret project metadata already in `.claude/settings.json`).

## Non-Goals

- Not retiring, migrating, or dual-tagging the existing `Chezmoi Current Status`/`Chezmoi Session Notes` convention.
- Not changing `bm-orient`'s query model or this project's note taxonomy so `bm-orient` can see existing history — deferred per the pilot findings, pending this config and a second pilot.
- Not enabling native `SessionStart`/`PreCompact` lifecycle hooks — unaffected, out of scope, already governed by its own requirement.
- Not a fleet-wide rollout decision for other projects; this change configures the `chezmoi` project and the canonical template, same as Stage 2's pattern. Each other installed project adopts it (or not) via its own `check-drift.sh update`, on its own timeline.
- Not Stage 4 (delegating startup retrieval) or any further reduction of the existing hooks/scripts.
