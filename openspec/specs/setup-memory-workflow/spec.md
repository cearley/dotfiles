# setup-memory-workflow Specification

## Purpose
Installs and runs the Basic Memory 1.x session workflow: `save-session`, manual `save-session-maintenance`, startup reminders, recovery detection and a direct-write guard. `check` and startup `drift-warn` observe existing state; explicit `install`, `update` and targeted `apply` perform setup and repair. Rendered skills bake the resolved project identity, while shared hook scripts read current checkout state at runtime. Version-only drift can be updated; identity mismatches require explicit targeted repair. Automatic recording additionally requires a valid checkout-bound `.basic-memory-workflow.json` grant; installation never grants consent. One-time saves, recovery of a named prior transcript and maintenance retain their own authorization boundaries. Host tool approvals remain independent.

## Requirements

### Requirement: basic-memory project registration
The workflow SHALL discover existing BM registration before explicit installation. It SHALL register a missing local project at `$HOME/.local/share/basic-memory/$PROJECT` and preserve an existing registration, including custom paths, without silently relocating notes or replacing routing.

#### Scenario: First-time setup
- **WHEN** `check-drift.sh install` runs in a project with no existing basic-memory registration
- **THEN** it resolves `$PROJECT` (see the project identity requirement below), then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before any piece is created

#### Scenario: Re-run on existing project
- **WHEN** `check-drift.sh install` runs in a project already registered with basic-memory
- **THEN** existing registration is discovered read-only and reused without another project-add call or relocation
- **AND** incompatible identity or routing is reported for explicit resolution rather than overwritten

#### Scenario: Existing registration has a custom path
- **WHEN** installation discovers the intended BM project already registered outside the default notes root
- **THEN** it preserves that registration and reports any default-path-only excerpt limitation without moving notes

#### Scenario: basic-memory not installed at session start
- **WHEN** `check-drift.sh install` runs and the `basic-memory` CLI is not on `PATH`
- **THEN** it reports `MISSING` and exits non-zero immediately, before attempting registration or creating any piece — `save-session`'s own installation/version check (see the separate installation requirement) independently surfaces the same problem if the user runs `/save-session` without ever having run `check-drift.sh`

#### Scenario: Plugin enabled mid-session, SessionStart never fires
- **WHEN** considering the retired plugin-era failure mode this scenario originally described — a plugin enabled mid-session via `/reload-plugins` never getting its `SessionStart` hook to fire that session, so a second, redundant per-invocation registration check inside `save-session`/`sync-memory` was needed as a fallback
- **THEN** it no longer applies: the workflow only ever runs when `check-drift.sh` is explicitly invoked in a project (see the "Per-project explicit opt-in" requirement) — there is no "plugin becomes active" event to race against, so registration discovery and any required creation at `check-drift.sh install` time is sufficient with no per-save creation fallback needed

### Requirement: basic-memory installed via uv tool install
The workflow SHALL check for a working uv-installed BM 1.x `basic-memory` installation on each `save-session` invocation (not once at install time) and instruct the user to install it with `uv tool install 'basic-memory>=1,<2'`, not `uvx` or `pip`, if missing or incompatible.

#### Scenario: basic-memory not found
- **WHEN** `save-session` runs and the CLI is absent or its version is outside BM 1.x
- **THEN** it tells the user to run `uv tool install 'basic-memory>=1,<2'` and stops before attempting project registration or any note write

### Requirement: Per-project explicit opt-in
Installing this workflow into a given project SHALL always be an explicit, individual action — running `check-drift.sh install` (or `update`/`apply`) directly in that project. The workflow SHALL NOT become active in a project merely because it is active elsewhere.

#### Scenario: Installed in one project only
- **WHEN** `check-drift.sh install` has been run in Project A, creating its `.claude/skills/save-session/` etc.
- **THEN** Project B, where the script has never been run, has no `save-session`/`save-session-maintenance` skills and no `SessionStart` hook from this workflow

#### Scenario: Plugin enabled in one project only
- **WHEN** considering the retired plugin-era mechanism this scenario originally described — enabling `basic-memory-workflow` for Project A via `enabledPlugins` in that project's `.claude/settings.json` or `.claude/settings.local.json`, leaving Project B (no such entry) with no hook or skills from the plugin
- **THEN** the same opt-in guarantee holds under the new mechanism, just via a different action — see "Installed in one project only" above, where running `check-drift.sh install` in a project is what opts it in, instead of an `enabledPlugins` entry

