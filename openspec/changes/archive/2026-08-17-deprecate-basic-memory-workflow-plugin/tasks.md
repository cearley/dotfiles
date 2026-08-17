## 1. Enhance `check-drift.sh` mechanics

- [x] 1.1 Replace the bare `PROJECT=$(basename "$PROJECT_ROOT")` derivation with the override-aware resolution: check `<project-root>/.claude/basic-memory-project.txt` first (non-blank content wins), else fall through to `basename` — mirroring `resolve-project-name.sh`'s blank/whitespace-only-treated-as-absent behavior, ported into `check-drift.sh` itself rather than a separate runtime script
- [x] 1.2 Add an `update` subcommand: reuse `check`'s existing per-piece marker comparison, and for every piece currently reporting version `DRIFT` (not `NAME-MISMATCH`), call its existing `apply_templated_file`/equivalent unconditionally — no per-piece confirmation. Print a summary of what was updated and what was skipped (and why, for any `NAME-MISMATCH` pieces)
- [x] 1.3 Confirm `NAME-MISMATCH` handling is untouched — still reported by `check`, still requires an explicit `apply <piece>` invocation, never touched by `update`. **Refined during implementation**: `piece_status()` now checks name-match *before* version, so a piece that is simultaneously version-stale and identity-mismatched reports `NAME-MISMATCH`, not `DRIFT` — the original v8 logic would have let `update` silently re-identity such a file while "just" fixing its version. Documented in the v9 CHANGELOG entry as a closed latent bug, and applied the same fix to the hook-config piece (which had no `NAME-MISMATCH` category at all in v8)
- [x] 1.4 Confirm registration (`basic-memory project add`) needs no code change — it already runs once, unconditionally, inside `cmd_check`, which is the correct apply-time-only shape this change wants (see task 2.3 for *why* no porting is needed here)
- [x] 1.5 Bump `SMW_VERSION` to `9`

## 2. Port forward plugin-era behavioral fixes into the templates

*The v8 templates predate the plugin era and are missing real behavior added since — porting this forward is required by design.md's "leave runtime behavior identical from a user's perspective" goal, since "identical" means identical to current (plugin) behavior, not to v8. See proposal.md's What Changes for the commit list.*

- [x] 2.1 Port `28dc2cc` (session-log auto-rollover past 300 lines) into `assets/save-session-skill.md.template` — currently absent from the v8 template entirely; re-template any `__PROJECT__`-dependent text the ported section introduces
- [x] 2.2 Port `b0bf2c1` (sync-memory cursor data-loss and mid-session registration-gap fixes) into `scripts/sync-memory.py.template`, `assets/save-session-skill.md.template`, and `assets/sync-memory-skill.md.template` — ported directly from the plugin's current (post-fix) file contents rather than replaying the incremental diff, re-templating `PROJECT_NAME`/`__PROJECT__` and dropping the runtime `resolve_project_name()` subprocess call the plugin version needed (unnecessary here since `PROJECT_NAME` is already baked in for both default and `--standalone` modes)
- [x] 2.3 Confirm `531d07f` (bootstrap-on-first-`SessionStart`) needs no porting: per its own commit message, this fixed a bug the *plugin conversion itself introduced* by dropping the old skill's one-time bootstrap step — v8's existing `cmd_check`-time registration already has this covered correctly, nothing to port
- [x] 2.4 Confirm `5a1755a` (routing `resolve-project-name.sh` through `bash` to skip an auto-mode classifier) needs no porting — that script is retired entirely in this design, the fix doesn't apply

## 3. `CHANGELOG.md`

- [x] 3.1 Add a `v9` entry documenting: override-file-aware `$PROJECT` resolution at apply-time, the new `update` subcommand and its unconditional-overwrite-for-version-drift-only scope, registration confirmed apply-time-only (no behavior change from v8), and the ported-forward session-log-rollover/cursor-data-loss fixes — matching the existing v8 entry's style

## 4. Verify against this repo (dry run before touching any real state)

