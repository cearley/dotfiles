# Status-Note Open-Items Bloat Mitigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Bound the live `current-status.md` note's size contribution from its Open
section, without ever hiding that unresolved backlog exists, by pointer-izing new Open
items and rolling long-untouched ones into a session-count-triggered, still-visible
index.

**Architecture:** A new deterministic bash library (`lib-open-items.sh`) adds two
read-only signals — an Open-section overflow warning (SessionStart) and a session-count
staleness computation (`check-drift.sh open-staleness`) — following the exact pattern
`lib-status-note.sh`/`lib-session-log.sh` already use. Two skill templates change their
guidance: `save-session-skill` creates a small per-item note + one-line pointer for new
Open items instead of an inline paragraph (forward-only; nothing existing is rewritten);
`save-session-maintenance-skill` gains a rollup step that collapses stale items into a
"Stale Open Items Index" note using the new signal, plus a narrow on-request path to
convert one existing legacy item at a time.

**Tech Stack:** bash (bashunit for tests), basic-memory MCP tools (`bm_write`, `bm_edit`,
`bm_find`, `bm_schema`) invoked from skill-template prose, chezmoi template rendering.

**Spec:** `docs/superpowers/specs/2026-11-17-status-note-open-items-bloat-design.md`

## Global Constraints

- basic-memory has no native TTL/retention/expiry. All staleness logic is implemented in
  this workflow's own scripts — never assume a BM feature does this.
- `bm_schema` validates frontmatter field shape only. It never enforces size, line, or
  item-count caps; nothing in this plan uses it for that.
- Every `SessionStart`-reached script/function must stay read-only, degrade to a silent
  no-op on any missing file/section/directory, and never cause the hook to exit nonzero.
- `save-session-maintenance` stays `disable-model-invocation: true`. No new logic may
  run automatically from a bloat reminder — only on explicit `/save-session-maintenance`.
- Must not change the behavior of the existing `check-drift.sh status-bloat` subcommand
  or the v23 Status Summary growth gate in `save-session-skill.md.template` Step 1.
- Open-section live-line cap default: 15 (reuses `lib-status-note.sh`'s
  `OPEN_EXCERPT_MAX_LINES` value as a sibling constant, not a shared variable, since the
  two files' caps are independently tunable per the spec).
- Session-count staleness threshold default: 5 sessions untouched, tunable.
- Staleness computation is a deterministic shell function/script, never a model/MCP
  judgment call made during a skill run.
- Migration is forward-only. No task may bulk-rewrite the ~30 existing prose Open items
  in any real project's note; only a narrow, explicitly-invoked single-item conversion
  is in scope.
- `open-items/` and its `type: schema` note are created lazily by `save-session` on
  first need — they are not added as a new piece type to `lib-pieces.sh`'s
  templated-file/hook-command engine.
- Every shell file or template created or modified must pass `tests/lint-shell <file>`
  before the task's commit.
- Any shipped template/script behavior change requires an `SMW_VERSION` bump and a
  `CHANGELOG.md` entry, per this skill's existing convention (see v20–v24).

## Review Focus

- An `open-item` note's `last_touched_session` date does not match any entry currently
  in the status note's Status Summary (a prior maintenance run condensed/archived that
  entry away) — the computation must not error or silently skip the item; it must
  classify it as stale (count it as older than everything currently visible), covered
  in Task 2.
- The Open section has fewer live items than the cap — the overflow signal must print
  nothing, never nag on a healthy note, covered in Task 1.
- Two or more Status Summary entries share the same date (`**2026-11-17**` and
  `**2026-11-17 (later same day):**`) — each must count as one separate touched
  session, not collapse into one, so the threshold isn't silently undercounted,
  covered in Task 2.
- No `open-items/` directory exists yet (a brand-new project, or one that hasn't
  created its first pointer-ized item) — both the overflow signal and
  `open-staleness` must degrade to a clean no-op, matching every other signal's
  missing-file/missing-directory contract, covered in Tasks 1 and 2.
- An `open-item` note exists but is missing `last_touched_session` entirely (hand-
  edited or malformed) — the staleness script must skip that one note without
  aborting the computation for the others; `bm_schema validate` (Task 4) is the
  layer responsible for flagging the malformed note itself, covered in Task 2.

---

### Task 1: Open-section overflow signal

