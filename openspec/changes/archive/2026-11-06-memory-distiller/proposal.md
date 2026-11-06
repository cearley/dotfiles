> **ABANDONED / SUPERSEDED — 2026-11-06. Stalled at 33/45 tasks, never shipped.**
>
> This change reached section 8 of `tasks.md` (core worker + registry) but stalled before the
> LaunchAgent wiring, removal, and archive steps in sections 9–12. It is archived with
> `--skip-specs`: none of its delta specs are merged into `openspec/specs/`, because the two
> breaking decisions below are being reversed rather than landed.
>
> **Why it was abandoned:**
> 1. **The SpecStory-removal decision didn't hold up.** A `/research` pass on SpecStory
>    utilization (2026-11-06) found SpecStory's `.specstory/history/` is the *only* surviving
>    record of session content past Claude Code's own transcript retention window — native JSONL
>    for sessions more than a few weeks old is already gone on this machine. This change's premise
>    ("first-party JSONL transcripts become the sole input") assumed that archive wasn't needed;
>    it is. SpecStory is being kept, not removed.
> 2. **A simpler crash-recovery design was found instead of the polling worker.** The abandoned
>    `autonomous-save-session` branch's `SessionStart` crash-recovery *detection* logic (find the
>    latest prior transcript, compare against a last-saved marker) turned out to be sound — only
>    its `spawn_headless()` call was the problem. Feeding the same catch-up instruction back as
>    plain hook *stdout* (a system-reminder for the already-starting session to act on inline, the
>    same mechanism the existing SessionStart reminder already uses) removes the recursion by
>    construction without needing a separate machine-level launchd worker, a project registry, or
>    polling.
>
> **What carries forward into the new change (`specstory-cleanup-and-crash-recovery`):** the
> `sync-memory` removal (this change's task 11.2) — confirmed independently as the right call
> (the distilled note it produces was never read, and isn't the note `/save-session` actually
> maintains) — plus a from-scratch, hook-based (not polling-based) crash-recovery design, plus a
> SpecStory duplicate-history cleanup this change never anticipated.

## Why

`/save-session` only runs when the user remembers to type it, and a session ending by crash or
closed terminal is never captured at all. The previous attempt at fixing this
(`autonomous-save-session`, archived 2026-08-27) spawned `claude -p` from Claude Code hooks. That
billed a Max/Pro subscription for automated, non-first-party invocations; and because a spawned
`claude -p` process is itself a Claude Code session, it re-fired the hook that spawned it —
producing a fork-bomb that forced a reboot on 2026-08-24, with a second sequential variant still
being found by code review on 2026-08-27. Almost all of that change's complexity existed solely to
contain that recursion. Doing the work in a process that is *not* a Claude Code session removes
the billing problem and makes the recursion impossible by construction rather than defended
against.

## What Changes

- **New:** a machine-level `memory-distiller` worker, run by a launchd agent on a 300-second
  interval, that distils quiescent Claude Code JSONL transcripts into a machine-owned
  basic-memory note via the basic-memory MCP server, using the Anthropic API.
- **New:** an explicit project registry. Projects opt in by registration rather than by having a
  per-project copy of a script installed.
- **Trigger changes from hooks to polling.** A transcript becomes eligible when it has been
  untouched for ≥300s and has unread bytes. This one test replaces session-end detection, crash
  recovery, and the live-session hazard — a running session is by definition not quiet, and a
  killed session goes quiet exactly like a cleanly-ended one.
- **BREAKING — `sync-memory` is removed entirely** (skill, script, templates, drift pieces, and
  its capability spec). `memory-distiller` supersedes it, inheriting its cursor discipline,
  dedicated-note convention, per-run backlog cap and cost-sane model default.
- **BREAKING — SpecStory is removed** from `packages.yaml` (the `ai` tag) and from the `trusted:`
  invariant list. First-party JSONL transcripts become the sole input. Existing
  `.specstory/history/` files remain on disk, but no new ones are produced.
- **Not in scope, because it never shipped:** the hook scripts, the `PreToolUse` guard, the
  session marker, the lock directory and the `mkdir`-lock / stale-reclaim / holder-file /
  timeout-watcher stack were only ever present on an unpushed local branch. They were dropped
  when that branch was abandoned and have no presence in this repository's history — see
  `openspec/changes/archive/2026-08-27-autonomous-save-session/`. This change therefore removes
  no hooks; the only hook in the project is the plain `SessionStart` echo reminder, which was
  never part of that machinery and is retained.
- **Retained:** interactive `/save-session` and `/save-session-maintenance`. Their split is the
  durable outcome salvaged from the abandoned branch, and landed separately at
  `setup-memory-workflow` v12.
- The worker writes **only** a machine-owned note and never rewrites curated content. Editorial
  defrag stays interactive; the worker records threshold crossings for the user to act on.

## Non-goals

- Replacing interactive `/save-session`. It remains how curated notes get written.
- Unattended editorial defrag of curated notes. An optional low-cadence scheduled job may be
  proposed later; it is out of scope here.
- Real-time capture. Latency of roughly ten minutes is acceptable and deliberate.
- Cross-machine or cloud state. Everything stays local to the machine.

## Capabilities

### New Capabilities

- `memory-distiller`: scheduled, API-backed distillation of Claude Code transcripts into a
  machine-owned basic-memory note. Covers the polling trigger and quiescence test, the project
  registry, per-session byte-offset state and its advance-only-on-verified-success rule,
  MCP-mediated vault access, mechanical rollover, maintenance-signal reporting, and the
  degradation behaviour when no API key is present.

### Modified Capabilities

- `setup-memory-workflow`: the requirement that the workflow is distributed as per-project
  rendered copies no longer holds for this component — the worker is a single machine-level
  script managed by chezmoi, and projects opt in via registration instead of per-project
  install. The `sync-memory` pieces are removed from the drift mechanism. The same delta also
  brings the requirement's list of rendered pieces up to date with `save-session-maintenance`,
  which landed at v12 ahead of this change.
- `sync-memory`: capability retired in full. Every requirement is removed; its durable behaviours
  are re-expressed as requirements of `memory-distiller`.

## Impact

**Affected tags:** `ai` primarily — it gates both the SpecStory packages being removed and the
`ANTHROPIC_API_KEY` being added. A machine without the `ai` tag simply has no worker.

**Affected code and config:**
- New: `home/dot_local/bin/`, a `LaunchAgents` plist plus its `run_onchange` loader, and a
  machine-level distillation skill asset.
- Modified: `home/private_dot_zsh_secrets.tmpl` (adds `ANTHROPIC_API_KEY`),
  `home/.chezmoidata/packages.yaml` (SpecStory removal from both the `ai` block **and**
  `trusted:` — these are hand-synced with no automatic check), and `check-drift.sh` (the
  `sync-memory-skill` and `sync-memory-script` pieces removed, leaving four).
- Deleted: `.claude/skills/sync-memory/` and its `.template` mirrors.

**Dependencies:** adds `anthropic` and `mcp` Python packages, and a runtime dependency on the
basic-memory MCP server being launchable headlessly (`uvx --python 3.12 basic-memory mcp`).
Removes the third-party SpecStory wrapper from the critical path.

**Security:** `ANTHROPIC_API_KEY` follows the established pattern — stored in KeePassXC, rendered
into `~/.zsh_secrets` (`private_`, 0600) at apply time. The key is therefore on disk in plaintext
exactly as `GITHUB_TOKEN` and the other AI keys already are; this change adds a consumer, not a
new exposure class. launchd does not read zsh startup files, so the agent sources the secrets file
explicitly. Absent tag or KeePassXC database, the worker degrades to a logged no-op rather than
failing. The worker runs unattended with an API key and network access, so its blast radius is
deliberately confined to a single note it alone writes.

**Cost:** API spend scales with how much Claude Code is used rather than with a fixed schedule,
which needs a per-run token ceiling and cost logging from the outset.
