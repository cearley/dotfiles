## ADDED Requirements

### Requirement: Uninstall Hint Output
After listing orphans in any manager section, the audit SHALL print a suggested uninstall command so the user can copy, paste, and edit it without looking up each manager's syntax manually. Hints SHALL be emitted to stderr (same channel as `print_message`) so that stdout remains pipe-friendly and contains only plain orphan names.

#### Scenario: Hint follows orphan list immediately
- **WHEN** a manager section finds at least one orphan
- **THEN** the audit SHALL print a `💡 To remove:` hint to stderr immediately after the orphan list
- **AND** the hint SHALL appear before the next section header

#### Scenario: No hint when no orphans
- **WHEN** a manager section finds no orphans
- **THEN** the audit SHALL NOT print any uninstall hint for that section

#### Scenario: One-line hint for multi-arg managers
- **WHEN** the orphan-containing section is Homebrew formulae, Homebrew casks, UV tools, Bun global packages, or Cargo crates
- **THEN** the hint SHALL be a single command with all orphan names space-separated as arguments
- **AND** the command prefix SHALL be:
  - Homebrew formulae: `brew uninstall`
  - Homebrew casks: `brew uninstall --cask`
  - UV tools: `uv tool uninstall`
  - Bun global packages: `bun remove -g`
  - Cargo crates: `cargo uninstall`

#### Scenario: Per-line hint for per-arg managers
- **WHEN** the orphan-containing section is Homebrew taps, SDKMAN candidates, Claude Code plugins, Claude Code plugin marketplaces, Claude Code MCP servers, or Claude Code skills
- **THEN** the hint SHALL emit one command line per orphan
- **AND** the command prefix SHALL be:
  - Homebrew taps: `brew untap`
  - SDKMAN candidates: `sdk uninstall`
  - Claude Code plugins: `claude plugins uninstall`
  - Claude Code plugin marketplaces: `claude plugins marketplace remove`
  - Claude Code MCP servers: `claude mcp remove`
  - Claude Code skills: `claude skills remove`

#### Scenario: Hint does not appear on stdout
- **WHEN** the user pipes `audit-packages` stdout to another command (e.g., `audit-packages | grep foo`)
- **THEN** the uninstall hint lines SHALL NOT appear in the piped output
- **AND** only the plain orphan names SHALL appear on stdout

#### Scenario: Non-UTF-8 locale fallback
- **WHEN** the `LANG` environment variable does not contain `UTF-8`
- **THEN** the hint prefix SHALL be `[TIP]` instead of `💡`
- **AND** the rest of the hint format SHALL be unchanged
