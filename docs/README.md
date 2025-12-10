# Reference Documentation

This directory contains quick reference guides and command cheat sheets for working with the chezmoi dotfiles repository.

**For specifications and requirements**, see [`openspec/specs/`](../openspec/specs/) and [`openspec/project.md`](../openspec/project.md).

## Available References

### [Command Reference](command-reference.md)
Daily command cheat sheet covering:
- chezmoi commands (edit, apply, diff, update)
- Template development and testing
- Git workflow
- Package management (Homebrew, SDKMAN, UV)
- Development environment commands

### [macOS Utilities Reference](macos-utilities.md)
macOS-specific system utilities and commands:
- Core system commands (Darwin-specific)
- File operations, process management, network operations
- Package management with Homebrew
- macOS-specific tools (defaults, mas, launchctl, security)
- Important notes on Darwin vs Linux differences

## Purpose

These reference guides serve as quick lookups for common commands and workflows. They are intentionally separate from:
- **OpenSpec** (`openspec/`) - Authoritative specifications and design
- **Serena Memories** (`.serena/memories/`) - Actual decisions, troubleshooting records, and problem-solving approaches

## Usage for AI Agents

AI agents working in this codebase can reference these guides for:
- Command syntax and examples
- Platform-specific utility usage
- Quick workflow reminders
- Common operations reference

For understanding *why* systems work the way they do or architectural decisions, consult OpenSpec and Serena memories instead.
