# Design

## Context

`home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` is registered as a
`PreToolUse` hook (matcher `Bash|Edit|Write`) by `claude-settings-hooks-modifier` in every
persona. Its Bash path works like this:

1. It exits early unless the command mentions `.claude*/(settings.json|plugins/|skills/|rules/)`.
2. `extract_bash_target` recognizes redirects, `mv`/`cp`, `sed -i`, `tee`, and `rm`, and
   `check_path` tiers that target as `deny` or `ask`.
3. Anything left over reaches the informational branch. That branch writes a session marker
   in `$TMPDIR/claude-tooling-write-guard/`, then prints
   `{hookSpecificOutput: {permissionDecision: "allow", additionalContext}, systemMessage}`.

The guard has no tests today.

## Goals / Non-Goals

**Goals:** remove the `allow` with the smallest possible diff, and add a regression test
that pins the whole permission contract (the spec), not only this one branch.

**Non-Goals:** reworking the guard's structure, its matcher, or its message. The optional
`claude-tooling-plugin` change ports the guard wholesale, and a minimal diff here keeps that
port easy.

## Decisions

### D1. Drop the field rather than switch it to `ask`
The informational branch's `hookSpecificOutput` keeps `hookEventName` and
`additionalContext` and simply loses `permissionDecision`. Claude Code then applies its
normal flow: allow rules, `defaultMode`, and the prompt or auto-mode classifier.

*Alternative:* `permissionDecision: "ask"`. Rejected because it would override allow rules
too. Every allowlisted read of `settings.json` (e.g. `jq`) would start prompting, and in
auto mode an `ask` from a hook forces a prompt. Leaving the decision unset makes only
commands that nothing allowlists prompt.

### D2. Keep `systemMessage` and the once-per-session marker as they are
Behavior visible to the user is unchanged except for permissions.

### D3. Test by rendering the template and piping payloads
`tests/test-claude-tooling-write-guard.sh` renders the guard with `tests/run-template` into a
scratch file, then runs it with `TMPDIR` pointed at a scratch directory so session markers
never touch the real `$TMPDIR`. Each case is a JSON hook payload with a unique `session_id`
and an assertion on the output (`jq` checks on `permissionDecision`, or empty output). The
`deny`/`ask` cases use real persona paths, because `check_path` calls `chezmoi managed` /
`source-path`, which are read-only.

The deployed guard is never edited or run to test the change; only the rendered scratch
copy is used. The live hook is shared by every session on the machine.

## Risks / Trade-offs

- [More permission prompts for tooling-path reads not covered by allow rules] → This is the
  intended trade: the hook no longer vouches for commands it can't classify. If a specific
  read becomes noisy, add a narrow `permissions.allow` entry to that persona's `$extra`.
- [Claude Code rejects a `PreToolUse` `hookSpecificOutput` that has no `permissionDecision`]
  → Unlikely, since `additionalContext`-only output is a documented shape. Task 2.2 checks
  it in a live session after apply. If it fails, emit only `systemMessage` plus top-level
  context, and revisit.
- [The test depends on the machine's chezmoi state for the `deny`/`ask` cases] → The same
  is true of the guard itself. The test targets files that are always chezmoi-managed on an
  `ai` machine, such as `~/.claude/rules/global-preferences.md`.

## Migration Plan

`chezmoi apply` rewrites `~/.local/bin/claude-tooling-write-guard`. The hook runs the script
fresh on every tool call, so running sessions pick up the change on their next call; no
restart is needed.

**Rollback:** revert the commit and run `chezmoi apply`.
