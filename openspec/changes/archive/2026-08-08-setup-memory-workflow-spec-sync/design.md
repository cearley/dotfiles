## Context

See proposal.md - Why. The implementation this change documents is already committed (`531d07f`): `plugins/basic-memory-workflow/scripts/ensure-project-registered.sh` wraps `resolve-project-name.sh` with an idempotent `basic-memory project add`, and the `SessionStart` hook (`session-start-reminder.sh`) calls it instead of the bare resolver. `save-session/SKILL.md` no longer performs registration itself.

## Goals / Non-Goals

**Goals:**
- Bring `openspec/specs/setup-memory-workflow/spec.md` in line with the shipped behavior, so the spec is a correct reference for future changes to this plugin.

**Non-Goals:**
- No code changes — the implementation is already correct and verified (tested against both an existing project and a simulated brand-new project during the original bug-fix session).
- No changes to the `claude-plugin-marketplace` capability — marketplace registration and per-project plugin opt-in are unaffected.

## Decisions

**Fold the registration-timing change into the existing two requirements rather than adding a new one.** The "basic-memory project registration" requirement's WHEN/THEN scenarios already describe registration mechanics end-to-end; rewriting them in place (rather than adding a parallel "SessionStart hook registers the project" requirement) avoids two requirements describing the same behavior from different angles. The "Runtime project identity resolution" requirement gets a smaller edit: one sentence distinguishing pure resolution (`resolve-project-name.sh`, still called directly by `save-session`/`sync-memory`) from resolution-plus-registration (`ensure-project-registered.sh`, called only by the hook). Considered: a separate new requirement for `ensure-project-registered.sh` itself — rejected as redundant, since its behavior is fully covered by the registration requirement's scenarios plus the one clarifying sentence in the resolution requirement.

**Added a new scenario for the "basic-memory not installed" case** under the registration requirement. The old spec didn't cover this because registration used to happen inside `save-session`, which already had its own explicit `which basic-memory` check as a separate requirement. Now that registration happens in the hook (which must stay silent per its own no-noise contract), the spec needs to say what happens when `basic-memory` is missing at session start — it's a real, reachable branch in `ensure-project-registered.sh`, not implementation trivia.

## Risks / Trade-offs

None — this is a documentation-only change matching already-verified, already-committed behavior. The only risk was internal (spec/implementation drift), and this change resolves it.
