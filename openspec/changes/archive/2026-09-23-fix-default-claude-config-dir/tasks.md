# Tasks

## 1. Failing test first

- [x] 1.1 Write `$SCRATCHPAD/test-default-config-dir.sh` per design D3. It does four things:
  1. Renders script 38 with a `scutil` shim that reports an unmatched name, so the machine has no `claude_envs`.
  2. Creates a sandboxed `HOME` containing `.claude/`.
  3. Runs the rendered script with `env -i`, passing `PATH`, `HOME=<sandbox>`, and `CLAUDE_CONFIG_DIR=<sandbox>/.claude-decoy`.
  4. Asserts that `basic-memory` is in `<sandbox>/.claude.json`, that `<sandbox>/.claude/.claude.json` and `<sandbox>/.claude-decoy/.claude.json` don't exist, and that `claude mcp list` with the variable unset lists `basic-memory`.

  Verify that the test **fails** against the current script, with the actual file locations shown in its output. Result: failed as predicted (registration landed in `$HOME/.claude/.claude.json`). The `env -i` calls also need `LANG`, because `shared-utils.sh` reads it under `set -u`.

## 2. Implementation

- [x] 2.1 Add `run_claude_in_env` to `home/scripts/shared-utils.sh` after `for_each_claude_env` (design D1 and D2), with a usage comment matching the neighboring functions. Verify with a sandboxed unit check using a stub `claude` on `PATH` that prints `${CLAUDE_CONFIG_DIR-UNSET}`: for `$HOME/.claude` it prints `UNSET` even with a decoy exported, for `$HOME/.claude-x` it prints `$HOME/.claude-x`, and the stub's exit code passes through.
- [x] 2.2 In script 38, replace all three `CLAUDE_CONFIG_DIR="$env_dir" claude …` call sites with `run_claude_in_env "$env_dir" …`. Verify that `grep -c 'CLAUDE_CONFIG_DIR=' <script>` prints 0, and that the rendered output passes `bash -n` for MacBook Pro, Mac Studio, and a no-persona render.
- [x] 2.3 Make the same replacement at both call sites in script 39, and verify the same way.

## 3. Verification

- [x] 3.1 Re-run the test from 1.1. Verify that it **passes**.
- [x] 3.2 Add a persona-machine regression check: render script 38 as MacBook Pro, run it in a sandbox with `.claude-bedrock/`, `.claude-personal/`, and `.claude-work/` folders, and verify that `basic-memory` lands in each `<persona>/.claude.json` and nowhere else.
- [x] 3.3 Run `openspec validate fix-default-claude-config-dir --strict`. Verify that it reports the change as valid.
- [x] 3.4 Record the manual cleanup in the chezmoi status note: on no-persona machines, after applying, confirm with `claude mcp list` and then delete `~/.claude/.claude.json`. On this MacBook Pro, the stray `~/.claude/.claude.json` has no MCP servers, so it can be deleted now. Verify that the note has been updated.
