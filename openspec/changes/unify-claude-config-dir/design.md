## Context

This dotfiles repo manages three Claude Code config environments (`~/.claude-bedrock`, `~/.claude-personal`, `~/.claude-work`) selected via the `CLAUDE_CONFIG_DIR` environment variable. The current wiring lives twice — once in `home/dot_zshrc.tmpl` (lines 132–162) and once in `home/dot_bashrc.tmpl` (lines 14–48) — and pivots on a `claude` *alias* that expands to a function like `claude-work`, which in turn invokes `command claude` with a per-call `CLAUDE_CONFIG_DIR=...` prefix.

Two problems motivate this change:

1. **Launch-surface inconsistency.** Aliases and functions are interactive-shell artifacts. They do not propagate into the GUI session managed by `launchd`. When the user opens Claude-aware IDEs like JetBrains Rider from Spotlight or the Dock, those processes inherit `launchd`'s environment (which has no `CLAUDE_CONFIG_DIR`) and fall back to `~/.claude`. Terminal-launched IDEs work correctly because they inherit the shell's env. Today this asymmetry is *uniformly* wrong (everything GUI-launched is vanilla); a previously-considered "export but not via launchd" approach would have made it *split* (GUI from terminal vs. GUI from Finder differ). The user explicitly named JetBrains Rider as a real workflow that hits this surface.

2. **Template duplication.** The Claude block is byte-identical between zshrc and bashrc. Future edits must be made in two places, and divergence has already started (zshrc has machine-tag-gated extras like LM Studio paths inside the same region). A single `.chezmoitemplates/` partial — already an established pattern in this repo (`machine-config`, `machine-name`, `machine-settings`) — is the obvious fix.

A third concern surfaced during discussion: the LaunchAgent label needs a reverse-DNS prefix. Hardcoding `software.craigearley` into a checked-in data file would bake the user's personal domain into a public repo. Putting it in `home/.chezmoi.toml.tmpl` (which renders to `~/.config/chezmoi/chezmoi.toml`, never committed) keeps it personal while providing a sensible `io.github.<username>` default for fresh clones.

## Goals / Non-Goals

**Goals:**

- Make `CLAUDE_CONFIG_DIR` globally observable and inheritable across both shell-launched and GUI-launched processes on a given machine.
- Eliminate the duplicated Claude wiring between zshrc and bashrc.
- Keep per-invocation overrides (`claude-bedrock`, `claude-personal`, `claude-work`) working unchanged, so the user can cross contexts without re-exporting or shell gymnastics.
- Avoid leaking the user's personal reverse-DNS domain into checked-in repo files.
- Preserve idempotency: every script and template safely re-runs with `chezmoi apply`.

**Non-Goals:**

- Adding a prompt or status-bar indicator for the active environment. The exported variable makes this trivial to add later, but it is not part of this change.
- Cross-validating `claude_default` against `claude_envs` in `config.yaml`.
- Resolving the function-vs-alias asymmetry between base `claude-*` and `*-spec` wrappers.
- Layering direnv on top for project-bound contexts.
- Modifying behavior on machines without the `ai` tag or without a `claude_default` (Mac mini).

## Decisions

### Decision 1: Export `CLAUDE_CONFIG_DIR` instead of aliasing `claude`

**Choice:** Set `export CLAUDE_CONFIG_DIR="$HOME/.<claude_default>"` in the shared partial whenever `claude_default` is non-empty.

**Why:**

- Environment variables propagate to child processes; aliases do not. The whole point of the alias was to inject `CLAUDE_CONFIG_DIR` for one process; exporting accomplishes the same thing for *all* processes spawned from the shell.
- Subagents that Claude itself spawns (Bash tool calls, MCP servers) inherit the var automatically. The alias-of-function approach already worked here because `VAR=value command claude` puts the var in the child's env, but exporting makes the inheritance unconditional rather than contingent on routing through the wrapper.
- Per-invocation overrides via `claude-bedrock`/`claude-personal`/`claude-work` continue to work because zsh's "prefix assignment to a simple command" semantics shadow the exported value for that one invocation.

**Alternative considered: keep the alias.** Rejected because it does not fix launch-surface inconsistency and prevents future use of `${CLAUDE_CONFIG_DIR}` as a globally-readable indicator (e.g., in a Powerlevel10k segment).

**Alternative considered: direnv.** Useful for project-bound contexts but orthogonal — direnv is location-scoped, the export is invocation-scoped. Discussed and deferred. The two could coexist later.

