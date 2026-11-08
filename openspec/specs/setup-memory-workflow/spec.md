# setup-memory-workflow Specification

## Purpose
Bootstraps and runs the basic-memory session workflow (`save-session`, `sync-memory`, a `SessionStart` reminder hook, and a `PreToolUse` write-guard hook) by copying rendered templates into each target project via `check-drift.sh`. Project identity resolves once, at apply-time, and is baked into every per-project-templated piece — there is no runtime resolution script. A version marker embedded in each templated piece lets `check-drift.sh check` report drift and `check-drift.sh update` unconditionally repair version-only drift; an identity mismatch (`NAME-MISMATCH`) is never auto-repaired and always requires an explicit `apply <piece>` after confirmation. The write-guard hook is the one piece that is not per-project-templated — see the dedicated requirement below.

## Requirements

### Requirement: basic-memory project registration
The workflow SHALL ensure the current project is registered with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` as part of `check-drift.sh check`, before any per-project piece is created or repaired.

#### Scenario: First-time setup
- **WHEN** `check-drift.sh check` runs in a project with no existing basic-memory registration
- **THEN** it resolves `$PROJECT` (see the project identity requirement below), then `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project before any piece is checked or created

#### Scenario: Re-run on existing project
- **WHEN** `check-drift.sh check` runs in a project already registered with basic-memory
- **THEN** `basic-memory project add` exits 0 with a notice; the check continues without error and without re-creating anything

#### Scenario: basic-memory not installed at session start
- **WHEN** `check-drift.sh check` runs and the `basic-memory` CLI is not on `PATH`
- **THEN** it reports `MISSING` and exits non-zero immediately, before attempting registration or creating any piece — `save-session`'s own `which basic-memory` check (see the separate installation requirement) independently surfaces the same problem if the user runs `/save-session` without ever having run `check-drift.sh`

#### Scenario: Plugin enabled mid-session, SessionStart never fires
- **WHEN** considering the retired plugin-era failure mode this scenario originally described — a plugin enabled mid-session via `/reload-plugins` never getting its `SessionStart` hook to fire that session, so a second, redundant per-invocation registration check inside `save-session`/`sync-memory` was needed as a fallback
- **THEN** it no longer applies: the workflow only ever runs when `check-drift.sh` is explicitly invoked in a project (see the "Per-project explicit opt-in" requirement) — there is no "plugin becomes active" event to race against, so registration happening once, at `check-drift.sh check` time, is sufficient with no fallback needed

### Requirement: basic-memory installed via uv tool install
The workflow SHALL check for a working `basic-memory` installation on each `save-session` invocation (not once at install time) and instruct the user to install it with `uv tool install basic-memory`, not `uvx` or `pip`, if missing.

#### Scenario: basic-memory not found
- **WHEN** `save-session` runs and `which basic-memory` returns no result
- **THEN** it tells the user to run `uv tool install basic-memory` and stops before attempting project registration or any note write

### Requirement: Per-project explicit opt-in
Installing this workflow into a given project SHALL always be an explicit, individual action — running `check-drift.sh check` (or `update`/`apply`) directly in that project. The workflow SHALL NOT become active in a project merely because it is active elsewhere.

#### Scenario: Installed in one project only
- **WHEN** `check-drift.sh check` has been run in Project A, creating its `.claude/skills/save-session/` etc.
- **THEN** Project B, where the script has never been run, has no `save-session`/`sync-memory` skills and no `SessionStart` hook from this workflow

#### Scenario: Plugin enabled in one project only
- **WHEN** considering the retired plugin-era mechanism this scenario originally described — enabling `basic-memory-workflow` for Project A via `enabledPlugins` in that project's `.claude/settings.json` or `.claude/settings.local.json`, leaving Project B (no such entry) with no hook or skills from the plugin
- **THEN** the same opt-in guarantee holds under the new mechanism, just via a different action — see "Installed in one project only" above, where running `check-drift.sh check` in a project is what opts it in, instead of an `enabledPlugins` entry

### Requirement: Skill is distributed as per-project rendered copies, not a shared reference
The `save-session` skill and the `SessionStart` hook configuration SHALL each be rendered from a canonical template into the target project's own `.claude/` directory (or `.claude/settings.local.json`, for the hook), with a version marker (`setup-memory-workflow-version:N`) embedded in each rendered piece. The `crash-recovery-hook` and `PreToolUse` write-guard hook are deliberate exceptions to the version-marker part of this guarantee — see their own scenario below.

#### Scenario: Missing piece is created unconditionally
- **WHEN** `check-drift.sh check` finds a piece (skill file, script, hook entry, or `.mcp.json` entry) missing from the current project
- **THEN** it renders the current canonical template into place directly — creating a missing piece is always safe and requires no confirmation

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