**Files:**
- Create: `home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh`
- Modify: `home/dot_claude/skills/setup-memory-workflow/scripts/executable_session-reminder.sh`
- Test: `tests/setup_memory_workflow_open_items_test.sh`

**Interfaces:**
- Consumes: `resolve_status_note_path()` from `lib-status-note.sh` (already sourced by
  `session-reminder.sh` before this change; `lib-open-items.sh` must be sourced after
  `lib-status-note.sh` wherever both are used).
- Produces: `OPEN_LINE_CAP` (constant, value `15`), `check_open_section_overflow()` — no
  args, relies on `$PROJECT`/`$HOME` already being set, prints one warning line (format:
  `[setup-memory-workflow] Open section has <N> live items (cap <CAP>) — run
  /save-session-maintenance to roll stale items into the index.`) or nothing, always
  succeeds (never a nonzero exit from this function itself).

- [ ] **Step 1: Write the failing tests**

```bash
# tests/setup_memory_workflow_open_items_test.sh
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL_DIR="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts"

function set_up() {
    SCRATCH="$(bashunit::temp_dir)"
    HOME="$SCRATCH"
    PROJECT="proj"
    STATUS_DIR="$SCRATCH/.local/share/basic-memory/proj/status"
    mkdir -p "$STATUS_DIR"
    NOTE="$STATUS_DIR/proj-current-status.md"
    # shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-status-note.sh
    source "$SKILL_DIR/lib-status-note.sh"
    # shellcheck source=home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh
    source "$SKILL_DIR/lib-open-items.sh"
}

function write_open_section() {
    local n="$1"
    {
        printf '## Open\n\n'
        for ((i = 0; i < n; i++)); do printf '- [problem] item %d\n' "$i"; done
    } >"$NOTE"
}

function test_under_cap_prints_nothing() {
    write_open_section 10
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}

function test_at_cap_prints_nothing() {
    write_open_section 15
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}

function test_over_cap_prints_warning() {
    write_open_section 16
    local out
    out=$(check_open_section_overflow)
    assert_contains "16" "$out"
}

function test_no_status_note_prints_nothing() {
    rm -f "$NOTE"
    local out
    out=$(check_open_section_overflow)
    assert_empty "$out"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bashunit tests/setup_memory_workflow_open_items_test.sh`
Expected: FAIL — `lib-open-items.sh: No such file or directory` (file doesn't exist yet)

- [ ] **Step 3: Implement `lib-open-items.sh`**

Follow `lib-status-note.sh`'s header-comment contract (read-only, never errors,
degrades to no-op on any missing file/section). Define `OPEN_LINE_CAP=15` and
`check_open_section_overflow()`: resolve the status note via
`resolve_status_note_path()`; if none, return silently. Extract the `## Open` section
the same way `extract_open_excerpt()` does (awk between the `## Open` header and the
next `##`), count lines matching `^- `, and print the warning line only when that
count exceeds `OPEN_LINE_CAP`.

- [ ] **Step 4: Wire it into the SessionStart hook**

In `executable_session-reminder.sh`, add a source line for `lib-open-items.sh`
immediately after the existing `lib-session-log.sh` source line, and add
`check_open_section_overflow || true` on its own line immediately after the existing
`check_session_log_bloat || true` call.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bashunit tests/setup_memory_workflow_open_items_test.sh`
Expected: PASS, 4 tests, 4 assertions

- [ ] **Step 6: Lint the touched shell files**

Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh`
Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/executable_session-reminder.sh`
Expected: both exit 0

- [ ] **Step 7: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh \
        home/dot_claude/skills/setup-memory-workflow/scripts/executable_session-reminder.sh \
        tests/setup_memory_workflow_open_items_test.sh
git commit -m "feat(setup-memory-workflow): add Open-section overflow signal"
```

---

### Task 2: Session-count staleness computation

