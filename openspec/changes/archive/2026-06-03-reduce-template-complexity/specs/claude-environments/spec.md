## MODIFIED Requirements

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

#### Scenario: Color coding by environment — data driven
- **WHEN** the partial is rendered
- **THEN** the env-to-color mapping SHALL be read from `claude_env_colors` in the active machine's config (via `machine-settings`)
- **AND** if `claude_env_colors` is not set for the active machine, the partial SHALL use built-in defaults equivalent to: `work → 33`, `personal → 76`, `bedrock → 208`, `(any other) → 244`
- **AND** adding a new environment to `claude_envs` SHALL NOT require editing the partial — only adding the env to `claude_env_colors` in `config.yaml` is needed

#### Scenario: Unknown environment suffix
- **WHEN** the suffix is not found in `claude_env_colors` (or the built-in defaults)
- **THEN** the segment SHALL render in p10k color 244 (grey) and display the basename verbatim

#### Scenario: Instant prompt compatibility
- **WHEN** `POWERLEVEL9K_INSTANT_PROMPT` is `verbose` or `quiet`
- **THEN** the segment SHALL render in instant prompt with the same value and color as the regular prompt
- **AND** SHALL NOT cause an instant-prompt warning