#### Scenario: Installation does not grant recording consent
- **WHEN** install, update or apply installs or repairs workflow artifacts
- **THEN** automatic recording remains unauthorized until separate explicit project consent is recorded
- **AND** installing or upgrading another project never changes that consent

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill and the `SessionStart` reminder, `PreToolUse` write-guard and crash-recovery hook *entries* SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for hook entries), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece. The `crash-recovery-hook`, `PreToolUse` write-guard hook, and `SessionStart` reminder hook are deliberate exceptions to the version-marker part of this guarantee — see their own scenarios below.

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh install` finds a piece (skill file, script, hook entry, or `.mcp.json` entry) missing from the current project
- **THEN** it renders the current canonical template into place directly — the explicit install request authorizes missing workflow artifacts, but never a recording-consent grant

#### Scenario: Two projects have independent copies
- **WHEN** the workflow is installed in two different projects
- **THEN** each project has its own physically separate rendered files — editing one project's installed copy has no effect on the other

#### Scenario: One canonical copy serves every enabled project
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that two projects with the plugin enabled ran the exact same shared skill/hook content, with no per-project rendered copy of any of it
- **THEN** it is deliberately inverted, not preserved: each project now has its own independently rendered copy (see "Two projects have independent copies" above) — this is the whole point of returning to a copy-based distribution, since a single shared copy is exactly what made runtime `$PROJECT` resolution necessary and skippable in the first place

#### Scenario: Updating the plugin updates every consumer
- **WHEN** considering the retired plugin-era guarantee this scenario originally described — that changing the canonical plugin content and updating the marketplace propagated to every enabled project automatically, with no per-project drift-check or repair step
- **THEN** it is deliberately inverted, not preserved: canonical template changes now reach an installed project only when `check-drift.sh update` (or `apply`) is explicitly run there — propagation is opt-in and per-project again, in exchange for eliminating the plugin's own weaker update story (a commit-SHA-pinned cache with no `needsUpdate` signal, confirmed stale on a real install during this change's own investigation)

#### Scenario: PreToolUse write-guard hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `PreToolUse` write-guard hook
- **THEN** it does not apply to that piece — the guard script itself is a single, static file deployed machine-wide (not rendered per project) and carries no `setup-memory-workflow-version:N` marker; only the fixed hook *entry* pointing at it is managed per project, and its drift is detected by literal command-string comparison instead (see the dedicated "PreToolUse write-guard hook" requirement below)

#### Scenario: Crash-recovery hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `crash-recovery-hook` `SessionStart` entry
- **THEN** it does not apply to that piece either, for the same reason as the `PreToolUse` write-guard hook: the script itself is static and deployed machine-wide, with no project-specific substitution needed, and only the fixed hook *entry* pointing at it is tracked per project

#### Scenario: SessionStart reminder hook is a deliberate exception
- **WHEN** this requirement's version-marker guarantee is considered against the `SessionStart` reminder hook entry
- **THEN** it does not apply to that piece either: the reminder hook's script is a single, static, non-templated file deployed machine-wide, resolving `$PROJECT` and the status note path itself at runtime (see the "Project identity" requirement's exception above) — only the fixed hook entry pointing at it is tracked per project, by literal command-string comparison, the same as the write-guard and crash-recovery-hook entries

#### Scenario: Upgrading from a prior version replaces the legacy reminder hook without duplicating it
- **WHEN** a project's installed `SessionStart` hooks include a legacy reminder entry from before this version (an exactly recognized owned per-project-rendered `echo` command containing baked note content) and `check-drift.sh update` runs
- **THEN** the legacy entry is removed and the new canonical static reminder-hook entry is present exactly once — never both, and never a second copy of the canonical entry

### Requirement: Crash-recovery hook detects a session that ended without a completed save
A `SessionStart` hook piece (`crash-recovery-hook`) SHALL detect, without spawning any new agent process, when the most recent prior session's transcript has more unsaved real user turns than a fixed threshold since the session that last completed `save-session`'s own evaluation for this project (by session-ID identity combined with a recorded turn-count checkpoint, not transcript mtime — an earlier mtime-based design was proven unsound), and SHALL describe potentially unsaved work without claiming an unobserved crash or SessionEnd event, and SHALL surface a catch-up instruction to the current session via hook stdout rather than performing the save itself.

#### Scenario: Prior session has no completed save
- **WHEN** a new session starts and the most recent prior session transcript's (excluding the session now starting) count of unsaved real user turns — the transcript's total real-user-turn count minus the turn-count recorded in `.claude/.last-saved-session` if that transcript's session ID matches the marker's recorded session ID, or the full total if it doesn't match (never saved at all) — exceeds the fixed threshold
- **THEN** the hook prints a catch-up instruction to stdout naming that prior transcript's path, which Claude Code injects as a system-reminder into the current, already-running session — no `claude -p` or any other new process is spawned

#### Scenario: Prior session was already saved
- **WHEN** a new session starts and the most recent prior session transcript's count of unsaved real user turns (computed the same way) is at or under the fixed threshold
- **THEN** the hook prints nothing and exits zero — this covers both a session that was fully saved and a small session (for example, one ended by `/clear` shortly after it began) that was never saved at all but has too little at stake to be worth a reminder

#### Scenario: A session that saves early and keeps going past the threshold still fires
- **WHEN** a session's most recent save recorded a turn-count checkpoint, and that same session (same session ID) continues for more than the threshold's worth of additional real user turns before ending without saving again
- **THEN** the hook still fires for that session on the next session start, even though its session ID matches the one recorded in `.claude/.last-saved-session` — session-ID identity alone is no longer sufficient to mean "fully covered"

#### Scenario: save-session marks its own completion
- **WHEN** an authorized `save-session` reaches its confirmed "On success" step or a legitimate no-content Step 0 skip after authorization
- **THEN** it writes `$CLAUDE_CODE_SESSION_ID:$TURN_COUNT` into `.claude/.last-saved-session` (content, not just mtime), where `$TURN_COUNT` is the number of real user turns in the current transcript at that moment, so a normal completed evaluation (saved or legitimately skipped) always advances both the identity and the checkpoint the crash-recovery hook compares against

#### Scenario: An older marker with no recorded turn-count degrades to zero, not an error
- **WHEN** `.claude/.last-saved-session` contains a bare session ID with no `:turn_count` suffix (written before this behavior existed)
- **THEN** the hook treats the missing turn-count as zero rather than erroring, self-healing the next time any marker-writing spot in `save-session` runs again

#### Scenario: Currently-starting session is excluded
- **WHEN** the crash-recovery hook scans prior transcripts in the same directory as the session now starting
- **THEN** it excludes the transcript whose filename matches the current session's own `session_id`

#### Scenario: Denied consent is not a completed evaluation
- **WHEN** save-session lacks standing or explicit one-time authorization, or a note write failed or is uncertain
- **THEN** it does not advance the saved-session marker or represent the session as covered

#### Scenario: Detection is distinct from transcript recovery
- **WHEN** the hook inspects local transcript metadata and counts real user turns to detect potentially unsaved work
- **THEN** it may perform that bounded detection without recording consent
- **AND** reconstructing knowledge from another transcript and saving it requires an explicit recovery request

### Requirement: Active session-log note is resolved deterministically, not by search
`save-session`'s Step 1 SHALL read the current status note and resolve the active
session-log note from it by taking the most recent wikilink in its Status Summary
section, rather than by issuing a `bm_search` query against the project's
basic-memory corpus. Step 2 then appends to that resolved note. `bm_search` SHALL be
used only as a fallback when no such wikilink can be found.

#### Scenario: Status note has a recent Detail link
- **WHEN** the current status note's most recent Status Summary entry contains one or
  more wikilinks (e.g. a `Detail: [[...]]` pointer)
- **THEN** Step 1 resolves the note named by the last wikilink in that entry and makes no
  `bm_search` call; Step 2 appends to that note

#### Scenario: No wikilink found — cold start
- **WHEN** the current status note has no wikilink in its Status Summary section (e.g. a
  brand-new project's first-ever `/save-session` run, before any entry has been written)
- **THEN** Step 1 falls back to the prior `bm_search`-based behavior, unchanged

#### Scenario: Multiple wikilinks in the most recent entry
- **WHEN** the most recent Status Summary entry contains more than one wikilink
- **THEN** Step 1 uses the last wikilink in that entry, matching this skill's own
  established convention of placing the session-log pointer at the end of each dated
  paragraph

#### Scenario: Step ordering
- **WHEN** `save-session` runs
- **THEN** Step 1 (read the current status note and resolve the active session-log note)
  completes before Step 2 (append to the session log) begins, so Step 2 appends to the
  note Step 1 already resolved instead of issuing its own read or search

#### Scenario: First save has no existing session log
- **WHEN** an authorized first save has no status link and scoped discovery finds no session log
- **THEN** it creates a session log with bm_write and retains the exact returned identifier for the status link and append
- **AND** ambiguous candidates are surfaced without guessing or appending to an arbitrary result

### Requirement: PreToolUse write-guard hook denies direct basic-memory filesystem writes
The workflow SHALL install a `PreToolUse` hook (matcher `Bash|Edit|Write`) into the target project's `.claude/settings.local.json` that denies any Bash, Edit, or Write call writing to a path under `$HOME/.local/share/basic-memory/` (the whole basic-memory notes tree, not scoped to the current project alone), and directs the model to use the basic-memory MCP tools (`bm_write`/`bm_edit`) instead.

#### Scenario: Guard script is global, not per-project
- **WHEN** the write-guard hook is installed in any project
- **THEN** its `.claude/settings.local.json` hook entry references a single, non-templated script deployed machine-wide — the same fixed global path in every project — rather than a per-project rendered copy

#### Scenario: Bash write denied
- **WHEN** a Bash tool call's command references a path under `$HOME/.local/share/basic-memory/` and is write-shaped (a redirect, or `rm`/`mv`/`cp`/`touch`/`mkdir`/`tee`/`sed -i`/etc.)
- **THEN** the hook emits a `permissionDecision: deny` with a reason pointing at the basic-memory MCP tools, and the Bash call is blocked

#### Scenario: Edit or Write denied
- **WHEN** an `Edit` or `Write` tool call's `file_path` resolves under `$HOME/.local/share/basic-memory/`
- **THEN** the hook denies it the same way as a Bash write

#### Scenario: Reads and unrelated commands are not blocked
- **WHEN** a Bash command only reads a path under the basic-memory tree (e.g. `cat`, `grep`, `jq`, `ls`), or a `Read` tool call targets that tree, or any tool call is unrelated to that tree entirely
- **THEN** the hook makes no permission decision and emits no output

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh install` finds no `PreToolUse` hook entry referencing the guard script in the current project
- **THEN** it creates the entry directly, pointing at the fixed global script path, under the explicit installation request, without granting recording consent

