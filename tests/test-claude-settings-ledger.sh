#!/usr/bin/env bash
# Fixture tests for the claude-settings-hooks-modifier extra-settings ledger
# (openspec capability: claude-settings-ledger).
#
# Each case under tests/fixtures/claude-settings-ledger/<case>/ holds:
#   extra.json     claudeExtraSettings passed to the partial
#   input.json     the live settings.json piped in
#   expected.json  expected output; absent means "output must equal input byte-for-byte"
#   tags.json      optional: .tags for this case (default ["ai"], so cases don't depend on
#                  the host's tags); e.g. ["core"] for a non-ai machine. Must be non-empty,
#                  since merge ignores empty values. .chezmoi.os is the host's (darwin).
#
# extra.json and tags.json are embedded in a Go raw string, so they must not contain
# backticks.
#   exact          optional marker: compare key/element order too (jq ., not jq -S)
#
# Comparison ignores the "hooks" key unless expected.json has one, so only the hooks
# case pins the hook stage's output. Every case is also re-run on its own output and
# must come back byte-identical (idempotence). A crashing modifier counts as a failure.
#
# Usage: tests/test-claude-settings-ledger.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures/claude-settings-ledger"

scratch=$(mktemp -d)
trap 'rm -rf "$scratch"' EXIT

pass=0
fail=0

check() {
  if [[ "$2" == 1 ]]; then
    pass=$((pass + 1)); echo "PASS  $1"
  else
    fail=$((fail + 1)); echo "FAIL  $1"
  fi
}

for dir in "$FIXTURES"/*/; do
  name=$(basename "$dir")
  extra=$(jq -c . "$dir/extra.json")
  tags='["ai"]'
  [[ -f "$dir/tags.json" ]] && tags=$(jq -c . "$dir/tags.json")
  overrides="(dict \"claudeExtraSettings\" (fromJson \`$extra\`) \"tags\" (fromJson \`$tags\`))"
  "$SCRIPT_DIR/run-template" --inline \
    "{{ includeTemplate \"claude-settings-hooks-modifier\" (merge $overrides .) }}" \
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
    strip='.'
    jq -e 'has("hooks")' "$dir/expected.json" >/dev/null || strip='del(.hooks)'
    got=$(jq $order_flag "$strip" <<<"$out1")
    want=$(jq $order_flag . "$dir/expected.json")
    if [[ "$got" == "$want" ]]; then
      check "$name: matches expected" 1
    else
      check "$name: matches expected" 0
      diff <(echo "$want") <(echo "$got") | sed 's/^/      /' || true
    fi
  fi
  check "$name: idempotent" "$([[ "$out1" == "$out2" ]] && echo 1)"
done

# check-claude-overrides greps the rendered modifier for exactly one extra_settings line.
lines=$(grep -c "^extra_settings='" "$scratch/01-ledger-contents.sh" || true)
check "extra_settings is a single standalone line" "$([[ "$lines" == 1 ]] && echo 1)"

echo "---"
echo "$pass passed, $fail failed"
[[ "$fail" -eq 0 ]]
