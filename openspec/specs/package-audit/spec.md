# Package Audit

## Purpose
The package audit system provides an on-demand, read-only report of packages that are installed on the machine but not declared in `packages.yaml`. It covers all six package management ecosystems (Homebrew, UV, Bun, Cargo, SDKMAN) plus Claude Code skills, plugins, and marketplaces. The report respects the active chezmoi tag set so only packages that the install scripts would actually manage on this machine are considered "declared".

## Requirements

### Requirement: On-Demand Audit Script Location
The system SHALL provide an on-demand audit script at `home/scripts/audit-packages.sh` that the user invokes manually to discover installed-but-not-declared packages.

#### Scenario: Script lives under home/scripts/
- **WHEN** the user inspects the repository
- **THEN** an executable file SHALL exist at `home/scripts/audit-packages.sh`
- **AND** it SHALL source `home/scripts/shared-utils.sh` for `print_message`, `command_exists`, and `require_tools`

#### Scenario: Script is not run by chezmoi apply
- **WHEN** the user runs `chezmoi apply`
- **THEN** the audit script SHALL NOT execute automatically
- **AND** running `chezmoi apply` SHALL produce no audit output

### Requirement: PATH-Accessible Invocation Shortcut
The system SHALL install a symlink to the audit script under a PATH-resident directory so that the user can invoke it by short name from any working directory.

#### Scenario: Symlink source file uses chezmoi convention
- **WHEN** the user inspects the source repository
- **THEN** a file SHALL exist at `home/dot_local/bin/symlink_audit-packages.tmpl`
- **AND** its body SHALL resolve to the absolute path of `home/scripts/audit-packages.sh` under `{{ .chezmoi.sourceDir }}`

#### Scenario: Symlink created on apply
- **WHEN** the user runs `chezmoi apply`
- **THEN** a symlink SHALL exist at `~/.local/bin/audit-packages` pointing at the source script

#### Scenario: Short-name invocation
- **WHEN** `~/.local/bin` is on the user's PATH
- **AND** the user runs `audit-packages` from any working directory
- **THEN** the audit script SHALL execute the same as if invoked by its full path
- **AND** `audit-packages --help` SHALL print the usage message

#### Scenario: Symlink target tracks source location
- **WHEN** the user inspects the symlink with `readlink ~/.local/bin/audit-packages`
- **THEN** the readlink output SHALL point inside the chezmoi source directory at `home/scripts/audit-packages.sh`

### Requirement: Active-Tag-Aware Declared Set
The audit SHALL compute the "declared" set of packages using only the chezmoi tags that are active on the invoking machine.

#### Scenario: Tags read from chezmoi config
- **WHEN** the audit script runs
- **THEN** it SHALL read the active tag list from `chezmoi data --format=json` (the `.tags` field)
- **AND** it SHALL NOT treat packages under inactive tags as declared

#### Scenario: Inactive-tag packages flagged as orphans
- **WHEN** a package is installed on the machine
- **AND** the package appears in `packages.yaml` only under a tag that is NOT in the active tag set
- **THEN** the audit SHALL list that package as an orphan

#### Scenario: Active-tag packages not flagged
- **WHEN** a package is installed on the machine
- **AND** the package appears under at least one active tag in `packages.yaml`
- **THEN** the audit SHALL NOT list it as an orphan

### Requirement: Per-Manager Audit Coverage
The audit SHALL produce orphan reports for each of the following package managers when its CLI is available: Homebrew (taps, formulae, casks), UV tools, Bun global packages, Cargo crates, SDKMAN candidates, Claude Code plugins, Claude Code plugin marketplaces, and Claude Code skills.

#### Scenario: Homebrew brews section
- **WHEN** the `brew` command is available
- **THEN** the audit SHALL list installed-on-request formulae not declared under any active tag's `brews` list

#### Scenario: Homebrew casks section
- **WHEN** the `brew` command is available
- **THEN** the audit SHALL list installed casks not declared under any active tag's `casks` list

#### Scenario: Homebrew taps section
- **WHEN** the `brew` command is available
- **THEN** the audit SHALL list active taps not declared under `packages.darwin.taps` or any active tag's `taps` list

#### Scenario: UV tools section
- **WHEN** the `uv` command is available
- **THEN** the audit SHALL list installed UV tools not declared under any active tag's `uv` list
- **AND** comparison SHALL normalize entries by stripping version pins (`==X.Y.Z`), git URLs (`git+...`), and version suffixes (`@latest`)

#### Scenario: Bun global packages section
- **WHEN** the `bun` command is available
- **THEN** the audit SHALL list globally-installed Bun packages not declared under any active tag's `bun` list

#### Scenario: Cargo crates section
- **WHEN** the `cargo` command is available
- **THEN** the audit SHALL list crates from `cargo install --list` not declared under any active tag's `cargo` list
- **AND** comparison SHALL normalize `--git <url>` cargo specs to their resulting crate name

#### Scenario: SDKMAN candidates section
- **WHEN** the `sdk` command is available
- **THEN** the audit SHALL list installed SDKMAN candidate versions not declared under `packages.darwin.dev.sdkman`
- **AND** SHALL only run when the `dev` tag is active

#### Scenario: Claude Code plugins section
- **WHEN** the `claude` command is available
- **AND** the `ai` tag is active
- **THEN** the audit SHALL list installed Claude plugins not declared under any active tag's `plugins` list

