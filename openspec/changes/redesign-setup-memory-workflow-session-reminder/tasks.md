# Tasks

Note: the files under `home/dot_claude/skills/setup-memory-workflow/scripts/`
and `assets/` are not chezmoi-templated (no `.tmpl` extension, no Go template
syntax) and are deployed as plain files via the symlink-shared
`home/dot_claude/skills/` tree — the chezmoi-specific verification steps
(`chezmoi execute-template`, `chezmoi diff`, 00-99 script-order checks) this
project's task conventions normally call for don't apply to this change;
`shellcheck`/`shellmetrics`/direct script execution are the equivalent checks
here.

## 1. Shared libraries

- [x] 1.1 Create `scripts/lib-project.sh` (sourced, no shebang, not
  executable) with `resolve_project()` extracted unchanged from today's
  `check-drift.sh`. Verify: `wc -l scripts/lib-project.sh` ≤100;
  `shellcheck scripts/lib-project.sh` clean.
- [x] 1.2 Create `scripts/lib-pieces.sh` (sourced) with the generic
  templated-file piece engine (`piece_status`, `apply_templated_file`,
  `report_templated_piece`, `update_templated_piece`, a trimmed `render()`
  with only `__PROJECT__`/`__SMW_VERSION__` substitution — no
  `__OPEN_EXCERPT__`) and the new generic hook-command piece engine
  (`hook_piece_status`, `hook_piece_apply`, parameterized by settings file /
  event / match substring / canonical command). Verify: `wc -l
  scripts/lib-pieces.sh` ≤100; `shellcheck scripts/lib-pieces.sh` clean.
- [x] 1.3 Write a fixture-based unit check: run the old `check-drift.sh`'s
  write-guard-hook and crash-recovery-hook check logic and the new
  `hook_piece_status`/`hook_piece_apply` against the same scratch
  `settings.local.json`, diff the outputs for those two pieces only. Verify:
  diffs are empty (per design.md's Risks section).

## 2. check-drift.sh rewrite

- [x] 2.1 Rewrite `scripts/executable_check-drift.sh` as an orchestrator:
  source `lib-project.sh`, `lib-pieces.sh`, `migrations.sh`; define the
  piece table (save-session skill, save-session-maintenance skill,
  `.mcp.json`, write-guard hook, crash-recovery hook, reminder hook); dispatch
  `check|update|apply|drift-warn`. The reminder hook's canonical command is
  the fixed string
  `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/session-reminder.sh`
  — no rendering. Verify: `wc -l scripts/executable_check-drift.sh` ≤100;
  `shellcheck` clean; `grep -iE 'open section|status note|session log' scripts/executable_check-drift.sh scripts/lib-pieces.sh scripts/lib-project.sh`
  returns nothing (per spec's intent and proposal's Impact section).
- [x] 2.2 Narrow `cmd_drift_warn` to the save-session-skill version-staleness
  check only — remove the `check_status_note_bloat`/`check_session_log_bloat`
  calls and the `memory.sh` source line. Verify: running `check-drift.sh
  drift-warn` against a project with an oversized status note prints nothing
  about that note (the signal now lives only in `session-reminder.sh`, task
  4.3).
- [x] 2.3 Fixture idempotency test: run `check-drift.sh update` twice against
  a scratch copy of chezmoi's real `.claude/settings.local.json`. Verify:
  the two resulting files are byte-identical (`diff` exits 0).

## 3. Upgrade migration

- [x] 3.1 Add `migrate_legacy_reminder_hook()` to `scripts/migrations.sh`,
  mirroring `migrate_hook_config()`'s shape: find any `SessionStart` hook
  entry whose command contains `basic-memory` and does not contain
  `session-reminder.sh`, remove it, call unconditionally before the generic
  piece engine's CREATE path. Verify: `wc -l scripts/migrations.sh` ≤100;
  `shellcheck` clean.
- [x] 3.2 Fixture upgrade test: seed a scratch `settings.local.json` with
  chezmoi's actual pre-change baked reminder command (captured before this
  change lands), run `check-drift.sh update`. Verify: exactly one
  `SessionStart` entry matching `session-reminder.sh` remains; `jq
  '.hooks.SessionStart | length'` matches the expected count with no
  duplicate reminder entry.

## 4. Memory-domain libraries and session-reminder.sh

- [x] 4.1 Create `scripts/lib-status-note.sh` (sourced) with
  `resolve_status_note_path()` (canonical-first: exact
  `status/${PROJECT}-current-status.md`, fallback to today's broader glob,
  signals canonical-vs-fallback to the caller), `extract_open_excerpt()`
  (same bullet-boundary-aware `awk` extraction as today), and
  `check_status_note_bloat()`. Verify: `wc -l scripts/lib-status-note.sh`
  ≤100; `shellcheck` clean.
