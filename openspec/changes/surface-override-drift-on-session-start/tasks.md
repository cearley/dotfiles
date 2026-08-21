## 1. Persona Resolution & Dedup State

- [x] 1.1 In `home/dot_local/bin/executable_check-claude-overrides.tmpl`, add a helper that
      resolves `${CLAUDE_CONFIG_DIR:-$HOME/.claude}` against the existing `PERSONA_DIRS`
      array and returns the matching index (or "no match"). Verify by rendering the template
      (`chezmoi execute-template <`) and sourcing the rendered script's functions in a shell
      to confirm a known persona directory resolves to the correct `PERSONA_NAMES` entry, and
      an arbitrary unrelated directory resolves to "no match". Verified: rendered script
      resolved `~/.claude-personal` correctly and `/tmp/nope` as no-match (exit 0, no output).
- [x] 1.2 Add read/compare/write logic for the dedup state file at
      `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.check-claude-overrides-last-drift`, storing sorted
      `kind<TAB>key<TAB>value` lines (empty file/no file = empty prior state). Verify by
      calling the function directly against a temp file with known "before" contents and a
      known drift-line list, confirming the change/no-change comparison result and post-write
      file contents match `specs/claude-override-audit/spec.md`'s dedup scenarios. Verified
      against a fake persona harness (4-round cycle below).

## 2. Session-Start Detection Path

- [x] 2.1 Add a `--session-start` CLI branch that: resolves the current persona (1.1), calls
      the unchanged `detect_persona_drift` for that persona only, compares the result against
      dedup state (1.2), and on a non-empty/changed result prints one short plain-stdout
      message pointing at `check-claude-overrides` for detail (no JSON envelope, no full TSV
      report). Verify: no drift → no stdout output and dedup file written empty; new drift →
      one-line message printed and dedup file updated; identical drift on a second run → no
      message printed, exit 0. Verified via a fake-persona test harness (function defs
      sourced with a stubbed `detect_persona_drift`): drift found → message + state write;
      unchanged → silent; resolved → silent + state cleared; new/different drift → message
      again. All four rounds exited 0.
- [x] 2.2 Confirm the "no declared persona matches `$CLAUDE_CONFIG_DIR`" case exits 0 with no
      output and no dedup file write, by running `--session-start` with `CLAUDE_CONFIG_DIR`
      set to a directory outside `PERSONA_DIRS`. Verified against `/tmp/nope`: exit 0, no
      stdout, no state file created.
- [x] 2.3 Confirm `--session-start` never modifies `settings.json` or any
      `modify_settings.json.tmpl`, in both the drift and no-drift cases (diff the files
      before/after the run). Verified: `settings.json` sha256 identical before/after a real
      run against `~/.claude-personal`; `git status` showed no change to either persona's
      `modify_settings.json.tmpl`.
- [x] 2.4 Update the script's usage text (`print_usage`) and header comment to document
      `--session-start` alongside the existing `--fix` and read-only default modes.

## 3. Hook Wiring

- [x] 3.1 In `home/.chezmoitemplates/claude-settings-hooks-modifier`, add a `SessionStart`
      entry to `managed_hooks` invoking `check-claude-overrides --session-start`, following
      the existing `PreToolUse`/`claude-tooling-guard` entry's shape.
- [x] 3.2 Verify via `chezmoi execute-template` (or `chezmoi diff` against a persona that
      already includes this template) that a darwin+`ai`-tagged persona's rendered
      `settings.json` gains the new `SessionStart` hook entry alongside the existing merged
      hooks, and that a non-darwin or non-`ai` render still passes input through unchanged
      (existing early-exit branch). Verified by rendering `dot_claude-personal/modify_settings.json.tmpl`
      and piping `{}` through the resulting script: `hooks.SessionStart` contains the new
      entry. The non-darwin/non-`ai` passthrough branch's guard condition was not touched by
      this change (edit was confined to the JSON literal inside the darwin+`ai` branch).
- [x] 3.3 Confirm the merge is idempotent: rendering twice (or running `chezmoi apply` twice)
      does not duplicate the `SessionStart` entry, matching the existing dedup-by-command-name
      behavior the `managed_hooks` merge already applies to other events. Verified: piped the
      first merge's output back through the same rendered script — `SessionStart` array
      length stayed 1, and the two outputs were byte-identical.

## 4. Verification & Rollout

- [x] 4.1 Run `chezmoi apply` on this machine and confirm `~/.claude*/settings.json` (each
      relevant persona) now has the `SessionStart` hook entry present. Verified: all four
      personas (`.claude`, `.claude-personal`, `.claude-work`, `.claude-bedrock`) show
      `hooks.SessionStart` → `check-claude-overrides --session-start`; `~/.local/bin/check-claude-overrides`
      confirmed deployed with the new `--session-start` code paths.
- [x] 4.2 Manually introduce a synthetic drift entry (a `skillOverrides.<skill>: "off"` not
      present in that persona's baseline) and confirm a real Claude Code session start for
      that persona surfaces the one-line message; start a second session with the same
      unresolved drift and confirm it stays silent; resolve the drift and confirm a
      subsequent session start also stays silent (per the "resolved drift updates state
      silently" scenario). Verified against the real deployed `~/.local/bin/check-claude-overrides`
      and `~/.claude-personal/settings.json`: added `skillOverrides.setup-memory-workflow: "off"`
      (a native skill with no prior override entry) → message printed, state written; re-run
      unchanged → silent; restored `settings.json` from backup (drift resolved) → silent,
      state cleared. `settings.json` confirmed byte-identical to its pre-test backup after
      cleanup; test-only dedup state file removed.
- [x] 4.3 Run `openspec validate surface-override-drift-on-session-start --strict` and confirm
      it still reports the change as valid after implementation (no spec/impl drift).
      Verified: "Change 'surface-override-drift-on-session-start' is valid".
