## Context

`setup-memory-workflow` already installs one skill (`save-session`) that appends a running session-notes note and updates a status note in basic-memory, both via MCP tools inside an active Claude Code session. It has no mechanism for capturing SpecStory transcripts (`.specstory/history/*.md`) that accumulate regardless of whether `/save-session` was ever run, and no mechanism that works without a live Claude Code session at all (e.g. triggered from cron).

`check-drift.sh` already establishes the install pattern this change extends: a single `SMW_VERSION` constant, template rendering with `__PROJECT__`/`__SMW_VERSION__` substitution for text artifacts, and a check/report-drift/apply-on-confirmation flow that never silently overwrites user customization.

**Revision note**: this change's design went through a real pivot after initial implementation and validation. The first version of `sync-memory.py` deliberately avoided template substitution, resolving the project name at runtime instead (see the superseded reasoning that used to live in Decisions 4 and 8, kept below as struck-through history rather than deleted, since the reasoning itself remains valid context even though the conclusion changed). Two things surfaced that reversed the decision: dogfooding revealed the script's own SKILL.md instructions referenced the wrong install-time path (a correctness bug, since fixed, unrelated to this pivot but discovered alongside it), and a deeper design discussion (prompted by the user asking "wouldn't it be better if it used `__PROJECT__` like the others?") surfaced that runtime resolution left the script with *zero* override path for its basic-memory identity — worse than the other three assets, which at least support a fragile hand-edit-after-install workaround. A persisted override file (`.basic-memory-project-name`) was proposed to solve that cleanly, and rejected — "it will never be clear who or what owns it." The resolution: full consistency. The script now uses the exact same `__PROJECT__`/`__SMW_VERSION__` substitution as the other three assets, accepting the same "hand-edit after install" limitation they already have, rather than being a special case with a worse limitation. A genuinely clean override mechanism is deferred to a possible future change.

## Goals / Non-Goals

**Goals:**
- Distill unsynced SpecStory logs into basic-memory, usable both interactively (inside a Claude Code session, no extra LLM spend) and unattended (cron, via a direct Anthropic API call).
- Never reprocess already-synced log content on rerun.
- Keep automated output out of the human-curated session-notes note `save-session` maintains.
- Fold installation of the new skill/script into the existing `setup-memory-workflow` check/drift/apply flow, with no new install pathway to learn.
- Skill is invoked only by explicit user action (`/sync-memory`), never by the model's own judgment.

**Non-Goals:**
- No secret-management integration for `ANTHROPIC_API_KEY` (plain env var only — see Decisions).
- No sub-file-level (e.g. per-line or per-turn) tracking of partially-synced logs.
- No cron job installation (LaunchAgent, crontab entry) — this change ships the script only.
- No dedup/merge logic beyond the cursor — if a log is edited to add content *before* the cursor position after being synced, that edit is not retroactively picked up.

## Decisions

**1. Dual-mode script: `stdout` hand-off by default, `--standalone` for direct API calls.**
The default mode assumes it's invoked by a running Claude Code session (via the `sync-memory` skill) and only does the deterministic part — find unsynced logs, print their content — leaving distillation and the basic-memory write to the invoking session's own MCP tool calls. `--standalone` mode does everything itself, including the Anthropic API call and a direct file write to the vault.
*Alternative considered*: always call the Anthropic API, regardless of context. Rejected — it would pay for a redundant LLM call every time the skill runs inside a session where a model is already available for free, and would require the API key to be configured even for the common interactive case.

**2. Cursor-based dedup via `.specstory/.sync-memory-state.json`.**
The script tracks the maximum log `mtime` it has processed and only considers logs modified after that cursor on the next run, advancing the cursor to the max `mtime` seen. This is a single JSON file `{"last_synced_mtime": <epoch>}`.
*Alternative considered*: per-file content hashes for finer-grained dedup. Rejected as unnecessary complexity — SpecStory logs are append-only per session; a single mtime cursor is sufficient and much simpler to reason about and debug.

