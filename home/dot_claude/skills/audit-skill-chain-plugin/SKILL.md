---
name: audit-skill-chain-plugin
description: Audit a Claude Code skill-chaining plugin against MindStudio's skill collaboration patterns. Covers loop-exit guards, state integrity, coupling, context bloat, skill boundaries, and error propagation.
triggers:
  - "audit skill chain"
  - "audit skill-chain plugin"
  - "review skill chaining"
  - "check plugin for skill chaining anti-patterns"
---

# Audit: Skill-Chaining Plugin

Use this skill when auditing a Claude Code plugin that orchestrates multiple skills in a sequential or iterative workflow (FSM-driven, stage-based, generate→review loops, etc.).

**Reference articles:**
- https://www.mindstudio.ai/blog/claude-code-skill-collaboration-chaining-workflows
- https://www.mindstudio.ai/blog/how-to-build-skill-system-claude-code-chaining-pipelines

---

## Inputs

Collect before starting:

- Plugin directory (e.g. `plugins/<name>/`)
- List of skills (`skills/*/SKILL.md`)
- Orchestrator skill (the entry-point that calls sub-skills in order)
- State layer: FSM file, state schema, state file path
- Any shared reference files (`references/`)
- Test files (`hooks/*.test.ts` or equivalent)

---

## Step 0: Identify the State Architecture

Before running any audit dimension, determine which of the three state designs the plugin uses. Dimensions 2, 3, and 5 vary by design — applying the wrong variant produces false findings.

| Design | How to recognise it | Key implication |
|---|---|---|
| **File-based** | A `state.json` written to disk by the FSM; a `parseState` function; stage derived from artifact mtimes | Survives session restarts; fully inspectable; highest FSM test complexity |
| **In-memory / context-carried** | State lives in Claude's conversation context; no persistent state file; decisions passed as context between skill calls | Lost on session restart; opaque to external tools; prone to context drift over long runs |
| **Hook-injected** | Hook reads artifact files at skill invocation time and injects current stage; skill does not write state.json directly | Stage derives from artifacts, not from a state document; hook logic is the FSM |

### State Architecture Trade-off Matrix

Use this if the audit reveals a design mismatch worth raising as a redesign recommendation.

| | File-based | In-memory | Hook-injected |
|---|---|---|---|
| **Session resume** | ✓ Full resume from disk | ✗ Context lost on restart | ✓ Re-derived from artifacts |
| **Debuggability** | ✓ State file is inspectable | ✗ Opaque — no external record | ✓ Artifacts are inspectable |
| **Audit trail** | ✓ `history[]` in state.json | ✗ Lost with context | ✗ Implicit (artifact timestamps only) |
| **Convergence risk** | Low | High — context drift over many turns | Low |
| **FSM test complexity** | High — parseState, defaulting, round-trip | Low — pure functions | Medium — mtime ordering, gap handling |
| **Coupling to filesystem** | High | None | Artifact-only |
| **Recommended for** | Multi-session, production workflows | Prototypes, short-lived chains | Stateless artifact pipelines |

Record the detected design at the top of your findings report before grading any dimension.

---

## Audit Dimensions

Work through all 10 dimensions. Grade each finding: **High / Medium / Low**.

### 1. Loop-Exit Guards

> Anti-pattern: iterative loops (generate → review → generate) with no cap.

- [ ] Identify every feedback loop in the orchestrator.
- [ ] Confirm each loop has a **maximum iteration count** tracked in persisted state (not just in-context).
- [ ] Confirm the orchestrator surfaces a user-visible escape when the cap is reached (e.g. AskUserQuestion with "keep trying / deploy with known issues / stop").
- [ ] Confirm the counter resets on a fresh run, not on session resume.
- [ ] **Pitfall:** A counter that increments on *any* path to the loop's target stage (not just the genuine regression path) over-counts. Verify the condition is `from === <review-stage>` (only genuine regression), not `from !== <prior-stage>` (fires on skip paths too).

