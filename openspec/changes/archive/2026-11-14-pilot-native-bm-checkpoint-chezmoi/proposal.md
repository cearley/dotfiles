# Proposal

## Why

Stage 1 (`stabilize-memory-workflow-bm1`, archived) made `setup-memory-workflow` coherent on BM 1.x and encoded an explicit per-project consent boundary. The upstream BM 1.0 review (`reference/bm-1-review-upstream-evidence-2026-11-13` in the `chezmoi` basic-memory project) found that upstream now ships richer, better-tested checkpoint/resume/diagnostic skills (`bm-checkpoint`, `bm-orient`, `memory-doctor`) than anything we'd build ourselves for Stage 3's typed-handoff goal. The user's stated goal for Stage 2 is to minimize infrastructure we maintain by relying on BM's native capabilities wherever they don't conflict with the recording-consent and chezmoi-configuration-ownership boundaries Stage 1 just hardened. This proposal pilots that adoption on the `chezmoi` project itself, the one place we can dogfood it safely.

## What Changes

- Declare the upstream `bm-checkpoint`, `bm-orient`, and `memory-doctor` skills for installation alongside the four already-declared shared memory skills, so they become available in this project (and any other project opting in later).
- Document, as an explicit spec requirement, that native `SessionStart`/`PreCompact` lifecycle hooks from BM's Claude Code and Codex plugins are **not** enabled by this pilot: they fire automatically and have no awareness of our `.basic-memory-workflow.json` consent record, which would silently reintroduce unconsented automatic recording. Enabling them requires a separate, explicit consent-mapping design — out of scope here.
- Document, as an explicit spec requirement, that BM's `bm-setup` skill's automatic settings-writing behavior is **not** used: it writes directly into `.claude/settings.json`/`.claude/settings.local.json`, bypassing chezmoi's declared ownership of that configuration. Any MCP/server registration this project needs continues to go through the existing chezmoi-managed path.
- Run the pilot itself in the `chezmoi` project: use `bm-checkpoint`/`bm-orient` for at least one real session handoff in place of (or alongside) the existing session-log/status-note convention, and `memory-doctor` for at least one read-only health check, to produce real evaluation evidence instead of another source-review pass.
- Record pilot findings (what worked, what didn't, whether the native checkpoint content is a credible substitute for Stage 3's planned typed-handoff work) back into the `chezmoi` basic-memory project for the eventual Stage 3/4 decision.

No change to `save-session`, `check-drift.sh`, the consent file schema, or any rendered hook/skill template — this pilot adds optional capability alongside the existing workflow; it does not modify or replace it.

## Capabilities

### New Capabilities
(none — this extends the existing memory-workflow capability rather than introducing a new durable system behavior)

### Modified Capabilities
- `setup-memory-workflow`: adds requirements that (a) declare native checkpoint/orient/doctor skills as available tooling, and (b) explicitly bound this pilot — native lifecycle hooks stay disabled and `bm-setup`'s config-writing path stays unused — so the existing consent and chezmoi-configuration-ownership guarantees are not silently weakened by installing adjacent upstream capability.

## Impact

- `home/.chezmoidata/packages.yaml`: add 2-3 entries to the existing `packages.darwin.ai.agents.claude_code.skills` list (same mechanism as the four already-declared shared skills). The exact fetch spec for plugin-scoped skills (`bm-checkpoint`/`bm-orient` live under `plugins/claude-code/skills/` and `plugins/codex/skills/` in the upstream repo, not the top-level `skills/` directory the current four come from) needs confirming against the installer script during design — recorded as an open design question, not assumed resolved here.
- No chezmoi-rendered skill/hook templates change.
- No consent file schema change.
- Affected tags: `ai` profile only (where the Claude Code skill-fetch script already runs).
- Security/permissions: none of the newly declared skills write outside the `basic-memory` notes tree or request elevated permissions beyond what the four already-declared shared skills use; no SIP or secret-management impact.
- This is a pilot on one project (`chezmoi`); no other project's installed workflow copy is touched.

## Non-Goals

- Not enabling BM's native `SessionStart`/`PreCompact` hooks — that needs its own explicit consent-mapping proposal.
- Not adopting `bm-setup`'s automatic configuration writing.
- Not retiring or modifying `save-session`, `save-session-maintenance`, the crash-recovery hook, or the write-guard hook — upstream evidence found no native equivalent for the crash-recovery hook's purpose, so it stays regardless of pilot outcome.
- Not a fleet-wide rollout to other projects.
- Not a decision to proceed with Stage 3 (typed handoffs) or Stage 4 (delegating startup retrieval) — this pilot produces the evidence for that decision, it doesn't make it.
