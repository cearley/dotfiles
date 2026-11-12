# setup-memory-workflow: migrations framework

**Date:** 2026-08-06
**Status:** Implemented

## Context

`setup-memory-workflow` (`home/dot_claude/skills/setup-memory-workflow/`) bootstraps and
self-heals the basic-memory session workflow in any project via
`scripts/executable_check-drift.sh`. Drift repair for its tracked pieces falls into two
categories:

- **Whole-file template pieces** (`save-session-skill`, `sync-memory-skill`,
  `sync-memory-script`) — repair is always "render the current template, overwrite the
  installed file." No transformation logic needed; `apply_templated_file()` handles all
  of these uniformly today and continues to.
- **Structural JSON pieces** (`hook-config`, and potentially `mcp-config` in the future)
  — the *current* canonical shape (does `.hooks.SessionStart` match the canonical
  command?) is managed directly in `check-drift.sh`, the same way it always has been.
  Separately, a change can leave behind a **legacy artifact** from a prior version of
  this skill that needs cleaning up — something check/apply's canonical-shape comparison
  has no natural way to express, since "compare to canonical" doesn't cover "and also
  remove this other thing that used to exist under a different name."

This session's work moving the basic-memory reminder hook from `UserPromptSubmit` to
`SessionStart` (to fix the reminder losing context-attention to skill invocation text on
the first prompt) hit exactly this second case: after the rename, any project that had
previously run this skill was left with a stale, orphaned `basic-memory` hook still
sitting under `UserPromptSubmit`, which nothing would ever notice or clean up on its own.

The first draft of this design conflated the two concerns — it had a `migrate_hook_config`
function that both (a) drove whatever hook state existed to the current canonical
`SessionStart` shape *and* (b) cleaned up the legacy `UserPromptSubmit` entry, and it had
`check-drift.sh` reaching into `.hooks.UserPromptSubmit` by name to decide whether to
report drift. That's wrong: it teaches the generic orchestrator (`check-drift.sh`) about a
specific legacy shape, which means every future structural change would need to teach it
about one more. The design below fixes that by keeping the two concerns fully separate.

## Design

### File layout

```
home/dot_claude/skills/setup-memory-workflow/
  CHANGELOG.md                     ← human-readable version history
  scripts/
    executable_check-drift.sh      ← sources migrations.sh, calls it unconditionally
    migrations.sh                  ← sourced library, never run standalone
    sync-memory.py.template
```

`migrations.sh` is sourced by `check-drift.sh`, not executed as its own entry point. It
carries no shebang, no chezmoi `executable_` filename prefix, and is not marked
executable — all three would misleadingly suggest it can be invoked directly.

### Division of responsibility

- **`check-drift.sh`** (directly, or via `check_templated_file()`/`apply_templated_file()`
  for whole-file pieces) owns comparing on-disk state to the *current* canonical shape and
  reporting `CREATED`/`UP-TO-DATE`/`DRIFT`/`NAME-MISMATCH`. It has **zero knowledge of any
  prior version's shape** — not `UserPromptSubmit`, not any future renamed key, nothing.
  It only ever asks "does this match canonical today?"
- **`migrations.sh`** owns cleaning up this skill's own artifacts left behind by prior
  versions. It has **zero knowledge of the current canonical shape** — a migration
  function never creates or manages current content, it only ever removes or transforms
  something that used to exist. The two files' knowledge never overlaps.

### `migrations.sh` contract

One function per piece that has legacy artifacts needing cleanup, named `migrate_<piece>`:

- Takes no arguments. Operates on the relevant file under `$PROJECT_ROOT`.
- **Must be idempotent**: safe to call unconditionally, every time, forever. No-ops
  silently (no output, no write) once the legacy state it targets no longer exists.
- Detects legacy state by an unambiguous marker this skill itself controls — for the hook,
  a literal `"basic-memory"` substring inside a command string. This makes the function
  inherently version-count-agnostic: it doesn't matter how many versions an install
  skipped, because it isn't looking for "the shape from version N," it's looking for "does
  this skill's own old artifact still exist," which is a single yes/no question regardless
  of how long ago it was created.
- Is called **unconditionally, once**, near the top of `check-drift.sh` — on every
  invocation, both `check` and `apply`, regardless of which piece (if any) is being
  checked or applied. Not gated behind a specific `apply <piece>` confirmation, because it
  only ever touches artifacts this skill created itself (matched by the same unambiguous
  marker), never anything a user might have added by hand.