- [x] 4.1 Run `check-drift.sh check` against this chezmoi repo — confirmed it correctly reports `CREATED` for all pieces. **Detour required**: the restored skill had never actually been deployed via chezmoi to `~/.claude/skills/setup-memory-workflow/` (running from the raw `home/` source tree fails on `sync-memory.py.template` since chezmoi hasn't stripped the `executable_` prefix yet); `chezmoi apply` on that target also hit 14 stale `entryState` records from a prior deploy/delete cycle (blocking on a TTY confirmation prompt) — resolved with `chezmoi apply --force` on that one target, safe here since the destination was confirmed empty, not actually conflicting. Re-ran cleanly from the properly deployed path afterward; spot-checked the generated `save-session/SKILL.md` (project name baked in, rollover section present) and `sync-memory.py` (`PROJECT_NAME = "chezmoi"`, compiles, `--dry-run` finds real unsynced logs)
- [x] 4.2 Ran `check-drift.sh update`/`apply` in a scratch git fixture: version-only drift auto-repaired silently by `update`; a piece made *simultaneously* version-stale and identity-mismatched correctly reported `NAME-MISMATCH` (not `DRIFT`) and was left untouched by `update` — confirms the 1.3 precedence fix works for both a templated piece and the hook-config piece (which had no identity-awareness at all in v8); explicit `apply <piece>` correctly repairs a confirmed `NAME-MISMATCH`
- [x] 4.3 Verified override-file resolution in the same fixture: a clean override value takes precedence over the directory basename; a whitespace-only override and a fully empty override both correctly fall through to `basename`. Confirmed (not a bug) that a non-blank override with incidental leading/trailing spaces is preserved verbatim, not trimmed — inherited as-is from `resolve-project-name.sh`'s original behavior, which the code comment already documents. Fixture removed after testing

## 5. Migrate `chezmoi` (this repo) off the plugin

*Plugin state is per-persona and not shared; two separate install records exist for this repo (`.claude-personal` local, `.claude-work` local/stale) even though the skill files themselves are shared via the `skills/` symlink.*

- [x] 5.1 Ran `check-drift.sh check` for real against this repo, creating `.claude/skills/save-session/SKILL.md`, `.claude/skills/sync-memory/{SKILL.md,scripts/sync-memory.py}`, and the `SessionStart` hook entry in `.claude/settings.local.json`
- [x] 5.2 Verified: re-running `check` reports `UP-TO-DATE` across every piece; `sync-memory.py --dry-run` finds real unsynced `.specstory` logs (23 found); project resolves to `chezmoi` throughout
- [x] 5.3 Uninstalled via `CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope local -y`; confirmed `.claude/settings.local.json`'s `enabledPlugins` is now `{}`
- [x] 5.4 Uninstalled via `CLAUDE_CONFIG_DIR="$HOME/.claude-work" claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope local -y` — confirmed via `claude plugin list --json` under that persona: no `basic-memory-workflow` entries remain (this was the stale install found during discovery)

## 6. Migrate `WES.ViewPoint.CommonMicro.API`

- [x] 6.1 Ran `check-drift.sh check` against `/Users/craig/work/Willdan-WLE/ViewPointV2/WES.ViewPoint.CommonMicro.API` — all four pieces `CREATED` correctly, project registered as `WES.ViewPoint.CommonMicro.API`
- [x] 6.2 Verified: re-`check` reports `UP-TO-DATE` across the board; `sync-memory.py --dry-run` finds real unsynced logs (526 found)
- [x] 6.3 Uninstalled via `CLAUDE_CONFIG_DIR="$HOME/.claude-bedrock" claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope local -y`, run **from within that project's directory** — `--scope local` resolves against the current working directory, not a global lookup; a first attempt run from the chezmoi repo's directory failed with "not installed in local scope" for exactly this reason. Confirmed `enabledPlugins` no longer contains the entry

## 7. Migrate `WES.ViewPoint.ExternalIntegration.FulcrumAppAPI`

*This install is `project` scope — its `enabledPlugins` entry lives in that repo's committed `.claude/settings.json`, not a gitignored local file. Treat this as a reviewable change in that repo, not a silent local edit.*

- [x] 7.1 Ran `check-drift.sh check` against `/Users/craig/work/WES.ViewPoint.ExternalIntegration.FulcrumAppAPI` — all four pieces `CREATED`, project registered
- [x] 7.2 Verified: re-`check` reports `UP-TO-DATE`; `sync-memory.py --dry-run` finds real unsynced logs (59 found)
- [x] 7.3 Uninstalled via `CLAUDE_CONFIG_DIR="$HOME/.claude-bedrock" claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope project -y`, from within that repo's directory. **Revises the design's team-coordination caution**: `git status`/`git log -- .claude` there show `.claude/` has never actually been committed in that repo (untracked, not gitignored either) despite using `project`-scope naming — so this was never actually shared with any teammate via git, and no reviewable-diff/communication step is needed after all. Confirmed `.claude/settings.json`'s `enabledPlugins` is now `{}`

## 8. Retire the global `user`-scope enablement

*No enumerable list of affected projects exists for this one — it covered every project opened under `.claude-personal`, not just ones with their own install record.*

- [x] 8.1 Uninstalled via `CLAUDE_CONFIG_DIR="$HOME/.claude-personal" claude plugin uninstall basic-memory-workflow@chezmoi-personal --scope user -y`; confirmed the entry is gone from `~/.claude-personal/settings.json`'s `enabledPlugins`
- [x] 8.2 Noted, not blocked on — sections 5-7 covered every real install this discovery pass found under every persona; any other project silently losing the reminder now needs its own deliberate `check-drift.sh check` run via the enhanced skill, which is the correct end state

## 9. Retire the plugin

*Only once every target in sections 5-8 is confirmed working — mirrors the original conversion's "delete last, gated on verification" discipline, in reverse.*

- [x] 9.1 Removed the `basic-memory-workflow` entry from `.claude-plugin/marketplace.json` (validated JSON, 9 plugins remain — every other entry untouched)
- [x] 9.2 Deleted `plugins/basic-memory-workflow/` in full
- [x] 9.3 Grepped the repo for remaining references: only the archived changes' own historical record (left untouched, per this repo's convention) and `openspec/specs/claude-plugin-marketplace/spec.md` (still pending — that's task 10.3) reference it; no live code does

## 10. Update specs and archive

- [x] 10.1 Authored proper delta specs (not direct main-tree edits — an initial direct-edit attempt had to be `git checkout --`-reverted once it became clear `openspec archive` needs to compute the merge itself, per its own "refuses to drop scenarios it can't match" safety check) at `specs/setup-memory-workflow/spec.md`: RENAMED+MODIFIED for the two requirements that changed shape, ADDED for the two new `update`/`NAME-MISMATCH` requirements, REMOVED for the migration-script requirement. Archive's scenario-matching check caught four retired plugin-only scenarios my first delta draft had silently dropped ("Plugin enabled mid-session, SessionStart never fires", "One canonical copy serves every enabled project", "Updating the plugin updates every consumer", "Plugin enabled in one project only") — fixed by preserving each original scenario title while repurposing its body to state plainly that the plugin-era guarantee is inverted/no-longer-applicable, same technique used by the original plugin-conversion archive
- [x] 10.2 Delta at `specs/sync-memory/spec.md`: RENAMED+MODIFIED the identity-resolution requirement back to install/apply-time baking via `check-drift.sh`'s `render()`, including the un-rendered-template guard; also fixed a stale cross-reference inside the untouched "Filesystem project root stays resolved at runtime" requirement's own "Vault directory defaults" scenario, which still said `PROJECT_NAME` was "runtime-resolved, not baked in at install time" — the opposite of v9's actual behavior
- [x] 10.3 Delta at `specs/claude-plugin-marketplace/spec.md`: MODIFIED the one requirement whose example scenario named `basic-memory-workflow`, swapped to `aws-local-dev` — no requirement text changed, capability still serves every other plugin
- [x] 10.4 `openspec validate deprecate-basic-memory-workflow-plugin --strict` — passed after the scenario-preservation fixes above
- [x] 10.5 `openspec archive deprecate-basic-memory-workflow-plugin --yes` — succeeded: `claude-plugin-marketplace` ~1 modified, `setup-memory-workflow` +2/~4/-1/→2, `sync-memory` ~2/→1. Archived as `2026-08-17-deprecate-basic-memory-workflow-plugin`. **Post-archive fix**: the `## Purpose` line of `setup-memory-workflow/spec.md` was still the old plugin-era text — Purpose isn't part of the delta-matching mechanism (confirmed by checking how the original plugin-conversion change handled this: a separate manual task, not an archive-applied delta) — updated directly after archiving to describe the copy-based mechanism
