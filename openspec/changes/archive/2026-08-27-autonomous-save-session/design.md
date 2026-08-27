## Context

See `proposal.md` for motivation. This design emerged from an `/opsx:explore` session on
2026-08-24. Relevant existing mechanics, established during that session by reading the actual
code and fetching current docs rather than assuming:

- `sync-memory.py.template` already exists, already installed per-project, with a working
  cursor-based state file (`.specstory/.sync-memory-state.json`, mtime-keyed) and a
  `--standalone` mode that calls the Anthropic API directly (Haiku) and writes straight to the
  vault file on disk — no MCP round-trip needed, since basic-memory's "vault" is just markdown
  files under `~/.local/share/basic-memory/<project>/`. It is explicitly `disable-model-invocation: true`
  and scoped to a separate "Distilled SpecStory Insights" note, never the curated session-log/
  status-note pair `save-session` maintains.
- SpecStory (`.specstory/history/*.md`) writes **one continuously-rewritten file per session**,
  confirmed by inspecting mtimes mid-session (this exploration's own transcript file changed
  mtime three times while being read). `sync-memory`'s cursor is whole-file mtime, not a
  byte/line offset.
- Claude Code independently writes its **own** durable per-session transcript, unrelated to
  SpecStory, at `$CLAUDE_CONFIG_DIR/projects/<encoded-cwd>/<session_id>.jsonl` — confirmed by
  finding this session's own file via `$CLAUDE_CODE_SESSION_ID`. `SessionEnd`'s hook payload
  includes this path directly as `transcript_path`, so no SpecStory dependency is needed for
  the save/maintenance mechanism this change adds.
- `SessionEnd` and `SessionStart` are both already-configured hook events on every persona on
  this machine (confirmed via `jq '.hooks | keys[]?'` across `~/.claude*/settings.json`).
  `setup-memory-workflow` currently only uses `SessionStart` (the basic-memory reminder).
- Current `SessionEnd` hook docs (fetched during this session): payload includes `session_id`,
  `transcript_path`, `cwd`, `reason` (`clear`/`resume`/`logout`/`prompt_input_exit`/`other`).
  Hooks run synchronously and block CLI exit; **all `SessionEnd` hooks share a 1.5-second total
  budget**, raised only if a per-hook `timeout` is set longer, capped at 60 seconds. `SessionEnd`
  cannot fire on `SIGKILL`, a closed terminal, or a crash — by construction, no hook can.
- Current `SessionStart` hook docs: default timeout 600 seconds, blocks CLI startup until hooks
  complete, but nothing enforces speed — a slow `SessionStart` hook is a self-inflicted problem.
  `SessionStart` stdout (unlike most hook events) is shown to Claude as context. No built-in
  guard against two sessions starting close together both running the same hook logic.
  `claude --help` confirms `-p`/`--print` headless mode exists with `--model`, `--mcp-config`,
  `--permission-mode` flags — reuses the CLI's existing auth, not a separate API key.
- `check-drift.sh` (`SMW_VERSION=11` as of this design) already establishes the exact idiom this
  change extends: mechanical, idempotent checks; CREATE-if-missing always safe; DRIFT
  auto-repairable via `update`; NAME-MISMATCH never auto-repaired. New pieces this change adds
  follow that same contract rather than inventing a new one.
- `setup-memory-workflow` v8–v11's changelog is the concrete evidence for why judgment-heavy
  status-note work is risky to automate blind: a real status note broke `read_note` at 70K+
  characters while sitting at only ~117 lines, driven by a single field re-prepended every
  session instead of condensed.

## Goals / Non-Goals

**Goals:**
- Remove the confirmation step before `/save-session`'s fast path runs, in-session.
- Cover sessions that end with no explicit wrap-up at all (closed terminal, crash) on a
  best-effort basis.
- Keep the judgment-heavy triage/rollover work isolated from the routine append work, so
  automating the latter doesn't inherit the former's risk.
- Make the automation auditable (a log survives even though nothing interactive is watching)
  and idempotent (no double-saves, no duplicate maintenance runs).

**Non-Goals:**
- Not modifying `sync-memory` (see proposal.md).
- Not building true real-time/periodic mid-session syncing.
- Not supporting a provider-swappable execution backend (OpenRouter, direct API) for the
  detached work — see Decision 8.
