# Spec Delta

## MODIFIED Requirements

### Requirement: GUI Session Inheritance via LaunchAgent
On macOS, when the active machine declares a `claude_default`, a user LaunchAgent SHALL inject `CLAUDE_CONFIG_DIR` into the GUI session managed by `launchd` so apps launched from Spotlight, Dock, and Finder inherit the same value as terminal-launched processes. When a machine previously declared a `claude_default` and now no longer does, the provisioning script SHALL detect the previously-installed LaunchAgent and tear it down — unloading it via `launchctl bootout` and removing its plist — rather than merely exiting early and leaving the stale LaunchAgent active.

#### Scenario: LaunchAgent installation
- **WHEN** `chezmoi apply` runs on a macOS machine with `claude_default` set
- **THEN** the file `~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist` SHALL exist
- **AND** SHALL have permission mode 644

#### Scenario: LaunchAgent contents
- **WHEN** the LaunchAgent plist is rendered
- **THEN** it SHALL define a label of `<reverse_dns>.claude-config-dir`
- **AND** SHALL declare `ProgramArguments` of `["/bin/launchctl", "setenv", "CLAUDE_CONFIG_DIR", "<home>/.<claude_default>"]`
- **AND** SHALL set `RunAtLoad` to `true`

#### Scenario: Live GUI session update
- **WHEN** the activation script runs
- **THEN** it SHALL call `launchctl setenv CLAUDE_CONFIG_DIR <path>` directly
- **AND** the running GUI session SHALL immediately reflect the new value
- **AND** the user SHALL NOT need to log out

#### Scenario: Already-running GUI app warning
- **WHEN** the activation script completes
- **THEN** it SHALL print a tip via `print_message tip` reminding the user to restart already-running GUI apps to inherit the new value

#### Scenario: Mac mini exclusion
- **WHEN** `chezmoi apply` runs on a machine without `claude_default`, and no LaunchAgent was previously installed
- **THEN** the LaunchAgent plist SHALL NOT be installed
- **AND** the activation script SHALL exit early without invoking `launchctl`

#### Scenario: Idempotent re-bootstrap
- **WHEN** the activation script runs and the LaunchAgent is already loaded
- **THEN** the script SHALL `bootout` the existing agent (tolerating "not loaded" errors)
- **AND** SHALL `bootstrap` the agent fresh
- **AND** SHALL succeed without manual intervention

#### Scenario: Reverse-DNS-derived filename and label
- **WHEN** the LaunchAgent plist is rendered
- **THEN** the filename SHALL be `<reverse_dns>.claude-config-dir.plist`
- **AND** the label SHALL match the filename without the `.plist` suffix
- **AND** both values SHALL be sourced from `{{ .reverse_dns }}` in chezmoi data

#### Scenario: claude_default removed after being previously set
- **WHEN** `chezmoi apply` runs on a machine whose `claude_default` was previously set (a LaunchAgent plist for it exists on disk) and is no longer declared
- **THEN** the script SHALL unload the existing LaunchAgent (`launchctl bootout`) and remove its plist file
- **AND** GUI-launched apps SHALL NOT continue inheriting the stale `CLAUDE_CONFIG_DIR` value after this run
