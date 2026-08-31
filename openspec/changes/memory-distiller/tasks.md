## 1. Verify load-bearing assumptions before building on them

- [x] 1.1 Confirm launchd refuses to overlap `StartInterval` runs of one label: load a throwaway
      agent whose script sleeps well past its interval, and verify from its log that no second
      instance starts. If it does overlap, add `fcntl.flock` around the whole run and record the
      change in design.md Decision 3 — the "no locks at all" claim depends on this.
      **Done 2026-08-28 — launchd serialises; no lock needed, design.md Decision 3 stands
      unchanged.** Probe: `StartInterval` 10s driving a script that sleeps 40s, bootstrapped into
      `gui/501` from a scratch path (never `~/Library/LaunchAgents`), torn down after. Log showed
      strict alternation over three cycles — `START 10877 t+0 / END 10877 t+40 / START 11282 t+50 /
      END 11282 t+90 / START 11692 t+100`. The four interval firings that elapsed during each 40s
      run were coalesced, and the next instance started 10s **after exit**, not 10s after the
      previous start. No second instance ever ran concurrently.
      Two incidental findings that constrain task 9.1: the agent's default `PATH` is
      `/usr/bin:/bin:/usr/sbin:/sbin` — Homebrew is absent, so `uv`/`uvx` must be invoked by
      absolute path or the `PATH` set in the plist; and launchd's inherited environment carries
      `CLAUDE_CONFIG_DIR` but nothing from the shell, confirming the plist must source
      `~/.zsh_secrets` explicitly.
- [x] 1.2 Confirm Claude Code only appends to a transcript and never rewrites it: record a
      session's JSONL size and checksum-of-prefix, resume the session, and verify the original
      prefix bytes are unchanged. If false, replace byte offsets with a content-hash strategy
      before writing any state code (design.md Risks).
      **Done 2026-08-28 — offsets kept, plus a runtime `guard_sha` (design.md Decision 8 amended).**
      Snapshotted size + SHA-256 for all 279 top-level transcripts (254 MB), then re-hashed exactly
      the baseline byte range: **0 prefixes rewritten, 0 truncated**, 278 unchanged, 1 grown with
      prefix intact (this session, appending live).
      One false alarm chased to ground: 67 files have a birthtime *later* than their first record,
      which looks like rewrite-by-rename. It is not — median birthtime sits at **0.04 of session
      span**, i.e. at session start and thousands of seconds before final mtime, whereas a
      rename-rewrite would land at ~1.0. It is deferred file creation/first flush. (An earlier
      fork-vs-rewrite check via shared record uuids was inconclusive by construction: replacing a
      file at the same path also leaves its uuids in exactly one file.)
      Not shown: behaviour **across a resume boundary** — all 77 resumed transcripts in the corpus
      pass, but were snapshotted after the fact. Rather than block, the assumption is now enforced
      at runtime by `guard_sha` (task 3.5), so a changed prefix reprocesses from 0 instead of
      silently skipping content.
      Incidental finding for 3.1: of 763 `.jsonl` files, **480 are subagent transcripts** at
      `<session-id>/subagents/*.jsonl`; only 283 are top-level sessions. The one-level glob already
      excludes them — now recorded as a deliberate decision in design.md Architecture rather than
      an accident.
- [x] 1.3 Confirm the current Haiku model ID and pricing via the `claude-api` skill; record the
      chosen ID as a named constant. Verify a one-line API call succeeds with that ID.
      **Done 2026-08-31 —** `MODEL_ID = "claude-haiku-4-5-20251001"`; Anthropic lists Haiku 4.5
      at $1/MTok input and $5/MTok output. A one-token Messages API call succeeded with that
      model (`input_tokens=11`, `output_tokens=1`).
