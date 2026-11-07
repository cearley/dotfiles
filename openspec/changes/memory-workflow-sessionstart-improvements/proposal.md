# Proposal

## Why

A 2026-11-07 cross-project comparison of `setup-memory-workflow` against `oh-my-claudecode`'s
and `oh-my-pi`'s memory architectures (recorded in
`docs/architecture/setup-memory-workflow.md`, "Comparative lessons" section) surfaced two gaps
in the current `SessionStart` hook behavior. First, the reminder hook only *instructs* the
model to call `search_notes`/`recent_activity` — there is no guarantee a bloated or
poorly-ranked search result surfaces the right content, and no fallback if the model skips the
instruction outright. Second, `check-drift.sh check` and `/save-session-maintenance` are both
honestly documented as manual-only, but nothing ever nudges a session to actually run them —
template drift and note bloat can go unnoticed indefinitely between runs. Both gaps are cheap
to close with local-file-only hook logic, following the same no-process-spawn pattern the
existing crash-recovery hook already uses.

## What Changes

- Extend the `SessionStart` reminder hook so it injects a small, size-bounded excerpt of the
  current-status note's Open items directly into the hook message — a cheap local read of the
  note file under `~/.local/share/basic-memory/<project>/`, not an MCP call — so critical open
  items are visible even before `search_notes`/`recent_activity` runs or if the model skips that
  instruction. If the excerpt can't be read cheaply (file missing, unreadable, oversized), the
  hook falls back to today's instruction-only message — this is additive, never a replacement
  that could leave the model with nothing.
- Extend the existing `cmd_drift_warn` function — already invoked on every `SessionStart` via
  the canonical reminder hook's command chain, and already resolving `$PROJECT` fresh on every
  invocation (per `resolve_project()`) — with a second, independent signal: current-status note
  bloat, using the same thresholds `save-session-maintenance` already documents (≥~8,000
  characters or ≥200 lines total, or any single entry ≥~800 characters). No new hook piece, no
  new global script, and no new `SessionStart` entry are needed — `drift-warn` already runs
  every session. It only nudges — it never runs `/save-session-maintenance` or
  `check-drift.sh update`/`apply` itself, and it never weakens the existing manual-confirmation
  model for `DRIFT`/`NAME-MISMATCH` repairs.
- Bump `SMW_VERSION` in `scripts/executable_check-drift.sh` so existing installs are flagged as
  drifted and pick up both pieces on their next `check-drift.sh check`/`update`.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `setup-memory-workflow`: adds a bounded status-note excerpt to the existing `SessionStart`
  reminder hook's injected message, and adds a new `SessionStart` staleness-nudge hook piece
  with its own drift/creation handling in `check-drift.sh`.

## Impact

- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` — new
  staleness-nudge piece (check/update/apply handling, canonical command generation, drift
  detection), extended reminder-hook message rendering, `SMW_VERSION` bump.
- `home/dot_claude/skills/setup-memory-workflow/assets/hook-message.txt.template` — template
  gains the bounded excerpt rendering (or a documented in-script fallback if templating the
  excerpt itself is impractical — see design.md).
- `cmd_drift_warn` in `executable_check-drift.sh` gains the note-bloat signal; no new script
  file, no new `SessionStart` entry, no deployment-model change.
- Every project that has already run `check-drift.sh check` picks up the `cmd_drift_warn`
  change automatically on the next session start, since that function lives in the global
  `check-drift.sh` script, not a per-project rendered copy — no `update`/`apply` needed for that
  half. The reminder-hook-message excerpt change *is* a per-project rendered piece, so it still
  reports `DRIFT` and needs `check-drift.sh update` to pick up, consistent with every prior
  `SMW_VERSION` bump.
- No tag (`core`/`dev`/`ai`/etc.) gating changes — this only affects projects that have already
  opted into `setup-memory-workflow`.
- No secrets, permissions, or SIP implications — both additions are local file reads inside
  `~/.local/share/basic-memory/` and `.claude/`, matching the existing crash-recovery hook's
  threat model and the write-guard hook's trust boundary.

## Non-goals

- Not changing the manual-only nature of `check-drift.sh check`/`update`/`apply` or
  `/save-session-maintenance` — the staleness nudge only suggests running them, it never invokes
  either automatically.
- Not changing `save-session`'s own Step 1/Step 2 logic, the write-guard hook, or the
  crash-recovery hook's existing behavior.
- Not introducing a new memory backend, embeddings, or any dependency beyond what
  `check-drift.sh` and the existing hook scripts already use (`bash`, `jq`).
- Not attempting the broader "named routing cheat-sheet" or "capture-path schema drift" lessons
  from the same comparative analysis — those are tracked separately, not in this change's scope.
