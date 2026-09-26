# Design

## Context

`claude-settings-hooks-modifier` runs one jq pipeline in two stages. See proposal.md (Why)
for why that's a problem.

1. **Hook stage.** Strips `retired_commands`, then for each event in `managed_hooks` it
   removes every group whose `hooks[0].command` is a managed command and appends the managed
   groups. The result is that managed hooks move behind foreign ones on every apply.
2. **Ledger stage.** Flattens `$extra` into `{path, value}` scalars and `{path, elem}` array
   elements, retracts what the previous `_chezmoiManaged` ledger has but `$extra` doesn't,
   applies `$extra` (scalar overwrite, order-preserving union for arrays), and rewrites the
   ledger.

`flat` already recurses objects and emits one entry per array element, whatever the
element's type. So `{"hooks": {"PreToolUse": [G]}}` flattens to
`{path: ["hooks","PreToolUse"], elem: G}` with no code change. jq's `==` on objects ignores
key order, so the groups Go's `toJson` emits (keys sorted: `hooks`, `matcher`) match the
live groups (`matcher`, `hooks`).

Prototype (2026-09-25, scratch copy, nothing applied): the current modifier was rendered
with personal's real `$extra` plus the five hook groups, and the live
`~/.claude-personal/settings.json` was piped through it. Apart from the ledger the output
was identical to the input, the ledger gained 5 hook entries, and a second run was
byte-identical.

Constraints carried over from `claude-settings-ledger`: a `modify_` script must be a pure
stdin→stdout function; `jq` is the only dependency; the `extra_settings='…'` line must stay
a single standalone line.

## Goals / Non-Goals

**Goals:**
- One ownership mechanism for every key chezmoi writes.
- No hand-maintained removal list.
- A net reduction in the modifier's size.

**Non-Goals:**
- Normalizing hook groups, for example matching by command instead of by full value. See
  D3.

## Decisions

### D1. Hooks are ordinary extra settings
The hook stage (`managed_hooks`, the command-name upsert, `retired_commands`) is deleted
outright. Each persona template adds a `"hooks" (dict …)` entry to its `$extra`, written in
the same Go `dict`/`list` style as the rest of the dict. The ledger stage's logic is not
modified; only how it serializes structured elements changes (D6).

*Alternative:* write the hooks in each template as a JSON string with `fromJson`. It's
shorter, but it mixes two notations in one dict, and a JSON string inside a Go template has
its own escaping pitfalls. Rejected.

*Alternative:* keep a shared hooks default inside the partial and let personas override it.
The user rejected this, in favor of self-contained persona files.

### D2. Migration keyed on the ledger having no hook entries
Legacy live files carry chezmoi's hook groups with no ledger record. If the ledger adopted
them as they are, two cases would break:
- a live group that differs from source (an older matcher) would stay forever as a
  "foreign" hook, next to the new one;
- a hook dropped from source before the machine migrates (`claude-tooling-guard`) would
  never be removed.

So, while `$prev` has no element whose `path[0] == "hooks"`, the pipeline first removes the
individual hooks whose `command` is on a frozen list of six legacy commands, and drops
groups left with an empty `hooks` array. Then the normal retract, apply, and rewrite steps
run.

Why this trigger:
- **It needs no extra state.** "The ledger has hook entries" is recorded in `settings.json`
  itself, which a stateless `modify_` script requires.
- **It stops acting on its own.** After the first apply the ledger records the source hooks,
  so the migration stops acting for that persona.
- **It works inside individual groups.** Removing inner hooks, not whole groups, keeps a
  foreign command that shares a group with a legacy one. The current hook stage would drop
  it. This is the same approach `claude-tooling-plugin` task 4.1 planned.

A frozen list, rather than one derived from `$extra.hooks`, means that hooks dropped from
source in the same apply are still removed. The list also never grows, unlike
`retired_commands`. It is deleted in a follow-up once every ai machine has applied (see
Migration Plan).

*Alternative:* use a ledger version marker (for example `_chezmoiManagedVersion`). That's
more general, but it adds a second key and version logic to cover one case. Rejected.

*Alternative:* do no migration and clean each machine by hand. That leaves the risk of a
duplicate write guard, or a stale one, on any machine nobody checks. Rejected, because the
guard is a security control.

**Accepted edge case:** a persona whose source declares no hooks keeps the migration active
indefinitely. It removes any legacy command a user adds by hand to that persona. All six
commands are chezmoi's own tools, so no real configuration adds them on purpose.

### D3. Managed hook groups are matched by full value
A group is "the same" only if its whole value is equal. The consequences are pinned by
fixtures, not worked around:
- a matcher edit is a remove plus an add (wanted);
- a group rewritten outside chezmoi (merged, or a `timeout` field added) no longer counts as
  chezmoi's. The source group is re-added next to it, and the rewritten group is left alone,
  because it's no longer recognized as chezmoi's.

