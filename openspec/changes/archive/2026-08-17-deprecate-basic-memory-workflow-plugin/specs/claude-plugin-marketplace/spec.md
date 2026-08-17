## MODIFIED Requirements

### Requirement: Marketplace source is a plain local path, not a published repo
The marketplace SHALL be declared as `.claude-plugin/marketplace.json` at the chezmoi source root, and SHALL NOT itself require a separate published git repository — the marketplace's own registration (the chezmoi source directory's path in the user-scope marketplace registry) is always a local filesystem path. Individual plugin entries listed within the marketplace MAY use either a relative path within the repo (for plugins authored in this repo) or a third-party git/URL source (for plugins that re-point at content published elsewhere).

#### Scenario: Marketplace manifest resolves plugins by relative path
- **WHEN** `.claude-plugin/marketplace.json` lists a self-authored plugin such as `aws-local-dev`
- **THEN** its `source` is a relative path (e.g. `./plugins/aws-local-dev`) resolved against the marketplace root

#### Scenario: Re-pointed plugin resolves by third-party source
- **WHEN** `.claude-plugin/marketplace.json` lists a plugin whose content is authored and published elsewhere (e.g. `atlassian`)
- **THEN** its `source` MAY be a `git`, `git-subdir`, `url`, or `github` source object pointing at the upstream repo, matching the shape other Claude Code marketplaces use for the same plugin
