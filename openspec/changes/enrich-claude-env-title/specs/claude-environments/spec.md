## MODIFIED Requirements

### Requirement: Terminal Title Hook
The partial SHALL emit an OSC-0 sequence on every prompt, in both zsh and bash, that sets the terminal window title to an additive, structured string combining the active Claude environment label, git repository and branch context (when available), and the current foreground job or command name — gracefully omitting any segment that is unavailable.

Segments SHALL be ordered general to specific (env label, repo, branch, job) and SHALL be joined by a single uniform separator, the middot surrounded by spaces (` · `), so the title reads as one flat hierarchy. The ordering exists so that a truncated tab label retains the segments that identify *which* terminal this is, discarding only the most volatile segment.

#### Scenario: zsh precmd title hook (idle)
- **WHEN** the partial is sourced by zsh and no command is currently running
- **THEN** it SHALL register a `precmd` function that emits an OSC-0 title built from the env label, git context, and the shell name (e.g. `zsh`) as the job segment
- **AND** SHALL emit a title with the env-label segment omitted when `CLAUDE_CONFIG_DIR` is unset

#### Scenario: zsh preexec title hook (running command)
- **WHEN** the partial is sourced by zsh and the user runs a command
- **THEN** it SHALL register a `preexec` function that emits an OSC-0 title built from the env label, git context, and the first word of the about-to-run command as the job segment
- **AND** the title SHALL update again to the idle form once the command completes and the next prompt is drawn

#### Scenario: bash PROMPT_COMMAND title hook (idle only)
- **WHEN** the partial is sourced by bash
- **THEN** it SHALL append a command to `PROMPT_COMMAND` that emits an OSC-0 title built from the env label, git context, and the literal shell name (`bash`) as the job segment
- **AND** SHALL preserve any pre-existing `PROMPT_COMMAND` value
- **AND** bash SHALL NOT track a live running-command name (no preexec-equivalent hook is used)

#### Scenario: Env label disambiguated with a `✳` marker
- **WHEN** `CLAUDE_CONFIG_DIR` is `$HOME/.claude-work`
- **THEN** the title's env-label segment SHALL render as `✳ work`
- **AND** SHALL NOT render as the bare word `work`
- **AND** the `✳` marker SHALL match the glyph Claude Code itself uses in its OSC-0 title, so shell-set and Claude-set titles read as one family

#### Scenario: Git repository and branch included when available (zsh, gitstatus reuse)
- **WHEN** the shell is zsh, the current directory is inside a git working tree, and Powerlevel10k's gitstatus plugin has already populated `$VCS_STATUS_WORKDIR` and `$VCS_STATUS_LOCAL_BRANCH` for the current prompt
- **THEN** the title SHALL include repo and branch as two adjacent segments, `<repo> · <branch>`, where `<repo>` is the basename of `$VCS_STATUS_WORKDIR` and `<branch>` is `$VCS_STATUS_LOCAL_BRANCH`
- **AND** the partial SHALL NOT invoke an additional `git` subprocess to obtain this information

#### Scenario: Git repository and branch included via fallback (bash, or gitstatus not yet populated)
- **WHEN** the shell is bash, or the shell is zsh but `$VCS_STATUS_WORKDIR` is empty (e.g. gitstatus has not run yet, or the `vcs` segment is disabled)
- **AND** the current directory is inside a git working tree
- **THEN** the partial SHALL determine repo and branch via `git rev-parse --show-toplevel` and `git branch --show-current`
- **AND** SHALL include the same `<repo> · <branch>` segment form as the gitstatus-reuse path

#### Scenario: Detached HEAD or no branch
- **WHEN** the current directory is inside a git working tree but no branch name is available (e.g. detached HEAD)
- **THEN** the title SHALL include the repo name alone (`<repo>`) with the branch segment and its separator omitted

#### Scenario: Non-git directory
- **WHEN** the current directory is not inside any git working tree
- **THEN** the title SHALL omit the repo and branch segments entirely
- **AND** SHALL NOT render a leading, trailing, or doubled ` · ` separator

#### Scenario: All segments present
- **WHEN** `CLAUDE_CONFIG_DIR` is set, the shell is inside a git repository with a branch, and a job/command name is available
- **THEN** the emitted title SHALL be exactly `✳ <label> · <repo> · <branch> · <job>`

#### Scenario: Only job segment present
- **WHEN** `CLAUDE_CONFIG_DIR` is unset and the current directory is not inside a git working tree
- **THEN** the emitted title SHALL be exactly `<job>` with no leading or trailing separator

#### Scenario: Stand down when the terminal manages its own titles
- **WHEN** `$GHOSTTY_SHELL_FEATURES` contains `title` (the terminal's own shell integration is already writing titles every prompt — e.g. inside cmux, which embeds Ghostty)
- **THEN** the partial SHALL NOT register its `precmd`/`preexec` hooks in zsh, and SHALL NOT append to `PROMPT_COMMAND` in bash
- **AND** the terminal's native title behavior SHALL be left intact, rather than raced by a second writer whose winner depends on hook ordering
- **AND** the `prompt_claude_env` p10k segment and the `claude-env` command SHALL continue to work normally, so the active environment is still visible at the prompt

#### Scenario: Take over when no other writer is active
- **WHEN** `$GHOSTTY_SHELL_FEATURES` is unset, or is set but does not contain `title`
- **THEN** the partial SHALL register its title hooks as normal
- **AND** the condition SHALL be evaluated on that feature flag rather than on terminal identity, so disabling the terminal's own title integration hands title management back to this partial

## REMOVED Requirements

### Requirement: Title reflects suffix only
**Reason**: Superseded by the structured, additive title format above — showing only the bare suffix (e.g. `personal`) was found to be ambiguous with same-named directories and to discard information the terminal would otherwise show by default (foreground job/command, git context).
**Migration**: No action required; the new title format is a superset that still conveys the environment, now disambiguated as the leading `✳ <label>` segment instead of the bare suffix.
