# Proposal

## Why

`claude-tooling-write-guard` is the `PreToolUse` hook that steers edits of Claude Code tooling
files toward their chezmoi source. Its informational fallback branch returns
`permissionDecision: "allow"`. That branch catches every Bash command that references a
deployed `.claude*/` tooling path but doesn't match one of the guard's recognized mutation
shapes. These are mostly reads, but they also include unrecognized writes such as
`python -c`, `jq -i`-style tools, `perl -pi`, `install`, or `ln -sf`. An `allow` from a hook
skips Claude Code's normal permission evaluation. A command that rewrites a persona's
`settings.json` in a form the guard doesn't parse therefore runs without a prompt.

The fix was planned inside `claude-tooling-plugin` (task 3.4). That change is now optional
and may never ship, so the fix needs to stand on its own.

## What Changes

- The guard's informational branch stops returning a permission decision. It still emits
  the once-per-session `additionalContext` note and `systemMessage`. The tool call then goes
  through Claude Code's normal permission flow: allow rules, `defaultMode`, and a prompt or
  the auto-mode classifier.
- The `deny` and `ask` branches are unchanged.
- A fixture-driven test for the guard is added under `tests/`. The guard currently has no
  tests.
- **BREAKING (behavior):** Bash commands that touch tooling paths without matching a
  recognized mutation shape are no longer auto-approved. Commands not covered by an allow
  rule may now prompt the first time in a session. This covers `cat` and `jq` reads of
  `settings.json` in personas where those aren't allowlisted.

## Non-goals

- Broadening the guard's mutation detection (e.g. recognizing `python -c` or `perl -pi`).
  The normal permission flow is the backstop for anything it doesn't classify.
- Changing the guard's matcher, its path list, or the informational message text.
- Adding `Read` to the matcher, context injection, or moving the guard into a plugin. All of
  these belong to the optional `claude-tooling-plugin` change.
- Adding allow rules to offset the new prompts. If some become annoying, that's a separate
  `permissions.allow` decision for each persona.

## Capabilities

### New Capabilities
- `claude-tooling-write-guard`: the guard's permission contract. It may deny, ask, add
  context, or stay silent, and it must never auto-approve a tool call.

### Modified Capabilities
<!-- None. No existing main spec covers the guard. -->

## Impact

- **Code:** `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`, which is the
  informational branch's `jq` output plus its header comment.
- **Tests:** a new `tests/test-claude-tooling-write-guard.sh`.
- **Depends on:** nothing.
- **Related:** the optional `claude-tooling-plugin` change ports this guard into a plugin.
  Its "Guard Never Auto-Approves" requirement restates this change's contract. If that
  change is ever implemented, it should reference the `claude-tooling-write-guard`
  capability rather than duplicate it.
- **Tags:** darwin machines with the `ai` tag (the guard is registered through
  `claude-settings-hooks-modifier`). All four personas share the same deployed guard
  binary, so a single `chezmoi apply` covers them.
- **Security:** this closes a permission bypass. A hook can no longer grant approval for
  commands it doesn't understand. No secrets are involved.
