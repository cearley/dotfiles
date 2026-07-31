## 1. Canonical sync-memory script

- [x] 1.1 Create `home/dot_claude/skills/setup-memory-workflow/scripts/executable_sync-memory.py` with project-root auto-detection (`git rev-parse --show-toplevel`, falling back to `basename "$PWD"`) — no `__PROJECT__` template substitution, per design decision 8.
- [x] 1.2 Implement cursor state file read/write at `.specstory/.sync-memory-state.json` (`{"last_synced_mtime": <epoch>}`).
- [x] 1.3 Implement log discovery: glob `.specstory/history/**/*.md`, select files with `mtime` after the cursor, falling back to a `--since-days` window (default 1) when no state file exists yet.
- [x] 1.4 Implement default (non-`--standalone`) mode: print the content of located logs to stdout; make no LLM API call; do not write to the vault.
- [x] 1.5 Implement `--standalone` mode: call the Anthropic API (default model `claude-haiku-4-5-20251001`, overridable via `--model`) to distill each located log.
- [x] 1.6 Implement vault directory resolution (`~/.local/share/basic-memory/<project-name>` default, `--vault-dir` override) and, in `--standalone` mode, append distilled output to a note titled "`<Project>` Distilled SpecStory Insights" — never the note `save-session` maintains.
- [x] 1.7 Implement `ANTHROPIC_API_KEY` environment check for `--standalone` mode: fail fast, before any log processing, with a clear error naming the missing variable.
- [x] 1.8 Implement `--dry-run` (report what would be processed, no vault write, no cursor advance) and confirm the cursor otherwise advances to the max `mtime` processed after a real run in either mode.

## 2. sync-memory skill prompt

