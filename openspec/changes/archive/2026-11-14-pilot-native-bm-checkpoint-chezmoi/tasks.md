# Tasks

## 1. Declare the skills

- [x] 1.1 Add `bm-checkpoint`, `bm-orient`, and `memory-doctor` entries to `packages.darwin.ai.agents.claude_code.skills` in `home/.chezmoidata/packages.yaml`, pointed at `basicmachines-co/basic-memory`, with a comment distinguishing the source repo from the existing four entries' `basic-memory-skills` repo. Verify with `tests/run-template home/.chezmoiscripts/run_onchange_after_darwin-36-2-install-claude-skills.sh.tmpl` that the rendered script includes the three new `npx skills add` lines with correct flags, alongside the unchanged four.
- [x] 1.2 Run `tests/lint-shell home/.chezmoiscripts/run_onchange_after_darwin-36-2-install-claude-skills.sh.tmpl` (unchanged script, but the template renders differently with the new data) and confirm it passes with no new findings.
- [x] 1.3 Re-run `npx skills add basicmachines-co/basic-memory --list` read-only (no `-y`, no install) immediately before applying, to confirm `bm-checkpoint`, `bm-orient`, and `memory-doctor` are still present at the commit upstream currently serves. Record the confirmed commit/date in the pilot findings note (task 3.1).

## 2. Deploy and confirm installation

- [x] 2.1 Run `chezmoi apply` (or the targeted script) on this machine and verify `~/.claude/skills/` gains `bm-checkpoint`, `bm-orient`, and `memory-doctor` directories, each containing a `SKILL.md`, via `npx skills list -g -a claude-code`.
- [x] 2.2 Verify no `hooks.json` or plugin registration was installed as a side effect: check `~/.claude/settings.json`/`~/.claude/settings.local.json` for this profile are unchanged (`git diff` against the chezmoi-managed baseline, or a direct read if not chezmoi-tracked) and confirm no new `SessionStart`/`PreCompact` hook entries referencing `basic-memory` appear.
- [x] 2.3 Verify `.mcp.json` and this project's `.claude/settings.local.json` are unchanged by the skill installation (no `basicMemory` block appeared) — confirming the "Native setup/configuration skills do not write chezmoi-owned settings" requirement holds in practice, not just by mechanism.

## 3. Run the pilot and record findings

- [x] 3.1 Use `bm-checkpoint` (or its agent-invoked equivalent) to produce at least one real checkpoint note for a `chezmoi` session, and `bm-orient` to resume from it in a later session. Record, in a new basic-memory note in the `chezmoi` project, what the checkpoint captured versus what the existing session-log/status-note convention would have captured, and whether resuming from it was accurate and sufficient.
- [x] 3.2 Run `memory-doctor` as a read-only health check against the `chezmoi` basic-memory project and record its findings (or confirmation of a clean report) in the same pilot-findings note.
- [x] 3.3 In the pilot-findings note, explicitly assess: (a) whether `bm-checkpoint`/`bm-orient` content is a credible substitute for the typed-handoff work Stage 3 would otherwise build from scratch, (b) any gaps versus the existing session-log convention, (c) a recommendation for whether Stage 3/4 should lean on these skills, build something else, or do both. This note is the deliverable that feeds the next stage decision — it does not itself authorize Stage 3/4 work.

## Workflow follow-up

- Validate with `openspec validate pilot-native-bm-checkpoint-chezmoi --strict` once tasks are complete.
- Run `/opsx:verify` before archiving.
- Archive the change after the pilot-findings note is recorded and reviewed with the user.