### Decision 2: Mirror the export into the GUI session via a user LaunchAgent

**Choice:** Install `~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist` that runs `launchctl setenv CLAUDE_CONFIG_DIR <path>` at login. An activation script also runs `launchctl setenv` immediately so the live GUI session updates without a logout.

**Why:**

- Without this, `CLAUDE_CONFIG_DIR` is set in shells but absent from the GUI session managed by `launchd`. Apps launched from Spotlight/Dock/Finder (e.g., JetBrains Rider) would silently fall back to `~/.claude`, producing a *split* inconsistency: the same IDE behaves differently depending on launcher.
- `launchctl setenv` injects values into the GUI session's environment so child processes (including subsequently-launched apps) inherit them. A LaunchAgent with `RunAtLoad=true` reapplies the value on every login.
- Existing user LaunchAgents in `~/Library/LaunchAgents/` (Box, Dropbox, Google, JetBrains, Homebrew/syncthing) are all mode 644. Matching that convention keeps `launchd`'s permission heuristics happy. **Do not** apply chezmoi's `private_` prefix here.

**Alternative considered: do nothing about GUI inheritance.** Rejected because the user has confirmed Rider is launched from both terminal and Finder. Either uniformly vanilla (today's alias) or uniformly per-machine-default (LaunchAgent) is acceptable; split behavior is not.

**Alternative considered: AppleScript/login hook approach.** More fragile, deprecated in modern macOS, and would still need to run `launchctl setenv`. The plist is the canonical mechanism.

### Decision 3: Extract a `claude-environments` partial

**Choice:** Move the entire `ai`-tag-gated Claude block (functions, export, spec aliases) into `home/.chezmoitemplates/claude-environments`, gated *internally* on `has "ai" .tags`.

**Why:**

- The block is already byte-identical between zshrc and bashrc; deduplication is mechanical.
- Internal gating means call sites are a single line `{{ includeTemplate "claude-environments" . }}` and the partial is self-contained. This matches `machine-config`'s self-contained design.
- Naming follows the mental model ("which Claude environment is active") rather than mechanism ("aliases and functions").

**Alternative considered: gate at the call site.** Marginally more consistent with how `dev`-tag blocks are gated in zshrc, but it would force every caller to remember the tag check. Rejected for ergonomics.

### Decision 4: Move `reverse_dns` to `.chezmoi.toml.tmpl`, not `.chezmoidata/`

**Choice:** Add a `promptStringOnce` for `reverse_dns` to `home/.chezmoi.toml.tmpl` with default `io.github.<gh_username>`. Reference as `{{ .reverse_dns }}`.

**Why:**

- `.chezmoidata/` files are checked into the repo. Hardcoding `software.craigearley` would leak a personal domain into a public-facing dotfiles repo and force every cloner to remember to override it.
- `.chezmoi.toml.tmpl` renders to `~/.config/chezmoi/chezmoi.toml`, which lives outside the repo. The user is prompted once on first init (or via `chezmoi init` after a pull) and the answer is stored locally.
- Existing identity values in this repo (`fullname`, `gh_username`, `keepassxc_db`, etc.) already follow this pattern. The new `reverse_dns` belongs in the same group.

**Alternative considered: `home/.chezmoidata/identity.yaml`.** Rejected on the leak/portability grounds above. The `.chezmoidata/` convention is fine for project constants, not personal ones.

### Decision 5: Convert `.chezmoiignore` to `.chezmoiignore.tmpl`

**Choice:** Rename `home/.chezmoiignore` → `home/.chezmoiignore.tmpl` and add a conditional stanza that excludes the LaunchAgent plist when `claude_default` is empty.

**Why:**

- chezmoi will render the plist template even when `claude_default` is empty, producing a malformed plist. Ignoring the file when not needed is cleaner than emitting empty output.
- The Mac mini is the concrete case: it has no `claude_default` and should not have the plist installed at all.
- Conversion is low-risk: the existing static contents render identically when treated as a template.

### Decision 6: Activation script numbered 38

**Choice:** `home/.chezmoiscripts/run_onchange_after_darwin-38-load-claude-launchagent.sh.tmpl`, using `run_onchange_after`.

**Why:**

- 36 = Claude Code install, 37 = Claude Code skills, 38 = Claude Code GUI inheritance. Logical grouping.
- `run_onchange_after` re-runs whenever the script's hashed source changes. Embedding the rendered plist path and `claude_default` value in the script body means a `claude_default` change triggers re-execution and the agent gets re-bootstrapped automatically.
- Darwin-only (`{{- if eq .chezmoi.os "darwin" -}}`); the entire LaunchAgent concept is macOS-specific.

## Risks / Trade-offs

- **[Risk]** Already-running GUI apps don't see the new `CLAUDE_CONFIG_DIR` after first apply, because they captured the GUI session env at launch.
  **→ Mitigation:** Activation script prints a `print_message tip` reminding the user to restart already-running GUI apps. Documented in the script's header comment.

- **[Risk]** A future tool reads `CLAUDE_CONFIG_DIR` and behaves badly when it's set machine-wide.
  **→ Mitigation:** The variable's name explicitly namespaces it to Claude. No known tool collisions today. Cost of the namespace squat is effectively zero.

- **[Risk]** The plist filename derived from `{{ .reverse_dns }}` could collide with another LaunchAgent if the user's reverse-DNS overlaps with a vendor's. (Extremely unlikely for `software.craigearley` or `io.github.<username>`.)
  **→ Mitigation:** Suffix `.claude-config-dir` is specific enough that collisions are implausible. No defensive logic needed.

- **[Risk]** First apply requires the user to answer a new prompt for `reverse_dns`. On a re-apply, `promptStringOnce` skips it; on a fresh init, the default `io.github.<gh_username>` keeps the flow non-blocking.
  **→ Mitigation:** Sane default + `promptStringOnce` semantics make this a one-time, low-friction prompt.

- **[Risk]** `bootout` of a not-yet-loaded agent returns non-zero, breaking `set -e` scripts.
  **→ Mitigation:** Activation script tolerates `bootout` failure (`launchctl bootout ... 2>/dev/null || true`) and proceeds to `bootstrap`. `bootstrap` of an already-loaded agent also fails, so the pattern is `bootout` → `bootstrap` unconditionally.

- **[Risk]** `~/Library/LaunchAgents/` permissions are user-managed; chezmoi might apply 600 (via `private_` heuristics) and break loading.
  **→ Mitigation:** No `private_` prefix on the plist filename. Defaults to 644, matching every other plist in that directory.

- **[Trade-off]** Bare `claude` invocation no longer routes through a function. `type claude` will report it as a normal binary on PATH, not as an alias for `claude-work`. This is the *correct* behavior under the new mental model ("the machine has a default; the binary inherits it") but anyone debugging by introspecting shell state will see different output than before. Expected and documented in the proposal as a BREAKING note for end-user behavior.

## Migration Plan

1. Add `reverse_dns` prompt to `.chezmoi.toml.tmpl`. Run `chezmoi init` (or just answer the prompt on next `apply`) to populate `~/.config/chezmoi/chezmoi.toml`.
2. Create the `claude-environments` partial.
3. Update zshrc and bashrc to use `includeTemplate`.
4. Convert `.chezmoiignore` → `.chezmoiignore.tmpl` and add the conditional stanza.
5. Add the LaunchAgent plist template.
6. Add the activation script.
7. Run `chezmoi apply`. On macOS with `claude_default` set:
   - Verify `launchctl getenv CLAUDE_CONFIG_DIR` returns the expected path.
   - Open a fresh shell; verify `echo $CLAUDE_CONFIG_DIR` is set.
   - Restart Rider (or any other already-running GUI app) and verify it sees the var.
8. On Mac mini (no `claude_default`): verify the plist file is not present and no script ran.

**Rollback:**

- Delete `home/.chezmoitemplates/claude-environments`.
- Revert zshrc and bashrc.
- Revert `.chezmoi.toml.tmpl` to remove the prompt.
- Delete the LaunchAgent plist template and the activation script.
- Convert `.chezmoiignore.tmpl` back to `.chezmoiignore` (drop the new stanza).
- Manually: `launchctl bootout gui/$(id -u)/<reverse_dns>.claude-config-dir`, `launchctl unsetenv CLAUDE_CONFIG_DIR`, `rm ~/Library/LaunchAgents/<reverse_dns>.claude-config-dir.plist`. Document this in the activation script's comment block so it can be reproduced from memory.

## Open Questions

None remaining at design time. Resolved during discussion:

- Plist label/filename → `{{ .reverse_dns }}.claude-config-dir`.
- `reverse_dns` storage → user prompt in `.chezmoi.toml.tmpl`, default `io.github.<gh_username>`.
- Partial name → `claude-environments`.
- `private_` prefix on plist → no, would set 600 and conflict with launchd's expectation of 644.
- `.chezmoiignore` strategy → rename to `.tmpl` and gate the plist line on empty `claude_default`.
