#!/bin/bash
# PreToolUse hook: Block Go template expressions in .chezmoidata/ files
# Data files are loaded before the template engine and cannot contain {{ }} syntax

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE" ]]; then
  exit 0
fi

if [[ "$FILE" == *".chezmoidata/"* ]]; then
  CONTENT=$(echo "$INPUT" | jq -r '.tool_input.new_string // .tool_input.content // empty')
  if echo "$CONTENT" | grep -qE '\{\{'; then
    echo "BLOCKED: Files in .chezmoidata/ are static data — they cannot contain Go template expressions ({{ }}). These files are loaded before the template engine runs." >&2
    exit 2
  fi
fi

exit 0
