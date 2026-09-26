#!/usr/bin/env bash
# Fixture tests for claude-settings-modifier and its _chezmoiManaged ledger
# (openspec capability: claude-settings-ledger).
#
# Each case under tests/fixtures/claude-settings-ledger/<case>/ holds:
#   managed.json   the managed settings (claudeSettings) passed to the partial
#   input.json     the live settings.json piped in
#   expected.json  expected output; absent means "output must equal input byte-for-byte"
#   tags.json      optional: .tags for this case (default ["ai"], so cases don't depend on
#                  the host's tags); e.g. ["core"] for a non-ai machine. Must be non-empty,
#                  since merge ignores empty values. .chezmoi.os is the host's (darwin).
#
#   exact          optional marker: compare key/element order too (jq ., not jq -S)
#
# managed.json and tags.json are embedded in a Go raw string, so they must not contain
# backticks. The ledger is compared as parsed JSON, not as a string.
#
# Every case is also re-run on its own output and must come back byte-identical
# (idempotence), and every persona's real source file must render and apply cleanly.
# A crashing modifier counts as a failure.
#
# Usage: tests/test-claude-settings-ledger.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures/claude-settings-ledger"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

pass=0
fail=0
parse_ledger='if has("_chezmoiManaged") then ._chezmoiManaged |= (fromjson? // .) else . end'

check() {
  if [[ "$2" == 1 ]]; then
    pass=$((pass + 1)); echo "PASS  $1"
  else
    fail=$((fail + 1)); echo "FAIL  $1"
  fi
}

for dir in "$FIXTURES"/*/; do
  name=$(basename "$dir")
  managed=$(jq -c . "$dir/managed.json")
  tags='["ai"]'
  [[ -f "$dir/tags.json" ]] && tags=$(jq -c . "$dir/tags.json")
  overrides="(dict \"claudeSettings\" \`$managed\` \"tags\" (fromJson \`$tags\`))"
  "$SCRIPT_DIR/run-template" --inline \
    "{{ includeTemplate \"claude-settings-modifier\" (merge $overrides .) }}" \
    > "$scratch/$name.sh"

  if ! out1=$(bash "$scratch/$name.sh" < "$dir/input.json" 2>"$scratch/$name.err"); then
    check "$name: modifier ran" 0
    sed 's/^/      /' "$scratch/$name.err"
    continue
  fi
  out2=$(bash "$scratch/$name.sh" <<<"$out1" 2>/dev/null) || out2="<crashed on re-run>"

  if [[ ! -f "$dir/expected.json" ]]; then
    check "$name: output equals input" "$([[ "$out1" == "$(cat "$dir/input.json")" ]] && echo 1)"
  else
    order_flag="-S"
    [[ -f "$dir/exact" ]] && order_flag=""
    got=$(jq $order_flag "$parse_ledger" <<<"$out1")
    want=$(jq $order_flag "$parse_ledger" "$dir/expected.json")
    if [[ "$got" == "$want" ]]; then
      check "$name: matches expected" 1
    else
      check "$name: matches expected" 0
      diff <(echo "$want") <(echo "$got") | sed 's/^/      /' || true
    fi
  fi
  check "$name: idempotent" "$([[ "$out1" == "$out2" ]] && echo 1)"
  # Claude Code flags hook-shaped objects outside "hooks", so the ledger must be a string.
  check "$name: ledger is absent or a string" "$(jq -e \
    '(._chezmoiManaged? // "") | type == "string"' <<<"$out1" >/dev/null 2>&1 && echo 1)"
done

# Every persona's real caller must find its sibling .claude-settings.json, and applying it
# to {} must write exactly that file. Callers are rendered by absolute path, so
# .chezmoi.sourceFile resolves; the host needs the ai tag for the non-pass-through branch.
for src in "$REPO_ROOT"/home/dot_claude*/.claude-settings.json; do
  dir=$(dirname "$src"); name=$(basename "$dir")
  "$SCRIPT_DIR/run-template" "$dir/modify_settings.json.tmpl" > "$scratch/persona-$name.sh"
  got=$(bash "$scratch/persona-$name.sh" <<<'{}' 2>/dev/null | jq -S 'del(._chezmoiManaged)') || got=""
  check "persona $name: caller applies its sibling source file" "$([[ "$got" == "$(jq -S . "$src")" ]] && echo 1)"
done

echo "---"
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