#### Scenario: Drift is detected and repaired by literal command-string comparison, not a version marker
- **WHEN** a positively identified workflow-owned `PreToolUse` hook entry differs from the canonical event, matcher, type or command
- **THEN** `check-drift.sh check` reports `DRIFT`, and explicit `check-drift.sh update` (or `apply write-guard-hook`) repairs only that owned entry to the canonical shape — there is no `NAME-MISMATCH` concept for this piece, since the command string carries no project identity to mismatch

#### Scenario: Guard rationale respects supported external editing
- **WHEN** the guard explains a denial
- **THEN** it describes the preference for indexed agent writes and risks of stale revisions or indexing delay
- **AND** it does not claim human Markdown editing is unsupported or that the heuristic is a security sandbox

### Requirement: Project identity is resolved once, at apply-time
`check-drift.sh` SHALL resolve the current project's basic-memory identity once per invocation, at the top of the script, and use that single resolved value for every piece it renders or checks in that invocation. No per-project-templated installed piece SHALL contain a runtime identity-resolution script or instruction. The `SessionStart` reminder hook's own script is a deliberate exception — see its scenario below — because its whole purpose is reading live content that cannot be pre-rendered.

#### Scenario: Default resolution
- **WHEN** `check-drift.sh` runs inside a git repository with no override file present
- **THEN** it resolves `$PROJECT` as the `basename` of `git rev-parse --show-toplevel`

