# Design

## Context

See [proposal.md](proposal.md) for motivation and the [spec delta](specs/setup-memory-workflow/spec.md) for the behavior contract. This is stage 1 of the BM review, not a native-integration migration.

The current `check-drift.sh` v19 combines inspection, project registration, missing-file creation and unconditional migration. `piece_status()` and `hook_piece_status()` also create missing content. Migration matches the generic string `basic-memory`, including during `drift-warn`. Changing dispatch alone therefore cannot make inspection read-only.

The save templates use legacy calls and assume write receipts always have a `project` field. They update one mutable status note and append to one session log. The global preference requires approval before recording, while the skill tells agents not to ask. Managed profile permissions currently ask for `bm_write`; standing consent must not silently remove host tool approvals.

`home/.chezmoidata/packages.yaml` installs BM with uv but launches MCP through a separate uvx environment. Four declared upstream memory skills are intentional dependencies, and some upstream instructions still contain stale calls. CLAUDE.md and the existing `setup-memory-workflow` spec establish chezmoi source ownership, independent profile settings and per-project artifacts. None of the generic package/settings-ledger contracts needs to change.

## Goals / Non-Goals

**Goals:** make the existing workflow coherent on BM 1.x; encode the user's selected consent boundary; provide predictable inspection and explicit mutation; preserve foreign configuration. Keep the implementation within the existing script/template structure.

**Non-Goals:** no native plugin installation, cloud adoption, new Codex runtime, log-layout redesign, fleet-wide rollout, general concurrent recovery or security sandbox. The host-neutral consent format is an interoperability boundary, not a claim that every external plugin enforces it.

## Decisions

### 1. One project-local consent record, separate from BM configuration

Use `<project-root>/.basic-memory-workflow.json`, owned by this workflow, with a strict v1 record:

```json
{
  "version": 1,
  "project": "chezmoi",
  "repository_root": "/Users/craig/.local/share/chezmoi",
  "automatic_recording": true,
  "granted_at": "2026-11-13T00:00:00Z"
}
```

This example illustrates the schema; it is not a grant and must not be installed as one. The v1 boolean covers curated findings, decisions and session checkpoints as a fixed bundle. Recovery of another transcript and knowledge maintenance are excluded by the version's semantics rather than user-editable booleans that might accidentally broaden authority. No transcript, token or secret belongs in this file.

Require correct JSON types, a supported version, exact resolved BM project, and the canonical physical root of the current checkout. A missing/false/invalid/mismatched record denies automatic recording. `granted_at` is provenance, not proof of authorization or an expiry. The agent writes a grant only after an explicit user instruction and confirms the scope. Revocation sets `automatic_recording` false atomically and preserves grant history fields; regrant updates the timestamp after new authorization. Unknown fields or malformed records are reported and not silently rewritten.

Recommend keeping the record local and gitignored; setup explains this without silently editing `.gitignore`. A copied or committed grant from another checkout does not match its physical root. A repository rename or new worktree needs regrant. This favors clear scope over convenience and is not cryptographic proof against a malicious same-user file editor.

Alternatives: global consent risks cross-project enrollment; `.claude/settings.local.json` binds shared policy to one harness and conflates host permissions; BM's `captureEvents` controls metadata, not this recording policy. Individual booleans for every operation add unnecessary policy combinations at this stage.

### 2. Explicit command boundaries

Keep `check-drift.sh` as the mechanical entry point with these commands:

| Command | Authority and side effects |
|---|---|
| `check` | Report CLI compatibility, registration/configuration, pieces and consent; no workflow or BM mutations |
| `drift-warn` | Cheap local startup observation; no migration, creation, registration or consent writes; always fail open |
| `install` | Register a missing local BM project and create missing workflow pieces under an explicit setup request; leave existing customized pieces for explicit repair; do not grant consent |
| `update` | Preserve existing version-only repair and identity-mismatch safeguards; migrate only relevant positively owned legacy artifacts; never grant consent |
| `apply <piece>` | Explicit targeted replacement; migrate only legacy content belonging to that piece; preserve unrelated pieces |
| `consent grant` | Validate and display current root/project; persist the record only when the invoking agent has explicit authorization for that scope |
| `consent revoke` | Disable automatic recording for this checkout without deleting notes or removing workflow artifacts |

