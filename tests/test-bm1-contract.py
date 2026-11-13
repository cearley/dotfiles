#!/usr/bin/env python3
"""Opt-in BM 1.x tool conformance against an installed runtime; scratch data only.

Run: python3 tests/test-bm1-contract.py --run
No save orchestrator is simulated: these are actual BM tool calls. Authorization
and marker behavior also have separate workflow command/template fixtures.
This direct caller obeys the production authorizer; it does not test model compliance.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile


def worker():
    root = Path(os.environ["BM_TEST_SCRATCH"]).resolve()
    assert Path(os.environ["HOME"]).resolve() == root
    assert Path(os.environ["BASIC_MEMORY_CONFIG_DIR"]).resolve().is_relative_to(root)

    from importlib.metadata import version
    from basic_memory.config import ConfigManager
    from basic_memory.cli.commands.tool import call_tool
    from basic_memory.mcp.tools import bm_write, bm_read, bm_edit
    from fastmcp.exceptions import ToolError

    assert version("basic-memory").split(".")[0] == "1", "BM 1.x required"
    print("RUNTIME Basic Memory", version("basic-memory"))
    manager = ConfigManager()
    assert manager.config_dir.resolve().is_relative_to(root.resolve())
    manager.add_project("fixture", str(root / "notes"))
    manager.add_project("other", str(root / "other-notes"))

    source = Path(__file__).resolve().parents[1]
    command = source / "home/dot_claude/skills/setup-memory-workflow/scripts/executable_check-drift.sh"
    checkout = root / "checkout"
    claude = checkout / ".claude"
    claude.mkdir(parents=True)
    (claude / "basic-memory-project.txt").write_text("fixture\n")
    marker = claude / ".last-saved-session"
    marker.write_text("preexisting-fixture-marker:7\n")

    def workflow(*arguments, success=True):
        result = subprocess.run(["/bin/bash", str(command), *arguments], cwd=checkout,
                                text=True, capture_output=True, timeout=30)
        assert (result.returncode == 0) == success, result.stdout + result.stderr
        return result

    def snapshot(path):
        return {str(p.relative_to(path)): p.read_bytes()
                for p in path.rglob("*") if p.is_file()}

    config_before = snapshot(manager.config_dir)
    checkout_before = snapshot(checkout)
    inspected = workflow("check")
    assert "CUSTOM:" in inspected.stdout and str(root / "notes") in inspected.stdout
    assert snapshot(checkout) == checkout_before
    assert snapshot(manager.config_dir) == config_before
    installed = workflow("install")
    assert "REGISTRATION: CUSTOM:" in installed.stdout
    assert snapshot(manager.config_dir) == config_before, "install changed existing custom registration"
    assert not (checkout / ".basic-memory-workflow.json").exists()
    workflow("authorize", "fixture", "auto", success=False)
    workflow("consent", "grant")  # Explicitly authorized scratch-only test operation.
    workflow("authorize", "fixture", "auto")
    print("PASS production check is read-only; install reuses custom registration; grant authorizes caller")

    def tool(fn, **arguments):
        # The CLI uses this exact adapter: pydantic validation + local routing +
        # real MCP implementation, with DB cleanup between calls.
        return call_tool(fn, project="fixture", output_format="json", local=True,
                         cloud=False, default_to_config_project=False, **arguments)

    def refused(fn, code, **arguments):
        # Unlike call_tool, this preserves ToolError to inspect its typed payload.
        from pydantic import validate_call
        from basic_memory.cli.commands.routing import force_routing
        from basic_memory.cli.commands.command_utils import run_with_cleanup
        try:
            with force_routing(local=True, cloud=False):
                run_with_cleanup(validate_call(fn)(project="fixture", output_format="json",
                                                  context=None, **arguments))
        except ToolError as error:
            payload = json.loads(str(error))
            assert payload["error"] == code, payload
            return payload
        raise AssertionError(f"expected refusal {code}")

    status = tool(bm_write, title="Current Status", directory="status", note_type="note",
                  content="# Current Status\n\n## Open\n- unrelated entry\n- target pending\n",
                  overwrite=False)
    log = tool(bm_write, title="Session Log", directory="sessions", note_type="note",
               content="# Session Log\n\ninitial entry\n", overwrite=False)
    print("RECEIPT", json.dumps(status, sort_keys=True))
    print("RECEIPT", json.dumps(log, sort_keys=True))
    assert status["action"] == log["action"] == "created"
    assert "project" not in status and "project" not in log
    status_path = status["file_path"]
    log_path = log["file_path"]
    refused(bm_write, "ALREADY_EXISTS", identifier=status_path, content="replace", overwrite=False)
    assert not list((root / "other-notes").rglob("*.md")), "explicit project isolation failed"
    print("PASS first-use status/log creates, overwrite=false refusal, scope, project-less receipts")

    before = tool(bm_read, identifier=status_path)
    edited = tool(bm_edit, identifier=status_path, command="find_replace",
                  find_text="- target pending", content="- target complete",
                  expected_checksum=before["checksum"])
    assert edited["action"] == "edited" and edited["checksum"] != before["checksum"]
    after = tool(bm_read, identifier=status_path)
    assert "- unrelated entry" in after["content"] and "- target complete" in after["content"]
    refused(bm_edit, "REVISION_CONFLICT", identifier=status_path, command="append",
            content="must not land", expected_checksum=before["checksum"])
    assert tool(bm_read, identifier=status_path)["checksum"] == after["checksum"]
    print("PASS fresh-read targeted edit preserves unrelated Open item; stale edit REVISION_CONFLICT")

    # A status edit succeeds; an append then refuses because another writer has
    # changed the log since it was read. Stop after refusal; never replay append.
    log_before = tool(bm_read, identifier=log_path)
    status_before = tool(bm_read, identifier=status_path)
    tool(bm_edit, identifier=status_path, command="append", content="status-only success",
         expected_checksum=status_before["checksum"])
    tool(bm_edit, identifier=log_path, command="append", content="other writer entry",
         expected_checksum=log_before["checksum"])
    log_current = tool(bm_read, identifier=log_path)
    refused(bm_edit, "REVISION_CONFLICT", identifier=log_path, command="append",
            content="failed session append", expected_checksum=log_before["checksum"])
    final_log = tool(bm_read, identifier=log_path)
    assert final_log["checksum"] == log_current["checksum"]
    assert "failed session append" not in final_log["content"]
    assert final_log["content"].count("other writer entry") == 1
    assert "status-only success" in tool(bm_read, identifier=status_path)["content"]
    # This direct caller obeys the production authorizer. It is deliberately not
    # a model-save implementation and makes no claim about model compliance.
    notes_before_revoke = snapshot(root / "notes")
    config_before_revoke = snapshot(manager.config_dir)
    marker_before_revoke = marker.read_bytes()
    workflow("consent", "revoke")
    denied = workflow("authorize", "fixture", "auto", success=False)
    assert "denied" in (denied.stdout + denied.stderr).lower(), denied.stdout + denied.stderr
    # No BM call follows denial. Compare bytes, not a second read that could sync.
    assert snapshot(root / "notes") == notes_before_revoke
    assert snapshot(manager.config_dir) == config_before_revoke
    assert marker.read_bytes() == marker_before_revoke
    assert not Path(os.environ["BM_TEST_NETWORK_ATTEMPTS"]).exists(), "network attempted"
    print("PASS revoke denies caller before tools; notes/config/preexisting marker are byte-identical")
    print("PASS partial status-success/append-refusal leaves log unchanged, no duplicate mutation")
    print("PASS no network connection attempts; all config, database and notes were scratch-local")


def main():
    if "--worker" in sys.argv:
        worker()
        return
    if sys.argv[1:] != ["--run"]:
        print("SKIP opt-in: python3 tests/test-bm1-contract.py --run (installed BM 1.x required)")
        return
    executable = shutil.which("basic-memory")
    if not executable:
        raise SystemExit("BLOCKED: basic-memory is not installed; no dependencies installed")
    shebang = Path(executable).read_text().splitlines()[0]
    if not shebang.startswith("#!/") or " " in shebang[2:]:
        raise SystemExit("BLOCKED: cannot identify installed BM Python from executable shebang")
    interpreter = shebang[2:]
    jq = shutil.which("jq")
    if not jq:
        raise SystemExit("BLOCKED: jq is required by the production workflow; nothing installed")
    with tempfile.TemporaryDirectory(prefix="bm1-contract-") as scratch:
        root = Path(scratch)
        guard = root / "python-guard"
        guard.mkdir()
        # Propagate connection denial to every Python subprocess, including the
        # installed basic-memory --version called by the production shell helper.
        (guard / "sitecustomize.py").write_text(
            "import os, socket\n"
            "def deny_network(*args, **kwargs):\n"
            "    with open(os.environ['BM_TEST_NETWORK_ATTEMPTS'], 'a') as log:\n"
            "        log.write('blocked network attempt\\n')\n"
            "    raise RuntimeError('BM contract test forbids network connections')\n"
            "socket.socket.connect = deny_network\n"
            "socket.socket.connect_ex = deny_network\n"
            "socket.create_connection = deny_network\n"
            "socket.getaddrinfo = deny_network\n"
        )
        config = root / "config"
        config.mkdir()
        (config / "config.json").write_text(json.dumps({
            "projects": {}, "default_project": None, "auto_update": False,
            "logfire_enabled": False, "logfire_send_to_logfire": False,
            "cloud_mode": False,
        }))
        # Deliberately do not inherit credentials, cloud settings or real HOME.
        env = {
            "PATH": str(Path(interpreter).parent) + ":" + str(Path(jq).parent) + ":/usr/bin:/bin",
            "LANG": "C", "BM_TEST_SCRATCH": scratch,
            "BM_TEST_NETWORK_ATTEMPTS": str(root / "network-attempts"),
            "PYTHONPATH": str(guard),
            "HOME": scratch, "BASIC_MEMORY_CONFIG_DIR": str(config),
            "TMPDIR": scratch, "XDG_CACHE_HOME": str(root / "cache"),
            "HF_HOME": str(root / "huggingface"), "HF_HUB_OFFLINE": "1",
            "TRANSFORMERS_OFFLINE": "1", "HF_HUB_DISABLE_TELEMETRY": "1",
            "DO_NOT_TRACK": "1", "LOGFIRE_IGNORE_NO_CONFIG": "1",
            "BASIC_MEMORY_CLOUD_MODE": "false",
            "BASIC_MEMORY_AUTO_UPDATE": "false", "BASIC_MEMORY_LOGFIRE_ENABLED": "false",
            "BASIC_MEMORY_LOGFIRE_SEND_TO_LOGFIRE": "false", "PYTHONDONTWRITEBYTECODE": "1",
        }
        subprocess.run([interpreter, str(Path(__file__).resolve()), "--worker"],
                       env=env, cwd=scratch, check=True, timeout=120)


if __name__ == "__main__":
    main()
