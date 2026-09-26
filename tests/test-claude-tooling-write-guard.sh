#!/usr/bin/env bash
# Fixture tests for claude-tooling-write-guard's permission contract
# (openspec capability: claude-tooling-write-guard).
#
# Renders the guard template into a scratch dir and pipes crafted PreToolUse payloads
# through it. The deployed ~/.local/bin copy is never run or modified, and session
# markers go to a scratch TMPDIR. Deny/ask cases call the real (read-only)
# `chezmoi managed` / `source-path`, as the guard itself does.
#
# Usage: tests/test-claude-tooling-write-guard.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TEMPLATE="$REPO_ROOT/home/dot_local/bin/executable_claude-tooling-write-guard.tmpl"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT
mkdir -p "$scratch/tmp"
"$SCRIPT_DIR/run-template" "$TEMPLATE" > "$scratch/guard"

pass=0
fail=0
all_output=""
run_id=$$

# run_guard <session_id> <tool_name> <tool_input-json>
run_guard() {
  local payload
  payload=$(jq -n --arg s "$1-$run_id" --arg t "$2" --argjson i "$3" \
    '{session_id: $s, tool_name: $t, tool_input: $i}')
  TMPDIR="$scratch/tmp" bash "$scratch/guard" <<<"$payload"
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

# 1. Unclassified Bash write → note, but no permission decision.
out=$(run_guard s1 Bash '{"command": "python3 -c \"import json\" ~/.claude/settings.json"}')
all_output+="$out"$'\n'
check "unclassified write: note emitted" "$([[ -n "$out" ]] && jq -e '.hookSpecificOutput.additionalContext' <<<"$out" >/dev/null && echo 1)"
check "unclassified write: no permissionDecision" "$([[ "$(decision "$out")" == none ]] && echo 1)"

# 2. Bash read → never allow.
out=$(run_guard s2 Bash '{"command": "jq . ~/.claude/settings.json"}')
all_output+="$out"$'\n'
check "read: no allow" "$([[ "$(decision "$out")" != allow ]] && echo 1)"

# 3. Same session twice → note once, then silence.
out_a=$(run_guard s3 Bash '{"command": "cat ~/.claude/settings.json"}')
out_b=$(run_guard s3 Bash '{"command": "cat ~/.claude/settings.json"}')
all_output+="$out_a"$'\n'"$out_b"$'\n'
check "once per session: first emits note" "$([[ -n "$out_a" ]] && echo 1)"
check "once per session: second is silent" "$([[ -z "$out_b" ]] && echo 1)"

# 4. Edit of a chezmoi-managed file → deny.
out=$(run_guard s4 Edit "$(jq -n --arg p "$HOME/.claude/rules/global-preferences.md" \
  '{file_path: $p, old_string: "a", new_string: "b"}')")
all_output+="$out"$'\n'
check "managed edit: deny" "$([[ "$(decision "$out")" == deny ]] && echo 1)"

# 5. Bash redirect into plugins/ → ask.
out=$(run_guard s5 Bash '{"command": "echo x > ~/.claude/plugins/guard-test-x"}')
all_output+="$out"$'\n'
check "plugins redirect: ask" "$([[ "$(decision "$out")" == ask ]] && echo 1)"

# 6. No tooling path → no output.
out=$(run_guard s6 Bash '{"command": "ls /tmp"}')
all_output+="$out"$'\n'
check "unrelated command: silent" "$([[ -z "$out" ]] && echo 1)"

# 7. chezmoi add/re-add of a persona settings.json → deny; other chezmoi commands don't.
for cmd in "chezmoi add --force ~/.claude-personal/settings.json" \
           "cd /tmp && chezmoi re-add ~/.claude/settings.json"; do
  out=$(run_guard s7 Bash "$(jq -n --arg c "$cmd" '{command: $c}')")
  all_output+="$out"$'\n'
  check "chezmoi add/re-add settings.json: deny ($cmd)" "$([[ "$(decision "$out")" == deny ]] && echo 1)"
done
out=$(run_guard s7b Bash '{"command": "chezmoi status ~/.claude/settings.json"}')
all_output+="$out"$'\n'
check "chezmoi status settings.json: not denied" "$([[ "$(decision "$out")" != deny ]] && echo 1)"

# 8. Sweep: nothing anywhere returns allow.
check "sweep: no \"allow\" in any output" "$([[ $(grep -c '"allow"' <<<"$all_output" || true) -eq 0 ]] && echo 1)"

echo "---"
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