- Not solving true `SIGKILL`/crash coverage at the moment it happens — structurally impossible.

## Decisions

**1. Split `save-session` into `save` and `maintenance` as two separately-triggered concerns,
not two steps of one flow.** The existing single flow's Step 3 (status-note update) already
requires reading the note to know current Open/Resolved state — so "no hindrance" for the fast
path can't mean "never read it," only "never try to *fix* what the read finds." Concretely:
`save` attempts the status-note read/edit and, on failure, logs and stops — it does not retry,
does not triage, does not roll over. `maintenance` owns 100% of the size-detection and
remediation logic, entirely decoupled from whether any particular save succeeded. This is the
core risk-reduction move: the fast, frequently-run, unattended-safe path only ever performs
small bounded edits (append one entry, move a few Open→Resolved items); the wholesale
restructuring work that's genuinely risky to run blind never runs on that cadence at all.

**2. `SessionEnd` triggers `save`'s catch-up; it cannot trigger `maintenance`.** Confirmed via
current docs: `SessionEnd` hooks share a hard 1.5-second budget (extendable, capped at 60s) and
block CLI exit — nowhere near enough for an agentic `claude -p` run reading a transcript and
editing notes. The hook command itself must detach a background process and return
near-instantly; it cannot do the real work inline regardless of configured timeout.

**3. A project-local marker file (`.claude/.last-saved-session`) dedups in-session saves against
`SessionEnd` catch-up.** The in-session path (Decision 9) writes the current `$CLAUDE_CODE_SESSION_ID`
to this file **on every terminal outcome — success, no-op, and failure alike** (revised; see
Finding 15 — the original "on a successful save" wording was the direct cause of a latent
runaway-spawn bug). The marker therefore means "the last session `save-session` reached a
terminal outcome on", not "the last session that saved successfully". `SessionEnd`'s hook checks it first: if it already names the
ending session, the in-session path already covered it and the hook is a no-op — avoiding a
redundant detached `claude -p` spin-up on the common path where the user got a natural,
in-conversation save already.

**4. `SessionStart` is the only trigger for `maintenance`, and it's opportunistic/self-healing,
not literally cron.** Rejected running `maintenance` on a real cron/launchd schedule (would need
to enumerate every project this skill is installed in, decoupled from any actual session
activity) in favor of a cheap check at the one point a session already starts anyway — matching
`check-drift.sh`'s existing "only act on actual drift" idiom exactly. The check itself must stay
pure-shell against the note/log **files directly** (`wc -c`, longest-line, line count) — no MCP
round-trip, no LLM call — so it costs effectively nothing even though `SessionStart`'s real
default budget (600s) wouldn't force that discipline on its own.

**5. `SessionStart` also covers `save`'s crash-recovery gap, using the same marker file.**
`SessionEnd` cannot fire on `SIGKILL`/crash/closed-terminal by construction. `SessionStart` can
check, on the *next* session, whether the marker file covers the most recent transcript at all;
if not, it spawns the same detached save catch-up `SessionEnd` would have. This reuses
Decision 3's marker for a second purpose (crash signal, not just dedup) rather than inventing a
parallel mechanism.
  - **Revised (2026-08-24): the gate compares the marker's *content* (a session id) against the
    latest prior transcript's own session id, not the marker file's *mtime* against the
    transcript's mtime.** The original mtime-based gate was structurally broken: `save`'s
    "On success" step writes the marker *mid-session*, before that same session's own closing
    turns keep appending to its transcript — so the marker file is virtually always older than
    the transcript that just wrote it, crash or no crash. That false-positived on essentially
    every session, and because the spawned catch-up worker's own transcript then became the new
    "latest prior" for the *next* `SessionStart`, it formed a permanent, self-perpetuating chain
    of unnecessary `claude -p` spawns — one per future `SessionStart`/resume, forever, with
    nothing ever having crashed. An id-match gate self-terminates the chain instead: once any
    worker (in-session or catch-up) finishes and stamps the marker with its own id, that
    worker's own transcript *is* the new latest-prior and its id matches the marker, so the next
    `SessionStart` correctly sees "already covered" and stops. Found during a comprehensive
    runaway-process/recursion review requested after the Decision 6 incident below — the lock
    that incident produced only bounded *concurrent* duplicate spawns; it did nothing to stop
    this *sequential*, indefinite one.

