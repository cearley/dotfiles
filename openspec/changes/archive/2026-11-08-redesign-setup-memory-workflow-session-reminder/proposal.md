# Proposal

## Why

`check-drift.sh`'s `canonical_hook_cmd()` bakes a live snapshot of the current
project's basic-memory status note into a literal `echo '...'` SessionStart
hook command, written into `.claude/settings.local.json` every time the skill
is checked or updated. This was a deliberate design (see the existing
`SessionStart reminder hook includes a bounded status-note excerpt`
requirement), but it has proven unsound in practice: on chezmoi itself, the
baked command is 6344 bytes (894 bytes with no excerpt) — frozen, stale
content that regrows on every run, confirmed independently across several of
the user's other real projects. A cross-project survey of basic-memory
projects (chezmoi, herdr, hcom, oh-my-claudecode, and three heavily-used
work repos) also found the status-note naming/location convention this
excerpt mechanism depends on is already inconsistent in production —
`WES.ViewPoint.CommonMicro.API` has no `status/` folder at all, so
`check-drift.sh`'s own discovery glob finds nothing there today.

Fixing this properly requires reversing the excerpt-baking design, not just
shrinking it, and taking the opportunity to also fix the discoverability
problem and reduce the skill's own maintenance burden (several of its scripts
are well over any reasonable complexity budget, and its templates carry
verbosity a capable model doesn't need).

## What Changes

- **BREAKING** (to installed behavior, not to any public API): the
  `SessionStart` reminder hook's command changes from a per-project, content-
  baked `echo` string to a **fixed, static script invocation**
  (`session-reminder.sh`) that reads the status note's `## Open` section
  **live, at session start** — never baked at `check-drift.sh update` time
  again. `STALE-EXCERPT` as a distinct `check-drift.sh` state is removed —
  there is no more baked excerpt to go stale.
- `check-drift.sh` is reduced to **zero memory/status/session-note logic** —
  it only manages the skill's own versioned files, templates, and hook
  *wiring*. Its ~580 lines are split into `check-drift.sh` (orchestrator),
  `lib-project.sh` (shared `$PROJECT` resolution), and `lib-pieces.sh` (a
  generic drift-detection engine replacing today's 6x hand-repeated
  check/update/apply blocks).
- `scripts/memory.sh` is deleted; its logic moves into two new files
  (`lib-status-note.sh`, `lib-session-log.sh`) owned exclusively by the new
  `session-reminder.sh` script, never sourced by `check-drift.sh`.
- The status note's canonical location is now **pinned mechanically**:
  `status/<project>-current-status.md`, matching `$PROJECT` exactly. A note
  found only via the old broader glob is flagged in the reminder output as
  non-canonical (never auto-moved — mirrors the existing `NAME-MISMATCH`
  philosophy of flagging identity drift rather than silently repairing user
  content).
- `drift-warn`'s current-status-note-bloat and session-log-bloat checks move
  out of `check-drift.sh` entirely, into `session-reminder.sh` — `drift-warn`
  keeps only the save-session-skill version-staleness check.
- `save-session-skill.md.template` gains a new step: consult
  `claude-session-index` (`sessions recent` / `sessions context <id>`,
  already installed, SQLite+FTS5, ~0.08s query time) as an input before
  writing the session-note entry, narrowing that entry to curated
  decisions/facts/problems rather than a transcript recap.
- `assets/save-session-skill.md.template` and
  `assets/save-session-maintenance-skill.md.template` are trimmed of
  generic markdown/process boilerplate a capable model already knows.
- `assets/hook-message.txt.template` is deleted — the reminder's static
  preamble becomes a literal string inside `session-reminder.sh`; there is no
  more rendering step for hook text.
- CI gains a `shell_lint` job (new `.github/workflows/ci.yml` job) running
  `shellcheck` (already an installed/declared package) and `shellmetrics`
  (fetched ephemeral in the CI step — no Homebrew formula exists, and no
  shipped script depends on it at runtime) against every script in
  `scripts/`, plus a `wc -l` ≤100 check per file.