**3. Dedicated note, not the session-notes note.**
Both modes write to a distinctly-titled note ("`<Project>` Distilled SpecStory Insights"), never the note `save-session` maintains. This keeps automated, unreviewed-by-a-human output from mixing into the note that's meant to be a curated running log.

**4. Vault path baked in at install time, not derived at runtime.** *(Revised — see revision note above; originally "derived at runtime via `git rev-parse` → `basename`", superseded by Decision 9.)*
`BASIC_MEMORY_DIR = Path.home() / ".local" / "share" / "basic-memory" / PROJECT_NAME`, where `PROJECT_NAME` is the `__PROJECT__` value rendered once at install time by `check-drift.sh`, identical to how the other three canonical assets get their project name. `--vault-dir` still overrides it for non-standard setups. This is a *different* project-root resolution than the one used to find `.specstory/history` — see Decision 9.

**5. `ANTHROPIC_API_KEY` from environment only.**
No integration with either of this repo's secret tiers. KeePassXC requires an interactive unlock prompt, which breaks unattended cron execution; SOPS+age is documented as scoped to secrets that exist solely to render chezmoi-managed files, and this is a runtime script secret, not a template-render secret — using it here would be a misuse of that tier's stated purpose. The script fails fast with a clear, actionable error if the variable is unset in `--standalone` mode.

**6. Model default: `claude-haiku-4-5-20251001`, overridable via `--model`.**
Chosen for a background/cron-friendly cost profile. `--model claude-sonnet-5` (or any other) is available for cases where distillation quality matters more than cost.

**7. `disable-model-invocation: true` on the skill.**
Unlike `save-session` (which the model may reasonably decide to run at natural session-end points), `sync-memory` triggers an external API call and file writes outside the note the model already manages — it should only run when the user explicitly asks for it via `/sync-memory`.

