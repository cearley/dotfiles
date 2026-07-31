## Why

Sessions run through Claude Code produce SpecStory transcripts (`.specstory/history/`) full of architectural decisions, coding-standard corrections, and hard-won bug fixes that never make it into basic-memory unless someone manually runs `/save-session`. That manual step is easy to skip, and nothing captures a session at all if no interactive Claude Code session ever runs `/save-session` for it (e.g. work done between sessions, or logs from tools other than the primary assistant loop). A sync mechanism that can distill unsynced SpecStory logs into basic-memory — either from inside a running Claude Code session or unattended via cron — closes that gap.

## What Changes

- Add a new `sync-memory` skill, installed by `setup-memory-workflow` alongside the existing `save-session` skill, at `.claude/skills/sync-memory/SKILL.md`. Unlike `save-session`, it is marked `disable-model-invocation: true` — user-invoked only (`/sync-memory`), never triggered automatically by the model, since it makes an external API call (in standalone mode) and shouldn't fire on the model's own judgment.
- Add a companion standalone script, rendered from `scripts/sync-memory.py.template` using the same `__PROJECT__`/`__SMW_VERSION__` substitution as the other three canonical assets (`save-session-skill`, `sync-memory-skill`, hook message) — full consistency, no bespoke mechanism. The *basic-memory identity* (vault directory, note title/permalink) is baked in at install time via `__PROJECT__`; the *filesystem* project root (for finding `.specstory/history` and the cursor state file) stays resolved at runtime via `git rev-parse`, since that has to reflect wherever the script actually runs from, not a value fixed at install time — these are different concerns and only one of them can be a install-time constant.
- The script runs in one of two modes:
  - **Default (interactive)**: locates SpecStory logs unsynced since the last run (tracked via a cursor file, `.specstory/.sync-memory-state.json`), prints their content, and does not call any LLM API — the invoking Claude Code session distills the content itself and writes it to basic-memory via MCP tools, the same way `save-session` already does.
  - **`--standalone`**: fully self-contained for unattended use (e.g. cron) — reads `ANTHROPIC_API_KEY` from the environment, calls the Anthropic API directly to distill each log, and appends the result straight to the basic-memory vault markdown file on disk.
- Both modes write to one dedicated, continuously-appended note ("`<Project>` Distilled SpecStory Insights"), kept separate from the human-curated session-notes note that `/save-session` maintains, so automated output never mixes with manually-curated entries.
- The vault directory defaults to `~/.local/share/basic-memory/<project-name>` — the same value `setup-memory-workflow` registers the project at (`SKILL.md` Step 1 / `check-drift.sh`'s `basic-memory project add` call) — baked in at install time as `Path.home() / ".local" / "share" / "basic-memory" / PROJECT_NAME`, where `PROJECT_NAME` is the rendered `__PROJECT__` value. A `--vault-dir` flag overrides it for non-standard setups.
- Extend `check-drift.sh`: bump `SMW_VERSION` (now at 6, after several iterations during this change — see tasks.md for the full history), and refactor the three `__PROJECT__`/`__SMW_VERSION__`-templated pieces (`save-session-skill`, `sync-memory-skill`, `sync-memory-script`) to share one `check_templated_file()`/`apply_templated_file()` helper pair instead of three near-duplicate blocks — `sync-memory-script` is no longer a special case using content-diff.
- Update `setup-memory-workflow/SKILL.md`'s Step 2/3 tables and "Updating the canonical templates" section to cover the new pieces and the shared templating mechanism.

Non-goals:
- Not building any secret-management integration for `ANTHROPIC_API_KEY` — it's read from a plain environment variable. Neither of this repo's two secret tiers (KeePassXC, SOPS+age) fits a script that needs to run unattended in cron: KeePassXC requires an interactive unlock, and SOPS+age is scoped to secrets that exist solely to render chezmoi-managed files, which this isn't.
- Not solving the case where a SpecStory log file is still being actively written when the sync cursor advances past it — later content in that file is picked up on the *next* run, not lost, but this change doesn't add finer-grained (e.g. per-line) tracking to avoid that delay.
- Not adding a cron job itself (e.g. a new chezmoi-managed LaunchAgent) — this change only ships the script and skill; wiring up unattended scheduling is left for the user (or a future change) to set up per-machine.
- Not building a clean mechanism to override the basic-memory project identity away from the directory basename (e.g. "directory is `foo`, but I want the basic-memory project to be `bar`"). This was explored during the change (a persisted override file was proposed and rejected — unclear ownership) and deliberately deferred: the outcome of this change is that all four canonical assets now share the *same* limitation (hand-edit the rendered files after install if you want a different name), rather than the script having none at all. A real override mechanism, if wanted, is a separate future change.

## Capabilities

### New Capabilities
- `sync-memory`: distills unsynced SpecStory session logs into a dedicated basic-memory note, either interactively (via a running Claude Code session, no extra API cost) or standalone (via a direct Anthropic API call, for unattended/cron use), with cursor-based tracking so reruns never reprocess already-synced content.

### Modified Capabilities
- `setup-memory-workflow`: install-time behavior extends to cover the new `sync-memory` skill and script — detection, creation-when-missing, and drift reporting for two additional artifacts (`.claude/skills/sync-memory/SKILL.md` and `.claude/skills/sync-memory/scripts/sync-memory.py`), plus the `SMW_VERSION` bump this introduces.

## Impact

- `home/dot_claude/skills/setup-memory-workflow/assets/sync-memory-skill.md.template` (new)
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_sync-memory.py.template` (new — canonical script is itself a `__PROJECT__`/`__SMW_VERSION__` template now, not a verbatim copy; `executable_` prefix so chezmoi sets +x on this repo's own deployed copy)
- `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh` (modified — new `check_templated_file`/`apply_templated_file` shared helpers, version bumps)
- `home/dot_claude/skills/setup-memory-workflow/SKILL.md` (modified — documents the new pieces)
- `openspec/specs/setup-memory-workflow/spec.md` (modified via delta spec — new requirements for the sync-memory pieces)
- No package, tag, or machine-config changes. No impact on `core`/`dev`/`ai`/`work`/`personal`/`datascience`/`mobile` tag installation — this is Claude-skill tooling, not a system package.
- Security: introduces the first script in this repo that calls an external LLM API directly (Anthropic, in `--standalone` mode) with local file content (SpecStory session transcripts, which may include command output, file paths, or discussion of secrets-adjacent config). `ANTHROPIC_API_KEY` is read from environment only, never written to disk or committed; the script fails fast with a clear error if it's unset in `--standalone` mode. This is a deliberate change in this repo's data-egress posture worth flagging explicitly during review.