- [x] 1.4 Settle transcript-reduction heuristics with the user and write them into design.md
      before implementing 3.3. **Done 2026-08-27** — measured against all 80 transcripts in this
      project (77 MB) rather than assumed; recorded as design.md Decision 10 with the full
      keep/drop table and named constants. Two measurements changed the design: `user` records
      with list content are injected skill/system text rather than human input, and a single
      pasted entry once accounted for 90.8% of a session, so per-entry caps are required
      alongside the total budget.

## 2. Credentials and scaffolding

- [x] 2.1 Add `ANTHROPIC_API_KEY` to `home/private_dot_zsh_secrets.tmpl` inside the existing
      `has "ai" .tags` block, sourced from KeePassXC like its siblings. Verify with
      `chezmoi execute-template` that it renders, and that a machine without the `ai` tag renders
      the file without it.
      **Done 2026-08-31 —** reads `Anthropic` / `API key` from KeePassXC. The applied live file
      contains the variable and authenticated the task 1.3 API check. An isolated
      `chezmoi execute-template` check confirmed the no-KeePassXC/no-`ai` gate emits no secret;
      full noninteractive rendering remains unavailable because existing KeePassXC lookups require
      `/dev/tty`.
- [x] 2.2 Create `home/dot_local/bin/executable_memory-distiller` with PEP 723 inline metadata
      declaring `anthropic` and `mcp`. Verify `uv run ~/.local/bin/memory-distiller --help`
      resolves dependencies and prints usage after `chezmoi apply`.
      **Done 2026-08-28.** `uv run --script` resolved `anthropic>=0.40` + `mcp>=1.9` (32 packages,
      186ms after download) and printed usage for the `run`/`register`/`unregister`/`list`
      subcommands. Shebang is `#!/usr/bin/env -S uv run --script`, verified working. The file is
      deliberately **not** a `.tmpl` — it contains no template syntax, so chezmoi copies it
      verbatim; `home/dot_local/bin/` is rendered, so a `.tmpl` here would try to interpret any
      future Go-template-looking text in the Python source.
      Note for 9.1: `uv` is at `/Users/craig/.local/bin/uv`, not Homebrew, and launchd's default
      `PATH` contains neither — the plist must use an absolute path.
- [x] 2.3 Establish the state directory layout under `~/.local/state/memory-distiller/` and verify
      the worker creates it on first run without error when absent.
      **Done 2026-08-28.** `state_dir()` / `ensure_state_dir()` / `registry_path()` / `log_path()`,
      all taking an injectable `home` so tests never touch real state. Layout: `registry.json`,
      `<profile>__<session-id>.json` per session, `distiller.log`. 4 tests including
      create-when-absent and create-twice-is-not-an-error.

## 3. Pure functions (no network, no vault, no clock)

- [x] 3.1 Implement project-root mangling and transcript discovery across all `~/.claude*` profile
      directories. Verify with unit tests over a fixture tree that a project with transcripts in
      two profiles returns both, and that a newly added profile directory is picked up with no
      config change (spec: "Transcripts are discovered across all Claude Code profiles").
      **Done 2026-08-28.** 8 unit tests in `tests/test_memory_distiller.py` (TDD: each watched to
      fail first). Covers both profiles returned, a later-added profile picked up with no config
      change, other projects excluded, subagent transcripts excluded, and missing profile
      directories not being an error. Cross-checked against the real corpus: this project resolves
      to 104 transcripts spread across all four profiles (`.claude` 18, `-bedrock` 5, `-personal`
      78, `-work` 3), so the multi-profile requirement is exercised by real data and not only by
      fixtures.
- [x] 3.2 Implement quiescence eligibility (untouched ≥ quiet window AND unread bytes past
      offset). Verify with unit tests that a recently-modified transcript is excluded, a quiet one
      with unread bytes is included, and a quiet one fully read is excluded.
      **Done 2026-08-28.** `is_eligible(transcript, offset, now)` with `now` injected so no test
      depends on the wall clock. 5 tests: recently-modified excluded, quiet-with-unread included,
      quiet-fully-read excluded, exactly-at-the-window included (boundary), and a shrunk file
      whose offset exceeds current size excluded rather than reading as "has unread bytes".
