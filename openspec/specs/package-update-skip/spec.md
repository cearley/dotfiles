# package-update-skip Specification

## Purpose
TBD - created by archiving change optional-skip-long-running-package-updates. Update Purpose after archive.
## Requirements
### Requirement: Global Environment Variable Override
The system SHALL support a `CHEZMOI_SKIP_PACKAGE_UPDATES` environment variable that, when set to a non-empty value, causes every long-running package-update layer to be skipped for that `chezmoi apply` invocation without prompting or reading/writing a cache file.

#### Scenario: Env var set
- **WHEN** `CHEZMOI_SKIP_PACKAGE_UPDATES` is set to a non-empty value in the environment `chezmoi apply` runs in
- **THEN** every layer (Homebrew, SDKMAN, UV, Bun, Cargo, Claude skills/MCP/plugins) SHALL be skipped for that run
- **AND** no interactive prompt SHALL be shown
- **AND** no cache file SHALL be read or written

#### Scenario: Env var unset or empty
- **WHEN** `CHEZMOI_SKIP_PACKAGE_UPDATES` is unset or set to an empty string
- **THEN** the system SHALL fall back to the cached-decision and prompt resolution flow

### Requirement: Per-Invocation Cached Decision
The system SHALL persist the resolved skip decision in a cache file keyed by the parent process ID (`$PPID`) so that all layer scripts spawned by the same `chezmoi apply` invocation share one decision, without requiring a prompt per script.

#### Scenario: Cache file location and key
- **WHEN** a layer script resolves the skip decision (env var unset)
- **THEN** it SHALL use a cache file at `${TMPDIR:-/tmp}/chezmoi-package-update-skip.$PPID`
- **AND** `$PPID` SHALL be the process ID of the `chezmoi apply` invocation that spawned the script

#### Scenario: First script writes the cache
- **WHEN** no cache file exists yet for the current `$PPID`
- **THEN** the script SHALL resolve the decision (via prompt or non-interactive default)
- **AND** SHALL write the resulting per-layer decisions to the cache file before returning

#### Scenario: Subsequent scripts reuse the cache
- **WHEN** a cache file already exists for the current `$PPID` and is not stale
- **THEN** the script SHALL read the per-layer decision from the cache file
- **AND** SHALL NOT prompt the user again

#### Scenario: Stale cache is ignored
- **WHEN** an existing cache file's modification time is more than 1 hour old
- **THEN** the script SHALL treat the cache as stale and re-resolve the decision as if no cache file existed
- **AND** SHALL overwrite the stale file with the newly resolved decision

### Requirement: Two-Step Interactive Prompt
When the environment variable is unset, no valid cache exists, and a TTY is attached to standard input, the system SHALL prompt the user in two steps: first whether to skip all layers, then — only if declined — whether to selectively choose layers.

#### Scenario: User skips everything
- **WHEN** the first prompt "Skip ALL long-running package-update checks this run? (y/N)" is answered yes
- **THEN** every layer SHALL be marked as skipped in the cached decision
- **AND** no further per-layer questions SHALL be asked

#### Scenario: User declines skip-all and declines per-layer selection
- **WHEN** the first prompt is answered no (or left at the default)
- **AND** the follow-up prompt "Selectively skip specific layers instead? (y/N)" is answered no (or left at the default)
- **THEN** every layer SHALL be marked as not-skipped in the cached decision
- **AND** behavior SHALL be identical to today's (no skip mechanism present)

#### Scenario: User selects specific layers
- **WHEN** the first prompt is answered no
- **AND** the follow-up prompt is answered yes
- **THEN** the system SHALL ask one yes/no question per layer (Homebrew, SDKMAN, UV, Bun, Cargo, Claude)
- **AND** SHALL record each layer's individual answer in the cached decision

### Requirement: Non-Interactive Default
When the environment variable is unset and no TTY is attached to standard input, the system SHALL default every layer to "not skipped" without prompting, preserving current behavior in non-interactive contexts.

#### Scenario: No TTY attached
- **WHEN** a layer script resolves the skip decision
- **AND** standard input is not a TTY (e.g. CI, `remote_install.sh` bootstrap, cron-triggered runs)
- **THEN** the system SHALL NOT display any prompt
- **AND** SHALL treat every layer as not-skipped, identical to current behavior

### Requirement: Shared Layer-Check Helper
The system SHALL provide a shared shell function that encapsulates the full resolution flow (env var → cache → prompt → default) and returns whether a given named layer should be skipped, for use as a guard clause at the start of each affected script.

#### Scenario: Helper contract
- **WHEN** a layer script sources `shared-utils.sh` and calls the helper with a layer name (one of `homebrew`, `sdkman`, `uv`, `bun`, `cargo`, `claude`)
- **THEN** the helper SHALL return a value indicating skip or run for that specific layer
- **AND** the calling script SHALL exit 0 with a `print_message "skip"` call when the layer should be skipped, before performing any install/upgrade work

#### Scenario: Skipping does not fail the script
- **WHEN** a layer is skipped via this mechanism
- **THEN** the script SHALL exit with status 0
- **AND** chezmoi SHALL mark the script as successfully run
- **AND** subsequent scripts in the apply invocation SHALL continue to execute normally

