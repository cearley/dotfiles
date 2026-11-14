# Tasks

## 1. Configure the basicMemory coding profile for this project

- [x] 1.1 Add a `basicMemory` block to this repo's tracked `.claude/settings.json` with `primaryProject: "chezmoi"`, `sessionProfile: "coding"`, `repository: "cearley/dotfiles"`, and a `placementConventions` string describing this project's note-placement conventions (sessions under `sessions/`, reference material under `reference/`, status under `status/`). Verify the file still parses as valid JSON (`python3 -m json.tool < .claude/settings.json`) and that no existing key (`hooks`, `enabledPlugins`) was altered.
- [x] 1.2 Confirm `bm-checkpoint`'s and `bm-orient`'s documented settings precedence (project `.claude/settings.json` overriding user-level `settings.json`) means this new block takes effect without any other file changing. Verify by re-reading `~/.claude/skills/bm-checkpoint/SKILL.md` and `~/.claude/skills/bm-orient/SKILL.md`'s "Resolve config" steps and confirming no project-side `.mcp.json` or hook change is also required.

## 2. Wire memory-doctor into save-session-maintenance

- [x] 2.1 Edit `home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`: insert a new "Step 0 — Run a memory-doctor health check" before the existing "Step 1 — Resolve and roll over the active log", instructing a read-only `bm doctor --skip-self-test --json --project __PROJECT__` call, folding its findings (or a clean result) into the final completion summary, and explicitly not acting on any suggested fix command. Renumber the existing Step 1/Step 2 headings only if needed for clarity (their content is unchanged). Verify by reading the edited file and confirming the existing Steps 1/2 content is byte-for-byte unchanged aside from the new section and any heading renumbering.
- [x] 2.2 Bump `SMW_VERSION` in `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` from 20 to 21. Verify with `grep SMW_VERSION= home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`.
- [x] 2.3 Update `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md` with a v21 entry describing the memory-doctor step. Verify the entry is present and follows the existing entries' format.
- [x] 2.4 Run `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` and fix any failures. Verify the command exits clean.

## 3. Deploy and verify in this project

- [x] 3.1 Run `check-drift.sh check` in this project to confirm it reports the installed `save-session-maintenance` skill as version-drifted (not identity-mismatched) against the new v21 template. Verify the reported drift is version-only.
- [x] 3.2 Run `check-drift.sh update` in this project to repair the rendered `.claude/skills/save-session-maintenance/SKILL.md` to v21. Verify the file's `setup-memory-workflow-version:` marker now reads 21 and the new Step 0 section is present.
- [x] 3.3 Run `/save-session-maintenance` for real (or confirm the user runs it) and observe the memory-doctor step executing and reporting a result. Verify the completion summary mentions the memory-doctor finding (or clean result) and that no notes were modified by that step alone. (Caveat: the executor ran Step 0's exact command — `bm doctor --skip-self-test --json --project chezmoi` — directly and confirmed it works and produces the documented clean result, but did not invoke the full `/save-session-maintenance` skill live, since that would perform real log-rollover/note mutations on the user's actual notes. A full live run remains optional before archive.)
- [x] 3.4 Run `make test` (existing `setup-memory-workflow` regression suite) and confirm no regressions from the template/version edits. Verify all checks pass.

## 4. Spec validation

- [x] 4.1 Run `openspec validate configure-basicmemory-coding-profile --strict` and fix any reported issues. Verify it passes.

## Workflow follow-up

- Run `/opsx:verify configure-basicmemory-coding-profile` before archiving.
- Archive the change (`openspec archive configure-basicmemory-coding-profile --yes` or `/opsx:archive`) and sync `openspec/specs/setup-memory-workflow/spec.md`.
- Commit and push on separate explicit confirmation, per the user's two-gate git workflow preference.
- Any other project with `save-session-maintenance` already installed picks up the v21 template on its own next `check-drift.sh update` — not part of this change's scope.
