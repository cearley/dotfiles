## 1. Shell Robustness Fixes

- [x] 1.1 Replace `already_has=$(jq ...) && [ "$already_has" != "true" ]` with `if ! jq -e '...' >/dev/null 2>&1` in the UserPromptSubmit hook guard
- [x] 1.2 Hoist hook command string into a shell variable; pass to jq via `--arg cmd "$hook_cmd"` to eliminate `\\\"` nesting

## 2. Install-Time Project Name Injection

- [x] 2.1 Move project name detection to step 2: capture both `$PROJECT_ROOT` (full path) and `$PROJECT` (basename) once
- [x] 2.2 Update step 3 (save-session skill) to substitute `$PROJECT` into description, search query, and note reference — removing runtime `git rev-parse` from the installed skill
- [x] 2.3 Update step 5 (hook command) to use `"echo 'SYSTEM REMINDER: This is the ${PROJECT} project...'"` — a static string with no runtime subshell

## 3. basic-memory Project Registration

- [x] 3.1 Add step 3: `basic-memory project add "$PROJECT" "$HOME/.local/share/basic-memory/$PROJECT"` (idempotent — exits 0 if already registered)
- [x] 3.2 Renumber subsequent steps (old 3→4, old 4→5, old 5→6)

## 4. Settings Verification

- [x] 4.1 Add step 5.5: run `jq '{mcp: .mcpServers["basic-memory"], hook_commands: [...]}' settings.local.json` and show output to user
- [x] 4.2 Document that jq exit non-zero means malformed JSON — stop and report rather than proceeding to confirm

## 5. Description and Install Instruction Polish

- [x] 5.1 Update skill description to lead with user benefit ("remembers context across sessions") and add "frustration about losing context" as a trigger signal
- [x] 5.2 Replace `pip install basic-memory` / `uvx basic-memory` install instruction with `uv tool install basic-memory`
- [x] 5.3 Update confirm step to show project path: `✓ basic-memory project registered — <name> → <path>`
- [x] 5.4 Update closing reminder: notes live at `~/.local/share/basic-memory/<project-name>/`, not in the repo