- [x] 2.1 Create `home/dot_claude/skills/setup-memory-workflow/assets/sync-memory-skill.md.template` with `disable-model-invocation: true` in frontmatter, the `__PROJECT__`/`__SMW_VERSION__` placeholders, and the `<!-- setup-memory-workflow-version:__SMW_VERSION__ -->` marker, matching `save-session-skill.md.template`'s conventions.
- [x] 2.2 Write the skill body: run `sync-memory.py` (default mode) to get unsynced log content, distill it into observations with `[category]` prefixes and `[[wikilink]]` relations per this user's basic-memory conventions, then append via `edit_note` into the dedicated "Distilled SpecStory Insights" note — explicitly distinct from the note `save-session` maintains.
- [x] 2.3 Document `--standalone` usage in the skill body (for the user's own reference when setting up cron) without instructing the skill itself to configure any scheduling — scheduling stays out of scope per the proposal's Non-goals.

## 3. check-drift.sh integration

- [x] 3.1 Bump `SMW_VERSION` from 2 to 3 in `home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh`.
- [x] 3.2 Add a `sync-memory-skill` check block to `cmd_check`: render `assets/sync-memory-skill.md.template`, create if `.claude/skills/sync-memory/SKILL.md` is missing, and use the same version-marker drift detection as the existing `save-session-skill` block.
- [x] 3.3 Add a `sync-memory-script` check block to `cmd_check`: copy the canonical script to `.claude/skills/sync-memory/scripts/sync-memory.py` if missing (setting it executable); if present, compare byte content against the canonical source and report `DRIFT` on any difference — never overwrite automatically.
- [x] 3.4 Add `sync-memory-skill` and `sync-memory-script` cases to `cmd_apply()`, applied only after user confirmation, matching the existing `save-session-skill`/`mcp-config`/`hook-config` pattern.
- [x] 3.5 Extend the confirm-step summary shown to the user to report status for both new pieces alongside the existing ones (implemented in `SKILL.md` Step 3, since that's the actual confirm-step summary block — `cmd_check`'s own `== verification ==` section is scoped to `.mcp.json`/hook per the existing spec and wasn't extended).

## 4. Documentation

- [x] 4.1 Update `setup-memory-workflow/SKILL.md` Step 2 (apply commands) and Step 3 (confirm summary) to list the two new pieces.
- [x] 4.2 Update the "Updating the canonical templates" section of `SKILL.md` to reference `assets/sync-memory-skill.md.template` and `scripts/executable_sync-memory.py` alongside the existing canonical assets, reiterating that changes to either require bumping `SMW_VERSION`.

## 5. Validation

- [x] 5.1 Syntax-check `sync-memory.py` (`python3 -m py_compile`).
- [x] 5.2 Run `check-drift.sh check` against this repo's own `~/.claude` install to confirm both new pieces are detected as missing and created cleanly (dogfooding the change before it ships to other projects). Re-ran against the deployed copy after the user's own `chezmoi apply`: `sync-memory-skill` reported `UP-TO-DATE` (already rendered correctly pre-deploy), `sync-memory-script` reported `CREATED` and verified byte-identical to canonical. Pre-existing, unrelated `save-session-skill`/hook drift (v1→3) confirmed present and left alone per user's explicit instruction to fix it manually.
- [x] 5.3 Invoke `/sync-memory` (default mode) in a live Claude Code session against this repo's own `.specstory/history` and confirm the end-to-end flow: log discovery → printed content → distillation → `edit_note` append into the dedicated note. Found 3 unsynced logs, distilled them (with user confirmation before writing, per the Basic Memory permission rule), and created "chezmoi Distilled SpecStory Insights" via `write_note` (permalink `chezmoi/chezmoi-distilled-spec-story-insights`) — separate from the human-curated session-notes note. Cursor advanced correctly to the max mtime processed.
- [x] 5.4 Run `sync-memory.py --standalone --dry-run` (with `ANTHROPIC_API_KEY` set) and confirm it reports what it would distill without advancing the cursor or writing to the vault. Ran with a dummy key (dry-run never reaches the API call, so this validates the same path a real key would take): correctly reported one log as pending — this session's own SpecStory transcript, whose mtime had advanced past the cursor again since 5.3 ran, a live demonstration of the documented "actively-written log" limitation from design.md.
- [x] 5.5 Unset `ANTHROPIC_API_KEY` and run `sync-memory.py --standalone` to confirm it fails fast with a clear error before touching any logs. Confirmed: exits 1 immediately with `ERROR: ANTHROPIC_API_KEY is not set — required for --standalone mode.`, before any log discovery.
- [x] 5.6 Re-run `openspec validate add-sync-memory-skill` after any implementation-driven edits to specs settle.

## 6. Deploy

- [x] 6.1 Review changes with `chezmoi status` (not `chezmoi diff`, which needs a TTY per this repo's known limitation). **Note**: in practice, `chezmoi status`/`diff` need a TTY for unrelated KeePassXC-templated files elsewhere in the managed set (e.g. AWS credentials) — neither works non-interactively regardless of `--exclude`. Superseded by the user reviewing and running the apply themselves interactively.
- [x] 6.2 Run `chezmoi apply` to deploy the new canonical files to `~/.claude/skills/setup-memory-workflow/`. User ran this themselves interactively. Verified post-apply: `SMW_VERSION=3` present in the deployed `check-drift.sh`, `scripts/sync-memory.py` and `assets/sync-memory-skill.md.template` both present. One cleanup needed: an errant `__pycache__/` from the assistant's own earlier `py_compile` test had leaked into the source tree and been carried along by the apply into the deployed copy — removed from both locations, and `__pycache__/`/`*.pyc` added to `.gitignore` to prevent recurrence.

## 7. Post-hoc audit fixes (via `/audit-skills`, after initial "complete" status)

- [x] 7.1 Fix extraction-criteria duplication: split `EXTRACTION_PROMPT` into a printable `EXTRACTION_CRITERIA` constant plus a thin wrapper; add `--print-extraction-prompt` to `sync-memory.py`; `sync-memory-skill.md.template` Step 2 now runs that flag instead of duplicating the criteria as separately hand-maintained prose. `SMW_VERSION` 3→4.
- [x] 7.2 Fix wrong script path in `sync-memory-skill.md.template`: all three bash blocks referenced `~/.claude/skills/sync-memory/...`, a path that never exists (the skill and script install per-project, not under `~/.claude`). Corrected to project-relative `.claude/skills/sync-memory/...`; the cron example additionally needed an explicit `cd` first, since cron doesn't start with cwd = project root. `SMW_VERSION` 4→5. This was the first time in the session the skill's literal documented command actually ran successfully as written — every earlier test had used a manually-corrected path without the template itself being fixed.
- [x] 7.3 Both fixes deployed via user-run `chezmoi apply`, drift correctly detected and applied to this repo's own project-local install, re-verified with the literal (not manually-corrected) skill commands.

## 8. Project-identity resolution: template substitution instead of runtime derivation

Prompted by the user asking whether `sync-memory.py` should use `__PROJECT__` like the other three assets instead of resolving at runtime. Initial exploration proposed a persisted override file (`.basic-memory-project-name`); rejected — "it will never be clear who or what owns it." Resolution: full consistency with the other three assets instead, deferring a clean override mechanism (see proposal.md Non-goals). See design.md's revision note and Decision 9 for the full reasoning, including a real placeholder-collision bug caught during implementation.

- [x] 8.1 Rename `scripts/executable_sync-memory.py` → `scripts/executable_sync-memory.py.template`. Add `PROJECT_NAME = "__PROJECT__"` and `BASIC_MEMORY_DIR = Path.home() / ".local" / "share" / "basic-memory" / PROJECT_NAME` as install-time-rendered constants. `resolve_project_root()` (used for `.specstory/history` and the cursor state file) stays runtime-derived, unchanged — a deliberate split between filesystem-root resolution (must stay dynamic) and basic-memory identity (now install-time-baked).
- [x] 8.2 Add a `# setup-memory-workflow-version:__SMW_VERSION__` comment marker to the template, matching the other three assets' drift-detection mechanism.
- [x] 8.3 Add a fail-fast safety check for the template being run un-rendered. **Bug caught and fixed during this task**: the first version compared `PROJECT_NAME == "__PROJECT__"` literally — but that's itself a literal occurrence of the placeholder, so `render()`'s blind global `sed` substitution rewrote the check, silently inverting its meaning. Fixed with `PROJECT_NAME.startswith("__") and PROJECT_NAME.endswith("__")`, which contains no literal occurrence of the placeholder for `sed` to touch.
- [x] 8.4 Refactor `check-drift.sh`: extract `check_templated_file()`/`apply_templated_file()` shared helpers (parameterized by installed path, template path, executable flag); migrate `save-session-skill`, `sync-memory-skill`, and `sync-memory-script` to all call them — `sync-memory-script` drops its old bespoke content-diff check entirely, now indistinguishable in mechanism from the other two.
- [x] 8.5 Bump `SMW_VERSION` 5→6.
- [x] 8.6 Remove the superseded non-template `scripts/executable_sync-memory.py` source file.
- [x] 8.7 Update `proposal.md`, `design.md`, and both delta specs to reflect the final mechanism — including documenting the rejected override-file exploration and the placeholder-collision bug as part of the design record, not just the code.

## 9. Validation (template-substitution rework)

- [x] 9.1 Syntax-check both the raw template (with literal placeholders — must remain valid Python) and a simulated `sed`-rendered output; confirm the rendered copy runs correctly (`--dry-run` succeeds) and the un-rendered template correctly fails fast with the safety check.
- [x] 9.2 Run the refactored `check-drift.sh` from the source tree against this repo's real, pre-rework installed files: confirms `sync-memory-skill` correctly reports `DRIFT` on the version bump, and `sync-memory-script` correctly reports `DRIFT (version none -> 6)` against the old runtime-derived file (which has no marker at all) — validates the actual upgrade path, not just fresh-install.
- [x] 9.3 Deployed via user-run `chezmoi apply`. Re-verified against deployed paths: `check-drift.sh check` correctly reported both pieces `DRIFT` (stale project-local install), applied both, re-check shows `UP-TO-DATE`. Rendered copy confirmed: `PROJECT_NAME = "chezmoi"`, correct `BASIC_MEMORY_DIR`, executable bit set. `--print-extraction-prompt` and `--dry-run` both confirmed working on the final deployed+rendered copy; syntax-checked clean.
- [x] 9.4 Orphaned `~/.claude/skills/setup-memory-workflow/scripts/sync-memory.py` (pre-rename, no `.template`) found present after apply as predicted, confirmed stale, removed.
- [x] 9.5 `openspec validate add-sync-memory-skill` passes.

## 10. Post-`/opsx:verify` spec coverage fixes

`/opsx:verify` found two implemented behaviors with no corresponding spec requirement: `--print-extraction-prompt` (task 7.1) and `--max-logs-per-run` (built in task 1, resolved as an open question in `design.md` but never given its own requirement). Both were real, working, correctly-implemented functionality — a spec documentation gap, not a code gap.

- [x] 10.1 Add "Extraction criteria are exposed via a flag, shared between modes" requirement to `specs/sync-memory/spec.md`.
- [x] 10.2 Add "Backlog processing is capped per run" requirement to `specs/sync-memory/spec.md`.
- [x] 10.3 Re-run `openspec validate add-sync-memory-skill` — passes.
