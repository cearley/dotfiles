#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.12"
# dependencies = ["mcp>=2.1,<3"]
# ///
"""A fake basic-memory MCP server, for testing memory-distiller.

Deliberately a REAL stdio MCP server rather than a mocked session object: the worker
spawns it as a subprocess and talks to it over the real transport, so the transport,
the client library and the tool-call plumbing are all genuinely exercised. Only the
server's behaviour is canned.

Every call is appended as JSON to the file named by FAKE_MCP_CALLS, so a test can
assert which tools were called with which `project` argument.

FAKE_MCP_PROJECT overrides the `project` reported back in results, so a test can
simulate a write landing in the wrong basic-memory project.
FAKE_MCP_FAIL_TOOL makes one named tool raise, to exercise error paths.
"""
import json
import os
from mcp.server.mcpserver import MCPServer

server = MCPServer("fake-basic-memory")
NOTES = json.loads(os.environ.get("FAKE_MCP_NOTES_JSON", "{}"))


def _record(tool: str, arguments: dict) -> None:
    path = os.environ.get("FAKE_MCP_CALLS")
    if not path:
        return
    with open(path, "a") as fh:
        fh.write(json.dumps({"tool": tool, "arguments": arguments}) + "\n")


def _maybe_fail(tool: str) -> None:
    if os.environ.get("FAKE_MCP_FAIL_TOOL") == tool:
        raise RuntimeError(f"fake server: {tool} deliberately failing")


def _result(tool: str, project: str, permalink: str) -> str:
    # Shaped like basic-memory's own textual result, which the worker parses to
    # verify the write landed in the intended project.
    return (
        f"# {tool}\n"
        f"project: {os.environ.get('FAKE_MCP_PROJECT', project)}\n"
        f"permalink: {permalink}\n"
    )


@server.tool()
def write_note(title: str, content: str, project: str, directory: str = "", folder: str = "") -> str:
    _record("write_note", {"title": title, "content": content,
                           "project": project, "directory": directory, "folder": folder})
    _maybe_fail("write_note")
    NOTES[title] = content
    slug = title.lower().replace(" ", "-")
    return _result("write_note", project, f"{project}/{slug}")


@server.tool()
def edit_note(identifier: str, operation: str, content: str, project: str,
              section: str = "", find_text: str = "", expected_replacements: int = 0) -> str:
    _record("edit_note", {"identifier": identifier, "operation": operation,
                          "content": content, "project": project, "section": section,
                          "find_text": find_text, "expected_replacements": expected_replacements})
    _maybe_fail("edit_note")
    current = NOTES.get(identifier)
    if current is None:
        raise ValueError(f"note not found: {identifier}")
    if operation == "append":
        NOTES[identifier] = current + content
    elif operation == "find_replace":
        NOTES[identifier] = current.replace(find_text, content, 1)
    elif operation == "replace_section":
        start = current.find(section)
        if start < 0:
            raise ValueError(f"section not found: {section}")
        next_section = current.find("\n## ", start + len(section))
        end = len(current) if next_section < 0 else next_section
        NOTES[identifier] = current[:start] + section + "\n\n" + content + "\n" + current[end:]
    return _result("edit_note", project, f"{project}/{identifier}")


@server.tool()
def read_note(identifier: str, project: str) -> str:
    _record("read_note", {"identifier": identifier, "project": project})
    _maybe_fail("read_note")
    if identifier in NOTES:
        return NOTES[identifier]
    if "FAKE_MCP_NOTE_BODY" in os.environ:
        return os.environ["FAKE_MCP_NOTE_BODY"]
    raise ValueError(f"note not found: {identifier}")


@server.tool()
def search_notes(query: str, project: str) -> str:
    _record("search_notes", {"query": query, "project": project})
    _maybe_fail("search_notes")
    return "no results"


@server.tool()
def recent_activity(project: str, timeframe: str = "7d") -> str:
    _record("recent_activity", {"project": project, "timeframe": timeframe})
    _maybe_fail("recent_activity")
    return "no recent activity"


@server.tool()
def delete_note(identifier: str, project: str) -> str:
    """Destructive. Present ONLY so tests can prove the worker never exposes it."""
    _record("delete_note", {"identifier": identifier, "project": project})
    return "deleted"


if __name__ == "__main__":
    server.run(transport="stdio")
