#!/bin/bash
# PostToolUse hook: Validate chezmoi templates after edits
# Runs chezmoi execute-template to catch syntax errors in .tmpl files

INPUT=$(cat)
FILE=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE" ]]; then
  exit 0
fi

if [[ "$FILE" == *.tmpl ]] && [[ -f "$FILE" ]]; then
  if ! chezmoi execute-template < "$FILE" > /dev/null 2>&1; then
    echo "Template validation warning: $(basename "$FILE") has template errors. Run: chezmoi execute-template < \"$FILE\"" >&2
  fi
fi

exit 0