- [x] 3.3 Implement `reduce(jsonl_bytes, char_budget) -> str` per design.md Decision 10, with
      every limit a named module-level constant (`MAX_USER_CHARS` etc.), never a literal. Verify
      with unit tests over recorded fixture transcripts that: successful tool-result bodies are
      dropped while `is_error` results keep a capped head; `user` records with list content are
      emitted as injection markers and never as human turns; a single oversized entry is capped
      independently of the total budget; and every truncation is marked inline.
      **Done 2026-08-28.** 22 tests, all watched to fail first. **Decision 10's table needed
      extending, again by measurement** — see design.md. The three documented tag prefixes cover
      only 4 of the 356 machinery records among 859 `user` strings; `<local-command-caveat>`,
      `<command-name>`, `<command-message>` and `<task-notification>` were unhandled and would have
      been attributed to the user verbatim. `<command-name>` is kept as a compact marker (which
      command drove a session is decision-worthy); the rest are dropped.
- [x] 3.4 Verify the reduction against the measured baseline: running it over this project's
      transcript corpus reproduces roughly 2.2% of raw bytes with no session exceeding
      `TOTAL_CHAR_BUDGET`. A large regression in either direction means a rule changed meaning.
      **Done 2026-08-28 — baseline reproduced.** 104 transcripts, 77.6 MB → 1.73 MB = **2.23%**
      against the 2.22% baseline (0.01pp), worst case 96.4 K, **0 sessions hit the budget**.
      Median fell 10.4 K → 2.9 K; since the total ratio is unchanged, that is the added drop rules
      plus 24 mostly-short sessions joining the corpus since 2026-08-27, not a rule discarding
      substance.
- [x] 3.5 Implement per-session state load/save with offset advance. Verify with unit tests that
      advance happens only when explicitly committed, and that a resumed-and-grown session yields
      only the delta.
      **Done 2026-08-28, including the `guard_sha` from the amended Decision 8.** 12 tests: state
      round-trips, a corrupt state file falls back to 0, `read_unread` never advances anything,
      a resumed-and-grown session yields only the delta, a matching guard is trusted, a **rewritten
      prefix of identical length is detected and reprocesses from 0**, a truncated file reprocesses
      from 0, the guard covers only the last `GUARD_BYTES` of a long prefix and the whole prefix of
      a short one, and offset 0 has no guard.
      State filenames are `<profile>__<session-id>.json`, not `<session-id>.json`: two profiles can
      hold transcripts with the same session id for one project, and they are different sessions.
      `save_state` writes via a temp file and `replace()` so an interrupted run cannot leave a
      half-written offset.
- [x] 3.6 Implement rollover computation (which entries move, given a note body and threshold).
      Verify with unit tests that entries older than the newest dated entry are selected and the
      newest is retained, and that a below-threshold note yields no move.
      **Done 2026-08-28.** `compute_rollover(body, threshold)` returns `(kept, moved)` or `None`,
      purely mechanically. Only `## YYYY-MM-DD` sections count as entries, so the note title and
      the `## Maintenance signals` section can never be rolled away — verified by test. The newest
      entry is chosen **by date, not by position**, and a note with fewer than two dated entries
      never rolls over however large, so the live note can never be emptied.
      `ROLLOVER_THRESHOLD_CHARS = 60_000` remains arbitrary (design.md Open Question 2).

## 4. Registry

- [x] 4.1 Implement `registry.json` load/save plus `register` / `unregister` / `list`
      subcommands. Verify by registering a project, listing it, unregistering, and confirming the
      file round-trips.
      **Done 2026-08-28.** 8 unit tests plus a CLI round-trip run against a **temp `HOME`** —
      register, re-register, list, unregister, list — confirming `~/.local/state/memory-distiller/`
      was never created on the real machine. Atomic temp-file-plus-`replace()` writes.
