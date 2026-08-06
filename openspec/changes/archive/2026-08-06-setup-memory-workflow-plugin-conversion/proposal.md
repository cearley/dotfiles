## Why

`setup-memory-workflow` distributes the basic-memory session workflow (`save-session`, `sync-memory`, the `SessionStart` reminder hook) by copying rendered templates into each target project, then detecting and repairing drift between those copies and the canonical source via version markers (`SMW_VERSION`) and a hand-rolled `check-drift.sh`/`migrations.sh` pair. This machinery has needed real, recurring maintenance — most recently a full session (`ffa5057`) fixing a stale hook entry that survived multiple prior "confirmed fixed" claims. Claude Code's plugin system makes the underlying problem disappear: plugins are referenced from a shared install location, not copied per consumer, so there is nothing to drift in the first place.

## What Changes

- New local Claude Code plugin marketplace, registered via a chezmoi `run_onchange_` bootstrap script that writes this repo's source path into `~/.claude/plugins/known_marketplaces.json` (user scope, idempotent — checks before writing). The marketplace (`.claude-plugin/marketplace.json`) and the plugin itself (`plugins/basic-memory-workflow/`) live at the repo root, outside `home/`, so chezmoi never templates or applies their content — they're plain files referenced directly by path.
- New plugin `basic-memory-workflow` bundles `save-session` (skill), `sync-memory` (skill + script), and the `SessionStart` reminder hook (`hooks/hooks.json`) as single canonical files. Install-time `__PROJECT__`/`__SMW_VERSION__` template rendering is removed — there is exactly one live copy of each asset, and Claude Code's own plugin versioning (declared `version`, or git SHA fallback) governs updates instead of a hand-rolled marker comparison.
- New shared script `scripts/resolve-project-name.sh`, called by the hook, by `sync-memory.py` as a subprocess, and directly per `save-session`'s own instructions. Resolves a project's basic-memory identity at runtime: `git rev-parse --show-toplevel` + `basename`, overridable by an optional `<project-root>/.claude/basic-memory-project.txt` file (falls through to the git/basename default if that file is absent, empty, or whitespace-only). Exits non-zero outside a git repo; the hook treats that as a silent no-op rather than an error.
- Per-project plugin enablement stays an explicit, individual opt-in — `enabledPlugins` in that project's `.claude/settings.json` or `.claude/settings.local.json` — matching today's UX where a project consciously gets the memory workflow set up rather than it appearing everywhere automatically.
- New `scripts/migrate-to-plugin.sh`, bundled in the plugin, `check`/`apply` style like today's `check-drift.sh` (dry-run report first, nothing overwritten without explicit confirmation). For a given project it: removes old `.claude/skills/save-session/` and `.claude/skills/sync-memory/` directories, removes the legacy hook entry from `.claude/settings.local.json`, removes now-pointless `.git/info/exclude` entries for those deleted paths, and adds the `enabledPlugins` entry. Not hardcoded to specific projects — run against whichever project you're standing in; known targets today are this chezmoi repo and `~/work/WES.ViewPoint.ExternalIntegration.FulcrumAppAPI`.
- **BREAKING**: `home/dot_claude/skills/setup-memory-workflow/` (`SKILL.md`, `CHANGELOG.md`, `assets/`, `scripts/check-drift.sh`, `scripts/migrations.sh`) is deleted in full once the plugin ships and known installs are migrated. The entire versioned-template/drift-check mechanism is superseded, not slimmed down.
- **BREAKING**: `sync-memory.py` drops its `.template` suffix and install-time project-identity baking; the deployed script becomes one canonical file that resolves identity at runtime via `resolve-project-name.sh` instead.

## Capabilities

### New Capabilities
- `claude-plugin-marketplace`: chezmoi-managed registration of a local Claude Code plugin marketplace pointing at this repo's own source tree, so in-repo plugins become installable/enablable without publishing anywhere or deploying plugin content through `home/`.

### Modified Capabilities
- `setup-memory-workflow`: the install-time-copy-with-drift-checking mechanism (`SMW_VERSION` markers, `check-drift.sh` check/apply, `migrations.sh` legacy cleanup, per-project templated `__PROJECT__` rendering) is replaced by plugin distribution, per-project `enabledPlugins` opt-in, a one-time `migrate-to-plugin.sh`, and runtime project-identity resolution. The capability's purpose (get a project's basic-memory session workflow set up and keep it healthy) is unchanged; essentially every requirement describing *how* is rewritten.
- `sync-memory`: the existing requirement "Project identity is resolved at install time, not runtime" is reversed — identity now resolves at runtime via the shared `resolve-project-name.sh`, including the new override-file escape hatch. Dual-mode operation, cursor-based state tracking, the dedicated note target, and the cost-sane default model are all unchanged.

## Impact

- **Affected code**: `home/dot_claude/skills/setup-memory-workflow/` (deleted); new `.claude-plugin/marketplace.json` and `plugins/basic-memory-workflow/` at repo root (untemplated, not under `home/`); new `home/.chezmoiscripts/` `run_onchange_` script for marketplace registration; this repo's own `.claude/` state, migrated via `migrate-to-plugin.sh`.
- **Externally affected**: `~/work/WES.ViewPoint.ExternalIntegration.FulcrumAppAPI` needs the same `migrate-to-plugin.sh` run against it separately, after the plugin ships.
- **Not touched**: basic-memory MCP server registration (already handled globally via the existing `packages.yaml`/`run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl` mechanism — `basic-memory` is already an `mcp_servers` entry there; the plugin does not bundle its own `mcpServers` entry); `save-session`/`sync-memory` runtime *behavior* (what they write, the status-note-vs-session-log split); the `basic-memory` tool installation bootstrap (`uv tool install basic-memory`, still a manual prerequisite).
- **Tags affected**: `ai` — consistent with the existing Claude Code MCP/plugin install scripts (`run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, `-39-install-claude-plugins.sh.tmpl`) this repo already tag-gates under `ai`.
- **Security**: no secrets are involved anywhere in this change. `migrate-to-plugin.sh` deletes local project files and edits local settings/exclude files, so it keeps `check-drift.sh`'s never-silently-overwrite discipline (report first, act only on explicit confirmation). Enabling a plugin for a project already requires Claude Code's own workspace-trust prompt, which is an existing platform safeguard this change relies on rather than reimplements.

## Non-goals

- Not republishing this as a standalone/public plugin repo (rejected during brainstorming in favor of a local marketplace living inside this chezmoi repo, since the workflow is tied to this user's specific basic-memory/SpecStory conventions, not generically reusable).
- Not making the plugin always-on globally — per-project opt-in is preserved deliberately.
- Not bundling basic-memory's own MCP server registration into the plugin — that's already solved elsewhere and out of scope here.
- Not changing what `save-session`/`sync-memory` actually write to basic-memory, or their command-line behavior — this is a distribution/packaging change only.
- Not building general-purpose multi-plugin marketplace tooling beyond what this one plugin needs.
