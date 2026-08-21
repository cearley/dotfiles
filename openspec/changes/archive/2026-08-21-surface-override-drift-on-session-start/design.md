## Context

`check-claude-overrides` (`home/dot_local/bin/executable_check-claude-overrides.tmpl`) already
bakes in, at chezmoi-apply render time, a persona list (`PERSONA_NAMES`/`PERSONA_DIRS`/
`PERSONA_TEMPLATES`) and a `detect_persona_drift` function that renders one persona's
`modify_settings.json.tmpl` baseline and diffs it against that persona's live `settings.json`.
`--fix` already reuses that same function to re-confirm an entry is flagged before writing.

Hook wiring for `SessionStart` in this repo goes through
`home/.chezmoitemplates/claude-settings-hooks-modifier`, which merges a `managed_hooks` JSON
literal into each darwin+`ai`-tagged persona's `settings.json` at chezmoi-apply time
(`session-topic-capture` on `UserPromptSubmit`/`PreCompact`/`SessionEnd`, `claude-tooling-guard`
on `PreToolUse`). The only confirmed-working `SessionStart` hook in this environment —
`setup-memory-workflow`'s per-project reminder — emits plain stdout text, which Claude Code
delivers as context directly; `claude-tooling-guard`'s `hookSpecificOutput`/`additionalContext`
JSON envelope is documented in its own header as verified specifically for `PreToolUse`'s
permission-decision contract, not for `SessionStart`.

See proposal.md - Why for motivation; see specs/claude-override-audit/spec.md for the
behavior contract this design implements.

## Goals / Non-Goals

**Goals:**
- Implement the three ADDED requirements in `specs/claude-override-audit/spec.md` with the
  smallest possible change to the existing script and hook-merge template.
- Reuse `detect_persona_drift` and the existing baked-in persona arrays unchanged, so the
  on-demand path's already-specced behavior (missing-baseline skip, baseline extraction,
  etc.) applies identically to the new automatic path without re-implementing it.

**Non-Goals:**
- (See proposal.md - Non-Goals; not restated here.)
- Not designing a general-purpose hook-payload-size solution — the session-start message is
  a single short line by construction, so the truncation risk documented in
  [[Claude Code Hook additionalContext/systemMessage Payloads Truncate Past a Few KB]]
  (memory note) doesn't apply here the way it did to `claude-tooling-guard`'s longer rule
  pointer.

## Decisions

**A new `--session-start` mode on `check-claude-overrides`, not a separate script.**
Reuses `detect_persona_drift`, `native_skills`, `declared_plugins`, and the render-time
`PERSONA_*` arrays as-is. A separate script (mirroring `claude-tooling-guard`'s split from
the guidance it points at) was considered and rejected: that split exists because
`claude-tooling-guard` is driven by a fundamentally different trigger (matching Bash command
payloads), whereas this mode needs the exact same persona/baseline/detection logic the
on-demand path already has — splitting it out would either duplicate that logic or just
shell back out to this script anyway.

**Persona resolved from `${CLAUDE_CONFIG_DIR:-$HOME/.claude}`, matched against the existing
`PERSONA_DIRS` array.** A match runs `detect_persona_drift` for that one persona only,
satisfying the "current persona only" requirement directly — no new enumeration logic. No
match (a `$CLAUDE_CONFIG_DIR` outside the declared persona set) emits nothing and exits 0:
fail open, consistent with `claude-tooling-guard`'s "never block the session over a config
edge case" posture, and consistent with the on-demand tool's own scope (it only ever checks
declared personas).

**Dedup state stored at `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.check-claude-overrides-last-drift`,
holding the sorted `kind<TAB>key<TAB>value` lines currently flagged (empty when none).**
The persona column is omitted from the stored content — the file's location already scopes
it to one persona. A missing file is treated as an empty prior state (any current drift is
"new"). The file is rewritten after every automatic invocation, whether or not it changed —
this keeps the comparison logic to a single string-equality check with no separate "did it
change" bookkeeping. Storing the file outside the chezmoi-tracked tree mirrors the existing
`.claude/basic-memory-project.txt`-style convention for persona-local, non-chezmoi state that
must survive `chezmoi apply` untouched.
- *Alternative considered*: hashing the drift lines (e.g. `shasum -a 256`) instead of storing
  them raw. Rejected — no accuracy benefit at this scale (at most a handful of lines), and
  raw storage keeps the state file human-inspectable (`cat` shows exactly what triggered the
  last message) without an extra tool dependency or a hash to mentally invert while
  debugging.

**Output is plain stdout text, not a `hookSpecificOutput` JSON envelope.** Matches the one
locally-confirmed `SessionStart` hook shape (`setup-memory-workflow`'s reminder) rather than
assuming `PreToolUse`'s envelope generalizes to a different hook event with no permission
decision to make. Message stays a single short line pointing at `check-claude-overrides` for
detail (exact wording is an implementation detail for tasks.md, not a design decision).

**`--session-start` reuses `detect_persona_drift` unchanged.** The "Missing-Baseline Graceful
Skip" requirement and baseline-extraction behavior already specced for the on-demand path
therefore apply identically here — this mode adds only persona-selection, dedup, and
output-format logic around the existing detection call, nothing new to detection itself.

## Risks / Trade-offs

- **[Risk]** A `$CLAUDE_CONFIG_DIR` that doesn't match any declared persona (a one-off local
  override, or a persona dropped from `claude_envs` but still in use) silently skips the
  check at session start. → **Mitigation**: identical scope to the existing on-demand tool
  (declared personas only); manual `check-claude-overrides` remains available and unaffected.
- **[Risk]** The dedup state file can go stale if hand-edited or deleted. → **Mitigation**:
  worst case is a one-time re-notification (file missing) or a missed one (file
  pre-populated to match current drift) — never a wrong *action*, since this path is
  report-only and never writes `settings.json` or any template.
- **[Risk]** Session-start latency grows by one `chezmoi execute-template` + `jq`/`yq` pass.
  → **Mitigation**: scoped to exactly one persona (Decision 2), the same per-persona cost the
  on-demand tool already pays once; no multiplier versus today's manual invocation.
- **[Trade-off]** State lives outside chezmoi, so it isn't portable or backed up like tracked
  config. → Accepted: it's disposable derived state (worst case, one redundant
  notification after loss), the same tier as `claude-tooling-guard`'s `$TMPDIR` markers.