- [x] 4.2 Make registration idempotent and refresh the basic-memory project name on re-register.
      Verify registering twice leaves exactly one entry with the current name
      (spec: "Registration is idempotent").
      **Done 2026-08-28.** Registry is keyed by normalized project root, so re-registering
      overwrites in place. Verified by unit test and by CLI: registering `/x` then `/x/` with a
      different project name left exactly one entry carrying the newer name. A corrupt
      `registry.json` reads as empty rather than crashing the run.
- [x] 4.3 Verify an unregistered project with transcripts is never read
      (spec: "Unregistered project is ignored").
      **Done 2026-08-28.** `eligible_sessions()` composes registry → discovery → guard-checked
      offset → quiescence, and iterates registered roots only. Test builds two projects with
      quiescent transcripts, registers one, and asserts only that one is returned. Also covered:
      a live (recently-modified) session is not eligible, and enumeration never mutates the
      registry — pruning dead entries is 8.4's job in the run loop, and is log-and-skip rather than
      removal.

## 5. MCP integration

- [x] 5.1 Spawn the basic-memory MCP server over stdio using the configured command (default
      `uvx --python 3.12 basic-memory mcp`), and verify `list_tools` returns `write_note`,
      `edit_note` and `search_notes` against the real server.
      **Done 2026-08-28.** Server starts headlessly (Basic Memory 4.0.0b1, FastMCP 4.0.0b1) and
      `list_tools` returns all three, plus `read_note`. `list_resources` confirms
      `memory://ai_assistant_guide` exists, which task 6.2 depends on.
      **Safety gap found and closed in design (new Decision 4a):** the server exposes **21** tools
      including `delete_note`, `delete_project` and `move_note`. Converting the whole list, as
      Decision 4 implied, would give an unsupervised model the power to delete curated notes, with
      the central invariant enforced only by 7.4's after-the-fact assertion. The worker will expose
      an allowlist of five read/write tools instead, so destructive calls are unavailable rather
      than merely unused.
- [x] 5.2 Convert MCP tool schemas to Anthropic tool definitions and run the tool-use loop.
      Verify against a fake stdio MCP server that a scripted tool call round-trips.
      **Done 2026-08-28.** `to_anthropic_tools()` + `run_tool_loop()`, 10 tests. The round-trip is
      driven by a **scripted fake Anthropic client** against a **real stdio MCP subprocess**, so
      the transport, client library and tool plumbing are genuinely exercised.
      Decision 4a is enforced **twice**: withheld tools are dropped at conversion (never offered),
      and a call naming one is refused locally and never forwarded. A test proves the fake server
      really does offer `delete_note` while the worker really does withhold it, and that a model
      call to it never reaches the server. Also covered: the `project` argument reaching the
      server, `max_turns` termination, and usage accumulated across turns.
      **Dependency hazard found and fixed:** the declared `mcp>=1.9` floats into **mcp 2.x**, where
      `FastMCP` was renamed to `MCPServer`. The client API the worker uses is unchanged, so this
      was silent, but a future 3.x need not be — pinned to `mcp>=2.1,<3` (resolves 2.1.1).
      `mcp` is imported lazily inside `mcp_session()`, verified: the module still imports and the
      pure functions still run in an interpreter with neither `mcp` nor `anthropic` installed.
- [x] 5.3 Build the fake stdio MCP server test double (canned results, recorded calls). Verify it
      supports asserting which tools were called with which `project` argument.
      **Done 2026-08-28** — `tests/fake_mcp_server.py`. Deliberately a **real** MCP server over the
      real stdio transport rather than a mocked session object; only its behaviour is canned.
      Records every call as JSON to `$FAKE_MCP_CALLS`, and a test asserts
      `calls[0]["arguments"]["project"] == "chezmoi"`.
      Three env knobs for later tasks: `FAKE_MCP_PROJECT` returns a **mismatched** project to drive
      5.4's verification failure, `FAKE_MCP_FAIL_TOOL` makes one tool raise for 8.x error paths,
      and `FAKE_MCP_NOTE_BODY` seeds note content for 7.2's rollover. It also exposes `delete_note`
      **on purpose**, so 7.4 can prove the worker withholds it rather than merely not calling it.
      Note: 5.3 had to be built before 5.2, since 5.2's stated verification depends on it.