**8. Drift-check integration is now fully uniform across all three templated pieces — no more special case.** *(Revised — see revision note above; originally "the script uses content-diff, not a version marker, because there's nowhere natural to embed one without it looking like dead code." That reasoning didn't hold up: a `# setup-memory-workflow-version:N` Python comment is completely idiomatic. Superseded by Decision 9.)*
`sync-memory-script` now follows the identical `setup-memory-workflow-version:N` marker pattern as `save-session-skill` and `sync-memory-skill`, via a shared `check_templated_file()`/`apply_templated_file()` helper pair in `check-drift.sh` that all three call (parameterized by installed path, template path, and whether to `chmod +x`). This replaced three near-identical ~15-line blocks with one ~20-line shared function plus three one-line call sites — a direct, in-scope fix for a duplication problem that would have gotten worse (a 4th near-copy) had the script's drift check stayed a bespoke content-diff.
*Trade-off accepted*: the old content-diff approach was structurally immune to one specific mistake — editing a canonical asset's content and forgetting to bump `SMW_VERSION`, which produces a false `UP-TO-DATE`. That's not hypothetical: it happened twice in this session, on the marker-based assets, before this decision was made. Full consistency was judged worth more than that extra robustness, especially since the failure mode is now well-documented (`SKILL.md`'s "Updating the canonical templates" section) and has been hit and fixed live twice already.

**9. Project *root* (filesystem location) and project *identity* (basic-memory name) are resolved differently, on purpose.**
The script needs project root for two distinct reasons: finding `.specstory/history` and the cursor state file (must reflect wherever the script actually runs from — cannot be a fixed value, since the whole point is finding *real* logs in the *actual* invocation context), and deriving the basic-memory vault/note identity (now baked in at install time, per Decision 4). `resolve_project_root()` stays runtime-derived via `git rev-parse --show-toplevel` for the first case; `PROJECT_NAME`/`BASIC_MEMORY_DIR` are install-time constants for the second. Conflating these two into one `project = project_root.name` computation (the original design) is what created the "no override path at all" gap — decoupling them, in the *right* direction (identity gets install-time baking, filesystem lookup stays dynamic), fixes it without losing the property that a cloned/moved repo still finds its own logs correctly.
*A real bug caught during implementation, worth recording*: the canonical template's own safety check (fail loudly if run un-rendered) was first written as `if PROJECT_NAME == "__PROJECT__":` — which is itself a literal occurrence of the placeholder, so `render()`'s blind global `sed` substitution rewrote the check itself, silently inverting its meaning (it would error when *correctly* rendered and pass silently when not). Fixed with a pattern check — `PROJECT_NAME.startswith("__") and PROJECT_NAME.endswith("__")` — that doesn't contain the placeholder as a literal substring. Anyone adding a similar self-referential check to a `__PROJECT__`-templated file should watch for this.

## Risks / Trade-offs

- **[Risk]** A SpecStory log still being actively written when the cursor advances past its current `mtime` will have earlier content synced but its later content delayed to the *next* run (not lost). → **Mitigation**: accepted as a non-goal; documented behavior, not a bug. Users running `/sync-memory` mid-session should expect a partial capture.
- **[Risk]** `--standalone` mode is this repo's first script that sends local file content to an external LLM API (Anthropic) unattended. SpecStory transcripts can contain command output, file paths, or config discussion. → **Mitigation**: env-var-only key handling (never persisted), fail-fast on missing key, and this is called out explicitly in the proposal's Impact section for visibility during review. No content filtering/redaction is added in this change — flagged as an open question below.
- **[Risk]** Bumping `SMW_VERSION` flags every existing `setup-memory-workflow` install (this repo's own, and any other project it was set up in) as having pieces in `DRIFT`/missing state on next check. This happened five times over the course of this change (2→3 initial ship, 3→4 and 4→5 for two audit-driven content fixes, 5→6 for the template-substitution rework) — more churn than anticipated at initial design time. → **Mitigation**: still matches the existing, already-accepted behavior of every version bump — `check-drift.sh` creates genuinely-missing pieces automatically and only prompts before overwriting something that already exists and differs. The repeated bumps were a direct, positive signal that the discipline works: each one caught a real, live drift case (including a false-negative from a version bump the assistant itself forgot, twice, corrected in-session) rather than any of them being spurious.
- **[Trade-off]** Interactive mode requires the user to actually invoke `/sync-memory`; nothing runs it automatically (by design, per Decision 7). If the user wants unattended capture, they must separately set up `--standalone` under cron themselves (explicitly out of scope — see Non-Goals).

## Migration Plan

No data migration. Rollout is purely additive within the existing `check-drift.sh check`/`apply` flow:
1. `SMW_VERSION` bumps (now at 6, after several iterations — see Risks above for the full history).
2. Next `check-drift.sh check` run (in this repo, via its own dogfooded install, and in any other project using this skill) reports `sync-memory-skill` and `sync-memory-script` as missing (first install) or `DRIFT` (upgrading from any earlier version of this change, including the pre-rework runtime-resolving script, which correctly shows as `DRIFT (version none -> 6)` since it has no marker at all) — never silently overwritten.
3. **New cleanup step from the template-substitution rework**: the canonical script source was renamed `scripts/sync-memory.py` → `scripts/sync-memory.py.template`. `chezmoi apply` has no built-in mechanism to delete a file that's been renamed out of the source tree, so the stale `~/.claude/skills/setup-memory-workflow/scripts/sync-memory.py` (without `.template`) is left behind as an orphan after the next apply — harmless (nothing references it) but should be manually removed for cleanliness.
4. No rollback beyond `git revert` — the new/changed pieces are inert until a user runs `/sync-memory` or the script directly.

## Open Questions

- Should `--standalone` mode support redacting obvious secret-shaped strings (tokens, keys) from log content before sending it to the Anthropic API? Deferred — no redaction mechanism exists elsewhere in this repo to reuse, and building one is a bigger scope than this change. Flagged for a future change if it becomes a real concern.
- ~~Should there be a `--max-logs-per-run` cap...~~ **Resolved**: implemented, default 20, see Decision list in `sync-memory` capability spec.
- Should there be a clean, first-class way to override the basic-memory project identity away from the directory basename (the "`foo` directory, want basic-memory project `bar`" scenario)? Deliberately deferred — see proposal.md's Non-goals. A persisted-override-file mechanism was explored and rejected during this change for unclear ownership; if revisited, it should probably apply uniformly to all four canonical assets, not just the script.
