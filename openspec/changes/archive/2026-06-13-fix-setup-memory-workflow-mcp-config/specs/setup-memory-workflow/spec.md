## ADDED Requirements

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
- **THEN** the skill merges the basic-memory entry using `//=` idempotency, preserving all other entries

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

## MODIFIED Requirements

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
