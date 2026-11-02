## RENAMED Requirements

- FROM: `### Requirement: Independence from the persona settings ledger`
- TO: `### Requirement: Independence from the profile settings ledger`

## MODIFIED Requirements

### Requirement: Independence from the profile settings ledger

Applying a permission pattern SHALL NOT read, write, or otherwise affect any profile's `~/.claude*/settings.json`, its `_chezmoiManaged` ledger, or any file under `home/dot_claude*/`. Profile selection (`CLAUDE_CONFIG_DIR`) and permission-pattern selection SHALL remain independent: choosing a profile SHALL NOT imply or constrain which pattern, if any, is stamped into a given repo.

#### Scenario: Stamping does not touch profile settings
- **WHEN** the stamping mechanism is invoked from within any profile (`~/.claude`, `-work`, `-personal`, `-bedrock`)
- **THEN** no file under that profile's `CLAUDE_CONFIG_DIR` is read or modified

### Requirement: Tag-gated availability

The permission-pattern templates and the stamping mechanism SHALL be available only on machines tagged `ai`, matching the existing gate on profile settings (`claude-settings-ledger`). The Pattern C container template and any container-runtime tooling it depends on SHALL additionally require the `dev` tag.

#### Scenario: Unavailable without the ai tag
- **WHEN** `chezmoi apply` runs on a machine without the `ai` tag
- **THEN** none of the permission-pattern templates or the stamping mechanism are deployed
