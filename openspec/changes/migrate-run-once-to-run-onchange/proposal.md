## Why

Ten `run_once_` scripts in `home/.chezmoiscripts/` currently run exactly one time per machine and never re-check their own state, even though several of them install things that go stale (Claude Code updates, security-tool posture, system defaults that get overridden) or depend on secrets/config that can change (nvm, Atuin login). The `home/.chezmoitemplates/time-bucket` partial already exists and gives `run_onchange_` scripts a rolling re-run cadence (N days) without needing an external state file, but it has only been applied to a couple of scripts opportunistically. This change makes a deliberate, documented pass over every `run_once_` script to decide keep-vs-convert, instead of leaving it as an ad hoc, one-off decision each time someone touches a script.

## What Changes

- Evaluate each of the 10 candidate `run_once_` scripts and record an explicit keep/convert decision:
  - `run_once_after_darwin-35-install-nvm.sh.tmpl`
  - `run_once_after_darwin-36-install-claude-code.sh.tmpl`
  - `run_once_after_darwin-80-setup-microsoft-defender.sh.tmpl`
  - `run_once_after_darwin-82-setup-global-protect.sh.tmpl`
  - `run_once_after_darwin-83-login-atuin.sh.tmpl`
  - `run_once_after_darwin-85-configure-system-defaults.sh.tmpl`
  - `run_once_before_darwin-05-install-rosetta.sh.tmpl`
  - `run_once_before_darwin-10-install-rust.sh.tmpl`
  - `run_once_before_darwin-20-install-sdkman.sh.tmpl`
  - `run_once_before_darwin-21-install-uv.sh.tmpl`
- Rename each converted script's file from `run_once_` to `run_onchange_` (chezmoi tracks this rename cleanly — `run_once_` scripts are keyed by content hash in `scriptState`, `run_onchange_` scripts by target name in `entryState`) and add a `# rerun trigger ({N}d): {{ includeTemplate "time-bucket" (dict "days" N) }}` comment with a cadence justified per-script (e.g. 7d for credential/token-adjacent checks, 30d for update checks, 90d for slow-changing config).
- Scripts that stay `run_once_` get a one-line rationale comment explaining why (genuinely one-shot install steps with no meaningful re-check).
- Document the resulting convention in `openspec/specs/script-execution/spec.md` so future scripts default to the right choice instead of defaulting to `run_once_` out of habit.

Non-goals:
- No change to what any script actually *installs* or *configures* — only whether/how often it re-runs.
- No change to the `time-bucket` partial itself.
- No new tags, no new script positions — this is purely a `run_once_`→`run_onchange_` naming/cadence decision within existing positions.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `script-execution`: add a requirement documenting when a script should use `run_onchange_` + `time-bucket` periodic re-run cadence versus `run_once_`, and record the convention that scripts remaining `run_once_` carry a one-line rationale comment.

## Impact

- Affected files: the 10 candidate scripts listed above (each is either renamed with a new trigger comment, or left alone with an added rationale comment).
- Tags affected: `ai` (35, 36), `work` (82), `dev` (10, 20, 21) — conversions must preserve each script's existing tag gating; this change does not alter gating logic.
- No security implications beyond what already exists per script — cadence conversion does not change which secrets a script touches, only how often it re-checks its own state.
- On next `chezmoi apply` after this lands, any converted script will re-run once immediately (rename triggers a state-tracking switch from `scriptState` to `entryState`), which is expected and safe since these are all idempotent installers per existing convention.
