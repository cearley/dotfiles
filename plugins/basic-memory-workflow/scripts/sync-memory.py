#!/usr/bin/env python3
"""Distill unsynced SpecStory session logs into basic-memory.

Default mode prints unsynced log content to stdout for an already-running
Claude Code session to distill via MCP tools (no LLM API call, no vault
write). --standalone calls the Anthropic API directly and writes straight
to the vault file, for use with no Claude Code session running (e.g. cron).

This is the single canonical copy, bundled in the basic-memory-workflow
plugin — there is no per-project install step and no template rendering.
Project identity is resolved at runtime via resolve-project-name.sh
(bundled alongside this script), never baked in.
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

DEFAULT_MODEL = "claude-haiku-4-5-20251001"
DEFAULT_SINCE_DAYS = 1
DEFAULT_MAX_CHARS_PER_LOG = 50_000
DEFAULT_MAX_LOGS_PER_RUN = 20

EXTRACTION_CRITERIA = """Extract only what would be useful to a future session working in this codebase:

1. Architectural decisions (why X over Y, library/database/pattern choices)
2. System rules or conventions established or corrected during the session
3. Gotchas, bugs, and their fixes (the trap and the resolution, not the debugging narrative)

Skip conversational filler, exploratory dead ends, and anything that's just narrating \
what a tool call returned. Format as concise markdown bullets, grouped under headings \
for Decisions / Conventions / Gotchas as applicable. Omit any heading with nothing to report."""

EXTRACTION_PROMPT = (
    "You are distilling a raw Claude Code session transcript into high-density notes "
    "for a persistent memory system. " + EXTRACTION_CRITERIA + "\n\nTRANSCRIPT:\n{content}"
)


def resolve_project_name() -> str:
    script = Path(__file__).resolve().parent / "resolve-project-name.sh"
    result = subprocess.run([str(script)], capture_output=True, text=True)
    if result.returncode != 0:
        sys.exit(result.stderr.strip() or "ERROR: could not resolve project name.")
    return result.stdout.strip()


def resolve_project_root(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit).resolve()
    result = subprocess.run(
        ["git", "rev-parse", "--show-toplevel"],
        capture_output=True,
        text=True,
    )
    if result.returncode == 0:
        return Path(result.stdout.strip()).resolve()
    return Path.cwd().resolve()


def load_cursor(state_file: Path) -> float | None:
    if not state_file.exists():
        return None
    try:
        data = json.loads(state_file.read_text())
    except (json.JSONDecodeError, OSError):
        return None
    return data.get("last_synced_mtime")


def save_cursor(state_file: Path, mtime: float) -> None:
    state_file.parent.mkdir(parents=True, exist_ok=True)
    state_file.write_text(json.dumps({"last_synced_mtime": mtime}))


def find_unsynced_logs(history_dir: Path, cursor: float | None, since_days: int) -> list[Path]:
    if not history_dir.exists():
        return []
    pattern = str(history_dir / "**" / "*.md")
    candidates = [Path(p) for p in glob.glob(pattern, recursive=True)]
    threshold = (
        cursor
        if cursor is not None
        else datetime.now(timezone.utc).timestamp() - (since_days * 86400)
    )
    unsynced = [p for p in candidates if p.stat().st_mtime > threshold]
    unsynced.sort(key=lambda p: p.stat().st_mtime)
    return unsynced


def resolve_vault_dir(explicit: str | None, project_name: str) -> Path:
    if explicit:
        return Path(explicit).expanduser().resolve()
    return Path.home() / ".local" / "share" / "basic-memory" / project_name


def default_mode(logs: list[Path]) -> None:
    """Print raw log content for the invoking Claude Code session to distill."""
    for log in logs:
        print(f"--- BEGIN LOG: {log} ---")
        print(log.read_text(errors="replace"))
        print(f"--- END LOG: {log} ---\n")


