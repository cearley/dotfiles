## REMOVED Requirements

### Requirement: Centralized Claude Environment Definitions
**Reason**: The "single chezmoi partial" model is replaced by a fully self-contained external plugin (`zsh-claude-env`) that needs no chezmoi-rendered definitions at all. Chezmoi's remaining involvement (a `.chezmoiexternal.toml.tmpl` entry, a `plugins=()` registration, and a `dot_p10k.zsh` settings block) is described by the updated `rc File Integration` and `Right-Prompt Registration in p10k Config` requirements below.
**Migration**: None required for end-user behavior. Anyone who previously edited `home/.chezmoitemplates/claude-environments` to change environment wiring now edits the `zsh-claude-env` plugin repository instead.

### Requirement: Template-Render-Time Validation of Claude Environment Configuration
**Reason**: This validation (the `~/.claude-<name>` shape check on each `claude_envs` entry, and the `claude_default`-must-be-a-member cross-check) lived only inside `claude-environments`, which is deleted. `claude_envs` and `claude_default` themselves remain in active use elsewhere — by `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, `-39-install-claude-plugins.sh.tmpl`, `dot_session-index/config.json.tmpl`, and the LaunchAgent (none of which this change touches, and none of which perform this validation themselves) — but the validation that used to incidentally protect them is not replaced. This is an accepted regression, not a "nothing left to validate" situation: `for_each_claude_env` (in `scripts/shared-utils.sh`) already silently skips any declared entry whose directory doesn't exist, which is judged sufficient — a malformed or undeclared entry degrades to a quiet no-op identically across every consumer rather than corrupting anything.
**Migration**: None. A malformed or undeclared `claude_envs` entry no longer fails `chezmoi apply` with a precise error message; it silently produces no effect anywhere it's consumed. Users are expected to notice via the environment simply not working, not via a render-time failure.

### Requirement: Per-Environment Shell Functions
**Reason**: Wrapper-function generation (`claude-<name>`) moves entirely into the `zsh-claude-env` plugin, which generates them at shell-init time from a filesystem glob of `$HOME/.claude-*` directories rather than from a chezmoi-rendered list. This is now purely plugin behavior, documented in the plugin's own README, not tracked by this repo's specs.
**Migration**: None for zsh users with the plugin installed — the generated functions behave the same way (env-file sourcing, invocation scoping). Bash users lose these functions entirely with no replacement; see the proposal's BREAKING notes.

### Requirement: SpecStory Wrappers
**Reason**: These wrapper functions (`claude-spec`, `codex-spec`, `gemini-spec`, `claude-<name>-spec`) move entirely into the `zsh-claude-env` plugin, generated from the same filesystem glob used for the per-environment `claude-<name>` functions. This is now plugin behavior, not chezmoi behavior.
**Migration**: None for zsh users with the plugin installed. Bash users lose these functions entirely with no replacement.

### Requirement: Powerlevel10k Active-Environment Segment
**Reason**: The segment's function definitions (`prompt_claude_env`, `instant_prompt_claude_env`) move entirely into the `zsh-claude-env` plugin. Chezmoi's only remaining involvement with the segment — registering it in `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` and hosting its display-preference settings — is covered by the updated `Right-Prompt Registration in p10k Config` requirement below, which also gains the show/hide-on-default behavior that motivated this whole change.
**Migration**: None for end-user behavior (suffix display, color coding, instant-prompt compatibility all carry over into the plugin unchanged); the new show/hide-on-default toggle is additive. Segment definitions are no longer chezmoi-rendered Go-template output — configuration is via plain `dot_p10k.zsh` variables the plugin reads, documented in the plugin's own README.

### Requirement: Terminal Title Hook
**Reason**: The OSC-0 terminal-title feature (git-context reuse, Ghostty double-writer avoidance, structured title format) moves entirely into the `zsh-claude-env` plugin, now independently toggleable via a plugin-owned `CLAUDE_ENV_TITLE_HOOKS` variable checked at hook-invocation time (safe to set in `dot_p10k.zsh` despite it loading after the plugin, since hooks are always registered and each checks the toggle when it fires, not at registration time).
**Migration**: None for zsh users with the plugin installed — title format and Ghostty-compatibility behavior are unchanged. Bash users lose this feature entirely with no replacement.

### Requirement: Session Environment Switcher
**Reason**: The `claude-env` switcher function moves entirely into the `zsh-claude-env` plugin, with its accepted-argument set validated at runtime against the same filesystem glob used for wrapper-function generation, rather than against a chezmoi-rendered list at template-render time.
**Migration**: None for zsh users with the plugin installed — switch/print-current/usage-on-invalid-argument behavior is unchanged. Bash users lose this function entirely with no replacement.

## MODIFIED Requirements

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
