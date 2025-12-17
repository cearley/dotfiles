# Tasks: Claude Code Native Installation

## Implementation Checklist

### Phase 1: Script Creation
- [x] Create `home/.chezmoiscripts/run_once_after_darwin-36-install-claude-code.sh.tmpl`
  - [x] Add platform conditional wrapper (darwin/linux check)
  - [x] Source shared utilities
  - [x] Check for `ai` tag selection
  - [x] Check if Claude Code already installed (`command -v claude`)
  - [x] Execute native install: `curl -fsSL https://claude.ai/install.sh | bash`
  - [x] Verify installation success with `claude --version`
  - [x] Print success/error messages using `print_message`
  - [x] Handle installation errors gracefully

### Phase 2: Script Testing
- [x] Test script execution on macOS (ARM64)
- [x] Verify `ai` tag gating works correctly
- [x] Test idempotency (re-run when already installed)
- [x] Verify installation creates `~/.local/bin/claude`
- [x] Test `claude --version` command post-install
- [x] Check that PATH includes `~/.local/bin`

### Phase 3: Documentation Updates
- [x] Update `docs/command-reference.md`
  - [x] Add "Claude Code" section
  - [x] Document basic commands: `claude`, `claude update`, `claude doctor`
  - [x] Document authentication setup
  - [x] Add troubleshooting tips
- [x] Update `.serena/memories/chezmoi-dotfiles-quick-reference.md`
  - [x] Add Claude Code to AI tools section
  - [x] Reference script execution order (36)
  - [x] Note tag requirement (`ai`)

### Phase 4: Spec Updates
- [x] Create `openspec/changes/add-claude-code-install/specs/package-management/spec.md`
  - [x] Add "ADDED Requirements" section
  - [x] Define "Claude Code Native Installation" requirement
  - [x] Include installation scenarios (fresh install, already installed, platform detection)
  - [x] Document tag-based gating behavior

### Phase 5: Validation
- [x] Run `openspec validate add-claude-code-install --strict`
- [x] Fix any validation issues
- [x] Ensure all scenarios have proper format
- [x] Verify spec delta is correctly structured

### Phase 6: Review and Approval
- [x] Review proposal.md for completeness
- [x] Review tasks.md for missing steps
- [x] Review spec delta for requirements clarity
- [x] Request approval before implementation
- [x] Address any feedback

## Post-Implementation

### After Deployment
- [x] Verify Claude Code installs successfully on test machine
- [x] Confirm `claude` command is available in PATH
- [x] Test authentication flow (Claude Console or Pro/Max)
- [x] Verify auto-update mechanism works
- [x] Archive change proposal: `openspec archive add-claude-code-install`

## Notes

### Script Order Rationale
- **Number 36**: Positioned between nvm (35) and shell plugins/auth (40+)
- Logical grouping with other environment managers/toolchains
- Early enough for development workflows, late enough after essential tools

### Platform Considerations
- macOS: Primary platform, ARM64 and x64 supported
- Linux: Ubuntu 20.04+, Debian 10+ (same install command)
- WSL: Both WSL 1 and WSL 2 supported (same install command)
- Uses `.chezmoi.os` and `.chezmoi.arch` for platform detection

### Tag Design
- Uses existing `ai` tag (aligns with Claude Desktop, Ollama, LM Studio)
- No new tag creation needed
- Consistent with package management conventions

### Installation Method
- Native install is Anthropic's recommended method
- Advantages: No Node.js, better performance, auto-updates
- Single command: `curl -fsSL https://claude.ai/install.sh | bash`
- Installation creates `~/.local/bin/claude` symlink