#### Scenario: Override file present
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists and contains non-blank content
- **THEN** `check-drift.sh` resolves `$PROJECT` as that file's content instead of the git-basename default

#### Scenario: Override file blank or whitespace-only
- **WHEN** `<project-root>/.claude/basic-memory-project.txt` exists but is empty or contains only whitespace
- **THEN** `check-drift.sh` falls through to the git-basename default, treating the file as if it were absent

#### Scenario: Not inside a git repository
- **WHEN** `check-drift.sh` runs outside any git repository
- **THEN** it resolves `$PROJECT_ROOT` as the current working directory rather than exiting — this matches `git rev-parse --show-toplevel`'s own fallback behavior in the script, so the workflow degrades to treating the current directory as the project root rather than failing outright

#### Scenario: SessionStart reminder script resolves identity at runtime, by design
- **WHEN** the `SessionStart` reminder hook's script runs at session start
- **THEN** it resolves `$PROJECT` itself, at that moment, using the same override-file-then-git-basename logic — this is a deliberate exception to the apply-time-only rule, required because the script reads live note content that no apply-time rendering step could have produced

### Requirement: Version drift is unconditionally repairable via `update`
`check-drift.sh update` SHALL unconditionally re-render and overwrite every installed piece whose version marker is stale, with no per-piece confirmation, as long as that piece's project identity still matches current resolution.

#### Scenario: Stale version, correct identity
- **WHEN** an installed piece's version marker is older than the skill's current `SMW_VERSION` and its embedded project name still matches current resolution
- **THEN** `check-drift.sh check` reports it as `DRIFT`, and `check-drift.sh update` overwrites it with current canonical content without asking for confirmation