def standalone_mode(
    logs: list[Path], vault_dir: Path, project_name: str, model: str, max_chars: int
) -> None:
    import anthropic  # deferred: only required when --standalone is used

    client = anthropic.Anthropic(api_key=os.environ["ANTHROPIC_API_KEY"])
    distilled_sections = []
    for log in logs:
        content = log.read_text(errors="replace")[:max_chars]
        response = client.messages.create(
            model=model,
            max_tokens=1024,
            messages=[{"role": "user", "content": EXTRACTION_PROMPT.format(content=content)}],
        )
        text = "".join(block.text for block in response.content if block.type == "text")
        distilled_sections.append(f"### {log.name}\n\n{text.strip()}")

    write_to_vault(vault_dir, project_name, distilled_sections)


def write_to_vault(vault_dir: Path, project_name: str, sections: list[str]) -> None:
    vault_dir.mkdir(parents=True, exist_ok=True)
    note_path = vault_dir / "distilled-specstory-insights.md"
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M")
    body = f"## Synced {timestamp}\n\n" + "\n\n".join(sections) + "\n"

    if not note_path.exists():
        header = (
            "---\n"
            f"title: {project_name} Distilled SpecStory Insights\n"
            "type: note\n"
            f"permalink: {project_name}/distilled-specstory-insights\n"
            "---\n\n"
        )
        note_path.write_text(header + body)
    else:
        with note_path.open("a") as f:
            f.write("\n" + body)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project-root", help="Override auto-detected project root")
    parser.add_argument("--vault-dir", help="Override the basic-memory vault directory")
    parser.add_argument(
        "--standalone",
        action="store_true",
        help="Call the Anthropic API directly and write straight to the vault (for cron/unattended use)",
    )
    parser.add_argument("--model", default=DEFAULT_MODEL, help="Model used in --standalone mode")
    parser.add_argument(
        "--since-days",
        type=int,
        default=DEFAULT_SINCE_DAYS,
        help="Fallback window when no state file exists yet",
    )
    parser.add_argument("--max-chars-per-log", type=int, default=DEFAULT_MAX_CHARS_PER_LOG)
    parser.add_argument(
        "--max-logs-per-run",
        type=int,
        default=DEFAULT_MAX_LOGS_PER_RUN,
        help="Cap on logs processed in one run, to bound API spend/latency on a large backlog",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Report what would be processed without writing anything or advancing the cursor",
    )
    parser.add_argument(
        "--print-extraction-prompt",
        action="store_true",
        help="Print the canonical extraction criteria (shared by --standalone and the "
        "sync-memory skill's interactive Step 2) and exit",
    )
    args = parser.parse_args()

    if args.print_extraction_prompt:
        print(EXTRACTION_CRITERIA)
        return

    if args.standalone and not os.environ.get("ANTHROPIC_API_KEY"):
        sys.exit("ERROR: ANTHROPIC_API_KEY is not set — required for --standalone mode.")

    project_root = resolve_project_root(args.project_root)
    history_dir = project_root / ".specstory" / "history"
    state_file = project_root / ".specstory" / ".sync-memory-state.json"

    cursor = load_cursor(state_file)
    logs = find_unsynced_logs(history_dir, cursor, args.since_days)

    if not logs:
        print("No unsynced logs found.")
        return

    if len(logs) > args.max_logs_per_run:
        print(
            f"Found {len(logs)} unsynced logs, processing the oldest {args.max_logs_per_run} "
            f"this run (--max-logs-per-run={args.max_logs_per_run}); the rest will be picked "
            "up on the next run.",
            file=sys.stderr,
        )
        logs = logs[: args.max_logs_per_run]

    if args.dry_run:
        print(f"Would process {len(logs)} log(s):")
        for log in logs:
            print(f"  {log}")
        return

    if args.standalone:
        project_name = resolve_project_name()
        vault_dir = resolve_vault_dir(args.vault_dir, project_name)
        standalone_mode(logs, vault_dir, project_name, args.model, args.max_chars_per_log)
    else:
        default_mode(logs)

    save_cursor(state_file, max(log.stat().st_mtime for log in logs))


if __name__ == "__main__":
    main()
