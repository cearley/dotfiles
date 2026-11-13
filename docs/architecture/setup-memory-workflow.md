# Session memory workflow: stage 1

`home/dot_claude/skills/setup-memory-workflow/` owns the shared helpers and rendered
project skills. This stage stabilizes the existing workflow on Basic Memory 1.x.
It retains one mutable current-status note and an append-only session log; it does
not install native BM plugins/hooks, enable cloud capture or redesign logs.

## Runtime and configuration

The `ai` package manifest installs `basic-memory>=1,<2` through uv. Managed local
MCP registrations launch that installed executable with `basic-memory mcp`, avoiding
a second unpinned uvx environment. A supported local CLI does not prove that a
connected MCP server exposes the same contract: setup/save must inspect the actual
connected tools and `bm_man` before writes. Missing/incompatible dependencies stop
the operation; the workflow does not automatically upgrade them.

BM calls use explicit `project`, with `bm_search`, `bm_read`,
`bm_project(command="recent")`, `bm_write`, `bm_edit(command=...)` and `bm_move`.
Do not translate old examples into nonexistent `bm_recent` or `bm_project_list`
aliases. Consult installed manuals for arguments and result schemas. Valid
`bm_write` title/directory/note_type arguments remain supported. Mutable edits read
structured content and checksum immediately before passing `expected_checksum`.
Validate success actions, paths and checksums; an absent receipt project field is
acceptable, contradictory qualified scope is not. Typed refusals, `isError`, malformed
receipts and uncertain outcomes stop success reporting. Two-note saves are not atomic:
report partial progress, retain the marker and inspect before retrying an append.

The four upstream memory-defrag/lifecycle/notes/schema skills remain declared.
Their existing installer source is retained until the canonical main-repository
`/skills` source syntax can be verified. Upstream examples may still use retired tools:
apply the local BM 1.x contract above to each actionable example, including explicit
scope, receipt checks and fresh checksums. Do not edit downloaded skills, install the
whole toolkit or infer that a source move alone fixes incompatible examples.