**Files:**
- Modify: `home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh`
- Modify: `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
- Test: `tests/setup_memory_workflow_open_items_test.sh`

**Interfaces:**
- Consumes: `resolve_status_note_path()` (`lib-status-note.sh`); `resolve_project()`
  (`lib-project.sh`); `open-item` note frontmatter fields `status` (`open`/`stale`/
  `resolved`) and `last_touched_session` (a `YYYY-MM-DD` date string) — field names are
  fixed by this task for Tasks 3–5 to write/read, but the notes' *content* beyond those
  two fields is Task 3's to define.
- Produces: `STALE_SESSION_THRESHOLD` (constant, value `5`), `resolve_open_items_dir()`
  (prints `$HOME/.local/share/basic-memory/$PROJECT/open-items` if that directory
  exists, nothing otherwise), `stale_open_items()` (no args; for every
  `open-items/*.md` note with `status: open` whose computed sessions-untouched count is
  `>= STALE_SESSION_THRESHOLD`, prints one line `<note-path>\t<count>`; prints nothing
  if the directory is missing, empty, or no item qualifies; always exits 0). Modifies
  `executable_check-drift.sh`: new `cmd_open_staleness()` prints `stale_open_items()`'s
  output and returns 1 if nonempty, 0 otherwise; wired into the `case` statement as
  `open-staleness` and added to the usage string.

**Staleness count, exact rule:** within the status note's `## Status Summary` section
only, collect every line's leading date in file order (top = newest), matching
`^\*\*([0-9]{4}-[0-9]{2}-[0-9]{2})` and keeping the matched date only (drop any
`(later same day)`-style suffix before the closing `**`) — do not deduplicate same-day
entries; each matched line counts once. For a given `open-item` note's
`last_touched_session` date, the "sessions untouched" count is how many collected dates
are strictly newer than it (i.e., appear above the first collected date that is `<=`
it, in file order). If `last_touched_session`'s date does not appear among the
collected dates at all, treat it as older than every collected date (count = total
number of collected dates) — this is the conservative "condensed away by a prior
maintenance run" case from Review Focus.

- [ ] **Step 1: Write the failing tests**

```bash
# appended to tests/setup_memory_workflow_open_items_test.sh
CHECK_DRIFT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh"

function write_status_summary() {
    # args: one or more dates, newest first, written as separate dated entries
    {
        printf '## Status Summary\n\n'
        for d in "$@"; do printf '**%s**\nentry\n\n' "$d"; done
        printf '## Open\n'
    } >"$NOTE"
}

function write_open_item() {
    # args: slug, status, last_touched_session
    mkdir -p "$SCRATCH/.local/share/basic-memory/proj/open-items"
    cat >"$SCRATCH/.local/share/basic-memory/proj/open-items/$1.md" <<EOF
---
type: open-item
status: $2
last_touched_session: $3
---
EOF
}

function run_open_staleness() {
    (cd "$PROJECT_DIR" && HOME="$SCRATCH" bash "$CHECK_DRIFT" open-staleness)
}

function set_up_project_dir() {
    # Named "proj" (not e.g. "repo") because `check-drift.sh` resolves
    # $PROJECT from this directory's basename when it isn't a git repo
    # (lib-project.sh's resolve_project() fallback) — it must match the
    # "proj" used in every fixture path below, or PROJECT mismatches and
    # every fixture note resolves as missing.
    PROJECT_DIR="$SCRATCH/proj"
    mkdir -p "$PROJECT_DIR"
}

function test_no_open_items_dir_exits_zero() {
    set_up_project_dir
    write_status_summary 2026-11-17
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}

function test_below_threshold_not_stale() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14
    write_open_item itemA open 2026-11-15
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_same "0" "$ec"
    assert_empty "$out"
}

function test_at_threshold_is_stale() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA open 2026-11-12
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_same "1" "$ec"
    assert_contains "itemA" "$out"
}

function test_same_day_entries_each_count() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-17 2026-11-17 2026-11-17 2026-11-17
    write_open_item itemA open 2026-11-16
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "1" "$ec"
}

function test_last_touched_not_found_is_conservatively_stale() {
    set_up_project_dir
    # Only 2 collected dates: below the 5-session threshold on its own, so
    # this fixture also proves "not found" falls back to counting *all*
    # collected dates (2), not some larger implicit value — update this
    # fixture's date count alongside STALE_SESSION_THRESHOLD if it changes.
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA open 2026-01-01
    local out ec=0
    out=$(run_open_staleness) || ec=$?
    assert_contains "itemA" "$out"
}

function test_resolved_item_never_counted() {
    set_up_project_dir
    write_status_summary 2026-11-17 2026-11-16 2026-11-15 2026-11-14 2026-11-13
    write_open_item itemA resolved 2026-01-01
    local ec=0
    run_open_staleness >/dev/null 2>&1 || ec=$?
    assert_same "0" "$ec"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bashunit tests/setup_memory_workflow_open_items_test.sh`
Expected: FAIL — `open-staleness` not a recognized `check-drift.sh` subcommand

- [ ] **Step 3: Implement `stale_open_items()` and `resolve_open_items_dir()` in `lib-open-items.sh`**

Add `STALE_SESSION_THRESHOLD=5`. Implement the exact rule stated above: collect dated
Status Summary headers via awk (bounded between `## Status Summary` and the next
`##`, same section-extraction idiom as `extract_open_excerpt()`), then for each
`open-items/*.md` note read its frontmatter `status`/`last_touched_session` (a small
awk/sed frontmatter-field reader, matching the style already used for the
`<!-- setup-memory-workflow-version:... -->` marker parsing in `lib-pieces.sh`'s
`piece_status()`), skip any note where `status != open` or `last_touched_session` is
absent, compute the count per the rule above, and print `<path>\t<count>` when it meets
the threshold.

- [ ] **Step 4: Wire the subcommand into `executable_check-drift.sh`**

Add a `# shellcheck source=...lib-open-items.sh` source line alongside the existing
library sources, add `cmd_open_staleness()` following `cmd_status_bloat()`'s shape, add
`open-staleness) cmd_open_staleness ;;` to the case statement, and add `open-staleness`
to the usage error string.

- [ ] **Step 5: Run tests to verify they pass**

Run: `bashunit tests/setup_memory_workflow_open_items_test.sh`
Expected: PASS, all tests from Task 1 and Task 2, 0 failures

- [ ] **Step 6: Lint the touched shell files**

Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh`
Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`
Expected: both exit 0

- [ ] **Step 7: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/scripts/lib-open-items.sh \
        home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh \
        tests/setup_memory_workflow_open_items_test.sh
git commit -m "feat(setup-memory-workflow): add session-count Open-item staleness check"
```

---

### Task 3: Pointer-ize, touch-track, and resolve Open items in `save-session`

**Files:**
- Modify: `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`
- Modify: `tests/setup_memory_workflow_templates_test.sh`

**Interfaces:**
- Consumes: nothing from Tasks 1–2 (independent track; shares only the `open-items/`
  directory name and the frontmatter field names below, which this task defines).
- Produces (fixed field names/values for Tasks 4–5 to rely on): `open-item` note
  frontmatter — `type: open-item`, `status` (`open`/`resolved`), `found_session` (date
  string of the entry that created it), `last_touched_session` (date string, same
  convention Task 2 reads), optional `severity`. Status-note Open-section line format:
  `- [<category>] <short title> — [[Open: <slug>]]`. `open-items/` directory and its
  `type: schema`, `entity: open-item` note are created lazily, on first need, by this
  template's Step — not pre-provisioned anywhere else. Resolving an indexed (stale)
  item removes its line from the Stale Open Items Index note (Task 4) rather than from
  the live Open section — functionally identical to today's Resolved flow, just
  targeting whichever note currently lists the item.

- [ ] **Step 1: Write the failing template-regression tests**

```bash
# appended to tests/setup_memory_workflow_templates_test.sh
function test_save_session_template_documents_open_item_note_type() {
    local found=0
    grep -q 'type: open-item' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_open_pointer_line_format() {
    local found=0
    grep -q '\[\[Open: ' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_is_forward_only_for_open_items() {
    local found=0
    grep -qi 'forward-only' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_still_preserves_open_baseline() {
    # Guards against this task accidentally dropping the existing v-anything
    # rule that resolved items are the only thing ever removed from Open.
    local found=0
    grep -q 'Preserve the existing Open' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_touch_tracking() {
    local found=0
    grep -q 'last_touched_session' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}

function test_save_session_template_documents_resolving_pointer_items() {
    local found=0
    grep -qi 'resolving a pointer-ized item' "$TEMPLATE" && found=1
    assert_same "1" "$found"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: FAIL on the three new assertions (strings not yet present)

- [ ] **Step 3: Edit `save-session-skill.md.template` Step 1's Open-item paragraph**

Immediately after the existing "Preserve the existing Open list as the baseline..."
paragraph, add guidance (one short paragraph, matching this template's existing prose
style) stating: this applies forward-only — items already in the Open section as
freeform bullets are left exactly as they are; only a *new* Open item created this
session uses the new shape. For a new item: on confirmed-missing `open-items/`
directory or schema note, create the `type: schema`/`entity: open-item` note (consult
`bm_man(page="bm-schema(3)")` for exact Picoschema authoring syntax if uncertain —
required fields `status`, `found_session`, `last_touched_session`, optional
`severity`), then create `open-items/<slug>.md` with `bm_write(overwrite=false)`
carrying that frontmatter and the item's `[category]` observation line as its body,
then add one line to the status note's Open section: `- [<category>] <short title> —
[[Open: <slug>]]`. Show the exact frontmatter shape as a concrete example, the same
way this template already shows a concrete `bm_edit` call elsewhere:

```
---
type: open-item
status: open
found_session: 2026-11-17
last_touched_session: 2026-11-17
---
```

Immediately after that, add two more short rules to the same paragraph: (1) **touch
tracking** — if this session's work references, updates, or reaffirms an *existing*
pointer-ized Open item (one with an `[[Open: <slug>]]` line already in the status
note), fresh-read that item's note and update its `last_touched_session` field to
today's dated entry via checksum-guarded `bm_edit`; this is the only time an existing
`open-items/` note's frontmatter changes outside of resolution or maintenance. (2)
**resolving a pointer-ized item** — when a named item with an `[[Open: <slug>]]` line
is actually resolved this session, update its note's `status` to `resolved` (mirroring
how a plain prose Open item already moves to Resolved) and remove its line from
wherever it currently appears — the live Open section if it has its own pointer line,
or the Stale Open Items Index note if it was already rolled up there (same removal
operation, different target note).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: PASS, all tests (existing + new)

- [ ] **Step 5: Lint the touched template**

Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`
Expected: exit 0 (template is Markdown with embedded shell fences; lint-shell degrades
gracefully on non-shell files per existing project convention — confirm no failures)

- [ ] **Step 6: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template \
        tests/setup_memory_workflow_templates_test.sh
git commit -m "feat(setup-memory-workflow): pointer-ize new Open items in save-session"
```

---

### Task 4: Stale Open Items Index rollup in `save-session-maintenance`

**Files:**
- Modify: `home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`
- Modify: `tests/setup_memory_workflow_templates_test.sh`

**Interfaces:**
- Consumes: Task 2's `check-drift.sh open-staleness` output format (`<path>\t<count>`
  lines, nonzero exit when any exist); Task 3's `open-item` frontmatter fields and
  Open-section pointer-line format.
- Produces: the `Stale Open Items Index — <project>` note (grouped pointer lines, one
  per stale item, grouped by original `[category]`) and the status-note rollup line
  format: `>N sessions untouched: <count> items — [[Stale Open Items Index —
  <project>]]`, replacing the individual pointer lines for exactly the items
  `open-staleness` reported.

- [ ] **Step 1: Write the failing template-regression tests**

```bash
# appended to tests/setup_memory_workflow_templates_test.sh
TEMPLATE_MAINT="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template"

function test_maintenance_template_exists() {
    assert_file_exists "$TEMPLATE_MAINT"
}

function test_maintenance_template_calls_open_staleness() {
    local found=0
    grep -q 'open-staleness' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_documents_stale_index_title() {
    local found=0
    grep -q 'Stale Open Items Index' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_runs_schema_validate() {
    local found=0
    grep -q 'bm_schema' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: FAIL on the three new assertions

- [ ] **Step 3: Add the rollup step to `save-session-maintenance-skill.md.template` Step 2**

Add a new sub-step, run after the existing status-note triage described there: run
`${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/check-drift.sh
open-staleness`; for each returned `<path>` (consulting its `open-items/` note),
replace that item's individual pointer line in the status note's Open section with (or
fold its count into) the single rollup line `>N sessions untouched: <count> items —
[[Stale Open Items Index — __PROJECT__]]`, creating that index note
(`bm_write(overwrite=false)` on first use, `bm_edit` append thereafter) with one
grouped pointer line per stale item, preserving each item's original `[category]`.
Then run `bm_schema(command="validate", note_type="open-item", project="__PROJECT__")`
and fold any findings into the completion summary (read-only; never auto-fixed, same
rule Step 0's `memory-doctor` check already follows in this template).

- [ ] **Step 4: Run tests to verify they pass**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: PASS, all tests (existing + new)

- [ ] **Step 5: Lint the touched template**

Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`
Expected: exit 0

- [ ] **Step 6: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template \
        tests/setup_memory_workflow_templates_test.sh
git commit -m "feat(setup-memory-workflow): add Stale Open Items Index rollup to maintenance"
```

---

### Task 5: On-request single-item conversion path

**Files:**
- Modify: `home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`
- Modify: `tests/setup_memory_workflow_templates_test.sh`

**Interfaces:**
- Consumes: Task 3's `open-item` note shape and pointer-line format.
- Produces: nothing further downstream — this is the last content-shape task.

- [ ] **Step 1: Write the failing template-regression test**

```bash
# appended to tests/setup_memory_workflow_templates_test.sh
function test_maintenance_template_documents_on_request_conversion() {
    local found=0
    grep -qi 'on-request' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}

function test_maintenance_template_conversion_is_not_bulk() {
    # Guards against this step regressing into an automatic sweep of every
    # legacy Open item.
    local found=0
    grep -qi 'never a bulk' "$TEMPLATE_MAINT" && found=1
    assert_same "1" "$found"
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: FAIL on the two new assertions

- [ ] **Step 3: Add the conversion path to `save-session-maintenance-skill.md.template`**

Add a new sub-section titled "On-request legacy Open-item conversion": only when the
user names one or more specific existing (legacy, freeform-prose) Open items for
conversion — never a bulk/automatic sweep of every legacy item — extract exactly those
items: create each one's
`open-items/` note (inferring `found_session` from the surrounding dated entry it
originally appeared under, and `severity` from any existing "(low priority)"-style
marker in its text) with `bm_write(overwrite=false)`, replace its prose bullet in the
status note with the standard pointer line from Task 3, and verify both receipts
before reporting done — the same explicit-invocation, no-sweep discipline this
template already applies to its reference-fact triage.

- [ ] **Step 4: Run tests to verify they pass**

Run: `bashunit tests/setup_memory_workflow_templates_test.sh`
Expected: PASS, all tests (existing + new)

- [ ] **Step 5: Lint the touched template**

Run: `tests/lint-shell home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template`
Expected: exit 0

- [ ] **Step 6: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/assets/save-session-maintenance-skill.md.template \
        tests/setup_memory_workflow_templates_test.sh
git commit -m "feat(setup-memory-workflow): add on-request legacy Open-item conversion"
```

---

### Task 6: Version bump, changelog, and full verification

**Files:**
- Modify: `home/dot_claude/skills/setup-memory-workflow/scripts/lib-drift-warn.sh`
- Modify: `home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md`

**Interfaces:**
- Consumes: everything from Tasks 1–5.
- Produces: `SMW_VERSION` moved to the next integer, so `check-drift.sh update`
  propagates every template change above to existing installs.

- [ ] **Step 1: Bump `SMW_VERSION` in `lib-drift-warn.sh`**

Increment the existing `SMW_VERSION=24` to `25`.

- [ ] **Step 2: Add a `## v25` entry to `CHANGELOG.md`**

Summarize, in this file's existing prose style (see v23's entry for shape): the
Open-section overflow signal and `check-drift.sh open-staleness` subcommand (Tasks 1–2,
backed by the live-evidence finding that Open items, not Status Summary narrative, are
the actual bloat driver — see
`docs/superpowers/specs/2026-11-17-status-note-open-items-bloat-design.md`); the
forward-only pointer-ized Open-item shape in `save-session` (Task 3); the Stale Open
Items Index rollup and `bm_schema` validation step in `save-session-maintenance`
(Task 4); and the on-request, non-bulk legacy-item conversion path (Task 5). State the
version bump ships these template changes to existing installs via
`check-drift.sh update`, matching every prior version's closing line.

- [ ] **Step 3: Run the full test suite**

Run: `make check`
Expected: all lint and test targets pass, including
`bashunit tests/setup_memory_workflow_open_items_test.sh` and
`bashunit tests/setup_memory_workflow_templates_test.sh`

- [ ] **Step 4: Commit**

```bash
git add home/dot_claude/skills/setup-memory-workflow/scripts/lib-drift-warn.sh \
        home/dot_claude/skills/setup-memory-workflow/CHANGELOG.md
git commit -m "chore(setup-memory-workflow): bump to v25 for Open-item bloat mitigation"
```
