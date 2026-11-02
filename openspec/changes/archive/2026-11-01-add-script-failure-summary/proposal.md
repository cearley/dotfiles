# Proposal

## Why

Since `non-fatal-brew-failures`, a failed brew step in darwin-23/28 no longer stops `chezmoi apply`; it prints a ⚠️ warning mid-output and retries next apply. Those warnings scroll past easily. The `.last-failure` stamp can't drive a summary on its own, because it is kept after later successes (it's the retry trigger).

## What Changes

- `record_script_failure` also writes `<name>.pending`.
- New `run_after_darwin-99-report-script-failures.sh.tmpl` (plain `run_after_`, runs every apply) lists pending failures at the end of the apply and deletes the `.pending` files. Silent when there are none.
- Plain `run_after_` is deliberate: failures are recorded after templates render, so a `run_onchange` trigger would only notice them one apply late.

## Impact

- **Affected specs**: `package-management` — new "End-of-Apply Script Failure Summary" requirement.
- **Affected files**: `home/scripts/shared-utils.sh`, new darwin-99 script, `home/.chezmoitemplates/CLAUDE.md`.
- If an apply aborts before darwin-99 runs (e.g. a hard `exit 1` elsewhere), pending failures are reported on the next completed apply.
