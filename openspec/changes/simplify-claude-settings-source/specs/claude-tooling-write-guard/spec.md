## ADDED Requirements

### Requirement: chezmoi add of a Persona settings.json Is Denied
For a Bash command that runs `chezmoi add` or `chezmoi re-add` with a
`.claude*/settings.json` path, the guard SHALL return `permissionDecision: "deny"`, with a
reason that points to `.claude-settings/<persona>.json`. That target is a `modify_` file,
and `chezmoi add` would replace its merge script with a full snapshot of the live file.
Other `chezmoi` subcommands on that path SHALL NOT be denied by this rule.

#### Scenario: Forced add is denied
- **WHEN** the command is `chezmoi add --force ~/.claude-personal/settings.json`
- **THEN** the guard SHALL return `permissionDecision: "deny"`

#### Scenario: Read-only chezmoi command is not denied
- **WHEN** the command is `chezmoi status ~/.claude/settings.json`
- **THEN** the guard SHALL NOT return `permissionDecision: "deny"` under this rule
