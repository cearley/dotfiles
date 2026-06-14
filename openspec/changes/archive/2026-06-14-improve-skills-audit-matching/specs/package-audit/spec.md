## MODIFIED Requirements

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
