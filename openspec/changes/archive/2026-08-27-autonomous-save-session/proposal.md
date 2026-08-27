# Automate session-save without confirmation, split from maintenance

> **ABANDONED / SUPERSEDED — 2026-08-27. Implemented but never shipped.**
>
> This change reached implementation-complete (all `tasks.md` items checked) but was abandoned
> before its `SessionStart` hook was ever re-enabled. It is archived with `--skip-specs`: none of
> its delta specs were merged into `openspec/specs/`, because none of the behaviour it describes
> is live, and the machinery it built is being deleted.
>
> **Why it was abandoned — three independent reasons:**
> 1. **Billing boundary.** It spawns `claude -p`, which bills a Max/Pro subscription for automated,
>    non-first-party invocations. Wrapping Claude Code inside a larger automated product is the
>    unambiguous case for an API key.
> 2. **Structural recursion.** A spawned `claude -p` process *is* a Claude Code session, so its own
>    `SessionStart` re-fires the hook that spawned it. This caused a real fork-bomb on 2026-08-24
>    requiring a forced reboot, and a second, slower sequential variant of the same bug was still
>    being found by code review on 2026-08-27 (see tasks.md §9).
> 3. **Cost of containment.** Almost all of this change's complexity — the `mkdir` lock, stale-lock
>    reclaim, the `holder`/`--session-id` binding, the portable timeout watcher, the `PreToolUse`
>    guard, and the session marker's stamping rules — exists solely to contain reason 2. None of it
>    serves the actual goal.
>
> **Superseded by:** the `memory-distiller` change — a polled launchd agent running an API-backed
> Python worker that is not a Claude Code session, and therefore cannot recurse.
>
> **What survives:** the split of `save-session` into append-only work plus a separate
> `save-session-maintenance` skill. That is cherry-picked forward; the automation is discarded.
>
> **Why this record is kept:** the 17 implementation findings, the fork-bomb post-mortem, and the
> review that killed the approach are the evidence base for the replacement design. Read this
> before proposing anything that spawns a Claude Code session from a Claude Code hook.

## Why

`/save-session` today requires either the user to type it explicitly or the model to ask
"should I save this session?" and wait for a yes. That confirmation step is not something
anyone deliberately designed in — `save-session-skill.md.template` contains no instruction
to ask permission — it's just the model's default caution bleeding over from higher-stakes
actions (git commit/push) onto a comparatively low-blast-radius, mostly-append operation.
Separately, a session that ends without any explicit wrap-up (closing the terminal,
`Ctrl+C`, a crash) gets no save at all today — nothing is watching for that case.

This change was designed via an `/opsx:explore` session on 2026-08-24. It started from a
different premise — "build an async script like `sync-memory.py` for `save-session`" — and
was redirected once it became clear `sync-memory` already exists, already has an unattended
`--standalone` mode, and was deliberately scoped to a separate, mechanical, append-only note
(`disable-model-invocation: true`, never touches the curated session-log/status-note). That
separation turned out to be load-bearing, not incidental: `save-session`'s status-note update
requires real editorial judgment (what moved Open→Resolved, when to roll over) — exactly the
failure mode `setup-memory-workflow` v8–v11 already fought (a status note whose "Last
updated" field grew to 9,196 characters from being blindly re-prepended instead of condensed).
Automating that judgment-heavy work unattended, conflated with the routine append work, risked
reintroducing the same bug with nobody watching.

The fix that emerged is a concern split: separate the cheap, bounded, safe-to-automate append
work from the size/triage work that actually carries risk, and give each its own automation
trigger matched to its own blast radius.

## What Changes

- **Split `save-session-skill.md.template` into two concerns:**
  1. **save** (fast, append-only, no hindrance): check `basic-memory` is installed, append to
     the session log with no rollover check, update the status note's Open/Resolved list with
     no size-check or triage. If the status-note read/edit fails, log it and stop — never
     attempt a fix inline.
  2. **maintenance** (periodic, self-healing, higher-risk): the session-log rollover
     (≥300 lines) and the status-note's existing three-signal oversized-note triage (read
     failure / ≥8,000 characters / any single entry ≥800 characters), delegating to
     `memory-defrag`/`memory-lifecycle` where installed.
- **In-session autonomous save, no confirmation asked:** a cheap mechanical pre-filter (a
  tool-call/turn-count threshold — explicitly *not* "were any files edited", see Decision 9 in
  `design.md`) gates whether an LLM judgment call even runs; if it does and judges the session
  decision-worthy, the model runs save's fast path itself, mid-session, without asking.
- **New `SessionEnd` hook** (must detach — `SessionEnd` hooks share a 1.5-second total budget
  and block CLI exit, confirmed against current docs): checks a project-local marker file
  (`.claude/.last-saved-session`) for whether the in-session path already covered this
  session; if not, spawns a detached headless `claude -p` run of save's fast path against this
  session's own transcript (`transcript_path`, supplied in the hook's stdin payload) and exits
  immediately.