A header comment in `migrations.sh` states this contract explicitly.

### `CHANGELOG.md` format

One entry per `SMW_VERSION` bump, newest first, prose style. Content-only version bumps
don't need a `migrations.sh` function; bumps that leave a legacy artifact behind name the
function that cleans it up:

```markdown
# setup-memory-workflow changelog

## v8 (2026-08-06)
Hook trigger moved from `UserPromptSubmit` to `SessionStart`. ... The new `SessionStart`
hook itself is managed as ordinary canonical-shape content in `check-drift.sh`. Separately,
`migrate_hook_config` in `scripts/migrations.sh` cleans up any leftover `basic-memory` hook
still sitting under `UserPromptSubmit` from a pre-v8 install — unconditional, silent, no
confirmation needed.
```

The changelog starts fresh at v8; earlier versions (v1–v7) predate this file and are not
backfilled — reconstructing accurate detail for all of them isn't reliably possible, and
fabricating detail would be worse than omitting it.

### `check-drift.sh` integration

- Near the top, after `render()` is defined: `source "$SKILL_DIR/scripts/migrations.sh"`,
  immediately followed by an unconditional top-level call to `migrate_hook_config`.
- `cmd_check`'s `== SessionStart hook ==` section and `cmd_apply`'s `hook-config)` case are
  **unchanged from how ordinary canonical-shape pieces already worked** — plain
  version-marker comparison against `.hooks.SessionStart` only, no mention of
  `UserPromptSubmit` anywhere in either. By the time either runs, the unconditional
  migration call has already removed any legacy hook, so there's nothing left to conflict
  with or duplicate.
- The `SMW_VERSION` bump-comment at the top of the file notes: "When a change also leaves
  behind a legacy artifact from a prior version (not just new canonical content), add a
  `migrate_<piece>` cleanup function to `migrations.sh` and a `CHANGELOG.md` entry."

### Verification

Tested via isolated scratch projects, sourcing the real `migrations.sh` and running the
real `check-drift.sh` (not reimplemented copies):

- Migration cleanup alone: a solo legacy hook, a mixed `UserPromptSubmit` array (legacy
  entry alongside an unrelated one, confirming the unrelated one survives), and an
  already-clean install (confirming silent no-op).
- The full realistic pipeline (migration cleanup, then the plain hook-check section) across
  five scenarios: legacy-only, mixed, nothing present, `SessionStart` present but stale,
  and already current — matching a real installed project's settings file byte-for-byte.
- The real `check-drift.sh apply hook-config` end-to-end against a scratch DRIFT scenario,
  plus a second run confirming idempotency.
- `bash -n` on both files for syntax.

**Known gap, not fixed by this design:** `apply hook-config`'s `map()`-based update assumes
`.hooks.SessionStart` already contains at least one entry — true whenever `apply` is
reached via the intended workflow (`check` always creates a missing hook directly, so
`apply` only runs after DRIFT is reported, which means something already exists). If
`apply hook-config` is invoked directly without `check` ever having run, the `jq` call
errors on `null`, the write is silently skipped, and the script still prints a false
`"APPLIED"` line. This is unchanged from the original pre-v8 code (same `map()`-only
shape), not a regression introduced here — left as-is rather than reintroducing
null-handling into `apply`'s canonical-shape logic, which would blur the same
responsibility line this design exists to keep clean.

## Out of scope

- Chained/sequential migration replay (à la traditional DB migrations). Rejected in favor
  of standalone idempotent transforms keyed on an unambiguous marker — no bookkeeping
  ledger of "which migrations ran," no ordering to get wrong.
- Formalizing the whole-file template pieces (`save-session-skill`, `sync-memory-skill`,
  `sync-memory-script`) as migrations. They leave no legacy artifact behind —
  `apply_templated_file()`'s overwrite-with-current-template behavior is sufficient and
  unchanged by this design.
- A structured/parseable changelog format that drives execution. The changelog is
  documentation for humans; `migrations.sh` is the sole executable source of truth.
- `migrate_<piece>` functions ever creating or managing current canonical content. That
  line is load-bearing for this design and intentionally not crossed, even when it would
  be convenient (see Context above for what went wrong the first time it was crossed).

`openspec/specs/setup-memory-workflow/spec.md` was updated in the same session to match
this final design (Purpose line, hook-installation requirement, and a new "Legacy
artifacts are cleaned up by unconditional migrations" requirement), validated via
`openspec validate --strict`.