Inspect only the active profile's supported configuration and project `.mcp.json`.
A name in `claude mcp list` does not establish scope or compatibility. For CLI
configuration, resolve local → project → user precedence; a project entry cannot
override a local entry ([official scope reference](https://code.claude.com/docs/en/mcp#scope-hierarchy-and-precedence)). Reuse existing
BM registration and custom storage paths; report identity/routing conflicts rather
than overwriting them. Customized/cloud entries are preserved for explicit review.
Profile settings/plugins/history are independent, even when skills/rules are shared.

## Project artifacts and commands

Project identity resolves from a nonblank `.claude/basic-memory-project.txt` override
or the checkout name. Rendered `save-session` and manual-only
`save-session-maintenance` skills bake this identity and version 20. Shared reminder,
recovery-detection and write-guard scripts inspect live checkout state at runtime;
they are deliberate exceptions to template identity baking. Project hook commands
and `.mcp.json` connect these shared pieces. `.claude/.last-saved-session` tracks an
authorized save evaluation; it is not proof that an earlier process ended cleanly.

| Command | Effect |
| --- | --- |
| `check` | Read-only report of prerequisites, registration, pieces and consent |
| `drift-warn` | Local-only, fail-open startup observation |
| `install` | Explicit registration of a missing local project and creation of missing pieces |
| `update` | Explicit repair of existing version drift; preserve identity mismatches |
| `apply <piece>` | Explicit targeted replacement after identity/customization review |
| `consent status` | Read-only grant diagnosis for this physical root and BM project |
| `consent grant` | Persist checkout-specific standing consent after explicit authorization |
| `consent revoke` | Disable automatic recording without deleting notes or artifacts |

Inspection never migrates, creates pieces, registers BM projects or writes consent.
Only explicit mutating operations migrate positively owned legacy content. Supported
signatures are enumerated with migration fixtures; generic product-name matches are
insufficient. Preserve native `bm hook` commands, unfamiliar scripts, foreign siblings
and group order. Ambiguous content needs manual review; targeted apply must not sweep
unrelated pieces. No setup/repair command grants consent as a side effect.

## Consent and save boundaries

The workflow owns `<project-root>/.basic-memory-workflow.json` with this strict v1
schema (illustrative only; this example is not a grant):

```json
{
  "version": 1,
  "project": "example",
  "repository_root": "/physical/path/to/example",
  "automatic_recording": true,
  "granted_at": "2026-11-13T00:00:00Z"
}
```

Require exact JSON types/fields, supported version, resolved BM project and canonical
physical checkout root. Missing, false, invalid or mismatched records deny automatic
recording. `granted_at` records provenance, not expiry or proof against malicious local
edits. Unknown fields/malformed records require review rather than silent rewriting.
Recommend keeping this file local and gitignored; setup does not silently edit
`.gitignore`. A new worktree, moved checkout or changed BM identity requires a new
authorized grant. Revocation atomically sets `automatic_recording` false, preserving
grant history; regrant refreshes its timestamp after new authorization.

A grant covers routine curated findings, decisions and session checkpoints. Reads
remain automatic under global startup lookup rules. An explicit save request permits
that save without granting standing consent; a generic wrap-up is only an offer trigger.
Recovering a named prior transcript and knowledge maintenance each require their own
explicit request, even with a grant. Bounded metadata/turn counting may identify
potentially unsaved work; it does not authorize reconstructing that transcript.

Save authorization precedes meaningful-activity checks and marker writes. Denial leaves
notes and markers untouched. Log selection follows the status note's credible link;
first use creates a log and retains its returned identifier, while ambiguous fallback
results require a choice. Maintenance handles rollover/triage only on explicit invocation.

Host tool approvals are independent: managed profile `bm_write` and `bm_edit` ask
entries remain in force. Standing consent removes redundant model questions, not host
approval prompts. The direct-write guard is a heuristic agent safeguard directing
writes through BM tools; it is not a security sandbox and does not prohibit external
human edits. Native capture has its own runtime and is outside this stage's policy.

## Deployment and re-enrollment

1. Verify source in scratch projects with stubbed BM/Claude commands and mock homes.
   Render affected chezmoi templates with `tests/run-template` and mock secrets.
2. Deploy the source through the normal reviewed chezmoi process to the intended
   profile. Source deployment updates shared helpers; it does not refresh every
   project's rendered skills or grant recording consent.
3. In each intended checkout, run `check-drift.sh check`, review identity, custom
   routing, ownership and version diagnostics. Use explicit `install` for missing
   pieces, `update` for version drift or confirmed `apply <piece>` for targeted repair.
   Bulk update follows the same inspection-first procedure and never enrolls consent.
4. Verify the updated rendered skills before relying on standing consent. Explain
   the exact project and physical checkout root, obtain explicit authorization, then
   run `check-drift.sh consent grant` from that root. `consent status` verifies scope.
   Existing installations receive no inferred consent. Use `consent revoke` to opt out.
5. Exercise an explicitly requested save and review its receipts. Maintenance and
   prior-transcript recovery remain separately invoked; no native/cloud rollout is
   implied by these checks.

These are rollout instructions, not actions performed by the source change. Never
run grant examples in a real checkout merely to test them.

## Conservative rollback

First revoke standing consent in each affected checkout while the v20 helper is
available. Restore the reviewed source and project artifacts from known backups,
preserving notes, custom registrations, foreign hooks and unrelated settings. Retain
explicit-save-only global instructions: older rendered skills do not enforce this
consent policy and must not resume automatic recording. A runtime downgrade needs
separate BM compatibility review; do not automatically downgrade notes/data or blindly
replay partially completed saves. Re-inspect the restored configuration before use.

## Opt-in runtime contract verification

With Basic Memory 1.x already installed, run:

```bash
python3 tests/test-bm1-contract.py --run
```

The test selects the installed executable's Python interpreter, creates a disposable
HOME/config/database/notes tree, clears inherited credentials and denies socket
connections in the worker and Python subprocesses. Offline model/telemetry settings prevent downloads; dependencies are
never installed. It runs the production `check` → `install` → consent grant →
`authorize fixture auto` boundary before actual BM tool calls, reusing an existing
scratch registration at a custom path. After the tool cases it revokes consent,
observes authorization failure and verifies notes/config/a preexisting marker remain
byte-identical. The direct caller obeys the authorizer; this does not demonstrate
model compliance or execute a model save skill.

It calls the actual BM tools through their CLI adapter and checks
first status/log creation with overwrite disabled, explicit project scope, receipts
without a project field, fresh checksums, targeted Open-item preservation, typed
revision conflicts and a successful status edit followed by a refused log append
without duplicate mutation. This tests the BM contract, not a fabricated executable
save workflow. Authorization/marker fixtures and review of model instructions remain
separate checks. Run without `--run` to skip the installed-runtime integration.
