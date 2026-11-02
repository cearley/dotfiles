#!/usr/bin/env bash
# Fixture tests for basic-memory-write-guard's permission contract (part of the
# setup-memory-workflow skill's write-guard-hook piece).
#
# Pipes crafted PreToolUse payloads through the real script with $HOME pointed at a
# scratch dir, so BASE ($HOME/.local/share/basic-memory) never resolves anywhere near
# a real basic-memory install. The deployed ~/.claude copy, if any, is never touched.
#
# Usage: tests/test-basic-memory-write-guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GUARD="$REPO_ROOT/home/dot_claude/skills/setup-memory-workflow/scripts/executable_basic-memory-write-guard.sh"

scratch=$(mktemp -d)
scratch=$(realpath "$scratch")  # canonicalize (e.g. macOS /tmp -> /private/tmp) so it
                                 # matches what the guard's own realpath resolves to
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/.local/share/basic-memory/proj"

pass=0
fail=0

# run_guard <tool_name> <tool_input-json>
run_guard() {
  local payload
  payload=$(jq -n --arg t "$1" --argjson i "$2" '{tool_name: $t, tool_input: $i}')
  HOME="$scratch" bash "$GUARD" <<<"$payload"
}

check() {
  local name="$1" ok="$2"
  if [[ "$ok" == 1 ]]; then
    pass=$((pass + 1)); echo "PASS  $name"
  else
    fail=$((fail + 1)); echo "FAIL  $name"
  fi
}

decision() { jq -r '.hookSpecificOutput.permissionDecision // "none"' <<<"${1:-{\}}"; }

# 1. Edit under the basic-memory tree → deny.
out=$(run_guard Edit "$(jq -n --arg p "$scratch/.local/share/basic-memory/proj/note.md" \
  '{file_path: $p, old_string: "a", new_string: "b"}')")
check "Edit under basic-memory: deny" "$([[ "$(decision "$out")" == deny ]] && echo 1)"

# 2. Write under the basic-memory tree → deny.
out=$(run_guard Write "$(jq -n --arg p "$scratch/.local/share/basic-memory/proj/note.md" \
  '{file_path: $p, content: "x"}')")
check "Write under basic-memory: deny" "$([[ "$(decision "$out")" == deny ]] && echo 1)"

# 3. Edit elsewhere → silent, no output.
out=$(run_guard Edit "$(jq -n --arg p "$scratch/some/other/file.md" \
  '{file_path: $p, old_string: "a", new_string: "b"}')")
check "Edit elsewhere: silent" "$([[ -z "$out" ]] && echo 1)"

# 4. Bash redirect into the basic-memory tree → deny.
out=$(run_guard Bash "$(jq -n --arg c "echo x > $scratch/.local/share/basic-memory/proj/note.md" '{command: $c}')")
check "Bash redirect: deny" "$([[ "$(decision "$out")" == deny ]] && echo 1)"

# 5. Bash rm on a basic-memory note → deny.
out=$(run_guard Bash "$(jq -n --arg c "rm $scratch/.local/share/basic-memory/proj/note.md" '{command: $c}')")
check "Bash rm: deny" "$([[ "$(decision "$out")" == deny ]] && echo 1)"

# 6. Bash read (cat) of a basic-memory note → silent, no output.
out=$(run_guard Bash "$(jq -n --arg c "cat $scratch/.local/share/basic-memory/proj/note.md" '{command: $c}')")
check "Bash read: silent" "$([[ -z "$out" ]] && echo 1)"

# 7. Bash command unrelated to basic-memory → silent, no output.
out=$(run_guard Bash '{"command": "ls /tmp"}')
check "unrelated command: silent" "$([[ -z "$out" ]] && echo 1)"

# 8. Read tool on a basic-memory note → never guarded (unhandled tool_name, no output).
out=$(run_guard Read "$(jq -n --arg p "$scratch/.local/share/basic-memory/proj/note.md" '{file_path: $p}')")
check "Read tool: silent" "$([[ -z "$out" ]] && echo 1)"

echo
echo "pass=$pass fail=$fail"
[[ "$fail" == 0 ]]
