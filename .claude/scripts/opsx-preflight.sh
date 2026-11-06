#!/usr/bin/env bash
# Preflight for /opsx:run-omc <change-slug>. Read-only. Prints a report; exit 1 if the change is not runnable.
set -u
slug="${1:-}"
[ -z "$slug" ] && { echo "usage: opsx-preflight.sh <change-slug>" >&2; exit 2; }
root="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"; cd "$root" || exit 2
fail=0
echo "## Preflight: $slug"
echo "branch: $(git branch --show-current)"

# 1. Change exists and validates
if [ ! -d "openspec/changes/$slug" ]; then echo "validation: FAIL (openspec/changes/$slug not found)"; echo "preflight: FAIL"; exit 1; fi
if vout="$(openspec validate "$slug" --type change 2>&1)"; then
  echo "validation: OK"
else
  echo "validation: FAIL"; printf '%s\n' "$vout" | grep -E '✗|ERROR|WARN' | head -10; fail=1
fi

# 2. Progress, strategy, guidance presence
tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT
if openspec instructions apply --change "$slug" --json >"$tmp" 2>/dev/null && [ -s "$tmp" ]; then
python3 - "$tmp" <<'PY'
import json, sys
d = json.load(open(sys.argv[1])); p = d.get("progress") or {}
total, done, rem = p.get("total", 0), p.get("complete", 0), p.get("remaining", 0)
print(f"tasks: total={total} complete={done} remaining={rem}")
print("state: " + str(d.get("state")))
print("strategy: " + ("none (no remaining tasks)" if rem == 0 else "quick" if rem <= 3 else "deploy"))
PY
else
  echo "tasks: FAIL (openspec instructions apply returned no JSON)"; fail=1
fi

# 3. Stale ralph PRD
if [ -f .omc/prd.json ]; then
python3 - .omc/prd.json <<'PY'
import json, sys, os, time
p = sys.argv[1]; d = json.load(open(p)); st = d.get("stories", [])
unfinished = sum(1 for s in st if not s.get("passes"))
age = int((time.time() - os.path.getmtime(p)) / 86400)
print(f"stale_prd: {p} title={d.get('title')!r} branch={d.get('branchName')!r} unfinished={unfinished}/{len(st)} age_days={age}")
PY
else
  echo "stale_prd: none"
fi

# 4. Untracked-file baseline, so the verify step can intent-add only files the executors create
mkdir -p .claude/.cache
git ls-files --others --exclude-standard | sort > .claude/.cache/untracked-baseline.txt
echo "untracked_baseline: $(wc -l < .claude/.cache/untracked-baseline.txt | tr -d ' ') files recorded in .claude/.cache/untracked-baseline.txt"

# 5. Working tree (all tracked files - this repo has no single compiled language to scope to)
echo "dirty_tree_files: $(git status --porcelain | wc -l | tr -d ' ')"

if [ "$fail" -eq 0 ]; then echo "preflight: OK"; else echo "preflight: FAIL"; fi
exit "$fail"