### Requirement: Crash-recovery hook detects a session that ended without a completed save
A `SessionStart` hook piece (`crash-recovery-hook`) SHALL detect, without spawning any new process, when the most recent prior session's transcript has more unsaved real user turns than a fixed threshold since the session that last completed `save-session`'s own evaluation for this project (by session-ID identity combined with a recorded turn-count checkpoint, not transcript mtime — an earlier mtime-based design was proven unsound), and SHALL surface a catch-up instruction to the current session via hook stdout rather than performing the save itself.

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
- **WHEN** `save-session` reaches either its "On success" step or its Step 0 no-op/skip outcome
- **THEN** it writes `$CLAUDE_CODE_SESSION_ID:$TURN_COUNT` into `.claude/.last-saved-session` (content, not just mtime), where `$TURN_COUNT` is the number of real user turns in the current transcript at that moment, so a normal completed evaluation (saved or legitimately skipped) always advances both the identity and the checkpoint the crash-recovery hook compares against

#### Scenario: An older marker with no recorded turn-count degrades to zero, not an error
- **WHEN** `.claude/.last-saved-session` contains a bare session ID with no `:turn_count` suffix (written before this behavior existed)
- **THEN** the hook treats the missing turn-count as zero rather than erroring, self-healing the next time any marker-writing spot in `save-session` runs again

#### Scenario: Currently-starting session is excluded
- **WHEN** the crash-recovery hook scans prior transcripts in the same directory as the session now starting
- **THEN** it excludes the transcript whose filename matches the current session's own `session_id`

### Requirement: Active session-log note is resolved deterministically, not by search
`save-session`'s Step 1 SHALL read the current status note and resolve the active
session-log note from it by taking the most recent wikilink in its Status Summary
section, rather than by issuing a `search_notes` query against the project's
basic-memory corpus. Step 2 then appends to that resolved note. `search_notes` SHALL be
used only as a fallback when no such wikilink can be found.

#### Scenario: Status note has a recent Detail link
- **WHEN** the current status note's most recent Status Summary entry contains one or
  more wikilinks (e.g. a `Detail: [[...]]` pointer)
- **THEN** Step 1 resolves the note named by the last wikilink in that entry and makes no
  `search_notes` call; Step 2 appends to that note

