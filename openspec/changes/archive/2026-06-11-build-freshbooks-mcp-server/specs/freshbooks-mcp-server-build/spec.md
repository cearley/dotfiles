## ADDED Requirements

### Requirement: Post-fetch build for FreshBooks MCP server
The chezmoi apply process SHALL compile the FreshBooks MCP server TypeScript source after fetching or updating the external git-repo, producing a runnable `dist/` output directory.

#### Scenario: Build runs after external is fetched
- **WHEN** `chezmoi apply` is run on a macOS machine with `ai` and `dev` tags and the 30-day time-bucket has elapsed
- **THEN** the script runs `npm install && npm run build` inside `~/.local/share/freshbooks-mcp-server` and exits zero

#### Scenario: Build skipped when server directory is missing
- **WHEN** `chezmoi apply` is run but `~/.local/share/freshbooks-mcp-server` does not exist
- **THEN** the script prints a warning and exits zero without error

#### Scenario: Build skipped on machines without required tags
- **WHEN** `chezmoi apply` is run on a machine that does not have both the `ai` and `dev` tags
- **THEN** the script file is not generated (template gate excludes it) and no build is attempted

### Requirement: npm availability check before build
The build script SHALL verify that `npm` is present in PATH before attempting the build and exit non-zero with a clear error message if it is not.

#### Scenario: npm missing
- **WHEN** `npm` is not available in the current shell's PATH at apply time
- **THEN** `require_tools npm` prints an error message and the script exits non-zero, preventing a silent partial-build state
