## Context

This change was originally scoped (as a locally-tracked task, before this repo used OpenSpec for it) against 10 `run_once_` scripts. Re-reading the current tree at proposal time found that 4 of the 10 have *already* been converted to `run_onchange_` with a 30-day `time-bucket` cadence in the time since: `35-install-nvm`, `10-install-rust`, `20-install-sdkman`, `21-install-uv`. Only 6 candidates remain to evaluate: `36-install-claude-code`, `80-setup-microsoft-defender`, `82-setup-global-protect`, `83-login-atuin`, `85-configure-system-defaults`, `05-install-rosetta`.

Each remaining candidate was read in full (not just its filename) to judge whether periodic re-run does anything useful, since converting a script that gains nothing from re-running just adds pointless re-execution overhead on every tagged machine.

## Goals / Non-Goals

**Goals:**
- Reach an explicit, justified decision for all 6 remaining candidates.
- Convert the ones where periodic re-run provides real self-healing value.
- Leave a one-line rationale on every script that stays `run_once_`, so the next person who looks at this doesn't have to re-derive the reasoning.

**Non-Goals:**
- Changing what any script installs/configures, or adding new update-check logic to scripts that don't already have it (e.g. we do not teach `36-install-claude-code` how to detect and apply a Claude Code update — that's a separate, larger feature).
- Re-litigating the 4 already-converted scripts' cadence (30 days) — out of scope, just confirmed as already done.

## Decisions

### Convert: `83-login-atuin` → `run_onchange_`, 7-day cadence
This script already contains real re-verification logic that only ever runs once under `run_once_`: it checks the session file, runs `atuin doctor` to confirm cloud sync is still active, compares the local key against KeePassXC and re-keys on mismatch, and re-logs-in if the session is invalid. Under `run_once_`, none of that self-healing logic can ever fire again after the first successful run — if the session expires, the keychain is reset, or the machine loses cloud login, this script goes silent forever. This is exactly the "credential/token refresh" case the original task called out. 7 days matches the proposal's suggested cadence for credential-adjacent checks and is cheap (the script's own logic already no-ops quickly when the existing session is still valid).

### Convert: `85-configure-system-defaults` → `run_onchange_`, 90-day cadence
Sets Terminal/iTerm2 font and several iTerm2 preference keys via `defaults write` / `PlistBuddy`. These are exactly "config convergence" — macOS major-version upgrades are a known way for `defaults` keys to get reset or for `.plist` structure to shift, and the script is already idempotent (each `defaults write` is a no-op if the value already matches). 90 days (not 7 or 30) because: these settings don't drift on their own between OS upgrades, and unlike `atuin` this script produces a visible side effect on every run (a "restart iTerm2 to apply font changes" warning if iTerm2 is currently open) that would be irritating if it fired monthly for no reason.

### Keep as `run_once_`: `36-install-claude-code`
The script's own logic is `command -v claude && exit 0 (skip)` — it never attempts an upgrade path, only a fresh install. Converting to `run_onchange_` would not cause Claude Code to actually update on re-run (it would just re-print the skip message every N days), so periodic re-execution buys nothing without also adding real update-check logic, which is explicitly out of scope for this change (see Non-Goals). Claude Code already has its own update mechanism (`claude update` / self-update); this script's job ends at "get it installed once."

### Keep as `run_once_`: `80-setup-microsoft-defender`, `82-setup-global-protect`
Both are interactive, browser-driven manual installers gated by `is_app_installed` and ending in `wait_for_app_installation` + `prompt_ready` ("press any key to continue"). Presence of these apps doesn't spontaneously drift once installed — a `run_onchange_` conversion would only ever matter in the rare case a user manually uninstalled a work-required security/VPN client, which is a deliberate action the user would already know about, not silent drift this automation needs to catch. Not worth trading away the option of "one clean prompt at first bootstrap, never again" for a periodic recheck that will skip 99.9% of the time anyway.

### Keep as `run_once_`: `05-install-rosetta`
Rosetta 2 is an OS-level translation layer; once installed on Apple Silicon it does not get silently removed or go stale. Purely a one-shot bootstrap step, same category the original task explicitly named as the reason to keep something `run_once_`.

### Already converted, no action needed: `35-install-nvm`, `10-install-rust`, `20-install-sdkman`, `21-install-uv`
All four already use `run_onchange_` with a 30-day `time-bucket` trigger comment (confirmed by reading each file). Tasks below include a verification step only, not a conversion.

## Risks / Trade-offs

- **[Risk]** Converting `83-login-atuin` and `85-configure-system-defaults` means their file names change (`run_once_` → `run_onchange_`), which switches chezmoi's tracking from `scriptState` (content-hash keyed) to `entryState` (target-name keyed) for those two scripts. → **Mitigation**: this is the same rename mechanism already used successfully for the 4 prior conversions and for the position-33/36/38 renumbering earlier this session — chezmoi handles it cleanly, the only visible effect is each converted script re-runs once on the next `chezmoi apply` (expected and safe, both scripts are already idempotent).
- **[Risk]** `85-configure-system-defaults`'s iTerm2 font-restart warning firing unexpectedly every 90 days. → **Mitigation**: 90 days (not a shorter cadence) specifically to minimize this; the warning is non-blocking (`print_message "warning"`, not a prompt) so it doesn't halt `chezmoi apply`.
- **[Risk]** Someone re-adds `run_once_` cargo-culting for a new script without reading this design. → **Mitigation**: the `script-execution` spec delta below turns the decision criteria into a documented requirement, not just a comment in one change's design doc.

## Migration Plan
1. Rename `run_once_after_darwin-83-login-atuin.sh.tmpl` → `run_onchange_after_darwin-83-login-atuin.sh.tmpl`, add the 7-day trigger comment.
2. Rename `run_once_after_darwin-85-configure-system-defaults.sh.tmpl` → `run_onchange_after_darwin-85-configure-system-defaults.sh.tmpl`, add the 90-day trigger comment.
3. Add a one-line rationale comment to the 4 scripts staying `run_once_` (36, 80, 82, 05).
4. Verify `chezmoi apply --dry-run` (or `tests/run-template` on each touched file) succeeds.
5. No rollback complexity beyond `git revert` — these are template-only changes with no data migration.

## Open Questions
None — every candidate has a decision above.