**High** if no cap exists. **Medium** if cap exists but resets incorrectly. **Low** if cap logic is sound but escape UX is weak.

### 2. Single Source of Truth for Shared Decisions

> Anti-pattern: a user decision written to a file *and* passed through context — two sources that can diverge.

Identify every user decision that spans more than one skill invocation, then apply the variant for the detected design.

**File-based:**
- [ ] Each decision has exactly one canonical artifact on disk.
- [ ] Downstream skills read the artifact directly; the orchestrator does not *also* pass the decision in context.
- [ ] The artifact has a **freshness predicate** (run_id or form_id match + `decided_at` ≥ run's `startedAt`) so stale decisions from a prior run are rejected.
- [ ] The predicate is defined once (in the resume phase) and referenced verbatim in every guard — not re-stated differently in three places.

**In-memory:**
- [ ] Each decision is held in exactly one named variable in the conversation context; the orchestrator does not also maintain a shadow copy.
- [ ] The variable is set in the current session's run, not inherited from a previous run's context window. (If the context was compacted or the session restarted, the decision must be re-elicited — confirm this is handled.)
- [ ] **Note:** there is no freshness predicate for in-memory state because there is no prior-run artifact to compare against. The risk is a different one — context drift. Flag it if the chain is long enough that the decision variable could be lost in compaction.

**Hook-injected:**
- [ ] Each decision is encoded in an artifact the hook reads; context does not carry a parallel copy.
- [ ] The artifact has a freshness predicate anchored to the run (same as file-based, applied in hook logic).
- [ ] The hook's gate logic and the orchestrator skill's resume logic agree on the predicate — check both.

**High** if two sources exist (any design). **Medium** if one source but no freshness check (file-based or hook-injected). **Low** if freshness check exists but is not documented in the resume phase.

### 3. Stop Guards Before Dependent Steps

> Anti-pattern: a skill that requires prerequisite X proceeding silently when X is absent or stale.

For every skill that depends on a prerequisite from an earlier step, apply the variant for the detected design.

**File-based:**
- [ ] An explicit stop guard is stated in the skill: "If file is absent or invalid for this run, stop and run Phase N first."
- [ ] The guard checks *both* absent *and* stale (freshness predicate from dimension 2).
- [ ] The guard is in the skill that *consumes* the artifact, not only in the orchestrator — a sub-skill invoked standalone must also guard itself.

**In-memory:**
- [ ] The orchestrator checks that each required context variable is set before invoking the dependent skill.
- [ ] If the prerequisite variable could have been lost to context compaction, the orchestrator detects that and re-elicits rather than proceeding with an undefined value.
- [ ] **Note:** staleness is not a concept for in-memory state. The risk is undefinedness — a variable that was never set or was cleared. Guard for `null` / `undefined`, not for timestamps.

**Hook-injected:**
- [ ] The hook refuses to invoke the dependent skill if the prerequisite artifact is absent or fails the freshness predicate — this is the guard, and it is enforced outside the skill itself.
- [ ] Confirm the hook's denial message is actionable ("cannot run X yet — run Y first") rather than a generic error.
- [ ] The skill's own `SKILL.md` still documents the prerequisite so a human reader (or standalone invocation) understands the dependency.

**High** if a dependent step can proceed without its prerequisite (any design). **Medium** if guard exists but does not cover stale (file-based/hook-injected) or does not cover undefined-after-compaction (in-memory). **Low** if guard is present but only in the orchestrator, not in the sub-skill itself.

### 4. Cross-Skill Coupling via Reference Paths

> Anti-pattern: Skill A's inputs reference `${CLAUDE_PLUGIN_ROOT}/skills/skill-b/references/doc.md` — a cross-skill path that breaks if skill-b is renamed or removed.

- [ ] Scan all `SKILL.md` Inputs sections for cross-skill reference paths.
- [ ] Shared content (pitfalls tables, API references, forbidden symbol lists) should live at the **plugin level** (`${CLAUDE_PLUGIN_ROOT}/references/`) and be referenced from there by all skills.

**Medium** per cross-skill coupling found.

### 5. Structured State with Audit Trail

> Anti-pattern: plain-text or loosely typed state, no record of transitions, no safe evolution path for the schema.

Apply the variant for the detected design.

**File-based:**
- [ ] State is persisted as typed JSON with a defined schema (not freeform text).
- [ ] State includes a `history: Transition[]` (or equivalent) that survives session restores.
- [ ] Stage transitions write to history atomically in the same function call — not as a separate append step.
- [ ] `parseState` defaults every field that has been added since v1 (e.g. `?? 0` for new counters, `?? null` for optional objects) so old state files deserialize safely without a migration script.
- [ ] A round-trip test exists: `parseState(JSON.stringify(s))` equals `s` for a non-trivial state.

**In-memory:**
- [ ] State is a structured object, not a bag of loose variables or plain prose.
- [ ] An audit trail is *especially* important here because there is no persistent artifact — if the trail isn't in the state object, it is nowhere. Confirm `history[]` or equivalent exists and is accumulated across skill invocations within the session.
- [ ] Since there is no `parseState`, schema evolution risk is lower — but confirm there is no deserialization of state from a user message or tool result that could silently drop fields.
- [ ] **Redesign flag:** if the chain is long enough that history would grow to a problematic size, or if session restarts are a real scenario, recommend migrating to file-based state.

**Hook-injected:**
- [ ] The hook's stage-derivation function (which reads artifact mtimes) handles: gaps in the artifact chain (stops at the first missing artifact), out-of-order timestamps (an upstream artifact newer than a downstream one regresses the stage), and the case where no artifacts exist (returns `idle`).
- [ ] These three cases each have a unit test.
- [ ] If the hook also maintains a `state.json` alongside the artifact files, apply the file-based checks above to that file.
- [ ] Schema evolution: if the hook's state format gains new fields, confirm the read path defaults them so existing `.fulcrum-data-events/` directories don't break.

**High** if no audit trail exists (any design). **Medium** if audit trail exists but new fields aren't defaulted on deserialise (file-based) or the derivation function lacks gap/regression handling (hook-injected). **Low** if all present but not covered by tests.

### 6. Context Bloat per Skill

> Anti-pattern: each sub-skill reads the entire state file or full workflow history — exhausts token budget as runs grow.

- [ ] Confirm each sub-skill reads only what it needs from state (form identity, stage, the specific artifact it consumes).
- [ ] Confirm sub-skills do not receive the full `history` array in their invocation context.
- [ ] Confirm large reference files (rules docs, API references) are read once per orchestrator run, not re-read by every sub-skill.

**Medium** per skill that re-reads the full state or re-fetches large references unnecessarily.

### 7. Skill Boundary: One Task Per Skill

> Anti-pattern: a single skill that fetches, parses, validates, and generates — a hidden mini-pipeline.

- [ ] Each sub-skill should do exactly one thing and write exactly one artifact.
- [ ] The orchestrator (entry-point skill) coordinates; sub-skills execute.
- [ ] Confirm sub-skill descriptions are accurate and include trigger phrases — Claude reads them to decide which skill to call.

**Medium** if a sub-skill does more than one distinct task. **Low** if descriptions are missing trigger phrases.

### 8. Error Propagation

> Anti-pattern: a skill that fails silently, leaving state in a partial or corrupted position.

- [ ] Confirm failure paths write an explicit error to state (e.g. `lastError`) rather than exiting without updating state.
- [ ] Confirm the orchestrator checks for `lastError` on resume and surfaces it to the user.
- [ ] Confirm hook-enforced denials produce actionable messages ("stage: X cannot run Y yet — run Z first").

**High** if failures leave state corrupted. **Medium** if errors aren't surfaced on resume. **Low** if messages exist but aren't actionable.

### 9. Parallelism Opportunities

> Anti-pattern: sequential execution of independent setup steps.

- [ ] In the orchestrator's setup phase, identify steps that have no dependency on each other.
- [ ] Confirm they are fired in parallel (e.g., "Fire these three in parallel: rules, form, API reference").
- [ ] Confirm artifact waits are explicit before the first dependent step proceeds.

**Low** per missed parallelism opportunity.

### 10. Test Coverage for State Machine Logic

> Anti-pattern: no tests for the FSM transitions, or tests that only cover the happy path.

- [ ] Confirm unit tests exist for the state transition function.
- [ ] Confirm tests cover: counter increment (regression path), counter non-increment (first-time path and skip paths), round-trip through `parseState`, default value for new fields on old state.
- [ ] **Pitfall:** `as any` casts in tests that were written before the type was updated — clean these up after the type change lands.
- [ ] Confirm mutation guards (the hook's `checkMutationAllowed`) are tested for all stages.

**High** if no FSM tests. **Medium** if tests exist but only cover the happy path. **Low** if minor gaps (e.g., missing non-increment test).

---

## Severity Grading Reference

| Severity | When to use |
|---|---|
| **High** | Runaway loops, corrupted state, missing stop guard, missing tests entirely |
| **Medium** | Two sources of truth, cross-skill coupling, context bloat, skill doing multiple tasks |
| **Low** | Missing trigger phrases, weak UX at loop cap, stale-not-absent only guards |

---

## Fix Pass Protocol

After grading all findings:

1. Fix High findings first — each requires a failing test written before the fix (TDD).
2. Fix Medium findings next.
3. For Low findings: fix inline if trivial; otherwise ledger as deferred.
4. Run the full test suite after each fix. Do not batch fixes across test runs.
5. For any ruling made (e.g., choosing one counter increment condition over another), record it explicitly: `Ruling: <what you decided> — <why> — <what it costs if wrong>`.

---

## Success Criteria

The audit is complete when:

- [ ] All 10 dimensions have been assessed and graded.
- [ ] All High findings are fixed with passing tests.
- [ ] All Medium findings are fixed or explicitly deferred with rationale.
- [ ] Full test suite is green.
- [ ] Each ruling is recorded (no silent deviations).

---

## Key Pitfalls Discovered in Practice (wes-marketplace, 2026-10-13)

- **`isRegen` condition:** `stage === 'scripted' && state.stage !== 'audited'` fires on `idle→scripted` skip paths in tests. Correct: `state.stage === 'reviewed'`. Test *both* the increment (regression) *and* non-increment (first-time arrival) cases.
- **Extensions two-source-of-truth:** Phase 4 was passing `preserve` array in context AND the generator was reading the file. Fix: generator reads the file directly; orchestrator passes nothing. One source.
- **Freshness check symmetry:** Define the validity predicate once (Phase 0) and reference it verbatim in Phase 3 skip condition and Phase 4 guard — three places that must stay consistent.
- **`as any` casts:** Written before a new field was added to the type; cleaned up after the type landed. Check for these after every type change.
- **Cross-skill path:** `${CLAUDE_PLUGIN_ROOT}/skills/fulcrum-generate-data-events/references/generation-guide.md` referenced from `fulcrum-review-script`. Moved shared content to plugin-level `references/pitfalls-reference.md`.

---

## Open Questions / Known Gaps

- **Nested-agent hand-offs:** If the plugin delegates to a sub-agent that maintains its own state, apply dimensions 2, 3, and 5 at each agent boundary — not encoded yet.
- **Mixed designs:** A plugin might use file-based state for the FSM but in-memory passing for transient decisions within a single skill invocation. In that case, apply file-based checks to the FSM layer and in-memory checks to the intra-skill layer independently.
