# Tasks for Automate session-save without confirmation, split from maintenance

## 1. Split the save-session skill into save + maintenance

- [x] 1.1 Trim `assets/save-session-skill.md.template` down to the fast path: check
      `basic-memory` installed, append session log (drop the ≥300-line rollover block), update
      status note Open/Resolved (drop the Step 3b oversized-triage block) — attempt the
      read/edit, and on failure, log to the new audit log (task 5) and stop
- [x] 1.2 Create `assets/save-session-maintenance-skill.md.template` containing the extracted
      session-log rollover logic and the full Step 3b three-signal triage logic (read failure /
      ≥8,000 chars / any entry ≥800 chars), delegating to `memory-defrag`/`memory-lifecycle`
      exactly as before — unchanged detection thresholds and remediation, just relocated
- [x] 1.3 Decide and document the exact frontmatter for the new skill (name, description,
      whether it needs `disable-model-invocation` — likely yes, since it's meant to run only via
      the `SessionStart` hook's detached spawn or explicit manual invocation, not the live
      model's own initiative mid-conversation)

## 2. In-session autonomous save (no confirmation)

- [x] 2.1 Define the mechanical pre-filter precisely (tool-call count and/or conversation-turn
      count threshold) — explicitly not keyed on file-edit presence (design.md Decision 9)
- [x] 2.2 Add the "run save-session directly, don't ask for confirmation" instruction — likely
      belongs in `save-session-skill.md.template` itself (or a short addition to the
      `session-completion` skill) rather than only as personal feedback memory, so it's
      auditable/versioned in the repo per the original automation requirements
- [x] 2.3 On a successful in-session save, write `$CLAUDE_CODE_SESSION_ID` to
      `.claude/.last-saved-session`

## 3. `SessionEnd` hook (detached save catch-up)

- [x] 3.1 Write the hook script: read `session_id`/`transcript_path` from stdin JSON, compare
      `session_id` against `.claude/.last-saved-session`; if it already matches, exit
      immediately with no spawn
- [x] 3.2 If it doesn't match, spawn a detached `claude -p` run of `save-session`'s fast path
      against `transcript_path` (properly detached — `nohup`/`disown` or equivalent, redirected
      stdio — verify it survives the parent CLI process exiting, per design.md's flagged risk)
      and return immediately
- [x] 3.3 Filter the hook's `matcher` to skip the `resume` reason value (session isn't actually
      ending) — confirm against current hook docs whether `clear`/`logout`/`prompt_input_exit`/
      `other` is the right inclusion set. Implemented as an in-script `reason` check rather than
      the hook config's own `matcher` field — keeps the inclusion logic in one testable place.
- [x] 3.4 Add this hook entry to `check-drift.sh`'s managed pieces (CREATE/DRIFT/NAME-MISMATCH
      contract, same as the existing `SessionStart` hook piece)

## 4. `SessionStart` hook extension (maintenance trigger + crash recovery)

- [x] 4.1 Write the mechanical check script: `wc -c` / longest-line / line-count against the
      status-note and session-log files directly (resolve their paths under
      `~/.local/share/basic-memory/<project>/` — no MCP call). Status note found via a
      permalink-frontmatter grep (fixed, derivable convention); session log found via a
      best-effort heuristic (root-level vault notes with a `## YYYY-MM-DD` heading) since it
      has no comparably fixed permalink — documented as a known limitation, not a full fix.
- [x] 4.2 Add the lockfile check (`flock`-based, per design.md Decision 6) guarding the
      detached maintenance spawn against overlapping `SessionStart`s
- [x] 4.3 Add the crash-recovery check: does `.claude/.last-saved-session` cover the most
      recently modified transcript for this project? If not, spawn the same detached save
      catch-up as the `SessionEnd` hook (task 3.2). Uses the hook payload's own
      `transcript_path` (its `dirname` gives the per-project transcript directory) rather than
      re-deriving Claude Code's cwd-to-directory-name encoding independently.
