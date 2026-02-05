---
name: apply
description: Preview chezmoi changes with diff, then apply after user confirmation
disable-model-invocation: true
allowed-tools: Bash
---

# Chezmoi Diff & Apply

Safely preview and apply chezmoi changes.

## Steps

1. Run `chezmoi status` to list files that would change
2. If no changes, report "No changes to apply" and stop
3. Run `chezmoi diff` to show detailed changes
4. Summarize the key changes (files added, modified, removed)
5. Ask the user for explicit confirmation before proceeding
6. If confirmed, run `chezmoi apply`
7. Run `chezmoi status` to verify the apply completed successfully
8. Report the result

## Notes

- Never run `chezmoi apply` without showing the diff first
- If the diff is very large, summarize rather than showing everything
- If apply fails, show the error and suggest running `chezmoi doctor` for diagnostics
