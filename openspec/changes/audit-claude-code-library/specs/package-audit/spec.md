## MODIFIED Requirements

### Requirement: Per-Manager Audit Coverage
The audit SHALL produce orphan reports for each of the following package managers when its CLI is available: Homebrew (taps, formulae, casks), UV tools, Bun global packages, Cargo crates, SDKMAN candidates, Claude Code plugins, Claude Code plugin marketplaces, and Claude Code skills. The Claude Code sections SHALL be computed by a shared library, deployed to `~/.local/lib/audit-claude-code.sh` from `home/dot_local/lib/audit-claude-code.sh.tmpl`, sourced by both `audit-packages` and any other script needing the same declared-vs-installed facts, rather than duplicated independently.

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
- **THEN** the audit SHALL list installed Claude plugins not declared under any active tag's `plugins` list, and not sourced from the chezmoi-personal marketplace (see "Chezmoi-personal plugins are not orphans" below)
- **AND** the installed side of the comparison SHALL be deduplicated before diffing, so a plugin installed at more than one scope (e.g. both `user` and `project`) is never reported as an orphan more than once, or reported as an orphan at all when it is genuinely declared (see "Multi-scope plugin installs are deduplicated" below)

#### Scenario: Chezmoi-personal plugins are not orphans
- **WHEN** an installed plugin's `id` ends `@chezmoi-personal`
- **THEN** the audit SHALL treat it as declared regardless of whether it also appears in `packages.yaml`'s `plugins` list
- **AND** it SHALL NOT be reported as a Claude Code plugins orphan, since the chezmoi-personal marketplace manifest (`~/.local/share/claude-plugins/.claude-plugin/marketplace.json`) is its own legitimate declaration source, independent of `packages.yaml`

#### Scenario: Multi-scope plugin installs are deduplicated
- **WHEN** the same plugin `id` is installed at more than one scope (e.g. `user` and `project`)
- **AND** that `id` is declared exactly once (in `packages.yaml` or via the chezmoi-personal marketplace)
- **THEN** the audit SHALL NOT report that plugin as an orphan
- **AND** this SHALL hold regardless of how many scopes the plugin is installed in

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
- **AND** the audit SHALL report as orphans only the installed skills that are not matched by any deterministic mapping, are not covered by any collection wildcard's org-derived prefix, and are not a chezmoi-managed skill (see "Chezmoi-managed skills are not orphans" below)

#### Scenario: Claude Code skills section — wildcard prefix coverage
- **WHEN** at least one declared spec is a collection wildcard (matches neither path-style nor `--skill` pattern)
- **AND** an installed skill's name starts with a prefix derived from that wildcard spec's org component
  (the org name with known company suffixes stripped, e.g. `specstoryai` → `specstory`)
- **THEN** that skill SHALL be attributed to the wildcard (not reported as orphan)
- **AND** the audit SHALL emit a `print_message "info"` note naming the wildcard spec(s) that covered at least one skill

#### Scenario: Chezmoi-managed skills are not orphans
- **WHEN** an installed skill's name matches a directory under `home/dot_claude/skills/` (deployed by `chezmoi apply`, never installed via `npx skills add`)
- **THEN** the audit SHALL treat it as declared regardless of whether it also appears in `packages.yaml`'s `skills` list
- **AND** it SHALL NOT be reported as a Claude Code skills orphan

#### Scenario: Claude Code skills section — orphan detection
- **WHEN** an installed skill cannot be matched by any deterministic mapping
- **AND** the skill's name does not start with any collection wildcard's org-derived prefix
- **AND** the skill's name does not match a chezmoi-managed skill directory
- **THEN** the audit SHALL report that skill as an orphan

#### Scenario: Claude Code skills section — no orphans
- **WHEN** all installed skills are accounted for (by direct match, wildcard, or chezmoi-managed directory)
- **THEN** the audit SHALL emit `print_message "success" "No orphans"` for the skills section

#### Scenario: Claude Code skills section — output format
- **WHEN** the skills audit runs
- **THEN** orphan skill names SHALL be printed as plain lines on stdout (no `print_message` wrapper)
- **AND** the dual-list "Declared / Installed" display SHALL NOT appear
