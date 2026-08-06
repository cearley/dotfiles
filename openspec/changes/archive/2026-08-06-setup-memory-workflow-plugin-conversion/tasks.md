## 1. Plugin scaffold

- [x] 1.1 Create `.claude-plugin/marketplace.json` at the chezmoi source root, listing the `basic-memory-workflow` plugin by relative path (`./plugins/basic-memory-workflow`)
- [x] 1.2 Create `plugins/basic-memory-workflow/.claude-plugin/plugin.json` — omit the `version` field deliberately (design.md decision: keeps every commit auto-propagating to consumers, no marker to bump)
- [x] 1.3 Port `assets/save-session-skill.md.template` into `plugins/basic-memory-workflow/skills/save-session/SKILL.md`, stripping `__PROJECT__`/`__SMW_VERSION__` placeholders — one canonical file, no rendering
- [x] 1.4 Port `assets/sync-memory-skill.md.template` into `plugins/basic-memory-workflow/skills/sync-memory/SKILL.md`, same de-templating; keep `disable-model-invocation: true`
- [x] 1.5 Port `scripts/sync-memory.py.template` into `plugins/basic-memory-workflow/scripts/sync-memory.py`, strip placeholders, mark executable
- [x] 1.6 Write `plugins/basic-memory-workflow/scripts/resolve-project-name.sh`: `git rev-parse --show-toplevel` + `basename`, with the `.claude/basic-memory-project.txt` override read first (blank/whitespace-only treated as absent), exits non-zero outside a git repo
- [x] 1.7 Update `sync-memory.py` to call `resolve-project-name.sh` as a subprocess for `PROJECT_NAME` instead of reading a baked-in value; update the vault-dir default accordingly
- [x] 1.8 Update `save-session/SKILL.md`'s first step to: call `resolve-project-name.sh` directly, run `which basic-memory` (stop with install instructions if missing), then idempotently run `basic-memory project add` — replacing the old one-time-install-step versions of these checks

## 2. SessionStart hook

- [x] 2.1 Write `plugins/basic-memory-workflow/scripts/session-start-reminder.sh`: resolve project name via `resolve-project-name.sh`, print the reminder message with it interpolated; silent no-op (exit 0, no output) if `resolve-project-name.sh` fails
- [x] 2.2 Write `plugins/basic-memory-workflow/hooks/hooks.json` declaring the `SessionStart` hook, command `"${CLAUDE_PLUGIN_ROOT}/scripts/session-start-reminder.sh"`. Real bug found via end-to-end testing (task 5.4): the file needs a top-level `"hooks"` key wrapping the event map (`{"hooks": {"SessionStart": [...]}}`), not the bare event map originally written — Claude Code's plugin UI reported "Failed to load hooks... expected record, received undefined". Fixed, validated with `claude plugin validate`, and force-refreshed into the cache via `claude plugin uninstall`/`install --scope local` (see design.md's operational note — `claude plugin update` doesn't detect content changes to an uncommitted local-directory plugin source)

## 3. Marketplace registration (chezmoi)