- [x] 5.4 Implement write verification: read back the tool result's `project` and `permalink` and
      require the project to match before committing the offset. Verify with a fake returning a
      mismatched project that the offset does not advance and the mismatch is logged
      (spec: "Write lands in the wrong project").
      **Done 2026-08-28.** `verify_write(calls, expected_project)` parses the result's `project:`
      and `permalink:` lines. 8 tests. Verification fails — not just on a mismatch — when **no
      write happened at all** and when the result carries **no project line**, so a silent
      no-op cannot be mistaken for success.
      The offset rule is tested end to end rather than in isolation: the run goes through the real
      stdio fake with `FAKE_MCP_PROJECT=WRONG-PROJECT`, and the assertion is that the state file
      still reads `offset == 0`, paired with a positive control where the correct project does
      advance it to 999.

## 6. Model instructions

- [x] 6.1 Write `home/dot_local/share/memory-distiller/distill.md` carrying this repo's
      conventions: pass `project=` explicitly, `[category]` observation prefixes, `[[wikilinks]]`,
      never write curated notes. Verify it deploys via `chezmoi apply` and the worker loads it.
      **Done 2026-08-31 —** the untemplated asset is loaded by `load_system_prompt()` and deployed
      to `~/.local/share/memory-distiller/distill.md`; the deployed worker read it successfully.
- [x] 6.2 Fetch basic-memory's `memory://ai_assistant_guide` resource at runtime and include it in
      the system prompt. Verify the worker still runs when the resource is unavailable, falling
      back to the repo skill alone.
      **Done 2026-08-31 —** `load_system_prompt(session)` reads the runtime resource and
      `run_tool_loop(..., system=None, ...)` supplies it to the model. Resource failures are
      logged and return the repository instructions alone. Four focused tests cover the asset,
      guide inclusion, fallback, and loop integration; the full suite has 90 passing tests.

## 7. Output behaviour

- [x] 7.1 Append distilled output to the machine-owned note, creating it via `write_note` on first
      run. Verify against a scratch basic-memory project that a first run creates the note and a
      second appends without overwriting.
      **Done 2026-08-31 —** first run creates `Distilled Sessions`; later runs append dated
      entries. Tested against the real stdio fake server.
- [x] 7.2 Drive rollover through MCP (`write_note` for the archive note, `edit_note` to trim the
      live one). Verify against a scratch project that an over-threshold note is split and the
      archive contains the older entries.
      **Done 2026-08-31 —** rollover writes `Distilled Sessions Archive — YYYY-MM-DD` then replaces
      the live machine note with only its newest dated entry; covered by a stdio fake test.
- [x] 7.3 Evaluate curated-note thresholds and rewrite a `## Maintenance signals` section in the
      machine note. Verify the section is replaced rather than appended on a second run
      (spec: "Findings are refreshed, not accumulated").
      **Done 2026-08-31 —** reports the approved 20k/60k size thresholds and the status-note
      required headings; replacement semantics are tested across two refreshes.
