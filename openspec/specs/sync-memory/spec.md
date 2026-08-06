# sync-memory Specification

## Purpose
Provides a user-invoked `sync-memory` skill and `sync-memory.py` script that distill unsynced SpecStory session logs into the project's basic-memory vault, either interactively inside a Claude Code session (no LLM API calls, the invoking session does the distillation) or fully standalone (calling the Anthropic API directly), with cursor-based sync-state tracking so logs are never reprocessed.
## Requirements
### Requirement: User-invoked only
The `sync-memory` skill SHALL be invocable only by explicit user action, never triggered automatically by the model's own judgment.

#### Scenario: Skill frontmatter disables model invocation
- **WHEN** the `sync-memory` skill is installed
- **THEN** its `SKILL.md` frontmatter includes `disable-model-invocation: true`

#### Scenario: Model does not proactively run the skill
- **WHEN** a Claude Code session is running with the `sync-memory` skill installed
- **THEN** the model SHALL NOT invoke `sync-memory` on its own initiative under any circumstance — only an explicit `/sync-memory` invocation by the user runs it

### Requirement: Dual-mode operation
The `sync-memory.py` script SHALL support two mutually exclusive modes: a default interactive mode with no LLM API calls, and a `--standalone` mode that is fully self-contained.

#### Scenario: Default mode inside a Claude Code session
- **WHEN** the script runs without `--standalone`
- **THEN** it locates unsynced SpecStory logs and prints their content to stdout
- **AND** it makes no call to any LLM API
- **AND** it does not write to the basic-memory vault itself — the invoking Claude Code session distills the output and writes it via MCP tools

#### Scenario: Standalone mode with no Claude Code session
- **WHEN** the script runs with `--standalone`
- **THEN** it locates unsynced SpecStory logs, calls the Anthropic API directly to distill each one, and appends the result to the basic-memory vault markdown file on disk
- **AND** it requires no running Claude Code session to complete successfully

### Requirement: Cursor-based sync state tracking
The script SHALL track the maximum modification time of SpecStory logs it has processed in a state file, and only consider logs modified after that cursor on subsequent runs.

#### Scenario: First run, no state file
- **WHEN** `.specstory/.sync-memory-state.json` does not exist
- **THEN** the script falls back to a `--since-days` window (default 1 day) to select logs, then creates the state file after processing

#### Scenario: Subsequent run with existing state file
- **WHEN** `.specstory/.sync-memory-state.json` exists with a `last_synced_mtime` value
- **THEN** only logs with `mtime` strictly greater than that value are considered unsynced

#### Scenario: Cursor advances after a run
- **WHEN** the script finishes processing one or more logs (in either mode) and is not run with `--dry-run`
- **THEN** it updates `last_synced_mtime` in the state file to the maximum `mtime` among the logs just processed

#### Scenario: Dry run does not advance the cursor
- **WHEN** the script runs with `--dry-run`
- **THEN** it reports which logs would be processed but does not update the state file or write to the vault

### Requirement: Filesystem project root stays resolved at runtime
Separately from project identity, the script SHALL continue to resolve the *filesystem* project root (for locating `.specstory/history` and the cursor state file) dynamically via `git rev-parse --show-toplevel`, since this must reflect wherever the script is actually invoked from.

#### Scenario: Default project root
- **WHEN** the script runs without `--project-root`
- **THEN** it resolves the project root via `git rev-parse --show-toplevel` (falling back to the current working directory)

#### Scenario: Vault directory defaults from install-time identity
- **WHEN** the script runs without `--vault-dir`
- **THEN** it uses `~/.local/share/basic-memory/<PROJECT_NAME>`, where `PROJECT_NAME` is the value `resolve-project-name.sh` returns for the current invocation (runtime-resolved, not baked in at install time), not necessarily the filesystem project root's raw basename

#### Scenario: Explicit vault override
- **WHEN** the script runs with `--vault-dir <path>`
- **THEN** it uses `<path>` instead of the derived default

### Requirement: Dedicated note target
Distilled output SHALL be written to a note dedicated to sync-memory output, never to the session-notes note that the `save-session` skill maintains.

#### Scenario: Output note title
- **WHEN** distilled content is written to basic-memory, in either mode
- **THEN** it is appended to a note titled "`<Project>` Distilled SpecStory Insights", where `<Project>` is the resolved project name