The shell command is the mechanism; the skill/global instructions obtain and check user authorization. It must not prompt interactively inside a hook. Installation and consent can be authorized together by one clear user request, but remain separate operations. A general request to check health authorizes `check`, not `install` or a grant.

Factor pure status functions from creation/repair functions in `lib-pieces.sh`; move the top-level migration calls behind mutating dispatch. Reuse `lib-project.sh`. A small sourced consent helper can centralize validation without a second configuration framework. Machine-readable status output must stay stable; new human diagnostics use existing shared-utils conventions. Do not introduce a new numbered chezmoi installation script.

`check` must not call BM commands that initialize/register/repair state; inspect existing configuration and use a non-mutating version check. If readiness cannot be established read-only, report unknown and suggest an explicit diagnostic rather than mutating to discover it. Cache/log effects of external runtime version checks are not permission to create project artifacts or change BM registration. Startup `drift-warn` remains local-only.

### 3. Safe legacy ownership and hook handling

Build a small enumerated set of legacy signatures from the workflow's own current code, CHANGELOG and archived assets. Recognize stable distinctive markers and the complete command shape around variable baked content; never use a bare product-name substring. Fixture examples must demonstrate each recognized shape. Unknown variants remain visible and unchanged.

Apply positive ownership recognition to current-hook detection and repair as well as legacy migration; current `lib-pieces.sh` substring matches are insufficient. Migrate owned commands inside mixed hook groups without deleting foreign siblings or changing their ordering. Append a canonical hook only when absent, and reconcile its event/matcher/type/command so repeated operations leave one intended entry. A targeted apply must not trigger all migrations. Retired `sync-memory` cleanup requires an owned skill marker/recognizable content; only remove its state when the ownership association is established. Ambiguity produces a diagnostic, not deletion.

This is deliberately narrower than a general migration engine. Exact recognition may leave old artifacts for manual review, which is preferable to removing upstream or user hooks.

### 4. One BM 1.x runtime and contract

Declare the supported package range as `basic-memory>=1,<2` through the existing uv package entry and use `basic-memory mcp` in managed registrations/canonical project configuration. Setup/save preflight checks the installed CLI's major version and availability of the connected tool contract. It does not auto-upgrade dependencies. Customized/cloud server configurations are reported and preserved; they are not forcibly rewritten to local stdio.

A `claude mcp list` name match is not evidence of global scope or compatibility. Inspect the current profile's configuration through supported CLI output and the current project's `.mcp.json`; identify scope explicitly. Discover existing BM project registration read-only before adding a missing project; reuse existing custom paths/routing, report identity conflicts, and never run unconditional project-add against an existing entry. The current default-path excerpt may remain unavailable for custom storage, which must be reported rather than repaired by relocation. Do not inspect other personas as a side effect. Managed source changes may cover targeted BM permission entries across profile source files, without auditing or deploying their live installations.

Use `bm_read`, `bm_search`, `bm_project(command="recent")`, `bm_edit(command=...)`, `bm_write` and `bm_move`, with explicit project. Consult installed `bm_man` for schema details. Do not require nonexistent `bm_recent`/`bm_project_list` aliases. `bm_write` still supports title/directory/note_type, so do not remove valid arguments just because identifier is also supported.

For mutable notes, read structured content/checksum immediately before edits and pass `expected_checksum`. Verify documented success actions and returned paths/checksums; a missing project field is not an error when the actual contract omits it. Reject contradictory qualified scope. Treat `isError`, typed refusals, malformed receipts and uncertain outcomes as failures. Do not mark success or retry an append blindly.

Keep status-link-based log selection. Specify first-use creation if no credible log exists, retaining its returned identifier. Multiple ambiguous fallback results require a choice. This repairs bootstrap ambiguity without changing the layout. Do not expand maintenance into new automatic triage or resolve every historical active-log selection issue here.

### 5. Save authorization precedes activity/marker logic

Save order becomes: validate checkout and baked identity; verify prerequisites; read consent or recognize an explicit one-time request; then apply the meaningful-activity filter and existing status/log operations. A missing grant is not an evaluated/no-op session: no marker may advance on denied authorization. A generic “I'm done” is an offer trigger, not one-time recording authorization.