Matching by command, as the current hook stage does, would tolerate rewrites. But it needs
hook-specific code in the ledger, which is exactly what this change removes. And it would
silently take over a group the user deliberately edited. Rejected for now. If rewrites ever
show up in practice, the merged-group fixture will show the effect and a follow-up can
decide.

### D4. Rename the partial to `claude-settings-modifier`
Once the hook stage is gone, "hooks" in the name is misleading. The old name is removed, not
kept as an alias. All five `includeTemplate` callers (four personas plus the test harness)
are in this repo and change in the same commit.

### D5. Test harness changes
`tests/test-claude-settings-ledger.sh` currently strips `hooks` from the comparison unless
`expected.json` has a `hooks` key, because the old hook stage injected managed hooks into
every case. Without the hook stage, the output's hooks come only from input and `extra.json`,
so that strip becomes unnecessary and is removed: every case compares the full output.
Fixture 09's expectation drops the five hooks the stage used to inject.

### D6. Structured ledger elements are stored as JSON strings
Recording a hook group as `{path: ["hooks","PreToolUse"], elem: G}` puts a hook-shaped
object at `_chezmoiManaged[i].elem`, outside `hooks`. Claude Code's settings validation
flags that (2026-09-25, `~/.claude-personal`): "PreToolUse/PermissionRequest hooks are
declared outside "hooks" … nothing it sits in is applied until the entry is fixed or
removed." The real hooks were correctly placed; only the ledger copy tripped it.

So the ledger is written with structured elements (objects and arrays) as
`{path, elemJson: (elem | tojson)}`. Scalars and scalar elements (e.g. `permissions.allow`
strings) keep `{path, value}` / `{path, elem}`. On read, `elemJson` is decoded back to
`{path, elem}` before anything else, so retraction and the D2 trigger see one shape, and
comparison stays by full value (D3). An `elemJson` that doesn't parse is dropped, like
any other malformed entry. A raw object `elem` is still accepted on read, so ledgers
written before this decision convert on the next apply without retracting and re-adding
the groups, and foreign hooks keep their positions.

The harness asserts for every case that the output ledger holds no object or array
`elem`. Input fixtures 21–24 and 30 keep the raw form, covering the legacy read path.

*Alternative:* move the ledger to a sidecar file. That breaks the stateless `modify_`
constraint (stdin→stdout only). Rejected.

*Alternative:* encode every element, scalars included. Uniform, but it turns readable
`permissions.allow` entries into escaped strings for no benefit. Rejected.

*Alternative:* store a hash of the group. Compact, but retraction needs the value itself to
remove it from the live array. Rejected.

## Risks / Trade-offs

- [A migration bug deletes the write-guard hook, and tooling writes go unguarded] → The
  migration fixture asserts that `claude-tooling-write-guard` is present after migration.
  Rollout task 4.1 compares each persona's output against its live file before applying. The
  expected difference is ledger entries only (plus `claude-tooling-guard`, on machines that
  still have it).
- [The five hook groups are copied four times and drift apart] → That's the accepted cost of
  self-contained persona files. A missed edit shows up as a persona behaving differently,
  and a grep across `home/dot_claude*/modify_settings.json.tmpl` finds it.
- [Claude Code rewrites a managed group, and the command runs twice] → D3; documented by a
  fixture; low likelihood, since the `/hooks` UI adds groups rather than merging them.
- [Hand-edited legacy command on a persona with no source hooks] → D2's accepted edge case.
- [`claude-tooling-plugin` plans against the old modifier structure] → Recorded in
  proposal.md (Impact). Not edited here.

## Migration Plan

1. Land the change. On the first apply, each persona's modifier sees no hook entries in its
   ledger, removes the legacy hooks, re-applies them from source, and records them. On this
   machine the net effect is new ledger entries only (as the prototype showed).
2. Other ai machines migrate on their next `chezmoi apply`, with nothing to do by hand.
3. Follow-up: open a `bd` issue to delete the migration block and its fixtures once every ai
   machine has applied.

**Rollback:** a plain revert is **not** safe on its own. The old pipeline runs its hook
stage before retraction. On the first apply after a revert, the hook stage upserts the
managed groups, and then retraction removes them, because the ledger lists them as elements
source no longer declares. That would remove the write guard until a second apply. The
safe rollback is:
1. revert;
2. in each persona's live `settings.json`, delete the `_chezmoiManaged` entries whose
   `path[0] == "hooks"` (`jq '._chezmoiManaged |= map(select(.path[0] != "hooks"))'`);
3. apply.

The hook stage then upserts as before, and nothing is retracted. Step 2 matters for D6
too: the old pipeline treats `elemJson` entries as malformed and skips them, which is safe,
but deleting them keeps the ledger clean.
