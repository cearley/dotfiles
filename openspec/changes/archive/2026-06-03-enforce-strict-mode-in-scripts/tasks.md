## 1. Scripts with No Error Mode (add full `set -euo pipefail`)

- [x] 1.1 Add `set -euo pipefail` after `#!/bin/bash` in `run_onchange_before_darwin-24-install-sdks.sh.tmpl`
- [x] 1.2 Add `set -euo pipefail` after `#!/bin/bash` in `run_onchange_before_darwin-25-install-tools.sh.tmpl`
- [x] 1.3 Add `set -euo pipefail` after `#!/bin/bash` in `run_onchange_before_darwin-26-install-bun-packages.sh.tmpl`
- [x] 1.4 Add `set -euo pipefail` after `#!/bin/bash` in `run_onchange_before_darwin-28-brew-bundle-install.sh.tmpl`
- [x] 1.5 Add `set -euo pipefail` after `#!/bin/bash` in `run_onchange_after_darwin-95-restart-syncthing.sh.tmpl`

## 2. Scripts with `set -uo pipefail` (add `-e`)

- [x] 2.1 Change `set -uo pipefail` → `set -euo pipefail` in `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`
- [x] 2.2 Change `set -uo pipefail` → `set -euo pipefail` in `run_onchange_after_darwin-39-install-claude-plugins.sh.tmpl`

## 3. Scripts with `set -e` Only (add `-uo pipefail`)

- [x] 3.1 Change `set -e` → `set -euo pipefail` in `run_onchange_after_darwin-45-setup-github-auth.sh.tmpl`
- [x] 3.2 Change `set -e` → `set -euo pipefail` in `run_onchange_after_darwin-90-update-hosts.sh.tmpl`

## 4. Fix Script 38's Exit-Code Capture Pattern

- [x] 4.1 In `run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`, for the first `_mcp_output=$(…)` (initial registration attempt): add `_mcp_exit=0` on the line before it and change the next line from `_mcp_exit=$?` to `|| _mcp_exit=$?` appended to the substitution line
- [x] 4.2 For the second `_mcp_output=$(…)` (retry after "already exists"): apply the same pattern — `_mcp_exit=0` before, `|| _mcp_exit=$?` appended

## 5. Verification

- [x] 5.1 Verify all 9 scripts now have `set -euo pipefail`: `grep -c 'set -euo pipefail' home/.chezmoiscripts/run_onchange_{before,after}_darwin-{24,25,26,28,38,39,45,90,95}-*.tmpl`
- [x] 5.2 Verify all 9 templates render cleanly: render each through `chezmoi execute-template | bash -n`
- [x] 5.3 Confirm script 38 has no bare `_mcp_exit=$?` on its own line: `grep -n '_mcp_exit=\$?' home/.chezmoiscripts/run_onchange_after_darwin-38-install-claude-mcp-servers.sh.tmpl`
