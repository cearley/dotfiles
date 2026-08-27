## 1. Verify load-bearing assumptions before building on them

- [ ] 1.1 Confirm launchd refuses to overlap `StartInterval` runs of one label: load a throwaway
      agent whose script sleeps well past its interval, and verify from its log that no second
      instance starts. If it does overlap, add `fcntl.flock` around the whole run and record the
      change in design.md Decision 3 — the "no locks at all" claim depends on this.
- [ ] 1.2 Confirm Claude Code only appends to a transcript and never rewrites it: record a
      session's JSONL size and checksum-of-prefix, resume the session, and verify the original
      prefix bytes are unchanged. If false, replace byte offsets with a content-hash strategy
      before writing any state code (design.md Risks).
- [ ] 1.3 Confirm the current Haiku model ID and pricing via the `claude-api` skill; record the
      chosen ID as a named constant. Verify a one-line API call succeeds with that ID.
- [ ] 1.4 Settle transcript-reduction heuristics with the user (design.md Open Question 1) and
      write them into design.md before implementing 3.3, so the deferred decision is stated
      rather than assumed.

## 2. Credentials and scaffolding

- [ ] 2.1 Add `ANTHROPIC_API_KEY` to `home/private_dot_zsh_secrets.tmpl` inside the existing
      `has "ai" .tags` block, sourced from KeePassXC like its siblings. Verify with
      `chezmoi execute-template` that it renders, and that a machine without the `ai` tag renders
      the file without it.
- [ ] 2.2 Create `home/dot_local/bin/executable_memory-distiller` with PEP 723 inline metadata
      declaring `anthropic` and `mcp`. Verify `uv run ~/.local/bin/memory-distiller --help`
      resolves dependencies and prints usage after `chezmoi apply`.
- [ ] 2.3 Establish the state directory layout under `~/.local/state/memory-distiller/` and verify
      the worker creates it on first run without error when absent.

## 3. Pure functions (no network, no vault, no clock)

- [ ] 3.1 Implement project-root mangling and transcript discovery across all `~/.claude*` profile
      directories. Verify with unit tests over a fixture tree that a project with transcripts in
      two profiles returns both, and that a newly added profile directory is picked up with no
      config change (spec: "Transcripts are discovered across all Claude Code profiles").
- [ ] 3.2 Implement quiescence eligibility (untouched ≥ quiet window AND unread bytes past
      offset). Verify with unit tests that a recently-modified transcript is excluded, a quiet one
      with unread bytes is included, and a quiet one fully read is excluded.
- [ ] 3.3 Implement `reduce(jsonl_bytes, char_budget) -> str` per the heuristics settled in 1.4.
      Verify with unit tests over a recorded fixture transcript that tool-result bodies are
      dropped, user/assistant content is retained, output respects the budget, and truncation is
      explicitly marked.
- [ ] 3.4 Implement per-session state load/save with offset advance. Verify with unit tests that
      advance happens only when explicitly committed, and that a resumed-and-grown session yields
      only the delta.
- [ ] 3.5 Implement rollover computation (which entries move, given a note body and threshold).
      Verify with unit tests that entries older than the newest dated entry are selected and the
      newest is retained, and that a below-threshold note yields no move.

## 4. Registry

- [ ] 4.1 Implement `registry.json` load/save plus `register` / `unregister` / `list`
      subcommands. Verify by registering a project, listing it, unregistering, and confirming the
      file round-trips.
- [ ] 4.2 Make registration idempotent and refresh the basic-memory project name on re-register.
      Verify registering twice leaves exactly one entry with the current name
      (spec: "Registration is idempotent").
- [ ] 4.3 Verify an unregistered project with transcripts is never read
      (spec: "Unregistered project is ignored").

## 5. MCP integration

- [ ] 5.1 Spawn the basic-memory MCP server over stdio using the configured command (default
      `uvx --python 3.12 basic-memory mcp`), and verify `list_tools` returns `write_note`,
      `edit_note` and `search_notes` against the real server.
- [ ] 5.2 Convert MCP tool schemas to Anthropic tool definitions and run the tool-use loop.
      Verify against a fake stdio MCP server that a scripted tool call round-trips.
- [ ] 5.3 Build the fake stdio MCP server test double (canned results, recorded calls). Verify it
      supports asserting which tools were called with which `project` argument.
- [ ] 5.4 Implement write verification: read back the tool result's `project` and `permalink` and
      require the project to match before committing the offset. Verify with a fake returning a
      mismatched project that the offset does not advance and the mismatch is logged
      (spec: "Write lands in the wrong project").

## 6. Model instructions

- [ ] 6.1 Write `home/dot_local/share/memory-distiller/distill.md` carrying this repo's
      conventions: pass `project=` explicitly, `[category]` observation prefixes, `[[wikilinks]]`,
      never write curated notes. Verify it deploys via `chezmoi apply` and the worker loads it.
- [ ] 6.2 Fetch basic-memory's `memory://ai_assistant_guide` resource at runtime and include it in
      the system prompt. Verify the worker still runs when the resource is unavailable, falling
      back to the repo skill alone.

## 7. Output behaviour

- [ ] 7.1 Append distilled output to the machine-owned note, creating it via `write_note` on first
      run. Verify against a scratch basic-memory project that a first run creates the note and a
      second appends without overwriting.
- [ ] 7.2 Drive rollover through MCP (`write_note` for the archive note, `edit_note` to trim the
      live one). Verify against a scratch project that an over-threshold note is split and the
      archive contains the older entries.
- [ ] 7.3 Evaluate curated-note thresholds and rewrite a `## Maintenance signals` section in the
      machine note. Verify the section is replaced rather than appended on a second run
      (spec: "Findings are refreshed, not accumulated").
- [ ] 7.4 Verify across the whole worker that no curated note is ever written: assert the fake MCP
      double records no `edit_note`/`write_note` against the session log or status note
      (spec: "Curated notes are untouched" — this is the design's central invariant).

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
