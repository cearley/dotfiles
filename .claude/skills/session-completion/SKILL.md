---
name: session-completion
description: Checklist for wrapping up a chezmoi dotfiles work session — quality gates, pushing to remote, saving session notes, and handoff. Use when the user says they're done for now, wrapping up, ending the session, or asks what's left before stopping.
---

# Session Completion

**When ending a work session**, complete these steps. Committing and pushing each still require explicit user confirmation per the global Git Workflow gates — this checklist does not override that.

1. **Run quality gates** (if code changed) - Tests, linters, builds
2. **Offer to push to remote** (only after the user confirms):
   ```bash
   git pull --rebase
   git push
   git status  # MUST show "up to date with origin"
   ```
3. **Save session notes** - Use `/save-session` to persist key decisions to basic-memory
4. **Hand off** - Provide context for next session