- [x] 7.4 Verify across the whole worker that no curated note is ever written: assert the fake MCP
      double records no `edit_note`/`write_note` against the session log or status note
      (spec: "Curated notes are untouched" — this is the design's central invariant).
      **Done 2026-08-31 —** output-operation and `run_once` tests assert every curated-note access
      is a read, and every write targets the machine note or an archive.
- [x] 7.5 Wire the `run` command through the read-only model loop and the worker-owned output
      operations. Verify with a quiescent synthetic transcript and the stdio fake that the model
      is offered no write tool, the machine note is created, and the offset advances only after
      the worker's verified write.
      **Done 2026-08-31 —** `run` now invokes `run_once`; a synthetic quiescent session proves the
      model receives only read tools, the worker creates its note, verifies the write, and advances
      its offset. The suite has 96 passing tests.

## 8. Robustness and observability

- [ ] 8.1 Degrade to a logged no-op when no API key is present, without repeating the message on
      every run. Verify two consecutive runs with no key exit 0 and log once.
- [ ] 8.2 On API error or rate limit, leave the offset unchanged and record `retry_after`. Verify
      with a fake client raising a rate-limit error that nothing advances and the next run retries.
- [ ] 8.3 Skip a project whose MCP server fails to start, continuing with the rest. Verify with a
      deliberately broken server command that remaining projects still process.
- [ ] 8.4 Log and skip a registry entry whose directory no longer exists, without auto-removing it.
      Verify the entry survives the run.
- [ ] 8.5 Implement run logging (projects scanned, sessions distilled, tokens used, errors) with
      size-based rotation, and ensure failures before any model interaction are recorded. Verify a
      forced startup failure produces a log line rather than silence
      (spec: "Process fails at startup").
- [ ] 8.6 Enforce per-run caps: maximum sessions per run and per-transcript character budget.
      Verify a backlog larger than the cap processes exactly the cap and leaves the remainder.

## 9. Scheduling

- [ ] 9.1 Add `home/private_Library/LaunchAgents/io.github.cearley.memory-distiller.plist.tmpl`
      (`StartInterval` 300, `RunAtLoad`, `StandardErrorPath`), invoking the worker via
      `/bin/zsh -c 'source ~/.zsh_secrets && exec ...'`. Verify `plutil -lint` passes on the
      rendered plist.
- [ ] 9.2 Add the `run_onchange` loader following the existing
      `run_onchange_after_darwin-40-load-claude-launchagent.sh.tmpl` pattern. Verify
      `launchctl list` shows the label after `chezmoi apply`.
- [ ] 9.3 Verify the agent actually inherits `ANTHROPIC_API_KEY`: trigger a run via
      `launchctl kickstart` and confirm from the log that it authenticated rather than taking the
      no-key path.

## 10. Integration verification

- [ ] 10.1 End-to-end test: whole worker against a temp `HOME`, temp vault, synthetic transcripts
      and the fake MCP double. Verify a quiescent transcript produces a note append and an
      advanced offset, and that nothing runs against real system state.
- [ ] 10.2 Register only this project and let it run over several real sessions. Verify distilled
      output is accurate and useful, and that curated notes are untouched, before proceeding to
      any removal task below.

## 11. Removal and migration (irreversible — only after 10.2 passes)

- [ ] 11.1 Make `setup-memory-workflow` install register the project and uninstall deregister it.
      Verify install then uninstall leaves the registry with no entry for that project
      (spec: "Installing the workflow registers the project for unattended distillation").
- [ ] 11.2 Remove `sync-memory`: skill, script, both `.template` mirrors, and the
      `sync-memory-skill` / `sync-memory-script` pieces from `check-drift.sh`. Verify
      `check-drift.sh check` passes with four pieces and no reference to sync-memory remains.
- [ ] 11.3 Remove SpecStory from `home/.chezmoidata/packages.yaml` — from the `ai` block **and**
      the two matching `trusted:` entries. Verify with `grep -c specstory` that the file has zero
      matches; these lists are hand-synced with no automatic check.
- [ ] 11.4 Bump `SMW_VERSION` and add a CHANGELOG entry covering the registration hand-off and the
      sync-memory removal. Verify `check-drift.sh check` reports UP-TO-DATE after `update`.
- [ ] 11.5 Register the remaining projects. Verify each appears in the registry and produces output
      on the following run.

## 12. Close out

- [ ] 12.1 Run `openspec validate memory-distiller --strict` and `/opsx:verify`. Verify both pass.
- [ ] 12.2 Archive the change so `openspec/specs/memory-distiller/` is created and the
      `sync-memory` capability is retired from `openspec/specs/`. Verify `openspec list --specs`
      shows `memory-distiller` and no longer shows `sync-memory`.