Global preferences state the same policy: reads are automatic; granted projects may record routine curated knowledge/checkpoints; other saves require approval. Preserve the existing global startup memory lookup requirement, but express snapshot-conditioned additional retrieval consistently: the snapshot may avoid redundant extra reads, not override a higher-priority startup lookup instruction.

Recovery still requires an explicit request covering the named prior transcript. Metadata inspection and bounded local turn counting for detection are permitted; reconstructing knowledge from its content requires the separate request. Maintenance stays manual, with explicit invocation authorizing its described scope. Correct recovery wording to “potentially unsaved work”; do not infer unobserved SessionEnd events. General marker concurrency/source-session redesign remains deferred, and no new claim of robust crash recovery is made.

Managed `bm_write`/`bm_edit` permissions continue to require host approval where configured. Add missing edit coverage consistently with existing profile policy, preserve stricter settings, and do not introduce host-wide allows. Per-project standing consent removes redundant model questions; it does not suppress host approvals. Native hooks may write through their own runtime rather than MCP approvals, which is another reason their activation stays outside this change.

### 6. Documentation and downstream skills

Update SKILL.md to use check/report, explicit install/repair, and separate consent grant/revoke. Replace unconditional “never ask” language. Bump SMW_VERSION for rendered assets. Update CHANGELOG, the architecture narrative and the main spec Purpose during implementation to remove retired sync-memory and correct static-hook/runtime exceptions; do not change main specs in this planning-only workflow.

Retain the four declared upstream memory skills. Move their declarations to the canonical main-repository `/skills` source only after checking supported installer syntax and BM 1.x guidance. If published instructions remain stale, add concise local contract guidance rather than editing fetched skill files or pretending a source move fixed them. This is a targeted dependency correction, not adoption of the entire toolkit.

## Risks / Trade-offs

- [Old projects stop automatic saves until re-enrolled] → show an explicit status and one-time consent route; direct requests still authorize individual saves.
- [Old installed copies ignore the new policy] → global instructions take precedence; document an explicit per-project update before using new standing consent. Source deployment alone does not update every rendered copy.
- [Read-only check changes a familiar command] → mark it breaking and update every maintained caller/example in scope, including bulk-update instructions that expected setup side effects.
- [A copied consent file authorizes another checkout] → compare canonical root and BM project exactly; no automatic repair of identity-bound consent.
- [Two-note saves are not transactions] → report partial success and retain the marker; inspect before recovery, never blindly replay an append.
- [BM's MCP/API version differs despite local CLI alignment] → verify the connected tool schema and stop on incompatible contracts; a CLI check alone is insufficient.
- [Permission settings still prompt] → document host approval as a separate boundary; no bypasses to make auto-save appear seamless.
- [Native hooks do not read our consent file] → do not enable them in this stage; the later pilot must map this policy explicitly.
- [Broad cleanup accidentally removes native hooks] → exact ownership fixtures, mixed-group/order tests, idempotence and narrow mutation dispatch.

## Migration Plan

1. Implement and verify against scratch project roots with stubbed BM/Claude commands and mock homes; never run setup on real projects during tests.
2. Render affected chezmoi templates with `tests/run-template`, run shell lint and preserve managed settings semantics. No generic installer/ledger changes.
3. Deliver source changes and explicit deployment instructions. Live chezmoi application, profile registration changes and project updates are separately invoked operations, not automatic apply tasks.
4. For an authorized project rollout, inspect first, explicitly update/install required pieces, resolve custom drift, then obtain and record consent for the displayed root/project. Existing installations remain unenrolled until that grant.
5. Roll back by restoring changed workflow source/rendered pieces and managed registrations from captured configuration, preserving foreign settings and notes. Never restore old unconditional automatic-save behavior as an implied grant; revocation or absent consent remains the conservative policy. Retain the consent file as disabled evidence if reverting runtime support.

## Review provenance

Research index and all three companion identifiers are in proposal.md. The user chose the per-project policy; this design's file schema, command split and BM 1.x range are implementation recommendations for artifact review. No implementation, native integration, deployment, commit or push is authorized by creating these artifacts.
