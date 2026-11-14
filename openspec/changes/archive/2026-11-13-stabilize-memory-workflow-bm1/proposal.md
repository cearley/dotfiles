# Proposal

## Why

The session-memory workflow still instructs agents to call retired Basic Memory tools, permits automatic saves contrary to the global recording policy, and runs broadly matched legacy migrations during startup inspection. Stabilize these contracts before considering BM-native plugins so existing memory remains usable and future integrations cannot be removed accidentally.

## What Changes

- Target the BM 1.x tool contract, explicit project scope, structured write receipts and checksum-checked mutable-note edits. Use the uv-installed CLI for managed MCP launch rather than resolving a separate unpinned `uvx` environment.
- Record explicit standing consent in a versioned, host-neutral, project-local policy. Opt-in permits curated findings, decisions and session checkpoints; recovering another session and knowledge maintenance remain separately authorized. Existing installations receive no inferred consent.
- Align global instructions, save/maintenance skills, startup reminders and managed Claude tool permissions with that policy. A direct save request authorizes that save without granting standing consent.
- **BREAKING:** make `check` and `drift-warn` observational. Move registration and missing-piece creation to explicit `install`; run owned legacy migration only within explicit install/update/apply operations.
- Recognize legacy artifacts by exact owned signatures, preserve unfamiliar/native hooks and user settings, and avoid granting consent as a migration side effect.
- Update the setup skill, architecture documentation and rollout instructions together. Keep the current status/session-log layout in this stage.

## Capabilities

### New Capabilities

None. Consent, compatibility and setup safety belong to the existing session-memory workflow.

### Modified Capabilities

- `setup-memory-workflow`: BM 1.x compatibility, per-project recording consent, read-only inspection, explicit installation and ownership-safe migration.

## Non-goals

- Install BM-native Claude/Codex plugins or hooks, enable cloud services, or claim native checkpoint parity.
- Replace the status/session-log layout, rewrite old notes, build general concurrent-session recovery, or change bd task authority.
- Build Codex lifecycle adapters, a new permission framework, or dual pre-1.0/1.x compatibility.
- Automatically enroll existing repositories, deploy to live profiles/projects, commit or push.

## Impact

- Primary code: `home/dot_claude/skills/setup-memory-workflow/`, including its templates and script helpers.
- Policy/configuration: `home/dot_claude/rules/global-preferences.md.tmpl`, the BM declaration under `home/.chezmoidata/packages.yaml`, and targeted `home/dot_claude*/.claude-settings.json` permission entries. No generic package-installer or settings-ledger behavior changes.
- Project artifacts: a new `.basic-memory-workflow.json` consent record, rendered skills, and existing project-local MCP/hook entries. Existing `.claude/basic-memory-project.txt` remains the identity override.
- Tags: `ai` on macOS; `work`/`personal` select consumers but do not imply recording consent. No `core`, `dev`, `datascience` or `mobile` installation changes.
- Security: automatic note recording requires explicit project consent; no new secrets, cloud routing, SIP changes or host-wide permission bypasses. BM writes remain subject to host controls. Direct-write guarding stays a heuristic agent policy; BM supports external human edits.
- Compatibility: documented callers that previously used `check` to install must use `install`. BM 1.x is required; project identity mismatches remain explicit repairs. No real-project rollout is part of applying the source change.

## Research and decisions

The user selected per-project standing consent after comparing per-save approval and explicit-save-only alternatives. The exact policy-file representation and command names are proposed implementation decisions for review.

The complete research is in Basic Memory project `chezmoi`, starting at `reference/basic-memory-1-workflow-review-2026-11-13.md`, with companions `reference/bm-1-review-local-evidence-2026-11-13.md`, `reference/bm-1-review-upstream-evidence-2026-11-13.md`, and `reference/bm-1-review-staged-handoff-2026-11-13.md`. Their earlier statements that consent selection was pending predate the user's selection in this session.

Local baseline: [architecture](../../../docs/architecture/setup-memory-workflow.md), [workflow source](../../../home/dot_claude/skills/setup-memory-workflow/), [main spec](../../specs/setup-memory-workflow/spec.md). Upstream baseline: [BM migration guide](https://docs.basicmemory.com/reference/migrating-to-1-0), [lifecycle documentation](https://docs.basicmemory.com/integrations/harness-capture), and [source commit 3e8a519](https://github.com/basicmachines-co/basic-memory/tree/3e8a519fa0ff406d98321af160080b74d8230c51). Use installed manuals/schemas to resolve stale upstream examples.
