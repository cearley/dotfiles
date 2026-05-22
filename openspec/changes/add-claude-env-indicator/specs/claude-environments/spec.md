## ADDED Requirements

### Requirement: Powerlevel10k Active-Environment Segment
The partial SHALL define a Powerlevel10k user segment named `claude_env` that displays a short, color-coded label for the active Claude environment in zsh interactive shells.

#### Scenario: Segment definition in partial
- **WHEN** the partial is rendered for a zsh shell
- **THEN** the partial SHALL define a function `prompt_claude_env`
- **AND** SHALL define a paired `instant_prompt_claude_env` function
- **AND** both SHALL be defined inside a `if [ -n "$ZSH_VERSION" ]; then ... fi` guard so bash sourcing is unaffected

#### Scenario: Segment hidden when env unset
- **WHEN** `CLAUDE_CONFIG_DIR` is empty or unset
- **THEN** `prompt_claude_env` SHALL emit no segment
- **AND** the right prompt SHALL render as if the segment were not registered

#### Scenario: Segment hidden on non-ai machines
- **WHEN** the active machine does not have `"ai"` in its tags
- **THEN** the partial SHALL emit no segment definition
- **AND** the registration in `dot_p10k.zsh` SHALL still be present but inert (the segment function is undefined, p10k handles missing functions gracefully)

#### Scenario: Suffix-only display
- **WHEN** `CLAUDE_CONFIG_DIR` is `$HOME/.claude-work`
- **THEN** the segment SHALL display the text `work`
- **AND** SHALL NOT display the path or the `claude-` prefix

#### Scenario: Color coding by environment
- **WHEN** the suffix is `work`
- **THEN** the segment SHALL render in p10k color 33 (blue)
- **WHEN** the suffix is `personal`
- **THEN** the segment SHALL render in p10k color 76 (green)
- **WHEN** the suffix is `bedrock`
- **THEN** the segment SHALL render in p10k color 208 (orange)
- **WHEN** the suffix is anything else (custom directory)
- **THEN** the segment SHALL render in p10k color 244 (grey) and display the basename verbatim

#### Scenario: Instant prompt compatibility
- **WHEN** `POWERLEVEL9K_INSTANT_PROMPT` is `verbose` or `quiet`
- **THEN** the segment SHALL render in instant prompt with the same value and color as the regular prompt
- **AND** SHALL NOT cause an instant-prompt warning

### Requirement: Right-Prompt Registration in p10k Config
`home/dot_p10k.zsh` SHALL register the `claude_env` segment in the right-prompt elements list.

#### Scenario: Position in element list
- **WHEN** `dot_p10k.zsh` is rendered
- **THEN** `claude_env` SHALL appear in `POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS` between `aws` and `context`
- **AND** the addition SHALL be wrapped in marker comments `# === BEGIN claude-env segment registration ===` and `# === END ===` to survive future `p10k configure` regenerations

#### Scenario: No additional p10k tuning required
- **WHEN** the segment renders
- **THEN** colors and behavior SHALL be controlled entirely by the function in the partial
- **AND** SHALL NOT require additional `POWERLEVEL9K_CLAUDE_ENV_*` variables in `dot_p10k.zsh`

### Requirement: Terminal Title Hook
The partial SHALL emit an OSC-2 sequence that sets the terminal window title to the active Claude environment suffix on every prompt, in both zsh and bash.

#### Scenario: zsh precmd title hook
- **WHEN** the partial is sourced by zsh
- **THEN** it SHALL register a `precmd` function that emits `\e]2;<suffix>\a` when `CLAUDE_CONFIG_DIR` is set
- **AND** SHALL emit nothing when `CLAUDE_CONFIG_DIR` is unset

#### Scenario: bash PROMPT_COMMAND title hook
- **WHEN** the partial is sourced by bash
- **THEN** it SHALL append a command to `PROMPT_COMMAND` that emits the same OSC-2 sequence under the same condition
- **AND** SHALL preserve any pre-existing `PROMPT_COMMAND` value

#### Scenario: Title reflects suffix only
- **WHEN** `CLAUDE_CONFIG_DIR` is `$HOME/.claude-personal`
- **THEN** the emitted title SHALL be `personal` (stripped prefix, no path)

#### Scenario: Title clears when env unset
- **WHEN** `CLAUDE_CONFIG_DIR` is unset between prompts
- **THEN** the next prompt SHALL emit `\e]2;\a` to clear the title
- **AND** host terminals SHALL render their default title

#### Scenario: Compatibility with cmux tab labels
- **WHEN** the shell runs inside a cmux pane
- **THEN** the OSC-2 emission SHALL update the cmux tab/title bar text
- **AND** SHALL coexist with any static `name` configured in `cmux.json`

### Requirement: Session Environment Switcher
The partial SHALL define a `claude-env` shell function that switches `CLAUDE_CONFIG_DIR` for the current shell session and refreshes the prompt.

#### Scenario: Switch to a known environment
- **WHEN** the user runs `claude-env work` (or `personal` or `bedrock`)
- **THEN** `CLAUDE_CONFIG_DIR` SHALL be exported as `$HOME/.claude-<name>` in the current shell
- **AND** in zsh, `p10k reload` SHALL be called so the prompt segment updates immediately

#### Scenario: Show current environment
- **WHEN** the user runs `claude-env` with no arguments
- **THEN** the function SHALL print the active environment label (e.g., `work`) to stdout
- **AND** SHALL print `(none)` if `CLAUDE_CONFIG_DIR` is unset

#### Scenario: Invalid argument
- **WHEN** the user runs `claude-env <unknown>`
- **THEN** the function SHALL print a usage message to stderr
- **AND** SHALL return exit code 1

#### Scenario: Available in both shells
- **WHEN** the partial is sourced by bash
- **THEN** `claude-env` SHALL be available and SHALL switch `CLAUDE_CONFIG_DIR`
- **AND** SHALL NOT attempt to call `p10k reload` (bash has no p10k)
