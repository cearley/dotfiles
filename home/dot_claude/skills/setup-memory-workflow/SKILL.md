---
name: setup-memory-workflow
description: Inspect, explicitly install or repair the basic-memory session workflow, and manage separate project-local recording consent. Use for setup, health checks, memory workflow repairs or enrollment. Inspection never installs or enrolls a project.
---

## Step 1 — Inspect and report

Run from inside the target checkout:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh check
```

This resolves the physical checkout root and BM project (including
`.claude/basic-memory-project.txt` overrides). `check` and startup `drift-warn` are
observational: no registration, missing-piece creation, migration, settings edits or
consent writes. Report missing/stale/ambiguous state and the explicit operation needed.
A request to check health authorizes inspection only.

Require the installed CLI major version 1 (`basic-memory>=1,<2`) and verify connected
BM 1.x tools, consulting `bm_man` as needed. Missing/incompatible prerequisites stop
writes; report them without installing, upgrading or resolving another uvx environment.
Local managed MCP launch is `basic-memory mcp`, using the installed runtime. Distinguish
current profile versus project registration scope; a matching name in `claude mcp list`
is insufficient evidence. Preserve/report custom storage, routing or cloud configuration
and project identity conflicts rather than overwriting or relocating them. Inspect only
the active profile; do not audit other personas as a side effect.

## Step 2 — Explicit installation or repair

An explicit setup request authorizes missing registration/piece creation:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh install
```

Installation never grants recording consent. It preserves existing customized pieces.
For reported `DRIFT` or `NAME-MISMATCH`, show current/canonical differences and determine
whether the user's request already authorizes replacement. Otherwise ask which concrete
pieces to update, preserve or manually merge. Version-only repair uses `update` with its
identity safeguards; targeted replacement uses:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply save-session-skill
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply save-session-maintenance-skill
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply mcp-config
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply hook-config
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply write-guard-hook
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh apply crash-recovery-hook
```

Only explicit install/update/apply run positively owned legacy migrations within their
scope. Foreign/native hooks, ambiguous commands, unrelated siblings and ordering survive;
never remove content merely because it mentions basic-memory. Targeted apply stays targeted.

## Step 3 — Separate recording consent

Display the resolved BM project and canonical physical repository root. Explain that
standing consent covers curated findings, decisions and session checkpoints for this
checkout only. Recovery of a named prior transcript and maintenance each require a
separate explicit request. Host tool approvals remain in force. Old installs, source
deployment and existing hooks do not imply consent; update old rendered skills before
using the new policy.

Only after an explicit user instruction for that displayed scope, run:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh consent grant
```

Installation and enrollment can be authorized by one clear request, but are separate
operations. Do not turn “set up memory” or a health check into an automatic grant.
To inspect or explicitly revoke:

```bash
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh consent status
~/.claude/skills/setup-memory-workflow/scripts/check-drift.sh consent revoke
```

Confirm `.basic-memory-workflow.json` location/scope. Missing, false, malformed,
unsupported-version or root/project-mismatched records deny automatic recording. Do not
silently rewrite invalid records. A renamed repository/new worktree needs a fresh grant;
copying the record cannot enroll another physical root. Recommend keeping this local and
gitignored; do not edit `.gitignore` silently. Revocation does not delete notes or uninstall
the workflow. A direct save request still authorizes that one save without granting
standing consent; generic wrap-up wording triggers an offer.

## Step 4 — Verify and hand off

Re-run read-only `check`; report actual status of registration, both skills, MCP config,
reminder/write-guard/recovery hooks and consent. Report unknown readiness honestly.
Confirm created/repaired/preserved pieces and unresolved identity/configuration issues.

Explain `.mcp.json` sharing versus personal gitignore choices and that
`.claude/settings.local.json` is local machine configuration. Custom BM paths may differ
from `~/.local/share/basic-memory/<project>/`; missing default-path excerpts do not justify
relocation. The startup reminder supplies background context and does not call MCP itself.
It preserves the required startup lookup and avoids redundant extra retrieval when the
snapshot suffices. Recovery detection is bounded local metadata/turn counting, not proof
of a crash or robust concurrent-session recovery.

The global write guard prefers indexed MCP agent writes to avoid stale revisions/indexing
delay. Human Markdown editing is supported. It is a heuristic policy, not a security
sandbox. It never replaces host permission controls. Do not activate native integrations
or change host-wide approvals as part of this workflow.

## Maintaining the source

Canonical rendered skills are `assets/save-session-skill.md.template` and
`assets/save-session-maintenance-skill.md.template`, with only `__PROJECT__` and
`__SMW_VERSION__` substitution in `scripts/lib-pieces.sh`. Each rendered skill carries
`<!-- setup-memory-workflow-project:__PROJECT__ -->` as its explicit baked identity
marker; `authorize <project> auto|once` verifies that marker and the current version
against the resolved checkout/project before authorizing a save. Bump `SMW_VERSION` in
`scripts/executable_check-drift.sh` when changing rendered assets. Blind substitution also
replaces placeholder literals inside self-checks; detect unrendered patterns instead.

`check-drift.sh` orchestrates project resolution, pure piece inspection, explicit
creation/repair, strict consent validation and ownership-scoped migration helpers.
Session reminder, write guard and recovery scripts are static machine-wide scripts;
only their canonical hook entries are managed per project. Their wording changes do not
require version markers. Reminder excerpt/log helpers remain read-only and fail open.
Use BM 1.x `bm_read`, `bm_search`, `bm_project(command="recent")`,
`bm_edit(command=...)`, `bm_write` and `bm_move` with explicit project, fresh checksums
for mutable edits and structured receipt verification. Adapt stale upstream guidance
locally rather than editing fetched skills. No BM-native installation is part of setup.