#### Scenario: Session-notes note is never written by sync-memory
- **WHEN** `sync-memory` runs in either mode
- **THEN** it SHALL NOT write to, or otherwise modify, the note that `save-session` maintains

### Requirement: Standalone mode requires ANTHROPIC_API_KEY from the environment
`--standalone` mode SHALL read its Anthropic API credential exclusively from the `ANTHROPIC_API_KEY` environment variable, and SHALL fail fast if it is unset.

#### Scenario: Key present
- **WHEN** `--standalone` runs with `ANTHROPIC_API_KEY` set in the environment
- **THEN** the script uses it to authenticate to the Anthropic API and proceeds

#### Scenario: Key missing
- **WHEN** `--standalone` runs and `ANTHROPIC_API_KEY` is unset
- **THEN** the script exits non-zero immediately with a clear error naming the missing variable, before attempting any log processing or API call

### Requirement: Cost-sane default model, overridable
`--standalone` mode SHALL default to a lower-cost model for distillation, with an explicit override available.

#### Scenario: Default model
- **WHEN** `--standalone` runs without `--model`
- **THEN** it uses `claude-haiku-4-5-20251001`

#### Scenario: Explicit model override
- **WHEN** `--standalone` runs with `--model <model-id>`
- **THEN** it uses `<model-id>` instead of the default

### Requirement: Extraction criteria are exposed via a flag, shared between modes
The script SHALL provide a way to print its extraction criteria without processing any logs, so the interactive skill's Step 2 and `--standalone` mode apply identical criteria from one source instead of duplicated, independently-maintained prose.

#### Scenario: Print extraction prompt and exit
- **WHEN** the script runs with `--print-extraction-prompt`
- **THEN** it prints the extraction criteria to stdout and exits, without discovering, reading, or processing any logs

#### Scenario: Same criteria used internally by --standalone
- **WHEN** `--standalone` mode calls the Anthropic API
- **THEN** the prompt it sends is built from the same criteria `--print-extraction-prompt` outputs, not a separately maintained copy

### Requirement: Backlog processing is capped per run
The script SHALL cap the number of logs processed in a single run, to bound API spend and latency in `--standalone` mode when a large backlog exists.

#### Scenario: Backlog within the cap
- **WHEN** the number of unsynced logs is at or below `--max-logs-per-run` (default 20)
- **THEN** all of them are processed in this run

#### Scenario: Backlog exceeds the cap
- **WHEN** the number of unsynced logs exceeds `--max-logs-per-run`
- **THEN** only the oldest `--max-logs-per-run` logs are processed this run, a notice is printed to stderr naming how many are deferred, and the remainder are picked up on a subsequent run — the cursor only advances past the logs actually processed, not the full backlog

### Requirement: Project identity is resolved at runtime via a shared script
`sync-memory.py` SHALL be a single canonical file with no install-time template rendering. It SHALL resolve its project identity (`PROJECT_NAME`) at runtime by invoking the shared `resolve-project-name.sh` script (see the `setup-memory-workflow` capability), and SHALL use that resolved value to derive both the default vault directory and the note title/permalink.

#### Scenario: Canonical template contains the placeholder
- **WHEN** the canonical `scripts/sync-memory.py` bundled in the plugin is inspected
- **THEN** it contains no `__PROJECT__` or `__SMW_VERSION__` placeholder and no `.template` suffix — it is the one file every project with the plugin enabled runs directly, unlike the pre-plugin canonical template this scenario originally described

#### Scenario: Installed copy has the identity baked in
- **WHEN** `sync-memory.py` runs in a project
- **THEN** it invokes `resolve-project-name.sh` as a subprocess to obtain `PROJECT_NAME` fresh on every run, rather than reading a value baked in at install time as this scenario originally described

#### Scenario: Un-rendered template fails fast if run directly
- **WHEN** `resolve-project-name.sh` cannot determine a project identity (e.g. `sync-memory.py` is run outside any git repository) — the closest equivalent in the new design to this scenario's original "un-rendered template" failure case
- **THEN** `sync-memory.py` exits non-zero immediately with the underlying error printed to stderr, before attempting any log processing

