# Claude Environments

## Purpose
The Claude environments system provides a unified, single-source-of-truth shell wiring for Claude Code multi-environment support, allowing users to invoke Claude with different configuration directories via named shell functions and aliases, with optional GUI session inheritance on macOS.
## Requirements
### Requirement: Centralized Claude Environment Definitions
The Claude Code multi-environment shell wiring SHALL be defined in exactly one place: a chezmoi template partial at `home/.chezmoitemplates/claude-environments`.

#### Scenario: Single source of truth
- **WHEN** the user wants to modify Claude Code environment functions or aliases
- **THEN** the change SHALL be made only in `home/.chezmoitemplates/claude-environments`
- **AND** SHALL be inherited automatically by both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl`

#### Scenario: Tag-gated activation
- **WHEN** the partial is included by an rc template
- **THEN** the partial SHALL emit no shell code unless `"ai"` is in the user's `tags`

#### Scenario: Self-contained partial
- **WHEN** an rc template calls `{{ includeTemplate "claude-environments" . }}`
- **THEN** the call site SHALL NOT need to add a separate `if has "ai" .tags` guard
- **AND** the partial SHALL handle internal gating

### Requirement: Template-Render-Time Validation of Claude Environment Configuration
The `claude-environments` partial SHALL validate the active machine's `claude_envs` and `claude_default` settings at template-render time and SHALL fail the render with a precise error when validation fails.

#### Scenario: Non-conforming claude_envs entry
- **WHEN** any entry in `claude_envs` for the active machine does not start with `~/.claude-`
- **THEN** rendering the partial SHALL fail
- **AND** the failure message SHALL identify `claude_envs` and the offending entry verbatim

#### Scenario: claude_default not in claude_envs
- **WHEN** `claude_default` for the active machine is set
- **AND** `claude_default` is not equal to `claude-<name>` for any `<name>` derived from `claude_envs`
- **THEN** rendering the partial SHALL fail
- **AND** the failure message SHALL identify `claude_default`, its current value, and the derived list of valid names

#### Scenario: claude_default unset
- **WHEN** the active machine has no `claude_default` set
- **THEN** the partial SHALL NOT validate `claude_default`
- **AND** rendering SHALL succeed regardless of `claude_envs` content

#### Scenario: Validation runs in every render path
- **WHEN** `chezmoi apply`, `chezmoi diff`, `chezmoi cat`, or `chezmoi execute-template` renders the partial
- **THEN** the same validation SHALL run
- **AND** any of those commands SHALL surface the same failure message on misconfiguration

### Requirement: Per-Environment Shell Functions
The partial SHALL define one shell function per Claude environment in the active machine's `claude_envs` list. Each function SHALL invoke `claude` with `CLAUDE_CONFIG_DIR` set to that environment's path for the duration of one invocation. Before invoking `claude`, each function SHALL also, if present, source a local per-environment env file (`~/.config/claude-env/<name>.env`) with its effect scoped to that one invocation only.

#### Scenario: Function generated per claude_envs entry
- **WHEN** the active machine's `claude_envs` contains `~/.claude-<name>`
- **THEN** the partial SHALL define a shell function `claude-<name>`
- **AND** the function SHALL invoke `command claude "$@"` with `CLAUDE_CONFIG_DIR=$HOME/.claude-<name>`
- **AND** the assignment SHALL apply only to that invocation

#### Scenario: Function omitted for environments not in claude_envs
- **WHEN** a name `<x>` is not present in the active machine's `claude_envs`
- **THEN** the partial SHALL NOT define `claude-<x>`
- **AND** typing `claude-<x>` SHALL produce a `command not found` error from the shell

#### Scenario: Override exported default
- **WHEN** `CLAUDE_CONFIG_DIR` is exported to one path and the user runs an environment function for a different env
- **THEN** the function's inline assignment SHALL shadow the exported value for that one process
- **AND** the parent shell's exported value SHALL remain unchanged

#### Scenario: Empty claude_envs
- **WHEN** the active machine has the `ai` tag but `claude_envs` is empty or missing
- **THEN** the partial SHALL define no per-environment functions
- **AND** the partial SHALL render successfully

#### Scenario: Local env file sourced before invocation
- **WHEN** `~/.config/claude-env/<name>.env` exists at the time `claude-<name>` is invoked
- **THEN** the function SHALL source that file before invoking `claude`
- **AND** every variable the file exports SHALL be present in the `claude` process's environment

#### Scenario: Missing env file is a no-op
- **WHEN** `~/.config/claude-env/<name>.env` does not exist
- **THEN** the function SHALL invoke `claude` without attempting to source any file
- **AND** SHALL NOT error or print a warning

#### Scenario: Sourced variables do not leak into the calling shell
- **WHEN** `claude-<name>` sources `~/.config/claude-env/<name>.env` and the resulting `claude` process later exits
- **THEN** none of the variables exported by that file SHALL be present in the parent interactive shell's environment
- **AND** any `CLAUDE_CONFIG_DIR` exported in the parent shell SHALL also remain unchanged

#### Scenario: Env file location is derived from the environment name
- **WHEN** `claude_envs` contains `~/.claude-<name>`
- **THEN** the function SHALL look for its local env file at exactly `~/.config/claude-env/<name>.env`
- **AND** SHALL NOT read env files belonging to other environments

#### Scenario: Env file is untracked and machine-local
- **WHEN** the `claude-environments` partial is rendered by `chezmoi apply`, `chezmoi diff`, or `chezmoi execute-template`
- **THEN** no content of any `~/.config/claude-env/<name>.env` file SHALL be read from or written to chezmoi source state
- **AND** the file SHALL be created and maintained directly by the user on each machine, outside chezmoi's management

### Requirement: Default Environment via Exported Variable
When the active machine declares a `claude_default` in `home/.chezmoidata/config.yaml`, the partial SHALL export `CLAUDE_CONFIG_DIR` to the corresponding path.

#### Scenario: Machine with claude_default set
- **WHEN** the active machine's pattern in `config.yaml` has `claude_default: claude-work`
- **THEN** the partial SHALL emit `export CLAUDE_CONFIG_DIR="$HOME/.claude-work"`

#### Scenario: Machine without claude_default
- **WHEN** the active machine's pattern in `config.yaml` has no `claude_default` key (e.g., Mac mini)
- **THEN** the partial SHALL NOT emit an export statement
- **AND** the default behavior of `claude` SHALL be the binary's built-in fallback (`~/.claude`)

#### Scenario: No alias for bare claude
- **WHEN** the partial is rendered for a machine with `claude_default` set
- **THEN** the partial SHALL NOT define an alias for `claude`
- **AND** the bare `claude` command SHALL invoke the binary directly with the inherited environment

### Requirement: SpecStory Wrappers
The partial SHALL define `*-spec` shell functions (not aliases) that wrap each Claude environment, and other AI CLIs, in `specstory run <cli> --no-cloud-sync`. Per-environment functions SHALL be generated from the active machine's `claude_envs` list. All `*-spec` functions SHALL forward extra arguments via `"$@"`.

#### Scenario: Default spec function
- **WHEN** the partial is rendered
- **THEN** it SHALL define a shell function `claude-spec` whose body invokes `specstory run claude --no-cloud-sync "$@"`
- **AND** the function SHALL inherit any exported `CLAUDE_CONFIG_DIR` rather than re-asserting it
- **AND** `type claude-spec` SHALL report it as a function

#### Scenario: Per-environment spec function generated per claude_envs entry
- **WHEN** the active machine's `claude_envs` contains `~/.claude-<name>`
- **THEN** the partial SHALL define a shell function `claude-<name>-spec` whose body invokes `specstory run claude --no-cloud-sync "$@"` with `CLAUDE_CONFIG_DIR=$HOME/.claude-<name>` set as a single-command assignment
- **AND** the parent shell's `CLAUDE_CONFIG_DIR` SHALL NOT be modified
- **AND** `type claude-<name>-spec` SHALL report it as a function

#### Scenario: Per-environment spec function omitted for environments not in claude_envs
- **WHEN** a name `<x>` is not present in the active machine's `claude_envs`
- **THEN** the partial SHALL NOT define `claude-<x>-spec`

#### Scenario: Other tool spec functions
- **WHEN** the partial is rendered
- **THEN** it SHALL define shell functions `codex-spec` and `gemini-spec`
- **AND** each function body SHALL invoke `specstory run <cli> --no-cloud-sync "$@"` with `<cli>` being `codex` or `gemini` respectively

#### Scenario: Argument forwarding
- **WHEN** the user runs `claude-spec <arg1> <arg2>` (or any `*-spec` function with extra arguments)
- **THEN** the resulting command line SHALL be `specstory run <cli> --no-cloud-sync <arg1> <arg2>`
- **AND** quoting and word-splitting SHALL be preserved as if the function were called by a normal shell function with `"$@"`

#### Scenario: Available in non-interactive shells
- **WHEN** the partial has been sourced (e.g., via `~/.bashrc` or `~/.zshrc`) in a shell where alias expansion is disabled (such as bash without `expand_aliases` set)
- **THEN** `*-spec` invocations SHALL still resolve and execute correctly
- **AND** SHALL produce the same command line as in an interactive shell

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
Both `home/dot_zshrc.tmpl` and `home/dot_bashrc.tmpl` SHALL include the partial via a single `includeTemplate` call.

#### Scenario: zsh integration
- **WHEN** `home/dot_zshrc.tmpl` is rendered
- **THEN** it SHALL contain exactly one call: `{{ includeTemplate "claude-environments" . }}`
- **AND** the previous duplicated Claude block SHALL be removed

#### Scenario: bash integration
- **WHEN** `home/dot_bashrc.tmpl` is rendered
- **THEN** it SHALL contain exactly one call: `{{ includeTemplate "claude-environments" . }}`
- **AND** the previous duplicated Claude block SHALL be removed

#### Scenario: Identical Claude wiring across shells
- **WHEN** both rc files are rendered for the same machine
- **THEN** the Claude environment functions, exports, and aliases SHALL be byte-identical between them

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
The partial SHALL emit an OSC-0 sequence on every prompt, in both zsh and bash, that sets the terminal window title to an additive, structured string combining the active Claude environment label, git repository and branch context (when available), and the current foreground job or command name — gracefully omitting any segment that is unavailable.

Segments SHALL be ordered general to specific (env label, repo, branch, job) and SHALL be joined by a single uniform separator, the middot surrounded by spaces (` · `), so the title reads as one flat hierarchy. The ordering exists so that a truncated tab label retains the segments that identify *which* terminal this is, discarding only the most volatile segment.

This requirement supersedes two behaviours of its previous form. The title is no longer the bare env suffix (e.g. `personal`), which was ambiguous with a same-named directory and discarded the job/git context the terminal would otherwise show; it is now the structured string above, of which the environment is one segment. The title also no longer clears to an empty string when `CLAUDE_CONFIG_DIR` is unset — the env-label segment is omitted and the remaining segments are still emitted, so an unconfigured shell keeps a useful title rather than falling back to the terminal default. No migration is required in either case.

#### Scenario: zsh precmd title hook
- **WHEN** the partial is sourced by zsh and no command is currently running
- **THEN** it SHALL register a `precmd` function that emits an OSC-0 title built from the env label, git context, and the shell name (e.g. `zsh`) as the job segment
- **AND** SHALL emit a title with the env-label segment omitted when `CLAUDE_CONFIG_DIR` is unset

#### Scenario: zsh preexec title hook (running command)
- **WHEN** the partial is sourced by zsh and the user runs a command
- **THEN** it SHALL register a `preexec` function that emits an OSC-0 title built from the env label, git context, and the first word of the about-to-run command as the job segment
- **AND** the title SHALL update again to the idle form once the command completes and the next prompt is drawn

#### Scenario: bash PROMPT_COMMAND title hook
- **WHEN** the partial is sourced by bash
- **THEN** it SHALL append a command to `PROMPT_COMMAND` that emits an OSC-0 title built from the env label, git context, and the literal shell name (`bash`) as the job segment
- **AND** SHALL preserve any pre-existing `PROMPT_COMMAND` value
- **AND** bash SHALL NOT track a live running-command name (no preexec-equivalent hook is used)

#### Scenario: Env label disambiguated with a `✳` marker
- **WHEN** `CLAUDE_CONFIG_DIR` is `$HOME/.claude-work`
- **THEN** the title's env-label segment SHALL render as `✳ work`
- **AND** SHALL NOT render as the bare word `work`
- **AND** the `✳` marker SHALL match the glyph Claude Code itself uses in its OSC-0 title, so shell-set and Claude-set titles read as one family

#### Scenario: Title reflects suffix only
- **WHEN** `CLAUDE_CONFIG_DIR` is `$HOME/.claude-personal`
- **THEN** this behaviour SHALL no longer apply — the emitted title SHALL NOT be the bare suffix `personal`
- **AND** the environment SHALL instead appear as the leading `✳ personal` segment of the structured title
- **AND** no migration SHALL be required, the structured title being a superset of the old one

#### Scenario: Title clears when env unset
- **WHEN** `CLAUDE_CONFIG_DIR` is unset between prompts
- **THEN** this behaviour SHALL no longer apply — the title SHALL NOT be cleared to an empty string
- **AND** the env-label segment SHALL be omitted while the remaining segments are still emitted, so the shell keeps a useful title instead of falling back to the terminal default

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

#### Scenario: Compatibility with cmux tab labels
- **WHEN** `$GHOSTTY_SHELL_FEATURES` contains `title` (the terminal's own shell integration is already writing titles every prompt — e.g. inside cmux, which embeds Ghostty)
- **THEN** the partial SHALL NOT register its `precmd`/`preexec` hooks in zsh, and SHALL NOT append to `PROMPT_COMMAND` in bash
- **AND** the terminal's native title behavior SHALL be left intact, rather than raced by a second writer whose winner depends on hook ordering
- **AND** the `prompt_claude_env` p10k segment and the `claude-env` command SHALL continue to work normally, so the active environment is still visible at the prompt

#### Scenario: Take over when no other writer is active
- **WHEN** `$GHOSTTY_SHELL_FEATURES` is unset, or is set but does not contain `title`
- **THEN** the partial SHALL register its title hooks as normal
- **AND** the condition SHALL be evaluated on that feature flag rather than on terminal identity, so disabling the terminal's own title integration hands title management back to this partial

### Requirement: Session Environment Switcher
The partial SHALL define a `claude-env` shell function that switches `CLAUDE_CONFIG_DIR` for the current shell session and refreshes the prompt. The function's accepted arguments SHALL be derived from the active machine's `claude_envs` list at template-render time.

#### Scenario: Switch to an environment present in claude_envs
- **WHEN** the user runs `claude-env <name>` and `~/.claude-<name>` is in the active machine's `claude_envs`
- **THEN** `CLAUDE_CONFIG_DIR` SHALL be exported as `$HOME/.claude-<name>` in the current shell
- **AND** in zsh, `p10k reload` SHALL be called so the prompt segment updates immediately

#### Scenario: Show current environment
- **WHEN** the user runs `claude-env` with no arguments
- **THEN** the function SHALL print the active environment label (e.g., `work`) to stdout
- **AND** SHALL print `(none)` if `CLAUDE_CONFIG_DIR` is unset

#### Scenario: Argument not in claude_envs
- **WHEN** the user runs `claude-env <x>` and `~/.claude-<x>` is not in the active machine's `claude_envs`
- **THEN** the function SHALL NOT modify `CLAUDE_CONFIG_DIR`
- **AND** the function SHALL print a usage message to stderr listing the names derived from `claude_envs`
- **AND** SHALL return exit code 1

#### Scenario: Empty claude_envs
- **WHEN** the active machine has the `ai` tag but `claude_envs` is empty or missing
- **THEN** the function's accepted-arguments set SHALL be empty
- **AND** any non-empty argument SHALL fall through to the usage-message branch
- **AND** the usage message SHALL list no valid names

#### Scenario: Available in both shells
- **WHEN** the partial is sourced by bash
- **THEN** `claude-env` SHALL be available and SHALL switch `CLAUDE_CONFIG_DIR`
- **AND** SHALL NOT attempt to call `p10k reload` (bash has no p10k)

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

### Requirement: Transition from Real Directory to Symlink
On machines where Claude Code has previously auto-created a real `skills/` directory inside an environment directory, chezmoi apply SHALL replace that directory with the managed symlink without manual intervention.

#### Scenario: Automated removal of real skills directory before symlink placement
- **WHEN** `chezmoi apply` runs and `~/.claude-<name>/skills` exists as a non-symlink directory
- **THEN** a `run_onchange_before` script SHALL remove that directory before chezmoi attempts to place the symlink
- **AND** the script SHALL log a message identifying the directory being removed

#### Scenario: Transition is idempotent
- **WHEN** the transition script runs and `~/.claude-<name>/skills` is already a symlink (from a prior apply)
- **THEN** the script SHALL skip that entry without error
- **AND** `chezmoi apply` SHALL complete successfully

#### Scenario: Missing environment directory is skipped
- **WHEN** the transition script runs and `~/.claude-<name>` does not yet exist on disk
- **THEN** the script SHALL skip that environment without error