- [x] 4.2 Create `scripts/lib-session-log.sh` (sourced) with
  `resolve_active_session_log_path()` and `check_session_log_bloat()`, moved
  unchanged from today's `memory.sh`. Verify: `wc -l
  scripts/lib-session-log.sh` ≤100; `shellcheck` clean.
- [x] 4.3 Create `scripts/executable_session-reminder.sh`: source
  `lib-project.sh`, `lib-status-note.sh`, `lib-session-log.sh`; resolve
  `$PROJECT`; resolve the status note; print the static preamble (literal
  string in this script) + live Open excerpt + non-canonical-location notice
  if applicable + bloat-warning lines; exit 0 unconditionally; never write
  any file. Verify: `wc -l scripts/executable_session-reminder.sh` ≤100;
  `shellcheck` clean.
- [x] 4.4 Run `session-reminder.sh` standalone against three scratch fixtures:
  (a) a status note at the canonical path with Open items — verify excerpt
  prints correctly; (b) no `status/` directory at all (simulating
  `WES.ViewPoint.CommonMicro.API`) — verify exit 0, no error, no excerpt, no
  basic-memory CLI/MCP call (confirm via `strace`/process-list or by running
  with no network/MCP access available); (c) a status note at a
  non-canonical filename under `status/` — verify the excerpt prints plus
  the non-canonical-location notice naming the canonical path.
- [x] 4.5 Delete `scripts/memory.sh`. Verify: `check-drift.sh` and
  `session-reminder.sh` both run with no "file not found" source errors;
  `! test -f scripts/memory.sh`.
- [x] 4.6 Delete `assets/hook-message.txt.template`. Verify: `!
  test -f assets/hook-message.txt.template`; `check-drift.sh check` runs
  clean with no reference to it.

## 5. Templates

- [x] 5.1 Trim `assets/save-session-skill.md.template`: remove generic
  markdown/process boilerplate; add the canonical status-note path
  convention (`status/<project>-current-status.md`); add the step
  instructing the model to consult `sessions recent`/`sessions context <id>`
  (claude-session-index) before writing the session-note entry. Verify: line
  count is lower than the pre-change 143; a spot-check diff against the
  pre-change version confirms the two-step save behavior, size thresholds,
  and archive-naming convention are all still present in substance.
- [x] 5.2 Trim `assets/save-session-maintenance-skill.md.template`: same
  verbosity-reduction pass, no behavior change. Verify: line count is lower
  than the pre-change 116; spot-check diff confirms thresholds/paths/
  archive-naming convention unchanged in substance.

## 6. Version and changelog

- [x] 6.1 Bump `SMW_VERSION` 18 → 19 in `scripts/executable_check-drift.sh`.
  Verify: `grep 'SMW_VERSION=19' scripts/executable_check-drift.sh` matches.
- [x] 6.2 Add a `## v19` entry to `CHANGELOG.md` at the v18 entry's level of
  detail, covering: the bake-at-update-time fix, the check-drift.sh/memory
  split, the canonical status-note path convention, and the session-index
  cross-reference addition. Verify: entry present and reads coherently
  alongside the v18 entry.

## 7. Agent-driven complexity review

- [x] 7.1 Spawn a reviewer agent (Task tool, `subagent_type: "oh-my-claudecode:code-reviewer"`,
  briefed with design.md's D1/D2 line-budget rationale) to run `shellmetrics` and
  `shellcheck` against every file under `scripts/` created or rewritten in sections
  1–4, and report per-file complexity/line-count findings. Verify: the agent's
  report is reviewed; any file flagged over the agreed threshold is either
  split/simplified in response, or the acceptance is explicitly noted here with
  rationale, before proceeding to task 8.1's CI wiring.

## 8. CI

- [x] 8.1 Add a `shell_lint` job to `.github/workflows/ci.yml` scoped to
  `home/dot_claude/skills/setup-memory-workflow/scripts/`: a `wc -l` ≤100
  check per `*.sh` file, a `shellcheck scripts/*.sh` step, and a
  `shellmetrics` step that fetches the tool ephemeral from a pinned
  tag/commit of `shellspec/shellmetrics` (confirm exact invocation/flags
  against the tool's own `--help`/README first — design.md's Open Question),
  failing the job if any file exceeds the documented threshold. Verify: the
  job runs green on this change's own branch in CI; deliberately
  reintroducing a >100-line file or a `shellcheck` warning locally and
  re-running the job's commands fails it, confirming the gate is real.

## 9. Final verification

- [x] 9.1 On this machine, run `check-drift.sh update` in the actual chezmoi
  project (not a fixture) and confirm the real `.claude/settings.local.json`
  now carries the short, fixed reminder command with no baked excerpt.
  Verify: `jq -r '.hooks.SessionStart[].hooks[].command' .claude/settings.local.json`
  shows the `session-reminder.sh` invocation at a stable, small byte length
  regardless of the current status note's size.
- [x] 9.2 Start a real Claude Code session in the chezmoi project and confirm
  the injected `SessionStart` reminder shows a live Open-items excerpt
  matching the current status note's actual `## Open` section content.
  Verify: visual match against `bm_read(section="Open")` for the same note.

## Workflow follow-up

- Run `check-drift.sh update` in each other project with this skill
  installed (herdr, hcom, oh-my-claudecode, the three WES/
  viewpoint-report-automation work repos) once this change is merged —
  each is independent and not required before archiving this change.
- Archive this change once the tasks above are complete and verified.
- Run `/opsx:verify` before archiving.