- **Extended `SessionStart` hook**, kept non-blocking by explicit design (its real default
  budget is 600 seconds — nothing forces speed here, so detaching before returning is a
  discipline this change imposes, not a platform guarantee):
  1. A pure-shell mechanical check directly against the status-note and session-log **files**
     (no MCP round-trip) for the maintenance thresholds above.
  2. Nothing over threshold → no-op, self-healing style (mirrors `check-drift.sh`'s existing
     "only act on actual drift" idiom).
  3. Something over threshold → check a lockfile (guards against two near-simultaneous
     `SessionStart`s both triggering maintenance); if clear, spawn a detached headless
     `claude -p` maintenance run and print one advisory line (`SessionStart` stdout is shown
     to Claude, confirmed against current docs) before returning.
  4. Same hook also closes the one gap `SessionEnd` structurally cannot cover: if the marker
     file doesn't cover the most recent transcript at all (the session was `SIGKILL`ed or the
     machine crashed — no hook can observe that at the moment it happens), spawn the same
     detached save catch-up here, on a best-effort, next-session basis.
- **Execution engine: `claude -p` headless, uniformly, for both detached paths.** A
  provider-swappable plain-script alternative (direct Anthropic API or OpenRouter, modeled on
  `sync-memory.py --standalone`) was considered and rejected — maintenance needs to delegate to
  the `memory-defrag`/`memory-lifecycle` companion skills, which are agentic Claude Code
  workflows only `claude -p` can invoke. Model selection stays a one-flag (`--model`) change in
  either case.
- **All new runtime state — marker file, lockfile, audit log — lives project-local under
  `.claude/`**, matching `settings.local.json`'s existing personal-machine scoping.

### Non-goals

- Not reusing or modifying `sync-memory` or its distilled-insights note. It stays exactly as
  it is today: a separate, user-invoked-only (`disable-model-invocation: true`) mechanism
  targeting a different, append-only note.
- Not building periodic mid-session syncing. Evidence gathered during exploration — SpecStory
  writes one continuously-growing file per session, and the existing cursor design is
  whole-file-mtime-based, not byte/line-offset — showed periodic mid-session sync would
  reprocess and re-append overlapping content every interval, for no robustness benefit that
  `SessionEnd` + `SessionStart` don't already provide (a session's transcript is durable on
  disk continuously regardless of how the process ends).
- Not adding OpenRouter or any provider-swappable execution path for the detached work. Decided
  against in favor of `claude -p` headless uniformly — see above.
- Not guaranteeing coverage of true `SIGKILL`/crash/power-loss cases at the moment they happen —
  structurally impossible for any hook to observe. Covered on a best-effort, next-`SessionStart`
  basis instead, the same way `check-drift.sh` already self-heals other drift.
- Not touching `check-drift.sh`'s existing DRIFT/NAME-MISMATCH/version-marker machinery beyond
  adding the new pieces this change introduces — the existing self-heal contract is unchanged.

## Capabilities

### Modified Capabilities

- `setup-memory-workflow`: `save-session` splits into a fast `save` concern and a periodic
  `maintenance` concern; adds a `SessionEnd` hook and extends the `SessionStart` hook with a
  non-blocking, self-healing mechanical check; adds an in-session no-confirmation autonomous
  invocation path gated by a mechanical pre-filter + LLM judgment; adds project-local
  marker/lock/audit-log runtime state.

## Impact

- **Affected files**: `home/dot_claude/skills/setup-memory-workflow/assets/save-session-skill.md.template`
  (trimmed to the save concern); a new `assets/save-session-maintenance-skill.md.template`
  (the extracted rollover/triage concern); `scripts/check-drift.sh` (new managed pieces: the
  `SessionEnd` hook entry, the extended `SessionStart` mechanical-check script, marker/lock/log
  path conventions); `scripts/migrations.sh` (cleanup for any pre-split installs, if needed);
  `CHANGELOG.md` (new `SMW_VERSION` entry); `openspec/specs/setup-memory-workflow/spec.md`
  (new/modified requirements, per this change's spec delta).
- **Affected tags**: none beyond existing — this is Claude Code tooling configuration, not
  package/machine-config, and carries no `.chezmoidata`/tag implications.
- **Affected personas**: all — hooks and skills render per-project under `.claude/`, independent
  of which `CLAUDE_CONFIG_DIR` persona runs a given session.
- **Migration**: existing `setup-memory-workflow` installs pick up the new pieces via
  `check-drift.sh update`/`apply`, the same self-healing pattern every prior version bump has
  used — no destructive change to existing session-log or status-note content.
- **Security implications**: none new. `claude -p` headless reuses the existing Claude Code
  subscription auth already in place for interactive sessions — no new secret/API key to
  provision, which was itself a factor in rejecting the OpenRouter/direct-API alternative.
- **External dependencies**: none added — `claude -p` is the already-installed Claude Code CLI.