#### Scenario: No wikilink found — cold start
- **WHEN** the current status note has no wikilink in its Status Summary section (e.g. a
  brand-new project's first-ever `/save-session` run, before any entry has been written)
- **THEN** Step 1 falls back to the prior `search_notes`-based behavior, unchanged

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
- **WHEN** `check-drift.sh check` finds no `PreToolUse` hook entry referencing the guard script in the current project
- **THEN** it creates the entry directly, pointing at the fixed global script path, with no confirmation needed (same as any other missing piece)

#### Scenario: Drift is detected and repaired by literal command-string comparison, not a version marker
- **WHEN** an installed `PreToolUse` hook entry's command string (identified by containing `basic-memory-write-guard`) differs from the canonical command string
- **THEN** `check-drift.sh check` reports `DRIFT`, and `check-drift.sh update` (or `apply write-guard-hook`) overwrites it with the canonical command — there is no `NAME-MISMATCH` concept for this piece, since the command string carries no project identity to mismatch

### Requirement: Project identity is resolved once, at apply-time
`check-drift.sh` SHALL resolve the current project's basic-memory identity once per invocation, at the top of the script, and use that single resolved value for every piece it renders or checks in that invocation. No installed piece SHALL contain a runtime identity-resolution script or instruction.

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

### Requirement: SessionStart reminder hook includes a bounded status-note excerpt
The `SessionStart` reminder hook SHALL include a size-bounded excerpt of the current-status note's Open items directly in its injected message, derived from a cheap local file read with no MCP call and no new process spawned beyond ordinary local utilities, and SHALL fall back to today's instruction-only message whenever that excerpt cannot be produced. When the excerpt is non-empty, the injected message SHALL also state the date the excerpt was captured. `check-drift.sh check` SHALL report a change limited to the excerpt's own content — the rendered hook command's embedded `setup-memory-workflow-version:N` marker unchanged — as a distinct `STALE-EXCERPT` state, separate from `DRIFT`. The injected message, including the excerpt, SHALL be framed as background context that current user or tool input takes precedence over, not as a directive that must be completed before anything else. The message SHALL condition its instruction to call `search_notes`/`recent_activity` on the excerpt being insufficient, rather than commanding that call unconditionally, and SHALL name user phrasing that indicates a direct resume or status request as overriding that default.

#### Scenario: Status note readable and under the excerpt size cap
- **WHEN** a session starts and the project's current-status note file is present and its Open-items excerpt is at or under the fixed size cap
- **THEN** the injected reminder includes that excerpt in addition to the existing instruction to call `search_notes`/`recent_activity`

#### Scenario: Excerpt exceeds the size cap
- **WHEN** the Open-items section is larger than the fixed excerpt size cap
- **THEN** the hook truncates the excerpt to the cap with a visible truncation indicator, rather than growing the injected message unbounded or failing

#### Scenario: Status note missing or unreadable
- **WHEN** the current-status note file cannot be found or read at the expected local path
- **THEN** the hook emits today's instruction-only reminder message, unchanged, with no error surfaced beyond that — this is purely additive and never regresses the existing behavior

#### Scenario: Excerpt reflects only local file state, never a live query
- **WHEN** the excerpt is produced
- **THEN** it is read directly from the note's file on disk under `~/.local/share/basic-memory/`, not retrieved via any MCP tool call or other query that could block or spawn a process

#### Scenario: Excerpt includes its capture date
- **WHEN** the excerpt is non-empty
- **THEN** the injected message states the date the excerpt was captured, so a reader can judge how fresh it might be without the excerpt itself being recomputed live

#### Scenario: check distinguishes an excerpt-only change from real template drift
- **WHEN** `check-drift.sh check` finds the installed hook command's embedded version marker matches the current `SMW_VERSION`, but the full command string still differs from canonical because only the baked excerpt text (or its capture date) changed
- **THEN** it reports `STALE-EXCERPT`, not `DRIFT`, for that piece — `check-drift.sh update` still repairs it the same unconditional way `DRIFT` is repaired

#### Scenario: Real version or template drift still reports DRIFT
- **WHEN** the installed hook command's embedded version marker differs from the current `SMW_VERSION`, regardless of what the excerpt contains
- **THEN** `check-drift.sh check` reports `DRIFT`, not `STALE-EXCERPT`, consistent with every other templated piece

#### Scenario: Reminder is framed as background context, not a directive that overrides current input
- **WHEN** the `SessionStart` reminder (including any excerpt) would otherwise conflict with the user's current request or the model's in-progress task
- **THEN** the reminder's wording explicitly defers to current user and tool input, rather than commanding an action that must be completed first

#### Scenario: Real memory retrieval is conditional on the excerpt's sufficiency
- **WHEN** the injected excerpt (with its capture date) already covers what the current turn needs
- **THEN** the reminder's wording does not command an unconditional `search_notes`/`recent_activity` call — it names that call as something to make only if the excerpt turns out to be insufficient, stale, or missing

#### Scenario: Direct resume or status-request phrasing overrides the default
- **WHEN** the user's message uses direct resume or status-request language (for example, "what's the current status," "where did we leave off," "let's resume/continue")
- **THEN** the reminder's own wording names this kind of phrasing as a signal that should override the "only if insufficient" default, prompting the real `search_notes`/`recent_activity` call regardless of how fresh the excerpt looks — detected by the model reading the user's message in the same turn, with no additional hook or runtime mechanism

### Requirement: drift-warn surfaces current-status note bloat, not just version drift
The `drift-warn` subcommand SHALL check both the current-status note's size and the active session-log note's size, using the `$PROJECT` value it already resolves on every invocation, and SHALL print a suggestion to run `/save-session-maintenance` when either is oversized — in addition to its existing save-session-skill version-drift check. It SHALL NOT invoke `/save-session-maintenance` or any repair itself under any condition.

#### Scenario: Current-status note is bloated
- **WHEN** `drift-warn` runs and the current-status note's total size or any single entry is at or over the same thresholds `save-session-maintenance` already defines (total size roughly 8,000 characters or 200 lines, or any single entry roughly 800 characters)
- **THEN** it prints a line suggesting `/save-session-maintenance`, in addition to (not instead of) its existing version-drift line if that also applies

#### Scenario: Current-status note is not bloated
- **WHEN** `drift-warn` runs and none of the note-bloat thresholds are crossed
- **THEN** it prints nothing for this signal (independent of whatever the version-drift check prints)

#### Scenario: drift-warn never performs the maintenance itself
- **WHEN** `drift-warn` detects bloat
- **THEN** it only prints a suggestion — it never invokes `/save-session-maintenance`, `check-drift.sh update`, or any other remediation on its own

#### Scenario: No new identity resolution is introduced
- **WHEN** `drift-warn` evaluates the note-bloat signal
- **THEN** it uses the same `$PROJECT` value `resolve_project()` already computes at the top of every `check-drift.sh` invocation — no new or additional identity resolution path is added for this signal

#### Scenario: Active session-log note is bloated
- **WHEN** `drift-warn` runs and the active session-log note — the most recently modified note under the project's `sessions/` directory — is at or over `save-session-maintenance`'s own session-log rollover threshold (300 lines)
- **THEN** it prints a line suggesting `/save-session-maintenance`, independent of (and in addition to) whatever the current-status-note-bloat and version-drift lines print

#### Scenario: Active session-log note is not bloated
- **WHEN** `drift-warn` runs and the active session-log note is under the rollover threshold
- **THEN** it prints nothing for this signal

#### Scenario: No session-log note exists yet
- **WHEN** `drift-warn` runs and the project's `sessions/` directory under basic-memory is missing or contains no notes
- **THEN** it prints nothing for this signal and exits 0, degrading the same way every other signal in this subcommand does when its input is absent

#### Scenario: Active log identified by recency, not by re-parsing note content
- **WHEN** `drift-warn` evaluates the session-log bloat signal
- **THEN** it identifies the active session-log note as the most recently modified file under the project's `sessions/` directory, rather than re-deriving it from the current-status note's wikilinks — the resolution mechanism `save-session`'s own Step 1 uses — so this signal does not carry a second, independently fallible reimplementation of that resolution logic into a hook context with no MCP access to verify it