#### Scenario: Claude Code marketplaces section
- **WHEN** the `claude` command is available
- **AND** the `ai` tag is active
- **THEN** the audit SHALL list registered Claude plugin marketplaces not declared under any active tag's `plugin_marketplaces` list

#### Scenario: Claude Code skills section — deterministic mapping
- **WHEN** the skills installation directory exists
- **AND** the `ai` tag is active
- **THEN** the audit SHALL derive a skill name from each declared spec using deterministic rules:
  - A spec of the form `<owner>/skills/<name>` (path-style) SHALL map to skill name `<name>` (last path segment)
  - A spec containing `--skill <name>` SHALL map to skill name `<name>`
  - A spec that matches neither rule SHALL be treated as a **collection wildcard**
- **AND** the audit SHALL report as orphans only the installed skills that are not matched by any deterministic mapping AND are not covered by at least one collection wildcard

#### Scenario: Claude Code skills section — wildcard coverage
- **WHEN** at least one declared spec is a collection wildcard (matches neither path-style nor `--skill` pattern)
- **AND** all unmatched installed skills are covered by that wildcard
- **THEN** the audit SHALL emit a note naming the wildcard spec(s)
- **AND** SHALL NOT report those skills as orphans

#### Scenario: Claude Code skills section — orphan detection
- **WHEN** an installed skill cannot be matched by any deterministic mapping
- **AND** no collection wildcard is declared
- **THEN** the audit SHALL report that skill as an orphan

#### Scenario: Claude Code skills section — no orphans
- **WHEN** all installed skills are accounted for (by direct match or wildcard)
- **THEN** the audit SHALL emit `print_message "success" "No orphans"` for the skills section

#### Scenario: Claude Code skills section — output format
- **WHEN** the skills audit runs
- **THEN** orphan skill names SHALL be printed as plain lines on stdout (no `print_message` wrapper)
- **AND** the dual-list "Declared / Installed" display SHALL NOT appear

### Requirement: Missing-CLI Graceful Skip
The audit SHALL skip — not error — any section whose package manager CLI is unavailable on the machine.

#### Scenario: Cargo missing on non-dev machine
- **WHEN** the audit runs on a machine without `cargo` on PATH
- **THEN** the cargo section SHALL emit `print_message "skip"` with a message naming the missing CLI
- **AND** the audit SHALL continue with remaining sections

#### Scenario: All optional CLIs missing
- **WHEN** the audit runs on a `core`-only machine (no `uv`, `bun`, `cargo`, `sdk`, `claude`)
- **THEN** only the Homebrew sections SHALL produce orphan reports
- **AND** all other sections SHALL emit skip messages
- **AND** the script SHALL exit successfully

### Requirement: Read-Only Operation
The audit SHALL NOT install, uninstall, upgrade, or otherwise modify any package or package-manager state.

#### Scenario: No modification under any flag
- **WHEN** the audit runs with any combination of flags
- **THEN** no `install`, `uninstall`, `remove`, `tap`, `untap`, `upgrade`, or write operations SHALL be invoked against any package manager
- **AND** no files outside the user's terminal output SHALL be modified

### Requirement: Output Formatting via Shared Utilities
The audit SHALL use `print_message` from `shared-utils.sh` for status, header, and summary messages.

#### Scenario: Section headers via print_message
- **WHEN** each manager's section begins
- **THEN** the script SHALL emit a header via `print_message "info"` naming the manager

#### Scenario: Empty section reports success
- **WHEN** a manager's installed set is a subset of its declared set
- **THEN** the script SHALL emit `print_message "success" "No orphans"` for that section

#### Scenario: Orphan list is plain stdout
- **WHEN** orphans are found in a section
- **THEN** each orphan SHALL be printed as one plain line on stdout (no `print_message` wrapper)
- **AND** the output SHALL be greppable and pipe-friendly

#### Scenario: Final summary
- **WHEN** the audit completes
- **THEN** the script SHALL emit a summary line via `print_message "info"` reporting the total number of orphans and the number of managers with at least one orphan

### Requirement: Exit Code Behavior
The audit SHALL exit `0` by default regardless of orphan count, and SHALL exit non-zero only when the user requests strict mode.

#### Scenario: Default exit code with orphans
- **WHEN** the audit runs without `--strict` and finds orphans
- **THEN** the script SHALL exit with status `0`

#### Scenario: Default exit code with no orphans
- **WHEN** the audit runs without `--strict` and finds no orphans
- **THEN** the script SHALL exit with status `0`

#### Scenario: Strict mode with orphans
- **WHEN** the audit runs with `--strict` and finds at least one orphan
- **THEN** the script SHALL exit with non-zero status

#### Scenario: Strict mode with no orphans
- **WHEN** the audit runs with `--strict` and finds no orphans
- **THEN** the script SHALL exit with status `0`

#### Scenario: Hard error exit
- **WHEN** the script cannot read `packages.yaml` or cannot run `chezmoi data`
- **THEN** the script SHALL emit `print_message "error"` and exit with non-zero status
- **AND** the failure SHALL NOT depend on `--strict`

### Requirement: YAML Parsing Dependency
The audit SHALL validate that `yq` is available before attempting to read `packages.yaml`.

#### Scenario: yq present
- **WHEN** `yq` is available on PATH
- **THEN** the audit SHALL parse `packages.yaml` using `yq`

#### Scenario: yq missing
- **WHEN** `yq` is not available on PATH
- **THEN** the audit SHALL emit `print_message "error"` instructing the user to `brew install yq`
- **AND** SHALL exit with non-zero status
