## RENAMED Requirements

- FROM: `### Requirement: Project identity is resolved at runtime via a shared script`
- TO: `### Requirement: Project identity is resolved at install/apply-time, baked into the installed copy`

## MODIFIED Requirements

### Requirement: Project identity is resolved at install/apply-time, baked into the installed copy
`sync-memory.py` SHALL be rendered from `scripts/sync-memory.py.template` by `check-drift.sh`, with `PROJECT_NAME` substituted for the `__PROJECT__` placeholder at apply-time (see the `setup-memory-workflow` capability's project identity requirement). The installed copy SHALL contain no runtime identity-resolution call — `PROJECT_NAME` is a plain string constant, used to derive both the default vault directory and the note title/permalink.

#### Scenario: Canonical template contains the placeholder
- **WHEN** the canonical `scripts/sync-memory.py.template` is inspected
- **THEN** `PROJECT_NAME` is assigned the literal string `"__PROJECT__"`, substituted by `check-drift.sh`'s `render()` at apply-time

#### Scenario: Installed copy has the identity baked in
- **WHEN** `sync-memory.py` runs in a project after being installed by `check-drift.sh`
- **THEN** `PROJECT_NAME` is already the project's literal resolved identity (e.g. `"chezmoi"`) — no subprocess call, no runtime resolution

#### Scenario: Un-rendered template fails fast if run directly
- **WHEN** the canonical `scripts/sync-memory.py.template` is executed directly rather than through its installed, rendered copy
- **THEN** it detects `PROJECT_NAME` still equals the literal placeholder string and exits non-zero with an error directing the user to the installed copy instead, before attempting any log processing

### Requirement: Filesystem project root stays resolved at runtime
Separately from project identity, the script SHALL continue to resolve the *filesystem* project root (for locating `.specstory/history` and the cursor state file) dynamically via `git rev-parse --show-toplevel`, since this must reflect wherever the script is actually invoked from.

#### Scenario: Default project root
- **WHEN** the script runs without `--project-root`
- **THEN** it resolves the project root via `git rev-parse --show-toplevel` (falling back to the current working directory)

#### Scenario: Vault directory defaults from install-time identity
- **WHEN** the script runs without `--vault-dir`
- **THEN** it uses `~/.local/share/basic-memory/<PROJECT_NAME>`, where `PROJECT_NAME` is the literal value baked in at apply-time (not runtime-resolved), not necessarily the filesystem project root's raw basename

#### Scenario: Explicit vault override
- **WHEN** the script runs with `--vault-dir <path>`
- **THEN** it uses `<path>` instead of the derived default
