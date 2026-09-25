# Tasks

## 1. Test and fix

- [x] 1.1 Add `tests/test-claude-tooling-write-guard.sh` (design D3). It renders `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl` with `tests/run-template` into a scratch file, and runs every case with `TMPDIR` set to a scratch directory and a unique `session_id`. Cases:
  - an unclassified Bash write (`python3 -c "…" ~/.claude-personal/settings.json`): output has no `permissionDecision`
  - a Bash read (`jq . ~/.claude-work/settings.json`): output has no `"allow"`
  - the same session twice: the note appears the first time and there is no output the second time
  - Edit of `~/.claude/rules/global-preferences.md`: `deny`
  - Bash redirect into `~/.claude-personal/plugins/x`: `ask`
  - a Bash command with no tooling path: no output
  - a sweep over every case's output: `grep -c '"allow"'` is 0

  Verify it fails against the current template only on the `allow` assertions (the expected red).
- [x] 1.2 In `home/dot_local/bin/executable_claude-tooling-write-guard.tmpl`, remove `permissionDecision: "allow"` from the informational branch's `jq` output, keeping `hookEventName`, `additionalContext`, and `systemMessage`. Update the header comment's description of the informational fallback so it says the fallback makes no permission decision. Verify `tests/test-claude-tooling-write-guard.sh` passes, and `grep -c 'permissionDecision: "allow"'` on the template returns 0.

## 2. Rollout

- [x] 2.1 Run `chezmoi apply ~/.local/bin/claude-tooling-write-guard` (scoped to the target, so the KeePassXC prompt isn't needed). Verify `grep -c '"allow"' ~/.local/bin/claude-tooling-write-guard` returns 0.
- [x] 2.2 In a new session, run a Bash read of a persona `settings.json` that no allow rule covers. Verify the informational note still appears, that there's no hook error, and that the command goes through the normal permission flow (a prompt, or the auto-mode classifier) instead of being auto-approved.