#### Scenario: `update` never touches an unrelated piece
- **WHEN** `check-drift.sh update` runs and a piece is already `UP-TO-DATE`
- **THEN** that piece is left untouched and not reported

### Requirement: Identity mismatch always takes precedence over version drift and is never auto-repaired
If an installed piece's embedded project name does not match the project's current identity resolution, the workflow SHALL report and treat it as `NAME-MISMATCH` — regardless of whether its version marker is also stale — and SHALL NOT repair it via `update`. Only an explicit `check-drift.sh apply <piece>`, invoked after the user has confirmed the identity change is intentional, may overwrite a `NAME-MISMATCH` piece.

#### Scenario: Identity mismatch alone
- **WHEN** an installed piece's version marker is current but its embedded project name does not match current resolution
- **THEN** `check-drift.sh check` reports `NAME-MISMATCH`, and `check-drift.sh update` skips it, reporting that it was skipped and why

#### Scenario: Simultaneous version drift and identity mismatch
- **WHEN** an installed piece is both version-stale and identity-mismatched
- **THEN** it is still reported and treated as `NAME-MISMATCH`, not `DRIFT` — `update` MUST NOT repair it, since doing so would silently change the piece's identity while appearing to only fix its version

#### Scenario: Confirmed repair via `apply`
- **WHEN** the user confirms a reported `NAME-MISMATCH` is an intentional identity change
- **THEN** `check-drift.sh apply <piece>` overwrites that piece with canonical content rendered against current identity resolution

### Requirement: SessionStart reminder hook reads the status-note excerpt live
The `SessionStart` reminder hook SHALL produce its status-note Open-items excerpt by reading the note's file directly when the session starts, never from a value stored in `.claude/settings.local.json`, and SHALL fall back to an instruction-only message when no excerpt can be produced.

#### Scenario: Status note readable and under the excerpt size cap
- **WHEN** a session starts and the resolved status note's Open-items excerpt is at or under the fixed size cap
- **THEN** the injected reminder includes that excerpt, captured as of the current session's start

#### Scenario: Excerpt exceeds the size cap
- **WHEN** the Open-items section is larger than the fixed excerpt size cap
- **THEN** the hook truncates the excerpt to the cap with a visible truncation indicator

#### Scenario: Status note missing or unreadable
- **WHEN** no status note can be resolved, or the resolved file cannot be read
- **THEN** the hook emits an instruction-only reminder message, with no error surfaced beyond that

#### Scenario: Excerpt is never read from settings.local.json or an MCP call
- **WHEN** the excerpt is produced
- **THEN** it comes from a direct read of the note's file on disk, not from any value written into `.claude/settings.local.json` and not from any MCP tool call

#### Scenario: The hook command itself never varies with note content
- **WHEN** `check-drift.sh check` or `update` compares the installed reminder hook entry against canonical
- **THEN** it compares a single fixed command string, unaffected by the current-status note's size or content

### Requirement: SessionStart reminder hook frames itself as deferential background context
The `SessionStart` reminder, including any excerpt, SHALL be framed as background context the user's current input takes precedence over, and SHALL condition additional `bm_search`/`bm_project(command="recent")` retrieval on the excerpt being insufficient. It SHALL NOT suppress a startup lookup required by higher-priority instructions.

#### Scenario: Reminder defers to current user input
- **WHEN** the reminder would otherwise conflict with the user's current request or the model's in-progress task
- **THEN** its wording explicitly defers to that current input rather than commanding an action that must complete first

#### Scenario: Direct resume or status-request phrasing overrides the default
- **WHEN** the user's message uses direct resume or status-request language (for example, "what's the current status," "where did we leave off," "let's resume/continue")
- **THEN** the reminder's own wording names this phrasing as overriding the "only if insufficient" default for additional retrieval with `bm_search`/`bm_project(command="recent")`

#### Scenario: Global startup lookup remains required
- **WHEN** global instructions require a startup memory lookup and a fresh excerpt is available
- **THEN** the agent still performs that required lookup while avoiding redundant additional retrieval when the excerpt is sufficient

### Requirement: SessionStart reminder hook surfaces current-status note bloat
The `SessionStart` reminder hook SHALL print a suggestion to run `/save-session-maintenance` when the resolved current-status note is at or over `save-session-maintenance`'s own size thresholds, and SHALL NOT perform any repair itself.

#### Scenario: Current-status note is bloated
- **WHEN** the resolved current-status note's total size or any single entry is at or over its threshold
- **THEN** the hook prints a line suggesting `/save-session-maintenance`, in addition to the Open-items excerpt

