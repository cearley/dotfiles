## ADDED Requirements

### Requirement: Install-time project name detection
The skill SHALL detect the project name from `git rev-parse --show-toplevel` (falling back to `basename "$PWD"`) once during setup, and substitute it into all generated artifacts — not resolve it at runtime.

#### Scenario: Git repository
- **WHEN** the skill runs inside a git repository
- **THEN** `$PROJECT` is set to the basename of the git root and used verbatim in the save-session skill content and hook command

#### Scenario: Non-git directory
- **WHEN** the skill runs outside any git repository
- **THEN** `$PROJECT` falls back to `basename "$PWD"` and setup proceeds normally

### Requirement: basic-memory project registration
The skill SHALL register the project with basic-memory at `$HOME/.local/share/basic-memory/$PROJECT` before installing any other artifacts.

#### Scenario: First-time setup
- **WHEN** no basic-memory project with that name exists
- **THEN** `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` creates and registers the project

#### Scenario: Re-run on existing project
- **WHEN** the basic-memory project is already registered
- **THEN** `basic-memory project add` exits 0 with a notice; setup continues without error

### Requirement: Idempotent hook installation via jq exit code
The skill SHALL use `jq -e` exit code to detect whether the UserPromptSubmit hook is already present, rather than capturing and string-comparing jq output.

#### Scenario: Hook absent
- **WHEN** no hook command in `settings.local.json` contains the string `"basic-memory"`
- **THEN** `jq -e` exits non-zero and the hook is appended

#### Scenario: Hook already present
- **WHEN** an existing hook command contains `"basic-memory"`
- **THEN** `jq -e` exits 0 and no duplicate hook is added

#### Scenario: Malformed JSON
- **WHEN** `settings.local.json` is malformed
- **THEN** `jq` exits non-zero; the outer guard prevents a corrupt append

### Requirement: Hook command built via jq --arg
The skill SHALL pass the hook command string to jq via `--arg`, keeping the command string and the jq filter syntactically separate.

#### Scenario: Hook command construction
- **WHEN** the hook is being written
- **THEN** the command string is assigned to a shell variable and passed as `jq --arg cmd "$hook_cmd"` — no `\\\"` escaping inside the filter

### Requirement: Settings file post-write verification
The skill SHALL verify `settings.local.json` is valid JSON and that both the MCP server entry and hook command are present after all writes complete.

#### Scenario: Successful verification
- **WHEN** all jq mutations have completed
- **THEN** a single jq query extracts `mcpServers["basic-memory"]` and all UserPromptSubmit hook commands, and the result is shown to the user

#### Scenario: Malformed output file
- **WHEN** the verification jq call exits non-zero
- **THEN** the skill stops and reports the error without proceeding to the confirm step

### Requirement: basic-memory installed via uv tool install
The skill SHALL instruct users to install basic-memory with `uv tool install basic-memory`, not `uvx` or `pip`.

#### Scenario: basic-memory not found
- **WHEN** `which basic-memory` returns no result
- **THEN** the skill tells the user to run `uv tool install basic-memory` and stops