- `SMW_VERSION` bumps 18 → 19, with a migration (`migrate_legacy_reminder_hook`
  in `migrations.sh`) that removes the old baked-excerpt SessionStart entry on
  upgrade so the new generic piece engine doesn't create a duplicate.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `setup-memory-workflow`: multiple requirement changes —
  - `SessionStart reminder hook includes a bounded status-note excerpt` is
    replaced by a live-read-at-session-start requirement (removes the
    baked-excerpt/`STALE-EXCERPT` mechanism entirely).
  - `drift-warn surfaces current-status note bloat, not just version drift`
    is replaced — that responsibility moves to `session-reminder.sh`;
    `drift-warn` itself narrows back to version-staleness only.
  - `Project identity is resolved once, at apply-time` gains an explicit,
    scoped exception for `session-reminder.sh`, which resolves `$PROJECT` at
    runtime (not apply-time) because its whole purpose is reading live
    content that cannot be pre-rendered.
  - `Skill is distributed as per-project rendered copies, not a shared
    reference` gains a third deliberate exception (alongside the existing
    write-guard and crash-recovery-hook exceptions): the reminder hook entry
    becomes a static, non-templated, non-version-marked global script
    invocation, exactly like those two.
  - A new requirement is added for the status note's canonical path
    convention and the non-canonical-location notice.

## Impact

- **Affected files**: `home/dot_claude/skills/setup-memory-workflow/scripts/*`
  (rewritten/split/new/deleted — see design.md for the full file map),
  `home/dot_claude/skills/setup-memory-workflow/assets/*.template` (trimmed,
  one deleted), `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md`
  (new v19 entry), `.github/workflows/ci.yml` (new job).
- **Affected tags**: none of `core`/`dev`/`ai`/`work`/`personal`/
  `datascience`/`mobile` — this skill is deployed via `chezmoi apply` to
  `~/.claude/skills/` and is not gated behind any install tag; it affects
  every project on every machine that has run `check-drift.sh check` in it,
  once each such project runs `check-drift.sh update` after this ships.
- **Existing installs**: every project currently at `setup-memory-workflow-
  version:18` (chezmoi and the other surveyed projects among them) upgrades
  cleanly via the new migration on its next `check-drift.sh update` — no
  manual per-project action required, except for the already-accepted,
  separately-scoped limitation that a status note at a genuinely
  unconventional location (e.g. `WES.ViewPoint.CommonMicro.API`'s
  `project/Current Open Items.md`) still won't be auto-discovered.
- **Security implications**: none new. `session-reminder.sh` is strictly
  read-only (never writes a file, even to create a missing canonical note —
  a raw filesystem write would bypass basic-memory's own SQLite
  index/checksums, the same hazard the existing `PreToolUse` write-guard
  warns about). No secrets are involved. The `PreToolUse` write-guard hook
  itself is unchanged by this proposal.
- **Dependencies**: no new runtime dependency — `shellmetrics` is CI-only,
  fetched ephemeral in the workflow step, not added to
  `home/.chezmoidata/packages.yaml`.

## Non-goals

- Picoschema/schema adoption for status or session notes (wrong granularity
  for the Open/Resolved split; perf-disqualified for the SessionStart hot
  path — confirmed by direct measurement).
- Any change to `crash-recovery-hook.sh`'s or `basic-memory-write-guard.sh`'s
  actual logic.
- Any change to `save-session-skill.md.template`'s or
  `save-session-maintenance-skill.md.template`'s workflow *behavior* beyond
  verbosity trimming and the one session-index cross-reference addition.
- A universal cross-folder prober that would auto-discover a status note
  living at a completely unconventional location (e.g.
  `WES.ViewPoint.CommonMicro.API`'s case) — flagged as a known, accepted
  limitation, not solved here.
- Rolling `shellcheck`/`shellmetrics` CI coverage out to the rest of the
  chezmoi repo's shell scripts beyond this skill's `scripts/` directory.
