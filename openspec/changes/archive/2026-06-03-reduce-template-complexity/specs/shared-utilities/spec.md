## ADDED Requirements

### Requirement: Claude Environment Iterator
The `for_each_claude_env` function SHALL iterate over a list of Claude environment directories, expand tilde prefixes, skip missing directories with a skip message, and invoke a caller-provided callback function for each valid directory.

#### Scenario: Valid directories are passed to callback
- **WHEN** `for_each_claude_env my_fn "~/.claude-work" "~/.claude-personal"` is called and both directories exist
- **THEN** `my_fn` SHALL be called once with the expanded path for each directory
- **AND** the function SHALL return 0

#### Scenario: Missing directory is skipped
- **WHEN** one of the env directories does not exist on disk
- **THEN** the function SHALL emit a skip message via `print_message "skip"`
- **AND** SHALL NOT call the callback for that directory
- **AND** SHALL continue to the next directory

#### Scenario: Tilde expansion is performed
- **WHEN** a directory argument begins with `~/`
- **THEN** the function SHALL expand `~` to `$HOME` before checking existence or invoking the callback
- **AND** the callback SHALL receive the fully expanded path

#### Scenario: Empty argument list
- **WHEN** `for_each_claude_env my_fn` is called with no directory arguments
- **THEN** the function SHALL return 0 without calling the callback

### Requirement: iCloud Installation Guard Template Partial
A chezmoi template partial named `icloud-install-guard` SHALL emit a bash block that exits the script early with a user-readable explanation when iCloud is not signed in at template-render time. Scripts that require iCloud availability SHALL include this partial instead of duplicating the guard inline.

#### Scenario: iCloud signed in — no guard emitted
- **WHEN** the `icloud-install-guard` partial is rendered and `icloud-account-id` returns a non-empty value
- **THEN** the partial SHALL emit no bash code
- **AND** the containing script SHALL proceed normally

#### Scenario: iCloud not signed in — guard exits the script
- **WHEN** the `icloud-install-guard` partial is rendered and `icloud-account-id` returns an empty value
- **THEN** the partial SHALL emit a bash block that:
  - prints a warning via `print_message "warning"` explaining iCloud is not signed in
  - prints an info message via `print_message "info"` advising the user to run `chezmoi apply` again after signing in
  - calls `exit 0` to skip the script without error

#### Scenario: Partial is reusable across scripts
- **WHEN** `{{ includeTemplate "icloud-install-guard" . }}` is included in any script template
- **THEN** the guard SHALL behave identically regardless of the surrounding script content
- **AND** the partial SHALL NOT assume any surrounding variable or function is defined