- [x] 4.4 Print one advisory line to stdout when a detached run is spawned (visible to Claude
      per current `SessionStart` docs) — registered as a separate `SessionStart` array entry
      from the existing basic-memory-reminder `echo`, so the two don't collide or compete.
- [x] 4.5 Add this extended hook logic to `check-drift.sh`'s managed pieces, alongside the
      existing basic-memory-reminder `SessionStart` entry

## 5. Runtime state (marker, lockfile, audit log)

- [x] 5.1 File names finalized (all under `.claude/`): `.last-saved-session` (marker, plain
      session-id text), `.save-session-maintenance.lock` (lockfile, held via `flock`),
      `.save-session-log` (audit log, tab-separated: timestamp, trigger, outcome, detail),
      `.save-session-headless.out` (stdout/stderr sink for detached `claude -p` runs, not a
      structured log — the audit log is the structured record)
- [x] 5.2 Confirmed via `.gitignore`: `.claude/*` is already ignored with an explicit allow-list
      (`commands/`, `hooks/`, `skills/`, `agents/`, `rules/`, `settings.json`) that none of these
      new flat files match — same existing pattern already covers `settings.local.json`, so no
      `.gitignore` change is needed. This also settles the audit log: it's gitignored like the
      rest, not committed for cross-machine visibility (consistent with "project-local and
      unshared" in the spec delta).

## 6. `check-drift.sh` / version bump

- [x] 6.1 Bump `SMW_VERSION` in `scripts/check-drift.sh` (11 → 12)
- [x] 6.2 Add `apply`/`update` support for every new piece (save-session-maintenance-skill,
      the two new script pieces, and a new "fixed-command hook piece" category for the
      SessionEnd/SessionStart-maintenance hook wiring — `fixed_hook_status`/`apply_fixed_hook`/
      `report_fixed_hook`/`update_fixed_hook`, mirroring but distinct from the existing
      templated-file helpers since these commands carry no project identity)
- [x] 6.3 Added a `CHANGELOG.md` v12 entry matching the style of v8–v11
- [x] 6.4 No migration function needed: the existing `save-session/SKILL.md` transitions from
      v11's monolithic content to v12's trimmed content via the *existing* generic DRIFT
      mechanism (version marker 11 ≠ 12, identity still matches → DRIFT → safely auto-repairable
      via `update`) — nothing is left behind that migrations.sh's contract would apply to. Every
      other new piece is entirely new (CREATED on first check/update), not a migration case.

## 7. Spec and verification

- [x] 7.1 `openspec validate autonomous-save-session --strict` passes clean
- [x] 7.2 Verified via a real (non-live-session) test: piped a synthetic `SessionEnd` JSON
      payload into the rendered `session-end-save-hook.sh` against a stubbed `claude` binary
      (records invocation, exits instantly, so real headless spin-up time doesn't confound the
      measurement) — script itself returns in ~0.05s, comfortably under the 1.5s budget.
      **Found and fixed a real bug in the process**: the original design used `flock`, which
      does not exist on stock macOS (this repo's actual target platform) — confirmed by the
      test failing with `flock: command not found`. Replaced with a portable `mkdir`-based lock
      (see 7.6), which also fixed a second, independently-flagged gap: the original fd-based
      lock only covered this script's own execution, not the detached run's full duration.
- [x] 7.3 Verified the same way: synthetic `SessionStart` payload against a small, under-threshold
      status note and a current marker — 0 spawns, no advisory line, fast return.
- [x] 7.4 Verified the marker-dedup logic directly: `SessionEnd` hook with a marker that already
      names the ending session → 0 spawns; with a mismatched/missing marker → spawns correctly
      with the expected prompt; `reason: "resume"` → 0 spawns regardless of marker state. (The
      full round-trip through a real interactive in-session save into a real session end is not
      exercised here — that requires an actual live session boundary, which this apply pass
      can't trigger on itself.)
- [x] 7.5 Verified the crash-recovery detection logic directly with fixture transcript files:
      marker older than a prior (non-current) transcript's mtime → spawns catch-up referencing
      the correct prior session id; marker current → 0 spawns; the *currently starting* session's
      own transcript is correctly excluded from "prior" consideration. (Not a literal `kill -9` of
      a real Claude Code process — the underlying mtime-comparison logic this depends on is fully
      exercised, but true end-to-end crash coverage will only be confirmed by an actual future
      crash.)
- [x] 7.6 Verified directly: lock held (simulated) → second invocation skips, 0 spawns; lock
      stale (mtime >30min old) → reclaimed automatically, spawn proceeds; real run → lock acquired
      before spawn, released (via `rmdir` in the detached subshell) after the stubbed `claude`
      process exits. Ran the *real* `check-drift.sh check`/re-`check` (not just the rendered
      templates in isolation) against a sandboxed fresh git repo with stubbed `basic-memory`/
      `claude` binaries — confirmed every new piece (skill, both scripts, both hook-wiring
      entries) is CREATED correctly, executable, `__PROJECT__`-substituted, and idempotent
      (100% UP-TO-DATE on re-check with no changes).
- [x] 7.7 Validated by construction/reasoning, not a runnable test: the mechanical pre-filter
      (tool-call/conversation-length, not file-edit presence) is a judgment instruction for a
      live model, not deterministic logic — its correctness was established by walking both
      cited cases against the actual rule during design (design.md Decision 9): the trivial
      session-id lookup fails the tool-call/length threshold (skip, correct); this exploration
      session itself passes despite editing zero files (save, correct). True live-usage
      validation happens organically in future sessions, not as a scripted check here.
- [x] 7.8 **Post-incident fix (2026-08-24, see design.md Decision 6):** 7.6's lock verification
      only exercised the `maintenance` branch — the crash-recovery branch (4.3) shipped with no
      lock at all, and its spawned `claude -p` process re-triggers this same `SessionStart` hook
      recursively (each spawned session sees the same stale marker until the run it came from
      finishes), which caused an actual unbounded fork-bomb incident live. First fixed same-day
      with a dedicated recovery-only `mkdir` lock; superseded by 7.9's shared lock below.
- [x] 7.9 **Comprehensive runaway-process/recursion review (2026-08-24), requested by the user
      immediately after 7.8.** Traced every spawn site in both hook scripts end-to-end rather
      than re-checking only the branch already patched. Found and fixed three more gaps, all in
      the same pass (see design.md Decisions 5 and 6 for full rationale on each):
      1. **Crash-recovery's gate was marker-*mtime* vs transcript-mtime, not a session-id
         match.** Since the marker is always written mid-session, before that session's own
         transcript finishes growing, this false-positived on nearly every session (not just
         crashed ones) and — because each spawned catch-up worker's own transcript became the
         next "latest prior" — degenerated into a permanent, one-per-`SessionStart` chain of
         spawns even with 7.8's lock in place (the lock stopped concurrent duplicates, not this
         sequential recurrence). Fixed by comparing the marker's stored session id against the
         latest prior transcript's own id instead of comparing mtimes.
      2. **`session-end-save-hook.sh` had no lock at all**, unlike the `SessionStart`-spawned
         paths, and all three sites can edit the same status note concurrently. Fixed by giving
         it the same `mkdir` lock, shared with the other two.
      3. **The `maintenance` and crash-recovery branches could both fire from a single
         `SessionStart`**, spawning two concurrent workers with no coordination between them.
         Fixed by having them share one lock dir (`.claude/.save-session-worker.lock.d`) instead
         of each other's separate lock, replacing 7.8's recovery-only lock — whichever branch's
         `mkdir` wins, the other correctly sees it held and skips.
      4. **No spawned `claude -p` had a timeout.** A hung run would just have its lock reclaimed
         every 30 minutes while continuing to run, accumulating orphaned processes rather than
         being terminated. Fixed with a portable (no `timeout`/`gtimeout` on stock macOS)
         sleep+kill watcher: background the real command, race a 1500s sleep against it, kill
         whichever loses.
      Verified all four in an isolated sandbox (stubbed `claude` on a scoped `PATH`, fake `HOME`
      and transcript directory, single Bash call so the sandboxed env couldn't leak across
      calls — a mistake made and caught while verifying 7.8, documented in memory): confirmed a
      normally-saved session no longer triggers a spurious recovery; confirmed a genuinely
      uncovered prior session still does, and that the shared lock blocks a concurrent duplicate
      spawned from either script; confirmed a hung worker is killed and its lock released well
      before the stale-lock reclaim window. Applied identically to both local hooks and both
      `.template` mirrors (diffed after to confirm only the `__PROJECT__`/`__SMW_VERSION__`
      placeholders differ). Re-verify end-to-end once more before this hook is re-registered in
      `settings.local.json` (currently removed as the incident's immediate mitigation).
- [x] 7.10 **Interactive/background contention fix (2026-08-24, see design.md Implementation
      Finding 12), raised by the user as a follow-up question to 7.9.** 7.9's shared lock only
      guards the three headless-spawn sites against each other — it says nothing about the
      foreground interactive session's own `save-session` run (Step 3/4, direct MCP tool calls),
      which can race a background `maintenance`/crash-recovery worker on the exact same session
      log or status note. Added a new Step 2 to `save-session`'s `SKILL.md` (and its `.template`
      mirror) that checks `.claude/.save-session-worker.lock.d` and defers (logs a `deferred`
      outcome, touches neither note nor the marker) if held — deliberately check-and-skip, not
      check-and-acquire, since the interactive path must never stall the live conversation or
      risk a lock stuck open by an interrupted turn. Old Steps 2/3 renumbered to 3/4
      accordingly; the two headless-worker spawn prompts (crash-recovery in
      `session-start-maintenance-check.sh`, catch-up in `session-end-save-hook.sh`) updated to
      say "Step 1 through Step 4" and to explicitly tell the worker it already holds the lock
      and should skip the new Step 2 — otherwise every worker would see its own lock and defer
      against itself. Confirmed via grep that only these four files reference the old step
      numbers (no stale "Step 3" cross-references left elsewhere); `openspec validate --strict`
      still passes.
- [x] 7.11 **Real enforcement for 7.10's check (2026-08-24, see design.md Implementation
      Finding 13), raised by the user directly challenging 7.10: an LLM can ignore an
      instructed check in a way it can't ignore a hook.** Added
      `.claude/hooks/basic-memory-worker-guard.sh`, a new `PreToolUse` hook (matcher
      `mcp__basic-memory__edit_note`) that denies the tool call outright whenever
      `WORKER_LOCK_DIR` is held by a session other than the caller — enforced by the harness,
      not dependent on the model reading or obeying anything. Identifying the legitimate
      holder without trusting the spawned model to self-report: `spawn_headless` (both hook
      scripts) now generates a UUID via `uuidgen` and writes it to `$WORKER_LOCK_DIR/holder`
      *before* spawning, then passes that same UUID as `claude -p --session-id <uuid>` — a
      pure code-to-code binding confirmed via `claude --help`. Every `rmdir` on the lock dir
      became `rm -rf` (it now always contains the `holder` file, so it's never empty) — both
      `reclaim_stale_lock` copies and both of `spawn_headless`'s release paths. Registered the
      new hook in `.claude/settings.local.json` via the project's `update-config` skill
      (`hooks.PreToolUse`, alongside the untouched existing `SessionStart`/`SessionEnd`
      entries), validated with `jq -e` per that skill's required check. Verified in an
      isolated sandbox: no lock → allow; lock held by another session → deny with the
      expected reason; lock held by the calling session → allow; a stale (>30min) lock →
      self-reclaimed by the guard itself, not just by the next `SessionStart`. Separately
      confirmed end-to-end that the `--session-id` actually passed to `claude -p` matches the
      `holder` file's content exactly. Applied to both local hooks and all three `.template`
      mirrors (including the new `basic-memory-worker-guard.sh.template`); diffed after to
      confirm only placeholders differ. Not yet propagated into `check-drift.sh`'s
      CREATE/DRIFT tracking — flagged as a follow-up, not done in this pass (see "8. Known
      limitations / follow-ups" below).

## 8. Known limitations / follow-ups

- [x] 8.1 **Wired into `check-drift.sh` (2026-08-26).** Extended `fixed_hook_status`/
      `report_fixed_hook`/`update_fixed_hook` with an optional 5th/4th `matcher` arg
      (default `""`, preserving the existing `SessionEnd`/`SessionStart` match-everything
      behavior unchanged) so a freshly CREATEd `PreToolUse` entry gets its real matcher
      (`mcp__basic-memory__edit_note`) instead of `""` — an empty matcher on `PreToolUse`
      would otherwise fire the guard on every tool call, not just `edit_note`.
      `apply_fixed_hook` didn't need the new arg (it only overwrites `command` on an
      already-correctly-matchered entry). Added new pieces `basic-memory-worker-guard-script`
      (ordinary templated-file piece, same family as the other two hook scripts) and
      `basic-memory-worker-guard-hook-config` (fixed-hook piece) to `cmd_check`/`cmd_update`/
      `cmd_apply`, plus the piece-name lists in the header docstring and both usage/error
      strings. Also found and fixed a real bug while verifying: the guard's template/local
      script had no rendered occurrence of `__PROJECT__` anywhere (unlike its two sibling
      scripts, which each embed the resolved project name somewhere), so `piece_status`'s
      generic NAME-MISMATCH check — which greps the installed file for the literal resolved
      `$PROJECT` string — always failed for it. Fixed by adding a
      `# basic-memory project: __PROJECT__` anchor comment (matching
      `session-end-save-hook.sh.template`'s existing pattern) to both the `.template` and the
      locally-deployed copy. Verified in an isolated sandbox (stubbed `basic-memory`/`claude`
      on a scoped `PATH`, fresh git repo): first `check` → CREATED for both new pieces with
      the correct matcher in `.claude/settings.local.json`; second `check` → UP-TO-DATE for
      both (idempotent); `update` → no-op; existing `SessionEnd`/`SessionStart` entries
      unaffected (still `matcher: ""`); rendered template diffed against the locally-deployed
      copy — identical modulo `__PROJECT__`/`__SMW_VERSION__` placeholders.
- [x] 8.2 **Auth-gap re-verification (2026-08-26).** The status note flagged an unresolved risk:
      a leftover `.claude/.save-session-headless.out` from the original incident showed every
      headless `claude -p` spawn failing with `Not logged in · Please run /login`, and every
      fix since had only been tested against a stubbed `claude` binary, never the real one.
      Re-tested directly against the real binary: user ran the exact invocation shape the
      hooks use (`nohup bash -c 'claude -p "..." --session-id <uuid> --permission-mode
      bypassPermissions ...' </dev/null >/dev/null 2>&1 & disown`) with a harmless no-tool
      prompt. Result: `PONG` — authenticates and responds correctly when detached. The auth
      gap does not reproduce; `claude auth status` also confirms a valid interactive login.
      The original failures were specific to the incident's environment/timing and are not a
      standing defect in the current mechanism. (Note: Claude Code's own auto mode classifier
      blocks the assistant itself from spawning a detached `claude -p` process directly — this
      verification had to be run by the user via `!`, not by the assistant's Bash tool.)

## 9. Post-review spawn-safety fixes (2026-08-27)

Raised by a full-diff `/code-review high` of `origin/main..HEAD` after the change was already
implementation-complete; each finding below was independently confirmed against live runtime
state before being acted on. All four are one cluster — the conditions under which a detached
worker is spawned, identified, and accounted for. Version bumped v13 → v14.

- [x] 9.1 **Marker stamped on every terminal outcome, closing a latent runaway-spawn loop.**
      `.claude/.last-saved-session` was written only by `save-session`'s "On success" step, so a
      worker that no-op'd or failed left it stale. Because the crash-recovery gate terminates
      only when the newest prior transcript's ID *matches* the marker — and a worker's own
      transcript becomes that newest prior — the mismatch could never clear, and every
      subsequent `SessionStart` spawned another worker indefinitely. Confirmed live: a no-op
      (`EE7A2F25…`) and a failure (`db812f53…`) in `.save-session-log` had both left the marker
      untouched. Marker-stamping is now a shared "Recording the session marker" step that
      success, the new explicit `On no-op` section, and `On failure` all end with; the empty-ID
      case leaves the file unchanged and logs, rather than writing a value matching no session.
      Step 0's proactive pre-filter deliberately does not stamp (a "not yet" judgement on a live
      session, not a terminal outcome). `save-session-maintenance` gained the same stamp on its
      headless path — otherwise every maintenance run guaranteed one wasted catch-up spawn
      afterwards. See design.md Finding 15.
- [x] 9.2 **Spawned `claude -p` exit status is now checked and logged.** Both hook scripts
      `wait`ed on the child and released the lock without inspecting `$?`, so any process dying
      before the model started (auth failure, missing binary, timeout-kill, OOM) left nothing in
      the audit log — only raw text in `.save-session-headless.out`, which nothing reads. That is
      how 9 rounds of `Not logged in` went unnoticed here while the mechanism looked healthy.
      Both spawn sites now capture the status, distinguish a signal kill (`> 128`, naming the
      timeout watcher) from an ordinary non-zero exit, and log a `failure` tagged with the
      calling branch (`SessionEnd catch-up` / `maintenance` / `SessionStart crash-recovery`).
      See design.md Finding 16.
- [x] 9.3 **Two smaller spawn-safety defects.** (a) `SessionEnd` now `stat`-checks
      `transcript_path` before taking the lock — a stale path previously burned a full worker run
      holding the shared lock, starving a real save queued behind it (observed in
      `.save-session-log` four seconds apart). (b) The worker session ID was best-effort on
      `uuidgen`; without it no `holder` file was written and `claude -p` ran with no
      `--session-id`, so `basic-memory-worker-guard.sh` — which fails closed on an empty holder —
      would deny the worker the only operation it exists to perform, for the full 25-minute
      timeout. Now falls back to `python3` then `/proc/sys/kernel/random/uuid`, and abandons the
      spawn (lock released, failure logged) if none is available. Also converted two
      `[ -n "$x" ] && cmd` trailing tests to `if` blocks — under `set -e` a false trailing test
      is itself a fatal status. See design.md Finding 17.
- [x] 9.4 **Verified in an isolated sandbox** (stubbed `claude`/`uuidgen`/`python3` on a scoped
      `PATH`, fake `HOME` and transcript dir, nothing touching the real repo, vault, or CLI):
      24 assertions across both hooks, all passing. Covers transcript-missing → no spawn; happy
      path → spawned with a pre-assigned `--session-id`, lock released, nothing logged as
      failure; non-zero exit → `exited N` logged with the caller's label; no UUID source → no
      spawn, lock released, failure logged; marker match → catch-up suppressed; lock held →
      crash-recovery skips. The decisive pair: with the worker's stamp applied the next
      `SessionStart` is quiet, and with it removed the spawn recurs — reproducing the exact loop
      9.1 fixes. One real bug was caught by the sandbox and fixed during this pass: unescaped
      `"On no-op"` inside the double-quoted `PROMPT` string terminated it early and broke the
      `SessionEnd` hook with exit 127.
- [x] 9.5 **Templates and rendered copies re-verified in parity** at `SMW_VERSION=14` — all five
      local copies re-rendered from their canonical `.template`/asset sources with the same
      `sed` substitution `check-drift.sh` uses, then diffed to confirm they differ in nothing.