- [x] 3.1 Pick the next available position number for a new `run_onchange_after_darwin-NN-register-claude-plugin-marketplace.sh.tmpl` by running `ls home/.chezmoiscripts/` — used 44
- [x] 3.2 Implement the script by mirroring `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`'s own pattern. Caught and fixed a real bug during testing: `.chezmoi.sourceDir` resolves to `<repo-root>/home` (this repo's `.chezmoiroot` is `home`), not the repo root where the marketplace files actually live — fixed to `MARKETPLACE_PATH="$(dirname "{{ .chezmoi.sourceDir }}")"`. Does **not** touch `packages.yaml`'s `plugin_marketplaces`/`plugins` lists (see design.md)
- [x] 3.3 Tested the template with `tests/run-template`; rendered output passed `bash -n`
- [x] 3.4 Ran the rendered script directly against live Claude environments (safer than a full non-interactive `chezmoi apply`, which would trigger unrelated onchange scripts and hit this repo's known KeePassXC/TTY limitation). Registered successfully in `.claude-bedrock`, `.claude-personal`, `.claude-work`; confirmed via `claude plugins marketplace list` (`chezmoi-personal` → `Directory (/Users/craig/.local/share/chezmoi)`); re-run confirmed idempotent ("already on disk", no duplicate)

*(No `home/.chezmoidata/` or `home/.chezmoitemplates/` files are affected by this change — the plugin's own content lives outside `home/` entirely, per design.md.)*

## 4. Migration script

- [x] 4.1 Write `plugins/basic-memory-workflow/scripts/migrate-to-plugin.sh` with `check` and `apply` subcommands, mirroring `check-drift.sh`'s report-then-confirm shape
- [x] 4.2 `check` mode: detect old `.claude/skills/save-session/`, old `.claude/skills/sync-memory/`, a legacy `basic-memory` hook entry in `.claude/settings.local.json`, and stale `.git/info/exclude` lines for those paths — report findings, modify nothing
- [x] 4.3 `apply` mode: delete the old skill directories, remove the legacy hook entry via `jq`, remove the stale `.git/info/exclude` lines. For enabling the plugin: initially wrote `enabledPlugins` via raw `jq`, but testing against a real (non-fixture) project revealed this leaves nothing actually installed — switched to `claude plugin install "basic-memory-workflow@chezmoi-personal" --scope local`, which sets the same `enabledPlugins` key *and* materializes the plugin cache + `installed_plugins.json` (see design.md)
- [x] 4.4 Verified end-to-end against scratch fixtures in `/tmp` (not real projects, cleaned up after): `check` correctly detected all four legacy artifacts; `apply` removed/added them correctly (unrelated `.git/info/exclude` lines preserved) and — after the CLI fix — correctly installed and cached the plugin; re-running `check`/`apply` afterward was a clean no-op both times

**Post-hoc fix (found during section 7)**: `_has_legacy_hook` only checked the v8+ `SessionStart` shape. A real project (`viewpoint-report-automation`, still `setup-memory-workflow-version:2`) was on the older pre-v8 `UserPromptSubmit` shape and was silently missed by the first `apply` there. Fixed to detect and remove both shapes independently (see design.md); re-verified against a fixture reproducing the `UserPromptSubmit`-only case.

## 5. Smoke test against this repo (pre-migration)

- [x] 5.1 Enabled `basic-memory-workflow@chezmoi-personal` for this repo via `claude plugin install ... --scope local` (done for real, not a fixture — this is the actual chezmoi repo); confirmed `enabledPlugins` in `.claude/settings.local.json` and cache materialized at `~/.claude-personal/plugins/cache/chezmoi-personal/basic-memory-workflow/`
- [ ] 5.2 Verify `save-session` registers the project, writes the session log and status note identically to today's behavior — **deferred**: exercising this for real would write a real (not test) entry to the actual vault; the underlying logic (project resolution, idempotent registration) is already covered by component tests. Full verification happens naturally at this session's own end-of-session `/save-session`, which will run against the newly-enabled plugin copy
- [x] 5.3 Verified `sync-memory.py --dry-run` from the *cached* (materialized) copy at `~/.claude-personal/plugins/cache/.../scripts/sync-memory.py` — correctly found 8 unsynced logs, no mutation (dry-run doesn't write or advance the cursor)
- [x] 5.4 Verify the `SessionStart` hook fires with the correct project name interpolated — **cannot be tested within this same running session** (hooks fire at session start; this session began before the plugin was enabled). Needs a fresh Claude Code session opened in this repo to confirm
- [x] 5.5 Verified `resolve-project-name.sh` from the cached copy returns "chezmoi" correctly (override-file and blank-override-fallback behavior already verified against the source copy in section 1)

## 6. Migrate this repo off the old system

- [x] 6.1 Ran `migrate-to-plugin.sh check` against this chezmoi repo; confirmed both old skill dirs, the legacy hook, and stale `.git/info/exclude` entries present, plugin already enabled — reviewed with the user (including confirming none of it is git-tracked) before applying
- [x] 6.2 Ran `migrate-to-plugin.sh apply` after user confirmation
- [x] 6.3 Verified: `.claude/skills/save-session/` and `.claude/skills/sync-memory/` gone; `.claude/settings.local.json` hooks reduced to `{}` (old hook removed, `enabledPlugins` intact); `.git/info/exclude`'s two stale lines removed, unrelated entries preserved; re-run of `check` reports clean/no-op
- [x] 6.4 Re-ran the cached `resolve-project-name.sh` and `sync-memory.py --dry-run` post-migration — both still correct.

**Task 5.4 result**: first attempt at this test uncovered a real bug (`hooks.json` missing its top-level `"hooks"` wrapper — see 2.2), fixed and force-refreshed via uninstall/reinstall. Second fresh-session test, with the old hook fully gone, confirmed success: on the user's first message, Claude proactively called basic-memory and surfaced accurate, real chezmoi-specific context (commit `ffa5057`, `inline-claude-env-p10k-segment`, `sops-age-secrets-pilot`) without being asked — exactly the intended `SessionStart` hook behavior. (The reminder has no visible output before the first message is sent — expected, since it's context injected for the model's first response, not a standalone pre-prompt message.)

## 7. Migrate real external projects

*(Two real targets ended up in scope, not one — `~/work/viewpoint-report-automation` (the user's own choice, not originally named in this task) and `~/work/WES.ViewPoint.ExternalIntegration.FulcrumAppAPI` (the originally-named target, confirmed by the user as a separate, real, still-needed-migration project). The script is project-agnostic so this doesn't affect the mechanism, just the task bookkeeping.)*

- [x] 7.1 `viewpoint-report-automation`: `check` run by the user directly, following the usage instructions given in conversation
- [x] 7.2 `viewpoint-report-automation`: `apply` run — this is what surfaced the `UserPromptSubmit` legacy-hook gap (see 4.4). Re-run after the fix, confirmed by the user: `.claude/settings.local.json`'s `hooks` is now empty, `enabledPlugins` correctly set
- [x] 7.3 `viewpoint-report-automation`: user confirmed via a fresh session — hook fired correctly, accurate unprompted memory context surfaced
- [x] 7.1b `WES.ViewPoint.ExternalIntegration.FulcrumAppAPI`: ran `check` — found the v8+ `SessionStart` shape (no `UserPromptSubmit` legacy issue here), old skill dirs, plugin not yet enabled; confirmed nothing about to be touched is git-tracked (`save-session`/`settings.local.json` globally gitignored, `sync-memory` untracked-but-unmodified-canonical-content) before applying
- [x] 7.2b `WES.ViewPoint.ExternalIntegration.FulcrumAppAPI`: ran `apply` — old skill dirs removed, legacy hook removed, plugin installed and enabled; re-`check` confirms clean/no-op
- [x] 7.3b `WES.ViewPoint.ExternalIntegration.FulcrumAppAPI`: fresh-session hook confirmation — user confirmed it fired correctly, same as the other two projects

## 8. Retire the old skill

- [x] 8.1 Deleted `home/dot_claude/skills/setup-memory-workflow/` in full (all 8 files) after confirming with the user — all three known real projects verified migrated and working first. Git-tracked deletion, shows as 8 `D` entries in `git status`, not yet committed
- [x] 8.2 Updated `openspec/specs/setup-memory-workflow/spec.md`'s `## Purpose` to describe the plugin-based mechanism
- [x] 8.3 Grepped the repo for remaining references — the two hits in live code (`migrate-to-plugin.sh`, the new chezmoi script) are intentional/benign; the two `openspec/specs/*.md` hits are the pre-archive main tree, corrected by `openspec archive` (section 9); one untracked historical `docs/` design doc left as-is per this repo's convention

## 9. Archive

- [x] 9.1 Ran `openspec validate setup-memory-workflow-plugin-conversion --strict` — passed. Along the way, archive itself caught two real spec-authoring bugs: a MODIFIED requirement whose header had been silently renamed (archive refuses to drop content it can't match — fixed via proper `RENAMED` + `MODIFIED` blocks), and a second MODIFIED requirement missing an original scenario name (fixed by preserving the original scenario title while repurposing its body to describe the closest equivalent new behavior)
- [x] 9.2 Ran `openspec archive setup-memory-workflow-plugin-conversion --yes` — succeeded: `claude-plugin-marketplace` created (+4), `setup-memory-workflow` updated (+4 ~2 -13), `sync-memory` updated (~2 →1 renamed). Archived as `2026-08-06-setup-memory-workflow-plugin-conversion`
