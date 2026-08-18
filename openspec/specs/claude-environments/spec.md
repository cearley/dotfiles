# Claude Environments

## Purpose
The Claude environments system provides the chezmoi-side wiring that connects Claude Code multi-environment support to the external `zsh-claude-env` oh-my-zsh plugin (https://github.com/cearley/zsh-claude-env), which owns the actual per-environment shell functions, session switcher, and prompt segment behavior. Chezmoi's remaining responsibilities are: exporting a default `CLAUDE_CONFIG_DIR` in both zsh and bash, declaring and registering the plugin itself, hosting its display-preference settings in `dot_p10k.zsh`, GUI session inheritance via a LaunchAgent on macOS, and ensuring every declared environment directory shares one skills location via symlink.
## Requirements
### Requirement: Default Environment via Exported Variable
When the active machine declares a `claude_default` in `home/.chezmoidata/config.yaml`, both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` SHALL export `CLAUDE_CONFIG_DIR` to the corresponding path via a small inline snippet — duplicated in each rc template, not a shared partial — reusing the same `claude_default` value the macOS LaunchAgent already consumes. In `dot_zshrc.tmpl` this export SHALL be positioned before the `plugins=(...)` block, so the `zsh-claude-env` plugin observes the correct value at its own load time.

#### Scenario: Machine with claude_default set (zsh)
- **WHEN** the active machine's pattern in `config.yaml` has `claude_default: claude-work`
- **THEN** `home/dot_zshrc.tmpl` SHALL emit `export CLAUDE_CONFIG_DIR="$HOME/.claude-work"` before its `plugins=(...)` block

#### Scenario: Machine with claude_default set (bash)
- **WHEN** the active machine's pattern in `config.yaml` has `claude_default: claude-work`
- **THEN** `home/dot_bashrc.tmpl` SHALL emit `export CLAUDE_CONFIG_DIR="$HOME/.claude-work"`

#### Scenario: Machine without claude_default
- **WHEN** the active machine's pattern in `config.yaml` has no `claude_default` key
- **THEN** neither rc template SHALL emit an export statement
- **AND** the default behavior of `claude` SHALL be the binary's built-in fallback (`~/.claude`)

#### Scenario: Reaches shells the LaunchAgent does not
- **WHEN** a shell is not spawned through the macOS GUI/launchd session the LaunchAgent's `launchctl setenv` reaches (e.g. an SSH session, or any bash shell)
- **THEN** this rc-template export SHALL still set `CLAUDE_CONFIG_DIR` correctly, independent of the LaunchAgent
- **AND** this SHALL hold for both zsh and bash, even though bash has no other Claude-environment integration

#### Scenario: No alias for bare claude
- **WHEN** either rc template is rendered for a machine with `claude_default` set
- **THEN** no alias for `claude` SHALL be defined
- **AND** the bare `claude` command SHALL invoke the binary directly with the inherited environment

### Requirement: GUI Session Inheritance via LaunchAgent
On macOS, when the active machine declares a `claude_default`, a user LaunchAgent SHALL inject `CLAUDE_CONFIG_DIR` into the GUI session managed by `launchd` so apps launched from Spotlight, Dock, and Finder inherit the same value as terminal-launched processes.

#### Scenario: LaunchAgent installation
- **WHEN** `chezmoi apply` runs on a macOS machine with `claude_default` set
- **THEN** the file `~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist` SHALL exist
- **AND** SHALL have permission mode 644

#### Scenario: LaunchAgent contents
- **WHEN** the LaunchAgent plist is rendered
- **THEN** it SHALL define a label of `<reverse_dns>.claude-config-dir`
- **AND** SHALL declare `ProgramArguments` of `["/bin/launchctl", "setenv", "CLAUDE_CONFIG_DIR", "<home>/.<claude_default>"]`
- **AND** SHALL set `RunAtLoad` to `true`

#### Scenario: Live GUI session update
- **WHEN** the activation script runs
- **THEN** it SHALL call `launchctl setenv CLAUDE_CONFIG_DIR <path>` directly
- **AND** the running GUI session SHALL immediately reflect the new value
- **AND** the user SHALL NOT need to log out

#### Scenario: Already-running GUI app warning
- **WHEN** the activation script completes
- **THEN** it SHALL print a tip via `print_message tip` reminding the user to restart already-running GUI apps to inherit the new value

#### Scenario: Mac mini exclusion
- **WHEN** `chezmoi apply` runs on a machine without `claude_default`
- **THEN** the LaunchAgent plist SHALL NOT be installed
- **AND** the activation script SHALL exit early without invoking `launchctl`

#### Scenario: Idempotent re-bootstrap
- **WHEN** the activation script runs and the LaunchAgent is already loaded
- **THEN** the script SHALL `bootout` the existing agent (tolerating "not loaded" errors)
- **AND** SHALL `bootstrap` the agent fresh
- **AND** SHALL succeed without manual intervention

#### Scenario: Reverse-DNS-derived filename and label
- **WHEN** the LaunchAgent plist is rendered
- **THEN** the filename SHALL be `<reverse_dns>.claude-config-dir.plist`
- **AND** the label SHALL match the filename without the `.plist` suffix
- **AND** both values SHALL be sourced from `{{ .reverse_dns }}` in chezmoi data

### Requirement: Conditional Plist Inclusion
The chezmoi ignore mechanism SHALL exclude the LaunchAgent plist on machines that do not declare `claude_default`.

#### Scenario: Empty claude_default
- **WHEN** the active machine has no `claude_default` in `config.yaml`
- **THEN** `home/.chezmoiignore.tmpl` SHALL list the plist path under an ignore stanza
- **AND** chezmoi SHALL NOT render or install the plist

#### Scenario: Non-empty claude_default
- **WHEN** the active machine has `claude_default` set
- **THEN** the ignore stanza SHALL NOT match
- **AND** the plist SHALL be rendered and installed normally

### Requirement: rc File Integration
`home/dot_zshrc.tmpl` SHALL declare the `zsh-claude-env` plugin as a `.chezmoiexternal.toml.tmpl` source and list it in `plugins=(...)`. Neither rc template SHALL reference the removed `claude-environments` partial or any Claude-environment *switching* functionality (wrapper functions, the `claude-env` switcher, title hooks, SpecStory wrappers) in bash.

#### Scenario: External plugin source declared
- **WHEN** `home/.chezmoiexternal.toml.tmpl` is rendered on a Darwin machine
- **THEN** it SHALL declare `.oh-my-zsh/custom/plugins/zsh-claude-env` as an archive-type external
- **AND** SHALL use the same `$zshPlugin` dict pattern (`type = "archive", exact = true, stripComponents = 1, refreshPeriod = "168h"`) already used for its sibling custom-plugin entries
- **AND** the source URL SHALL point at `https://github.com/cearley/zsh-claude-env/archive/main.tar.gz`

#### Scenario: Plugin listed in plugins=()
- **WHEN** `home/dot_zshrc.tmpl` is rendered
- **THEN** `plugins=(...)` SHALL include `zsh-claude-env`
- **AND** this entry SHALL NOT be conditional on `"ai" .tags`, matching the unconditional convention already used by the other custom-plugins entries in the same `.chezmoiexternal.toml.tmpl` darwin block

#### Scenario: No includeTemplate call remains
- **WHEN** `home/dot_zshrc.tmpl` or `home/dot_bashrc.tmpl` is rendered
- **THEN** neither SHALL contain `{{ includeTemplate "claude-environments" . }}` or any other `claude-env*`-named template call
- **AND** `home/.chezmoitemplates/claude-environments` SHALL NOT exist in the chezmoi source tree

#### Scenario: openspecui alias relocated inline
- **WHEN** `home/dot_zshrc.tmpl` or `home/dot_bashrc.tmpl` is rendered for a machine with `"ai"` in its tags
- **THEN** each SHALL contain a bare `alias openspecui='npx openspecui@latest'` line, gated on `has "ai" .tags` directly at that line, with no dependency on any Claude-environments partial

#### Scenario: Bash has no switching functionality, but keeps the default export
- **WHEN** `home/dot_bashrc.tmpl` is rendered
- **THEN** it SHALL define no `claude-<name>` functions, no `claude-env` switcher, no terminal-title hooks, and no `*-spec` wrapper functions
- **AND** this SHALL be true regardless of the active machine's tags
- **AND** it SHALL still contain the default-export snippet described in `Default Environment via Exported Variable`

### Requirement: Right-Prompt Registration in p10k Config
`home/dot_p10k.zsh` SHALL register the `claude_env` segment in the right-prompt elements list and SHALL host the `zsh-claude-env` plugin's display-preference settings as plain, hand-edited variables — the same way every other Powerlevel10k tuning parameter in that file is configured.

#### Scenario: Position in element list
- **WHEN** `dot_p10k.zsh` is rendered
- **THEN** `claude_env` SHALL appear in `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` between `aws` and `context`
- **AND** the addition SHALL be wrapped in marker comments `# === BEGIN claude-env segment registration ===` and `# === END ===` to survive future `p10k configure` regenerations

#### Scenario: No POWERLEVEL9K_CLAUDE_ENV_* variables required
- **WHEN** the segment renders
- **THEN** its color/behavior logic SHALL be controlled entirely by the `zsh-claude-env` plugin
- **AND** SHALL NOT require any `POWERLEVEL9K_CLAUDE_ENV_*`-namespaced variable in `dot_p10k.zsh`

#### Scenario: Plugin display settings hosted as plain dot_p10k.zsh variables
- **WHEN** `dot_p10k.zsh` is edited to configure the plugin
- **THEN** `CLAUDE_ENV_COLORS` and `CLAUDE_ENV_SHOW_DEFAULT` SHALL be set there as plain `typeset -gA`/`typeset -g` assignments, not chezmoi-templated
- **AND** these settings SHALL be safe to read only at prompt-render time (inside `prompt_claude_env()`), never at plugin-load time, since `dot_p10k.zsh` is sourced after oh-my-zsh loads the plugin
- **AND** no `CLAUDE_ENV_DEFAULT` variable SHALL exist — the plugin determines its own default baseline from whichever `CLAUDE_CONFIG_DIR` was already exported (per `Default Environment via Exported Variable`) at the plugin's own load time

#### Scenario: Show/hide-on-default toggle
- **WHEN** `CLAUDE_ENV_SHOW_DEFAULT` is `false`, and the active environment's label equals the label captured at plugin-load time
- **THEN** the `claude_env` segment SHALL render nothing
- **AND** switching to any other environment SHALL make the segment reappear immediately

#### Scenario: Settings absent means unchanged legacy behavior
- **WHEN** neither `CLAUDE_ENV_COLORS` nor `CLAUDE_ENV_SHOW_DEFAULT` is set in `dot_p10k.zsh`
- **THEN** the plugin SHALL fall back to built-in defaults (no color overrides, `CLAUDE_ENV_SHOW_DEFAULT` treated as `true`)
- **AND** the segment SHALL always show once an environment is active, matching the original pre-toggle behavior

#### Scenario: No default captured when CLAUDE_CONFIG_DIR was unset at load time
- **WHEN** `CLAUDE_CONFIG_DIR` was empty/unset at the moment the plugin loaded (no `claude_default` configured, and no other export reached the shell)
- **THEN** `CLAUDE_ENV_SHOW_DEFAULT=false` SHALL have no effect, since there is no captured baseline label to hide against
- **AND** the segment SHALL always show once an environment becomes active later in the session

### Requirement: Shared Skills Directory via Symlink
Every declared Claude environment directory SHALL contain a `skills/` entry that is a symbolic link pointing to `~/.claude/skills/`, ensuring all locally-managed and npm-installed skills are available regardless of the active `CLAUDE_CONFIG_DIR`.

#### Scenario: Skills symlink present in every env dir
- **WHEN** `chezmoi apply` completes on a machine with `ai` tag and a non-empty `claude_envs`
- **THEN** for each entry `~/.claude-<name>` in `claude_envs`, the path `~/.claude-<name>/skills` SHALL be a symbolic link
- **AND** the symlink SHALL resolve to `~/.claude/skills`

#### Scenario: Skills accessible in a non-default environment
- **WHEN** Claude Code is launched with `CLAUDE_CONFIG_DIR=~/.claude-personal`
- **THEN** it SHALL read skills from `~/.claude-personal/skills/`
- **AND** because `~/.claude-personal/skills` is a symlink to `~/.claude/skills`, all locally-managed skills SHALL be available

#### Scenario: Skills installed to any environment land in the shared location
- **WHEN** a skill is written to `~/.claude-<name>/skills/<skill-name>` (e.g., by `npx skills add` with that env's `CLAUDE_CONFIG_DIR`)
- **THEN** the write SHALL resolve through the symlink and create `~/.claude/skills/<skill-name>`
- **AND** the skill SHALL become immediately visible in every other environment without any additional action

#### Scenario: Symlink source managed by chezmoi
- **WHEN** the chezmoi source state for an env dir contains `symlink_skills.tmpl`
- **THEN** the template SHALL render to the absolute path `<home>/.claude/skills`
- **AND** chezmoi SHALL manage the symlink lifecycle (creation and updates)

### Requirement: Shared Rules Directory via Symlink
Every declared Claude environment directory SHALL contain a `rules/` entry that is a symbolic link pointing to `~/.claude/rules/`, ensuring all locally-managed rules are available regardless of the active `CLAUDE_CONFIG_DIR`.

#### Scenario: Rules symlink present in every env dir
- **WHEN** `chezmoi apply` completes on a machine with the `ai` tag and a non-empty `claude_envs`
- **THEN** for each entry `~/.claude-<name>` in `claude_envs`, the path `~/.claude-<name>/rules` SHALL be a symbolic link
- **AND** the symlink SHALL resolve to `~/.claude/rules`

#### Scenario: Rules accessible in a non-default environment
- **WHEN** Claude Code is launched with `CLAUDE_CONFIG_DIR=~/.claude-personal`
- **THEN** it SHALL read rules from `~/.claude-personal/rules/`
- **AND** because `~/.claude-personal/rules` is a symlink to `~/.claude/rules`, all locally-managed rules SHALL be available

#### Scenario: Rules added to the shared location land in every environment
- **WHEN** a rule file is added to `~/.claude/rules/`
- **THEN** it SHALL become immediately visible in every persona's `rules/` symlink without any additional action

#### Scenario: Symlink source managed by chezmoi
- **WHEN** the chezmoi source state for an env dir contains `symlink_rules.tmpl`
- **THEN** the template SHALL render to the absolute path `<home>/.claude/rules`
- **AND** chezmoi SHALL manage the symlink lifecycle (creation and updates)

