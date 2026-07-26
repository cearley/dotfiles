# setup-memory-workflow Specification

## Purpose
Bootstraps the basic-memory session workflow in any project: registers the project with basic-memory, installs the save-session skill, wires a UserPromptSubmit hook, and (if not already globally registered) adds the MCP server to `.mcp.json`.

## Requirements

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

### Requirement: Global MCP registration check
Before writing any MCP server config, the skill SHALL check whether basic-memory is already registered as a global MCP server using `claude mcp list`.

#### Scenario: basic-memory already globally registered
- **WHEN** `claude mcp list` output contains "basic-memory"
- **THEN** the skill skips writing any MCP server entry and reports that it is already globally registered

#### Scenario: basic-memory not globally registered
- **WHEN** `claude mcp list` does not contain "basic-memory" (or the command fails)
- **THEN** the skill proceeds to write the MCP server entry to `.mcp.json`

### Requirement: MCP server written to .mcp.json
When the MCP server entry is needed, the skill SHALL write it to `.mcp.json` at the project root, not to `.claude/settings.local.json`.

#### Scenario: .mcp.json absent
- **WHEN** `.mcp.json` does not exist at the project root
- **THEN** the skill creates it with a `mcpServers` object containing only the basic-memory entry

#### Scenario: .mcp.json already exists
- **WHEN** `.mcp.json` exists at the project root
- **THEN** the skill reads the existing `mcpServers["basic-memory"]` entry (if any) and compares it to the canonical value
- **AND** if no entry exists, adds the canonical entry while preserving all other keys
- **AND** if an entry exists and matches the canonical value, leaves the file untouched
- **AND** if an entry exists and differs, reports the drift to the user and asks whether to update, leave as-is, or merge manually — it SHALL NOT silently overwrite a differing entry

### Requirement: MCP server command uses uvx with Python 3.12
The MCP server entry written to `.mcp.json` SHALL invoke basic-memory via uvx with an explicit Python version.

#### Scenario: MCP server entry written
- **WHEN** the skill writes the basic-memory MCP server entry
- **THEN** the entry is `{"command": "uvx", "args": ["--python", "3.12", "basic-memory", "mcp"]}`

### Requirement: User decides .mcp.json gitignore status
The skill SHALL inform the user that `.mcp.json` may be committed or gitignored, without making that decision automatically.

#### Scenario: Confirm step mentions .mcp.json
- **WHEN** the skill reaches the confirm step after writing `.mcp.json`
- **THEN** the output notes that `.mcp.json` was created at the project root and reminds the user to decide whether to add it to `.gitignore` based on team preference

### Requirement: Idempotent, drift-checked hook installation via version marker
The skill SHALL extract any existing UserPromptSubmit hook command containing `"basic-memory"` from `settings.local.json`, then compare an embedded `setup-memory-workflow-version:N` marker (and whether it still names the current project) against the skill's current `SMW_VERSION` to decide whether the hook is up to date, needs the user's confirmation to repair, or should be left alone.

#### Scenario: Hook absent
- **WHEN** no hook command in `settings.local.json` contains the string `"basic-memory"`
- **THEN** the skill appends a fresh hook entry with the canonical command, embedding the current `SMW_VERSION` marker

#### Scenario: Hook present and current
- **WHEN** an existing hook command contains `"basic-memory"` with a version marker equal to `SMW_VERSION` and still naming the current project
- **THEN** the skill reports the hook is up to date and leaves it unchanged

#### Scenario: Hook present but drifted
- **WHEN** an existing hook command's version marker is missing, older than `SMW_VERSION`, or no longer names the current project
- **THEN** the skill shows the existing command against the canonical one and asks the user before replacing it in place — it SHALL NOT silently overwrite or append a duplicate

#### Scenario: Malformed JSON
- **WHEN** `settings.local.json` is malformed
- **THEN** `jq` exits non-zero; the outer guard prevents a corrupt write, and the skill stops and reports the error before proceeding further

### Requirement: Hook command built via jq --arg
The skill SHALL pass the hook command string to jq via `--arg`, keeping the command string and the jq filter syntactically separate.

#### Scenario: Hook command construction
- **WHEN** the hook is being written
- **THEN** the command string is assigned to a shell variable and passed as `jq --arg cmd "$hook_cmd"` — no `\\\"` escaping inside the filter

### Requirement: Settings file post-write verification
The skill SHALL verify `.mcp.json` (if written) and `.claude/settings.local.json` after all writes complete, in two separate checks.

#### Scenario: Successful verification of .mcp.json
- **WHEN** the MCP server entry was written to `.mcp.json`
- **THEN** a jq query verifies `mcpServers["basic-memory"]` is present in `.mcp.json` and shows the result to the user

#### Scenario: Successful verification of hook in settings.local.json
- **WHEN** all jq mutations to `.claude/settings.local.json` have completed
- **THEN** a jq query extracts all UserPromptSubmit hook commands and shows the result to the user

#### Scenario: MCP registration skipped (already global)
- **WHEN** the global registration check found basic-memory already registered
- **THEN** the `.mcp.json` verification step is skipped; the skill confirms the server was already present globally

#### Scenario: Malformed output file
- **WHEN** either verification jq call exits non-zero
- **THEN** the skill stops and reports the error without proceeding to the confirm step

### Requirement: basic-memory installed via uv tool install
The skill SHALL instruct users to install basic-memory with `uv tool install basic-memory`, not `uvx` or `pip`.

#### Scenario: basic-memory not found
- **WHEN** `which basic-memory` returns no result
- **THEN** the skill tells the user to run `uv tool install basic-memory` and stops