#### Scenario: Current-status note is not bloated
- **WHEN** the threshold is not crossed
- **THEN** the hook prints nothing for this signal

#### Scenario: Hook never performs the maintenance itself
- **WHEN** the hook detects the note is bloated
- **THEN** it only prints a suggestion — it never invokes `/save-session-maintenance` or any other remediation on its own

### Requirement: SessionStart reminder hook surfaces session-log note bloat
The `SessionStart` reminder hook SHALL print a suggestion to run `/save-session-maintenance` when the active session-log note (the most recently modified note under the project's `sessions/` directory) is at or over `save-session-maintenance`'s rollover threshold, independent of the current-status-note-bloat signal.

#### Scenario: Active session-log note is bloated
- **WHEN** the active session-log note is at or over the rollover threshold
- **THEN** the hook prints a line suggesting `/save-session-maintenance`, independent of whatever the current-status-note-bloat signal prints

#### Scenario: Active session-log note is not bloated
- **WHEN** the active session-log note is under the threshold
- **THEN** the hook prints nothing for this signal

#### Scenario: No session-log note exists yet
- **WHEN** the project's `sessions/` directory is missing or contains no notes
- **THEN** the hook prints nothing for this signal and does not error

### Requirement: Status note canonical path is pinned, not freely chosen
The status note's location SHALL resolve first by an exact path, `status/<project>-current-status.md`, rather than whatever title or location a model chose when the note was first created. A broader fallback glob SHALL be used only when the canonical path does not exist, and a note found only via fallback SHALL be flagged as non-canonical. The workflow SHALL NOT automatically move, rename, or merge any existing note.

#### Scenario: Note already at the canonical path
- **WHEN** a status note exists at `status/<project>-current-status.md`
- **THEN** the reminder hook reads it directly, with no fallback glob and no non-canonical notice

#### Scenario: Note found only via fallback
- **WHEN** no note exists at the canonical path, but one is found via the broader fallback glob under `status/`
- **THEN** the reminder hook reads that note and appends a one-line notice naming the canonical path it could be moved to

#### Scenario: Note not found by either method
- **WHEN** neither the canonical path nor the fallback glob matches anything
- **THEN** the reminder hook prints no excerpt and no non-canonical notice

#### Scenario: Existing note is never auto-moved
- **WHEN** a non-canonical note is detected
- **THEN** no file is moved, renamed, merged, or otherwise mutated by the workflow

### Requirement: SessionStart reminder hook never writes to the basic-memory notes tree
The `SessionStart` reminder hook's script SHALL only read files under the basic-memory notes tree, never create, write, or modify any file there, under any condition, and SHALL exit 0 regardless of what it finds.

#### Scenario: No status note exists anywhere
- **WHEN** the reminder hook finds no status note at the canonical path or via fallback
- **THEN** it does not create one — it degrades to printing no excerpt

#### Scenario: Hook exits zero regardless of what it finds
- **WHEN** the reminder hook runs under any outcome — note found canonically, found via fallback, or not found at all
- **THEN** it exits 0 in every case

### Requirement: BM 1.x scoped tool contract
Workflow instructions SHALL use the BM 1.x tool surface and canonical arguments, pass the intended project on every scoped call, and consult installed manuals when a contract is unclear. Managed local MCP launch SHALL use the uv-installed basic-memory executable instead of resolving a separate uvx environment.

#### Scenario: Retired tool instructions are replaced
- **WHEN** setup renders save or maintenance skills or emits retrieval instructions
- **THEN** actionable calls use bm_read, bm_search, bm_project commands, bm_edit with command, bm_write and bm_move as appropriate
- **AND** the workflow does not rely on removed tool names, implicit project selection or remembered server session state

#### Scenario: Runtime is missing or incompatible
- **WHEN** installation or a save detects an absent CLI, a non-1.x version, or unavailable required MCP tools
- **THEN** it reports the failed prerequisite and stops before note writes
- **AND** it does not install, upgrade or bypass another environment automatically

#### Scenario: Global MCP registration is discovered
- **WHEN** setup finds an existing BM server in the current Claude profile or project
- **THEN** it distinguishes configuration scope and compatibility instead of assuming every matching name is a healthy global registration
- **AND** repair of unfamiliar or customized configuration is explicit

### Requirement: Confirmed mutable-note edits and write receipts
Mutable-note edits SHALL use a checksum from a fresh read and structured success/error receipts. Refused or uncertain writes SHALL NOT be reported as successful saves or advance the saved-session marker.

#### Scenario: Concurrent edit is refused
- **WHEN** a note changed after it was read and bm_edit refuses the supplied expected_checksum
- **THEN** the workflow reports REVISION_CONFLICT without blind overwrite or blind append retry
- **AND** unrelated changes and the saved-session marker remain intact

#### Scenario: Successful receipt has no project field
- **WHEN** an explicit-project write returns a successful structured receipt without a project field
- **THEN** verification uses the documented action, returned identifier/path and checksum without requiring an invented field
- **AND** an explicitly conflicting qualified project path is refused

#### Scenario: Status succeeds and log append fails
- **WHEN** the first note update succeeds but the second note write fails or has an uncertain outcome
- **THEN** the workflow identifies the partial save, leaves the marker unchanged and does not repeat a possibly successful append blindly

### Requirement: Project-local standing recording consent
Automatic curated knowledge and session-checkpoint saves SHALL require explicit standing consent recorded for the current project in .basic-memory-workflow.json. Missing, invalid, revoked, unsupported-version or mismatched consent SHALL deny automatic recording. Read access SHALL NOT require recording consent.

#### Scenario: User grants project consent
- **WHEN** the user explicitly authorizes automatic curated knowledge and session checkpoints for the displayed repository root and BM project
- **THEN** the workflow records that scoped grant and confirms its location and permitted actions
- **AND** another project or checkout receives no implicit grant

#### Scenario: Existing workflow has no consent record
- **WHEN** an old installation is checked, updated or starts a session without a valid consent record
- **THEN** reading existing memory remains permitted but automatic note writes require approval
- **AND** no migration manufactures a grant from old skills, hook presence, global settings or package installation

#### Scenario: Explicit one-time save
- **WHEN** the user directly requests a save while standing consent is absent or revoked
- **THEN** that save is authorized without another redundant confirmation
- **AND** no standing grant is created and a generic wrap-up message is not treated as recording permission

#### Scenario: Consent is revoked or invalidated by identity drift
- **WHEN** the user revokes consent, the repository root or resolved BM project differs, or the record is malformed or unsupported
- **THEN** automatic saves stop and the workflow reports the reason without modifying existing notes
- **AND** a new grant requires explicit authorization

#### Scenario: Consent denied before marker writes
- **WHEN** the save skill lacks standing consent and no one-time save was requested
- **THEN** it stops before note writes or saved-session marker updates and may offer a save or enrollment

### Requirement: Recording consent has bounded authority
Standing consent SHALL cover routine curated findings, decisions and session checkpoints only. Recovery from a different transcript and restructuring, archiving or deleting knowledge SHALL require an explicit request for that action. Standing consent SHALL NOT override host permissions or activate native integrations.

#### Scenario: Recovery needs separate permission
- **WHEN** a hook identifies potentially unsaved work in a different session
- **THEN** it asks before reading that transcript for recovery and before saving reconstructed content, with one request allowed to authorize the complete recovery pass
- **AND** the standing grant alone never initiates that pass

#### Scenario: Maintenance is suggested
- **WHEN** bloat is detected in an opted-in project
- **THEN** the hook only suggests maintenance and does not restructure, archive or delete notes
- **AND** an explicit maintenance invocation authorizes its stated scope

#### Scenario: Host approval still applies
- **WHEN** Claude Code or another host asks for permission to run a BM tool
- **THEN** the workflow respects that control without removing global safeguards or routing through shell commands to bypass it

### Requirement: Inspection is read-only
check-drift.sh check and drift-warn SHALL inspect and report only. They SHALL NOT register projects, create missing workflow files, rewrite settings, migrate legacy artifacts, alter consent or write knowledge. Startup hooks SHALL remain non-mutating and fail open on inspection errors.

#### Scenario: Check encounters missing and legacy pieces
- **WHEN** check runs in a new or legacy project
- **THEN** it reports missing, stale or ambiguous state and the explicit installation/repair route
- **AND** inspected project files and BM registration remain unchanged

#### Scenario: Startup drift warning sees legacy hooks
- **WHEN** SessionStart invokes drift-warn in a project with legacy hook commands
- **THEN** it only reports and never executes legacy migration or removes retired files

### Requirement: Legacy migrations preserve foreign artifacts
Explicit install, update and apply operations SHALL mutate only positively identified workflow-owned legacy artifacts within their authorized scope. Unfamiliar or ambiguous hooks, native BM entries and unrelated settings SHALL survive unchanged. Repeated migration SHALL be idempotent and SHALL NOT grant consent.

#### Scenario: Recognized legacy hook is replaced
- **WHEN** an explicit operation encounters a legacy command whose complete owned signature is recognized
- **THEN** only that owned entry is migrated and the current hook exists exactly once
- **AND** unrelated entries retain their contents and ordering

#### Scenario: Generic basic-memory match is insufficient
- **WHEN** a hook mentions basic-memory but lacks a recognized owned signature
- **THEN** it is retained and reported as ambiguous when relevant, including native plugin or standalone hooks

#### Scenario: Retired skill path contains user content
- **WHEN** an explicit migration encounters a retired skill or state path without sufficient ownership evidence
- **THEN** it reports and preserves that content rather than deleting based only on its path

#### Scenario: Targeted apply stays targeted
- **WHEN** apply targets a single piece
- **THEN** unrelated legacy pieces, consent and settings are not migrated as a side effect

### Requirement: Current hook repair requires positive ownership
Inspection and repair SHALL positively identify workflow-owned current hook entries before replacing them. Generic product names or script-name substrings SHALL NOT establish ownership. Foreign siblings and order SHALL be preserved when owned entries need repair.

#### Scenario: Foreign hook contains a familiar script name
- **WHEN** an unrelated command mentions session-reminder.sh, basic-memory-write-guard or crash-recovery-hook.sh without a recognized owned command shape
- **THEN** check, install, update and apply preserve it and report ambiguity when relevant

#### Scenario: Owned entry has a wrong matcher
- **WHEN** an owned current entry has an incorrect matcher, event, type or command
- **THEN** inspection reports drift without mutation and explicit repair restores the intended entry without modifying foreign hooks

### Requirement: Native checkpoint/orient/diagnostic skills are available but not auto-invoked
The workflow SHALL make upstream BM 1.x `bm-checkpoint`, `bm-orient` and `memory-doctor` skills available as declared, installable skills alongside the existing shared memory skills. Their availability SHALL NOT itself trigger any automatic capture, write or consent change; each remains an explicit, agent- or user-invoked action.

#### Scenario: Skills are declared, not activated
- **WHEN** `bm-checkpoint`, `bm-orient` or `memory-doctor` is declared for installation
- **THEN** no automatic hook, startup capture or consent record is created as a side effect
- **AND** each skill is invoked only when an agent or user explicitly runs it

#### Scenario: Checkpoint write still follows the existing note-write contract
- **WHEN** `bm-checkpoint` performs a note write
- **THEN** the write is subject to the same host tool approvals and recording-consent boundary as any other basic-memory note write this workflow governs
- **AND** it does not bypass the `.basic-memory-workflow.json` consent check by virtue of being an upstream skill rather than `save-session`

### Requirement: Native lifecycle hooks remain disabled pending explicit consent mapping
The workflow SHALL NOT enable BM's native `SessionStart` or `PreCompact` plugin hooks (Claude Code or Codex) in any project as part of piloting the native checkpoint/orient/doctor skills. Enabling those hooks requires a separate, explicit proposal that maps their automatic behavior against the project's recording-consent record.

#### Scenario: Pilot installs skills without their sibling hooks
- **WHEN** the native checkpoint/orient/doctor skills are installed for a pilot project
- **THEN** the upstream plugin's `SessionStart` and `PreCompact` hook registrations are not installed or enabled alongside them

#### Scenario: Future hook adoption needs its own proposal
- **WHEN** enabling a native lifecycle hook is later proposed
- **THEN** that proposal explicitly states how the hook's automatic behavior respects or is gated by `.basic-memory-workflow.json` consent status
- **AND** adoption of the checkpoint/orient/doctor skills under this requirement does not itself authorize that later step

### Requirement: Native setup/configuration skills do not write chezmoi-owned settings
The workflow SHALL NOT use BM's native `bm-setup` skill (or any other upstream skill that writes directly to `.claude/settings.json`, `.claude/settings.local.json`, or `.mcp.json`) to configure a project. Any MCP server registration or project settings this workflow requires SHALL continue to be delivered through chezmoi-managed templates.

#### Scenario: bm-setup is available but its config-writing step is not used
- **WHEN** `bm-setup` or an equivalent upstream setup skill is present in a project's installed skill set
- **THEN** it is not invoked to write or merge `.claude/settings.json`, `.claude/settings.local.json`, or `.mcp.json`
- **AND** the project's actual MCP/server registration is whatever chezmoi's existing managed templates already deliver

#### Scenario: Conflicting settings are reported, not silently merged
- **WHEN** an upstream setup skill is run manually by a user outside this workflow and writes a `basicMemory` settings block
- **THEN** that write is understood to be outside this workflow's ownership boundary and is not treated as chezmoi-managed state
