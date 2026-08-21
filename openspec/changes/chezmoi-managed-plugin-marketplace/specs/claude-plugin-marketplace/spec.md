## MODIFIED Requirements

### Requirement: Marketplace source is a plain local path, not a published repo
The marketplace SHALL be declared as `.claude-plugin/marketplace.json` under a fixed chezmoi-deployed target directory (`~/.local/share/claude-plugins`), and SHALL NOT itself require a separate published git repository — the marketplace's own registration in the user-scope marketplace registry is always a local filesystem path, resolved against the deployed target directory rather than the location of the chezmoi source checkout. Individual plugin entries listed within the marketplace MAY use either a relative path within the deployed tree (for plugins authored in this repo) or a third-party git/URL source (for plugins that re-point at content published elsewhere).

#### Scenario: Marketplace manifest resolves plugins by relative path
- **WHEN** `.claude-plugin/marketplace.json` lists a self-authored plugin such as `aws-local-dev`
- **THEN** its `source` is a relative path (e.g. `./plugins/aws-local-dev`) resolved against the deployed marketplace root (`~/.local/share/claude-plugins`)

#### Scenario: Re-pointed plugin resolves by third-party source
- **WHEN** `.claude-plugin/marketplace.json` lists a plugin whose content is authored and published elsewhere (e.g. `atlassian`)
- **THEN** its `source` MAY be a `git`, `git-subdir`, `url`, or `github` source object pointing at the upstream repo, matching the shape other Claude Code marketplaces use for the same plugin
- **AND** installing that plugin from `chezmoi-personal` SHALL NOT require the upstream marketplace (e.g. `claude-plugins-official`) to also be registered

#### Scenario: Marketplace path is stable regardless of chezmoi source checkout location
- **WHEN** the chezmoi source tree for this repo is checked out at a different filesystem path than on another machine
- **THEN** the marketplace's registered path (`~/.local/share/claude-plugins`) SHALL be identical on both machines, since it is derived from the deployment target, not from `.chezmoi.sourceDir`

### Requirement: Marketplace registration is declared and idempotent
The marketplace's deployed local path SHALL be declared as a plain string entry in `packages.darwin.ai.agents.claude_code.plugin_marketplaces`, installed by the same generic `run_onchange_` mechanism used for every other declared marketplace, without producing duplicate entries on repeated runs. No dedicated, marketplace-specific bootstrap script SHALL be required.

#### Scenario: First run on a machine
- **WHEN** the generic plugin-marketplace installer script runs on a machine where `chezmoi-personal` is not yet registered
- **THEN** it adds an entry for the deployed `~/.local/share/claude-plugins` path to the user-scope registry, exactly as it does for every other declared marketplace entry

#### Scenario: Re-run on an already-registered machine
- **WHEN** the installer script runs again (e.g. after an unrelated `chezmoi apply`)
- **THEN** it detects the existing registration and makes no changes, producing no duplicate entry

#### Scenario: Declared marketplace is indistinguishable from any other declared marketplace for audit purposes
- **WHEN** `audit-packages`'s `audit_claude_marketplaces` compares installed marketplaces against `packages.darwin.ai.agents.claude_code.plugin_marketplaces`
- **THEN** `chezmoi-personal` SHALL appear as declared-and-installed like any other entry, requiring no hardcoded exception to avoid a false-positive orphan report

## REMOVED Requirements

### Requirement: Marketplace and plugin content are not chezmoi-templated
**Reason**: Superseded by "Marketplace and plugin content are chezmoi-managed and templatable" below — this repo's plugin marketplace content moves under `home/` specifically so it can participate in chezmoi's normal templating and deployment mechanism, reversing the prior restriction.
**Migration**: No content changes are forced by this removal alone; existing plugin files remain valid plain (non-`.tmpl`) files after the move. Templating becomes available for future use, not retroactively applied.

## ADDED Requirements

### Requirement: Marketplace and plugin content are chezmoi-managed and templatable
Files under the marketplace's source tree (`home/dot_local/share/claude-plugins/`) SHALL be ordinary chezmoi-managed source content, deployed to `~/.local/share/claude-plugins` by `chezmoi apply` like any other file under `home/`. Individual files MAY use the `.tmpl` extension and chezmoi's templating functions (including `keepassxcAttribute` for secret injection and conditionals on `.chezmoi.os`/tags) exactly as any other chezmoi-managed file may.

#### Scenario: chezmoi apply deploys plugin content to the fixed target
- **WHEN** `chezmoi apply` runs on a machine with this repo as its source
- **THEN** `home/dot_local/share/claude-plugins/dot_claude-plugin/marketplace.json` and everything under `home/dot_local/share/claude-plugins/plugins/` are rendered and deployed to `~/.local/share/claude-plugins/.claude-plugin/marketplace.json` and `~/.local/share/claude-plugins/plugins/...`, following the same attribute-prefix and `.tmpl` rendering rules as any other `home/` content

#### Scenario: A plugin file uses chezmoi templating
- **WHEN** a plugin's `.mcp.json` needs a value only known at chezmoi-render time (e.g. a per-machine conditional or a secret pulled via `keepassxcAttribute`)
- **THEN** that file MAY be authored as `.tmpl` and rendered normally by `chezmoi apply`, the same as any other chezmoi-managed template

#### Scenario: Editing plugin content requires a chezmoi apply to take effect
- **WHEN** a plugin file under `home/dot_local/share/claude-plugins/` is edited
- **THEN** the change SHALL NOT be visible to Claude Code's marketplace mechanism until the next `chezmoi apply`, since the marketplace reads from the deployed `~/.local/share/claude-plugins` copy rather than the chezmoi source tree directly

#### Scenario: Owner and author identity fields are templated, not hardcoded
- **WHEN** `marketplace.json`'s `owner` or any local plugin's `plugin.json`'s `author` declares a `name` or `email`
- **THEN** the committed source SHALL reference chezmoi data fields (`{{ .fullname }}`, `{{ .gh_commit_email }}`) rather than a literal personal name or email address, so that identity stays out of the plain committed JSON
