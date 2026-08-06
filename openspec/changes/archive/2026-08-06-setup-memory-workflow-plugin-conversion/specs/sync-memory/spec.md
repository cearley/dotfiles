## RENAMED Requirements

- FROM: `### Requirement: Project identity is resolved at install time, not runtime`
- TO: `### Requirement: Project identity is resolved at runtime via a shared script`

## MODIFIED Requirements

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
