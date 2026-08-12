#!/bin/bash
# list-claude-orphans.sh — Structured view of audit-packages' Claude Code findings, plus
# the environment context clean-claude-orphans needs to classify each orphan safely.
# Read-only: never installs, removes, or modifies any Claude Code state.
set -euo pipefail

if ! command -v audit-packages >/dev/null 2>&1; then
    echo "error: audit-packages not found on PATH" >&2
    exit 1
fi

# ---------------------------------------------------------------------------
# Claude Code environments present on this machine (openspec/specs/claude-environments)
# ---------------------------------------------------------------------------
echo "## environments"
printf 'current\t%s\n' "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
for dir in "$HOME"/.claude "$HOME"/.claude-*; do
    [[ -d "$dir" ]] || continue
    printf 'found\t%s\n' "$dir"
done

# ---------------------------------------------------------------------------
# Orphans from the four Claude Code sections of `audit-packages`, as clean
# <category>\t<item> lines. Forcing LANG=C/LC_ALL=C makes print_message emit its
# ASCII "[INFO]"-style prefixes instead of emoji, so section/noise lines are
# trivial to filter regardless of the invoking shell's locale. The per-line
# uninstall hint ("   claude plugins uninstall ...") is indented with leading
# whitespace; real orphan names never are, so that's also filtered out.
# ---------------------------------------------------------------------------
echo ""
echo "## orphans"
LC_ALL=C LANG=C audit-packages 2>&1 | awk '
    /=== Claude Code MCP Servers ===/         { section = "mcp_server"; next }
    /=== Claude Code Plugins ===/             { section = "plugin"; next }
    /=== Claude Code Plugin Marketplaces ===/ { section = "marketplace"; next }
    /=== Claude Code Skills ===/              { section = "skill"; next }
    /^===/                                    { section = ""; next }
    !section                                  { next }
    /No orphans/                              { next }
    /^\[/                                     { next }
    /^[[:space:]]/                            { next }
    /^$/                                      { next }
    { print section "\t" $0 }
'