**6. A lock guards every detached spawn against overlap — one shared lock across all three
spawn sites (`maintenance`, crash-recovery, and `SessionEnd`'s own catch-up), not one per
site.** Current docs confirm there's no built-in guard against two sessions starting close
together both running `SessionStart` hooks. Two nearly-simultaneous `SessionStart`s could
otherwise both see the same over-threshold note and both spawn a `maintenance` run — the
standard `flock`/pidfile idiom (the docs' own example for this exact situation; `mkdir` used
instead of `flock` since the latter isn't available on stock macOS) prevents that, matching how
a real cron job guards against overlapping runs. All three spawn sites can edit the *same*
basic-memory status note, so the lock is a single shared `.claude/.save-session-worker.lock.d`
rather than a separate lock per site — otherwise two of the three could still run concurrently
and race a read-modify-write against that note. A spawn that loses the race (including
`SessionEnd`'s, which previously had no lock at all) is skipped and logged rather than run
unlocked; the next `SessionStart`'s crash-recovery check (Decision 5) picks up anything a skip
left uncovered. Each detached run is also now killed by a portable sleep+kill watcher after
1500s if it hangs (no `timeout`/`gtimeout` on stock macOS either), so a stuck run is terminated
directly instead of just having its lock reclaimed every 30 minutes while it keeps running.
  - **Incident (2026-08-24): the crash-recovery spawn (Decision 5) was shipped without any lock
    and caused a runaway `claude -p` fork bomb.** The detached `claude -p` process Decision 5
    spawns is itself a new Claude Code session — its own `SessionStart` re-runs this same hook.
    Because the marker file wasn't updated until that spawned run *finished*, every session it
    in turn triggered (subagents, resumed sessions, etc.) saw the same stale marker and spawned
    another catch-up run, unboundedly, with no lock to stop it. Dozens of `claude` processes
    spawned before the user could intervene, degrading the machine badly enough to require a
    reboot. First fixed same-day with a dedicated recovery-only lock; then, during the
    comprehensive review below, folded into the single shared lock described above once the
    `SessionEnd`-side gap (no lock at all) and the maintenance/recovery double-fire gap (both
    could spawn from one `SessionStart`) were also found. The user's first response was to
    remove the `SessionStart` hook registration from `settings.local.json` entirely — that
    remains the safety net; these fixes are what would make re-enabling it safe.
  - **Follow-up review (2026-08-24), requested explicitly by the user after the incident above:**
    a comprehensive pass over every spawn site in this change turned up three more gaps beyond
    the one already patched: (a) Decision 5's mtime-based gate, fixed above; (b)
    `session-end-save-hook.sh` had no lock at all, so it could race the `SessionStart`-spawned
    workers on the same status note; (c) the `maintenance` and crash-recovery branches are
    independent `if` blocks that can both fire from a single `SessionStart`, so they needed to
    share the same lock, not each have their own, to actually prevent that race; (d) no spawned
    run had any timeout, so a hung `claude -p` would silently accumulate every 30 minutes as the
    stale-lock reclaim let a new one start without ever killing the old one. All four addressed
    in the same pass; verified in an isolated sandbox (stubbed `claude`, fake `HOME`/transcript
    dir, single Bash call so the sandbox env couldn't leak across calls — a mistake made and
    caught during the *first* fix's verification) before being applied to both the local hooks
    and their `.template` mirrors.

**7. `maintenance` delegates to `memory-defrag`/`memory-lifecycle` exactly as today's Step 3b
does, unchanged** — this change relocates *when* that logic runs, not *what* it does.

**8. Execution engine: `claude -p` headless (Engine A), uniformly, not a provider-swappable
plain-script alternative (Engine B).** `sync-memory.py --standalone` already demonstrates
Engine B's shape: a single isolated LLM-call function (`client.messages.create(...)`, deferred-
imported), operating directly on vault files, trivially portable to any OpenAI-compatible
endpoint (OpenRouter included) via one adapter function. That pattern was seriously considered
for symmetry with `sync-memory` and because it's lighter-weight and provider-agnostic. Rejected
because `maintenance`'s delegation to `memory-defrag`/`memory-lifecycle` (Decision 7) is only
possible through an agentic Claude Code session — those are skills, not callable functions, and
a plain completion call has no way to invoke them. Since `save`'s catch-up and `maintenance`'s
triage both need to be spawned by the same detached mechanism for consistency, Engine A wins
for both rather than splitting the two detached paths across different engines. Model choice
stays trivially adjustable (`claude -p --model <alias>`) even without Engine B.
  - **Alternative rejected**: OpenRouter/direct-API (Engine B) as the *default*, with `claude -p`
    as a fallback only when `maintenance` needs skill delegation. Rejected for added complexity
    (two engines to maintain, a dispatch decision between them) with no benefit once Engine A is
    already required for `maintenance` and reused for `save` anyway.

**9. The in-session/autonomous-save guardrail is a cheap mechanical pre-filter, then LLM
judgment — and the mechanical filter is explicitly *not* "were any files edited."** Verified
against this exploration session itself as a test case: zero files were touched (explore mode
forbids it) yet the session produced substantial, save-worthy architectural decisions. A
file-edit-based filter would have silently and systematically skipped saving *every* purely
exploratory session that reaches real conclusions — exactly backwards, since `/opsx:explore`'s
entire purpose is reaching conclusions without editing files. The mechanical filter instead
keys on tool-call count / conversation length past a small floor (rules out true one-liners like
"what's my session id?", a session-id-lookup exchange from earlier in this same conversation)
without pre-judging *content* — content judgment is reserved for the LLM step that follows.

**10. All new runtime state is project-local under `.claude/`.** Matches `settings.local.json`'s
existing personal-machine scoping (not committed, not shared across machines) — the marker,
lockfile, and audit log are per-machine execution state, not project content.

## Implementation Findings

**11. `flock` does not exist on stock macOS — this repo's actual target platform.** Decision 6
originally specified an `flock`-based lockfile, following the pattern shown in current hook docs
for exactly this situation. Confirmed broken by running the rendered `SessionStart` script for
real during implementation: `flock: command not found`. `flock` is a Linux/util-linux tool, not
present in macOS's base install. Replaced with a portable `mkdir`-based lock (atomic directory
creation is the standard portable substitute) — this also fixed a second, independently-flagged
gap in the original design: an `flock` file descriptor held open via `exec 200>...` only stays
open for the life of the *script holding it*, not a `nohup`'d detached child that doesn't inherit
it — meaning the original design's lock would have covered only this script's own few
milliseconds of execution, not the actual maintenance run's real duration. The `mkdir`-based
replacement is released explicitly inside the same backgrounded subshell, after `claude -p`
exits (success or failure), correctly covering the run's full duration — with a stale-lock
reclaim (mtime >30 minutes) as a safety net against a lock left behind by a crashed detached run.
Verified via direct testing (lock held → second invocation skips; stale lock → reclaimed;
real run → acquired then released after the process exits).

**12. `save`'s in-session/interactive path can race a background worker on the same notes —
`WORKER_LOCK_DIR` alone doesn't cover this.** Raised by the user after the Decision 6/11
incident and its follow-up review: every fix so far only guarded the three *headless-spawn*
sites against each other. It said nothing about the foreground interactive session itself
running `save-session`'s Step 3/4 (append the session log, edit the status note) via direct
MCP tool calls — that path never touches the lock at all. Concretely: `SessionStart` spawns a
`maintenance` worker that acquires `WORKER_LOCK_DIR` and may spend minutes restructuring the
same session log or status note; if the same foreground session then decides mid-conversation
(per Decision 9's judgment) to save, or the user types `/save-session`, it can read-modify-write
the same notes concurrently with zero coordination — worst case, an append lands between the
worker's rollover read and its full-body replace and simply vanishes.
  - **Fix: `save-session`'s own Step 2 checks the lock and defers, rather than acquiring it.**
    Deliberately asymmetric — only background hook-spawned workers acquire `WORKER_LOCK_DIR`;
    the interactive/explicit path only ever checks-and-skips. Having the interactive path
    acquire the lock too was considered and rejected: it risks stalling the live conversation
    if held, and reliably releasing it if the turn is interrupted (Ctrl-C, a crash mid-edit) is
    far less certain for instruction-driven Bash calls than for a real script's guaranteed
    subshell cleanup — a lock stuck by an interrupted interactive session is a worse failure
    mode than the rare deferred save this design accepts. A deferred save isn't lost: `SessionEnd`'s
    catch-up, or the next `SessionStart`'s crash-recovery (Decision 5's id-match gate), retries
    once the worker releases the lock.
  - **The headless workers themselves must skip this new check.** Every worker spawned by
    `spawn_headless` already holds `WORKER_LOCK_DIR` for the duration of its own run (that's
    what it's for) — if it ran `save-session`'s new Step 2 naively, it would see its own lock
    and defer against itself, permanently. Both spawn prompts (crash-recovery in
    `session-start-maintenance-check.sh`, catch-up in `session-end-save-hook.sh`) now say so
    explicitly, telling the worker to skip straight to Step 3.
  - Logged under a new `deferred` outcome (not `failure`) in the audit log, so it's
    distinguishable from a real error and doesn't get picked up by `save-session-maintenance`'s
    "check for a recent `save\tfailure` entry" signal (Step 2 of that skill).

**13. Finding 12's Step 2 check is advisory only — a real, harness-enforced backstop was
added, because the model can ignore an instructed check in a way it cannot ignore a hook
`deny`.** Raised by the user as a direct challenge to Finding 12: "the LLM can choose to
ignore direction, unlike a hook." Correct — Step 2 only protects contention if the model
actually reads and follows it (skipped context, a judgment call to proceed anyway, or simple
inconsistency all defeat it), whereas nothing the model does can bypass a `PreToolUse`
`permissionDecision: "deny"`. The fix is `.claude/hooks/basic-memory-worker-guard.sh`, a new
`PreToolUse` hook (matcher `mcp__basic-memory__edit_note`, registered in
`.claude/settings.local.json`) that denies the tool call outright whenever
`WORKER_LOCK_DIR` is held by a session other than the caller.
  - **The hard part: identifying "who holds the lock" without trusting the model to
    self-report.** A naive implementation would need the spawned worker to voluntarily write
    its own session id somewhere — the same class of compliance problem the guard exists to
    eliminate. Solved instead with `claude -p --session-id <uuid>` (confirmed available via
    `claude --help`): `spawn_headless` generates a UUID with `uuidgen` (confirmed present on
    stock macOS, unlike `flock`/`timeout`/`gtimeout`) and writes it to
    `$WORKER_LOCK_DIR/holder` *before* spawning, then passes the same UUID as the worker's own
    `--session-id`. Both steps happen synchronously in the parent script, before the detached
    process even starts — a pure code-to-code binding with no window where the lock exists
    without a recorded holder, and no dependency on the spawned model doing anything correctly.
  - **Locks are no longer bare directories — `rmdir` became `rm -rf` everywhere a lock is
    released or reclaimed** (`spawn_headless`'s two release paths, both `reclaim_stale_lock`
    copies, and the guard's own opportunistic reclaim), since the lock dir now always contains
    a `holder` file and is never empty.
  - **Scoped to `edit_note` only**, not `write_note`/`move_note`/`delete_note`: `edit_note` is
    the only tool `save-session` and `save-session-maintenance` currently use to mutate the two
    notes that can collide (the session log, the status note); `write_note` is only ever used
    to create the new, non-colliding archive note during rollover. If a future skill starts
    mutating either shared note via a different basic-memory tool, this guard's matcher needs
    to grow to cover it.
  - **The guard fails closed and self-heals independently of any hook script.** An
    unrecognized/unreadable holder or a session-id mismatch both deny (never assume safety when
    unsure); a lock older than 30 minutes is reclaimed by the guard itself at the point of
    contention (not just by the next `SessionStart`), so a genuinely orphaned lock doesn't block
    every `edit_note` call project-wide until someone happens to start a new session.
  - Verified in an isolated sandbox: no lock → allow; lock held by another session → deny with
    the expected reason; lock held by the calling session itself → allow; a stale lock →
    self-reclaimed and allowed. Separately confirmed the full `spawn_headless` chain: the
    `--session-id` value actually passed to `claude -p` matches the `holder` file's content
    exactly, for both the maintenance and crash-recovery spawn sites (`session-end-save-hook.sh`
    shares the identical mechanism).
  - Registered via the project's `update-config` skill rather than a hand-edit, per this repo's
    own convention for touching `.claude/settings.local.json`.

**14. `check-drift.sh`'s fixed-hook family needed a real `matcher` argument before
`basic-memory-worker-guard.sh` (Finding 13) could be added to it (2026-08-26).** The existing
`fixed_hook_status`/`report_fixed_hook`/`update_fixed_hook` functions hardcoded `matcher: ""`
when creating a new entry — correct for `SessionEnd`/`SessionStart`, which aren't tool-scoped,
but wrong for a `PreToolUse` guard: an empty matcher there fires on *every* tool call, not just
`edit_note`. Added an optional trailing `matcher` argument (default `""`, so the two existing
callers are unaffected) and passed `mcp__basic-memory__edit_note` for the new
`basic-memory-worker-guard-hook-config` piece. Also found while verifying: the guard's script
had no rendered occurrence of `__PROJECT__` anywhere, unlike its two sibling scripts (each embeds
the resolved project name somewhere), so `piece_status`'s generic NAME-MISMATCH check — which
greps the installed file for the literal resolved `$PROJECT` string — always failed for it.
Fixed with a `# basic-memory project: __PROJECT__` anchor comment, matching
`session-end-save-hook.sh.template`'s existing pattern. Verified in an isolated sandbox: CREATE
with the correct matcher, UP-TO-DATE on re-check, no-op `update`, existing `SessionEnd`/
`SessionStart` entries unaffected. See tasks.md 8.1.

**15. The marker had to be stamped on *every* terminal outcome, not just a successful save —
Decisions 3 and 5 were subtly but seriously wrong.** Found by a full-diff code review after the
change was already implementation-complete, then confirmed against live runtime state. Decision 3
specified writing the marker "on a successful save", and `save-session`'s "On success" step was
its only writer; the no-op and failure paths logged to `.claude/.save-session-log` and stopped.
Decision 5's crash-recovery gate, meanwhile, terminates only when the newest prior transcript's
session ID *matches* the marker — and a catch-up worker's own transcript becomes that newest
prior the moment it runs. A worker that no-ops (overwhelmingly the common case: it reads one
transcript and decides there is nothing worth persisting) therefore left a mismatch that nothing
could ever clear, so **every subsequent `SessionStart` spawned another worker, indefinitely** —
the same runaway-spawn failure as the original 2026-08-24 incident, merely sequential instead of
concurrent, and far harder to notice because each individual spawn looked reasonable. This was
not theoretical: `.save-session-log` already held a no-op (`EE7A2F25…`) and a failure
(`db812f53…`) that had both left the marker untouched. Fixed by making marker-stamping a shared
step every terminal outcome ends with ("Recording the session marker"), including an explicit
`On no-op` section that previously existed only as prose inside the two hook spawn prompts.
Step 0's proactive pre-filter deliberately does *not* stamp — it is a "not yet" judgement about a
still-running session, not a terminal outcome. `save-session-maintenance` gained the same stamp
on its headless path for the same reason (a maintenance run's transcript is likewise newest-prior
afterwards, otherwise guaranteeing one wasted catch-up spawn after every maintenance run).
Verified in an isolated sandbox with the terminating and non-terminating cases side by side:
stamped → next `SessionStart` quiet; unstamped → spawns again, reproducing the loop. See
tasks.md 9.1.

**16. Detached spawns failed invisibly: the child's exit status was never checked.** Same review.
Both hook scripts `wait`ed on the spawned `claude -p`, then unconditionally released the lock
without inspecting `$?` or writing anything to the audit log. Every failure-logging promise this
change makes lives *inside* `save-session`'s "On failure" step — which only runs once the model
has actually started — so any process that died before that (auth failure, missing binary,
timeout-kill, OOM) left no audit-log trace at all, only raw text in
`.claude/.save-session-headless.out`, which nothing reads. That is precisely how 9 rounds of
`Not logged in · Please run /login` sat unnoticed in this repo while the mechanism appeared
healthy, and why task 8.2's auth investigation had so little to go on. Both spawn sites now
capture the status, distinguish a signal kill (`> 128`, naming the timeout watcher as the likely
cause) from an ordinary non-zero exit, and log a `failure` line tagged with the calling branch.
See tasks.md 9.2.

**17. Two smaller spawn-safety defects in the same cluster.** (a) `SessionEnd` checked only that
`transcript_path` was non-empty, never that it existed. A stale path burned a full worker run —
holding the shared lock for its entire duration and starving any genuine save queued behind it —
only to reach "On failure" and report it had nothing to read. `.save-session-log` recorded exactly
that sequence, a phantom target failing and a real catch-up turned away four seconds later. Now
`stat`-checked before the lock is taken. (b) The worker's session ID was generated only `if
command -v uuidgen` succeeded; otherwise no `holder` file was written and `claude -p` was spawned
with no `--session-id`. `basic-memory-worker-guard.sh` fails closed on an empty holder, so such a
worker would be denied the single operation it exists to perform, for the full 25-minute timeout,
every run — a self-inflicted deadlock. `uuidgen` now falls back to `python3` and to
`/proc/sys/kernel/random/uuid`, and the spawn is abandoned outright (lock released, failure
logged) if none is available, rather than launching an unidentifiable worker. See tasks.md 9.3.

## Alternatives Considered

**Reuse/extend `sync-memory.py`'s mechanism directly for `save-session`.** This was the
exploration's starting premise. Rejected once it became clear the two skills target
fundamentally different notes with different risk profiles (see proposal.md's Why) —
`sync-memory`'s target note is append-only and mechanical by design; `save-session`'s status
note requires editorial judgment that has already caused real breakage (v8–v11). Conflating
them would have re-introduced exactly the risk the existing split (`sync-memory` separate,
`disable-model-invocation`) was built to avoid. The user's specific objection to `sync-memory`
("slow") turned out to mean foreground latency from its non-`--standalone` mode running inline
in the interactive session — which a properly detached design sidesteps entirely — but the
deeper reason for not reusing it is architectural scope, not just the latency complaint.

**Real cron/launchd scheduling for `maintenance`.** Considered and explicitly rejected by the
user in favor of `SessionStart`-opportunistic — see Decision 4.

**Periodic mid-session syncing** (for either `save` or `maintenance`). Rejected — see
proposal.md's Non-goals; SpecStory's continuously-growing single file + whole-file-mtime cursor
would make repeated mid-session syncing reprocess overlapping content every interval, and the
robustness goal it would nominally serve is already met by `SessionEnd` + `SessionStart`'s
crash-recovery combination (Decision 5).

**Engine B (OpenRouter/direct-API) as the default execution mechanism.** See Decision 8.

## Risks / Trade-offs

- **[Risk] `SessionStart`'s "non-blocking" property is a discipline this change imposes, not a
  platform guarantee.** The real default timeout is 600 seconds; a bug that fails to properly
  detach the spawned process (e.g., forgetting `nohup`/`disown` and stdio redirection) would add
  real, possibly severe, latency to every session start rather than failing loudly. Needs an
  explicit verification task, not just code review.
- **[Risk] True `SIGKILL`/crash/power-loss coverage is only ever eventual** — caught on the
  *next* `SessionStart` in that project, not at the moment of failure. Acceptable per Decision 5
  and the proposal's non-goals, but worth stating plainly rather than implying full robustness.
- **[Trade-off] `claude -p` headless spin-up cost.** Heavier than a plain API call (full agentic
  process start, not a single HTTP round-trip) — incurred on every detached `save` catch-up and
  every `maintenance` run. Accepted in exchange for `memory-defrag`/`memory-lifecycle`
  delegation (Decision 8); mitigated by the fact that `save`'s catch-up is the *rare* path
  (Decision 3's marker means it only fires when the in-session path didn't already cover it).
- **[Trade-off] The lockfile (Decision 6) only guards one machine.** It doesn't coordinate
  `maintenance` runs across multiple machines syncing the same basic-memory vault (Syncthing is
  already in use for this vault, per `home/.chezmoidata/syncthing.yaml` and the `.stversions/`
  directories observed during exploration) — two machines starting sessions in the same project
  around the same time could both run `maintenance` independently. Out of scope for this change;
  flagged for a future revision if it proves to matter in practice.
