---
name: bulk-update-memory-workflow
description: Inspect or propagate setup-memory-workflow version changes across existing projects on this machine. Use for an explicitly requested bulk memory-workflow check/update, not single-project setup or consent enrollment.
---

`setup-memory-workflow` source deployment updates the shared templates and helpers;
existing project skills require a separate update. This workflow discovers projects
with `.claude/skills/save-session/` beneath `$HOME`, excluding `.stversions/` and
`_Archived Items`. It uses the active `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` copy of
the shared helper. It does not audit other personas or enroll projects for recording.

## 1. Inspect before updating

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/bulk-update-memory-workflow/scripts/sweep.sh" check
```

Read every project's output. `check` is read-only: it does not register projects,
create missing pieces, migrate legacy content or write consent. Review:

- `UP-TO-DATE`: no version repair needed; consent is reported separately.
- `DRIFT`: existing version/content drift, eligible for explicitly requested update.
- `MISSING`: use explicit single-project `install` after the user requests setup.
- `NAME-MISMATCH`, custom routing or ambiguous ownership: review individually.
  Preserve custom registration paths and foreign hooks. Do not relocate storage to
  satisfy a default-path assumption. Resolve identity repairs with explicit
  `apply <piece>` after reviewing the affected identity and diff.
- Invalid/missing/mismatched consent: automatic recording stays disabled. Updating
  is not a grant, and a generic request to update everywhere does not authorize grants.

If inspection fails or cannot establish readiness, report it and resolve the diagnostic
before including that project in an update. Do not treat an aborted check as healthy.

## 2. Run the requested update

After reviewing inspection output, run the bulk update only when the user's request
covers updating the discovered projects:

```bash
"${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/bulk-update-memory-workflow/scripts/sweep.sh" update
```

For a restricted set, invoke `check-drift.sh update` separately in each approved root
instead of the full sweep. `update` repairs existing version drift and relevant owned
legacy content; it leaves identity mismatches for targeted repair and does not create
missing pieces or grant consent. Unknown/native hooks must survive.

## 3. Verify and report

Repeat the read-only `check` sweep. Summarize current/updated projects, failures,
missing pieces and identity/customization follow-ups. Report consent separately.
For v20 rollout, update old rendered skills before using standing consent; then obtain
explicit project/root-specific authorization and run `consent grant` in that checkout.
Never bulk-enroll projects from an update request. See
`docs/architecture/setup-memory-workflow.md` in the chezmoi source for staged rollout
and conservative rollback guidance.
