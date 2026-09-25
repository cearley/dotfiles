# Design

## Context

After `claude-tooling-plugin` lands, `claude-settings-hooks-modifier` does two things:
(a) removes six legacy hook commands (owned by that change and unchanged here), and
(b) merges the caller's `$extra` with jq `. * $extra`. This change replaces (b).

Other writers also change the same `settings.json`: Claude Code's `/permissions`,
`/plugin`, and model picker, plugins, and tools such as `bd setup`. See proposal.md (Why)
for how this drifts.

Constraints:
- A chezmoi `modify_` script must be a pure stdin→stdout function. Chezmoi also runs it for
  `diff` and `status`, so it cannot keep state in side files. Its record of what it wrote
  must live in `settings.json` itself.
- `check-claude-overrides` greps the rendered template for the `extra_settings='…'` line.
- `jq` is the only dependency.

## Goals / Non-Goals

**Goals:**
- No hand-maintained retirement state.
- Idempotent output.
- The first apply is safe (it retracts nothing).

**Non-Goals:** a general JSON-ownership library for other `modify_` scripts. It can be
extracted later if this proves out.

## Decisions

### D1. Ownership ledger stored in `settings.json`
A top-level `_chezmoiManaged` array holds one entry per leaf written from `$extra`:
- scalar: `{"path": [...], "value": v}`
- array element: `{"path": [...], "elem": e}`

The entries come from recursively flattening `$extra`: objects recurse, arrays emit one
entry per element, and anything else is a scalar. Empty dicts contribute nothing.

Each run:
1. **Retract** only what source dropped: the previous ledger minus the current one. A scalar
   is retracted when its path is absent from the current ledger, and deleted only if the
   live value still equals the recorded value. An array element is retracted when its
   `{path, elem}` pair is absent from the current ledger, and removed if present.
2. **Apply** `$extra`. Scalars overwrite. Array elements are appended only when absent,
   which gives an order-preserving union.
3. **Write** the new ledger.

Entries still in source are never retracted, so they keep their position. Retracting the
whole previous ledger and then re-applying would not be idempotent in practice. jq moves a
deleted-and-reset key to the end of its object, and re-appends a removed element behind any
entries the user added. Every user addition would then reorder the file and show up as a
diff on the next apply.

*Alternatives:*
- **`* $extra` plus a retired-keys list:** the same maintenance trap the hooks had.
- **chezmoi owns whole subtrees** (e.g. all of `skillOverrides`): this would break the
  `/plugin` and skill toggles that `check-claude-overrides` exists to detect.
- **Ledger in a side file:** impossible, because `modify_` scripts must not have side effects.
- **Ledger JSON-encoded in `env.CHEZMOI_CLAUDE_MANAGED`:** always schema-valid, but it
  leaks into every session's environment. This is the fallback if task 1.1 shows Claude
  Code rejects an unknown top-level key.

### D2. Compare before retracting scalars
If the user changes a managed scalar (e.g. `defaultMode` to `plan`) and source later drops
that key, the user's value is kept. While the key remains in source, chezmoi's value wins on
every apply, as it does today.

### D3. Emptied containers are kept
Retraction never deletes an object or array, even when it leaves one empty (e.g.
`"skillOverrides": {}` after its last managed key is retracted). An empty container behaves
the same as an absent one for these keys. Pruning it would also delete a container another
writer created, and the ledger doesn't record who created containers.

### D4. Keep the `extra_settings='…'` line
`extra_settings='{{ … | toJson }}'` stays a standalone line. The ledger is computed in jq,
not in Go, so the grep contract that `check-claude-overrides` relies on is untouched.

### Prototype
The extra-settings half of the pipeline (about 15 lines of jq) was run against a copy of
`~/.claude-personal/settings.json` with an allow entry added by hand. Results:
- the added entry survived
- a removed skill override and a removed allow element were retracted
- a second run was byte-identical
- all other keys were unchanged

The prototype retracted the whole previous ledger. D1's set-difference refinement came
after it and is covered by the position-stability fixture in task 2.1.

## Risks / Trade-offs

- [Claude Code rejects or strips the unknown `_chezmoiManaged` key] → Task 1.1 checks this
  before implementation; if it fails, fall back to the `env` encoding (D1). If the key is
  stripped when the UI saves, the next apply finds no ledger and retracts nothing (fails
  safe), then rewrites the ledger.
- [A user adds an allow entry that chezmoi also adds, and source later drops it] → chezmoi
  retracts it. This is rare and visible, and the user can grant it again.
- [Stale keys left by removals made before the ledger existed] → no ledger can recover
  them. Task 3.2 is a one-time manual audit.
- [Union semantics mean chezmoi can't revoke allow entries it never wrote] → intended; those
  belong to the user. `permissions.deny` in `$extra` remains available for hard blocks.
- [A hand-edited ledger] → a malformed entry could retract the wrong path, but only paths
  chezmoi could have written.

## Migration Plan

1. After `claude-tooling-plugin` is applied everywhere, land this change. The next apply
   seeds the ledger in each persona and retracts nothing.
2. Remove any stale keys found in the audit by hand (task 3.2).

**Rollback:** revert. The old `* $extra` merge ignores `_chezmoiManaged`, which does nothing
under the old modifier. Arrays go back to being replaced wholesale.
