## ADDED Requirements

### Requirement: Category-Level Brew Install Environment Variables
Any tag category in `packages.yaml` MAY declare an optional `brew_env` key containing a string-to-string map of environment variable names to values. These variables SHALL be exported into the shell environment before `brew bundle` runs, making them available to all Homebrew formula installations in that run.

#### Scenario: brew_env declared in an active category
- **WHEN** a tag category (e.g., `work`) is active
- **AND** that category contains a `brew_env` key with one or more key-value pairs
- **THEN** each key-value pair SHALL be exported as a shell environment variable before `brew bundle` executes
- **AND** the variable SHALL apply to all formulae and casks installed in that bundle run

#### Scenario: brew_env absent from a category
- **WHEN** a tag category does not contain a `brew_env` key
- **THEN** no additional environment variables SHALL be exported for that category
- **AND** the category's brews, casks, and taps SHALL install exactly as before

#### Scenario: brew_env present in multiple active categories
- **WHEN** two or more active categories each declare `brew_env`
- **THEN** ALL key-value pairs from ALL active categories SHALL be collected
- **AND** if the same key appears in multiple categories, the value from the last active category in iteration order SHALL win
- **AND** the collected vars SHALL be exported before `brew bundle` runs

#### Scenario: brew_env values are properly quoted
- **WHEN** a `brew_env` value is exported into the shell environment
- **THEN** the value SHALL be shell-quoted to prevent word-splitting or globbing
- **AND** the exported variable SHALL be available as-is to the `brew install` subprocess

#### Scenario: env vars are ephemeral to the script
- **WHEN** the darwin-23 install-packages script completes
- **THEN** all exported `brew_env` variables SHALL exist only in that script's process environment
- **AND** SHALL NOT be persisted to any shell profile or subsequent scripts

#### Scenario: brew_env for Microsoft SQL packages
- **WHEN** the `work` tag is active
- **AND** `packages.darwin.work.brew_env` contains `HOMEBREW_ACCEPT_EULA: "Y"`
- **THEN** `HOMEBREW_ACCEPT_EULA=Y` SHALL be exported before `brew bundle`
- **AND** `msodbcsql18` and `mssql-tools18` SHALL install without requiring manual EULA acceptance

## MODIFIED Requirements

### Requirement: Tag-Based Package Categories
Packages SHALL be organized into logical categories based on their purpose. Each category MAY contain the following keys: `taps`, `brews`, `casks`, `mas`, `sdkman`, `uv`, `bun`, `cargo`, and `brew_env`.

#### Scenario: Core packages
- **WHEN** packages are essential for basic system operation
- **THEN** they SHALL be placed in the `core` tag category

#### Scenario: Development packages
- **WHEN** packages are development tools (docker, IDEs, language tools)
- **THEN** they SHALL be placed in the `dev` tag category

#### Scenario: AI/ML packages
- **WHEN** packages are AI or machine learning related (Claude, Ollama, LM Studio)
- **THEN** they SHALL be placed in the `ai` tag category

#### Scenario: Work packages
- **WHEN** packages are enterprise or work-specific tools (Teams, Workspaces)
- **THEN** they SHALL be placed in the `work` tag category

#### Scenario: Personal packages
- **WHEN** packages are personal productivity tools
- **THEN** they SHALL be placed in the `personal` tag category

#### Scenario: Data science packages
- **WHEN** packages are data analysis tools (R, RStudio, csvkit)
- **THEN** they SHALL be placed in the `datascience` tag category

#### Scenario: Mobile/network packages
- **WHEN** packages are VPN or network tools (Tunnelblick, WireGuard)
- **THEN** they SHALL be placed in the `mobile` tag category
