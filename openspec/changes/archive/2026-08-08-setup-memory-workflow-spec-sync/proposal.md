## Why

The `basic-memory-workflow` plugin's `setup-memory-workflow` capability spec still describes basic-memory project registration as something `save-session` performs on every invocation. That description went stale during this session's bug fix (commit `531d07f`): a brand-new project had no bootstrap at session start, so the `SessionStart` hook's reminder told Claude to call `search_notes`/`recent_activity` against a basic-memory project that had never been registered — which fell back to cloud-mode MCP routing and failed on missing credentials instead of erroring cleanly. The fix moved registration into the `SessionStart` hook itself (the one guaranteed-to-run-first place in a session), via a new `ensure-project-registered.sh` wrapper script, and removed the now-redundant registration call from `save-session`. The spec needs to catch up to the already-shipped implementation.

## What Changes

- Rewrite the "basic-memory project registration" requirement to describe registration happening once, automatically, in the `SessionStart` hook — before any skill or MCP tool call in the session — rather than idempotently on every `save-session` invocation.
- Clarify the "Runtime project identity resolution via shared script" requirement to distinguish pure identity resolution (`resolve-project-name.sh`, still used directly by `save-session` and `sync-memory`) from resolution-plus-registration (`ensure-project-registered.sh`, used only by the `SessionStart` hook).
- No code changes — `plugins/basic-memory-workflow/` already reflects this behavior as of commit `531d07f`. This change brings `openspec/specs/setup-memory-workflow/spec.md` in line with it.

## Capabilities

### New Capabilities

(none)

### Modified Capabilities

- `setup-memory-workflow`: registration timing and mechanism (SessionStart-hook-driven via `ensure-project-registered.sh`, instead of per-`save-session`-invocation) and the identity-resolution requirement's description of what the hook calls.

## Impact

- `openspec/specs/setup-memory-workflow/spec.md` only. No changes to `plugins/basic-memory-workflow/` (already shipped) or to the `claude-plugin-marketplace` capability (unaffected — marketplace registration and per-project opt-in are untouched by this fix).
- No tags, scripts, machine configs, or secrets affected — this plugin lives outside `home/` and is not chezmoi-templated or deployed via `chezmoi apply`.
