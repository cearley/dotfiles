#!/usr/bin/env python3
"""Exercise the real setup scripts in isolated homes; never invoke a live BM server."""

import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
SKILL = REPO / "home/dot_claude/skills/setup-memory-workflow"
SCRIPT = SKILL / "scripts/executable_check-drift.sh"
PREFIX = '${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills/setup-memory-workflow/scripts/'


class WorkflowTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name).resolve()
        self.project = self.root / "sample"
        self.project.mkdir()
        self.home = self.root / "home"
        self.home.mkdir()
        self.config = self.home / ".basic-memory"
        self.config.mkdir()
        self.bins = self.root / "bin"
        self.bins.mkdir()
        self.log = self.root / "calls"
        self.env = {**os.environ, "HOME": str(self.home),
                    "CLAUDE_CONFIG_DIR": str(self.home / ".claude-test"),
                    "BASIC_MEMORY_CONFIG_DIR": str(self.config),
                    "PATH": f"{self.bins}:{os.environ['PATH']}",
                    "BM_TEST_LOG": str(self.log), "BM_TEST_VERSION": "1.0.0"}
        for key in ("GIT_DIR", "GIT_WORK_TREE", "BASIC_MEMORY_PROJECTS", "BASIC_MEMORY_PROJECT_ROOT"):
            self.env.pop(key, None)
        subprocess.run(["git", "init", "-q", str(self.project)], check=True, env=self.env)
        self.executable("basic-memory", '''#!/usr/bin/env python3
import json, os, sys
from pathlib import Path
a=sys.argv[1:]
if a == ["--version"]:
 print("basic-memory " + os.environ["BM_TEST_VERSION"])
elif a[:2] == ["project", "add"]:
 with open(os.environ["BM_TEST_LOG"],"a") as f: f.write("add\\n")
 p=Path(os.environ["BASIC_MEMORY_CONFIG_DIR"])/"config.json"
 c=json.loads(p.read_text()) if p.exists() else {}
 c.setdefault("projects",{})[a[2]]={"path":a[3],"mode":"local"}
 p.write_text(json.dumps(c))
else:
 raise SystemExit("unexpected BM call: " + repr(a))
''')
        self.executable("claude", '#!/bin/sh\necho "unexpected claude invocation" >&2\nexit 99\n')

    def executable(self, name, text):
        p = self.bins / name
        p.write_text(text)
        p.chmod(0o755)

    def run_script(self, *args, ok=True):
        r = subprocess.run(["bash", str(SCRIPT), *args], cwd=self.project,
                           env=self.env, text=True, capture_output=True)
        if ok:
            self.assertEqual(r.returncode, 0, r.stdout + r.stderr)
        return r

    def snapshot(self):
        return {str(p.relative_to(self.root)): p.read_bytes()
                for p in self.root.rglob("*") if p.is_file()}

    def settings(self, value):
        p = self.project / ".claude/settings.local.json"
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value))
        return p

    def policy(self, **overrides):
        value = {"version": 1, "project": "sample", "repository_root": str(self.project),
                 "automatic_recording": True, "granted_at": "2026-11-13T00:00:00Z"}
        value.update(overrides)
        p = self.project / ".basic-memory-workflow.json"
        p.write_text(json.dumps(value))
        return p

    def install(self):
        self.run_script("install")

    def test_check_missing_project_has_no_side_effects(self):
        before = self.snapshot()
        r = self.run_script("check")
        self.assertIn("MISSING", r.stdout)
        self.assertEqual(before, self.snapshot())

    def test_check_and_startup_preserve_legacy_and_malformed_settings(self):
        p = self.settings({"hooks": {"SessionStart": [{"hooks": [{"command": "bm hook session-start"}]}]}})
        for text in (p.read_text(), "{broken"):
            p.write_text(text)
            before = self.snapshot()
            self.run_script("check", ok=False)
            self.run_script("drift-warn")
            self.assertEqual(before, self.snapshot())

    def test_install_is_idempotent_and_does_not_grant_consent(self):
        self.install()
        before = self.snapshot()
        self.install()
        self.assertEqual(before, self.snapshot())
        self.assertEqual(self.log.read_text(), "add\n")
        self.assertFalse((self.project / ".basic-memory-workflow.json").exists())

    def test_existing_custom_registration_is_reused(self):
        p = self.config / "config.json"
        value = {"projects": {"sample": {"path": str(self.root / "custom"), "mode": "local"}}}
        p.write_text(json.dumps(value))
        self.install()
        self.assertEqual(json.loads(p.read_text()), value)
        self.assertFalse(self.log.exists())

    def test_incompatible_runtime_stops_before_install(self):
        for version in ("0.24.1", "2.0.0", "garbage"):
            self.env["BM_TEST_VERSION"] = version
            before = self.snapshot()
            r = self.run_script("install", ok=False)
            self.assertNotEqual(r.returncode, 0)
            self.assertEqual(before, self.snapshot())

    def test_consent_grant_revoke_and_exact_scope(self):
        self.run_script("consent", "grant")
        p = self.project / ".basic-memory-workflow.json"
        c = json.loads(p.read_text())
        self.assertTrue(c["automatic_recording"])
        self.assertEqual(c["repository_root"], str(self.project))
        self.assertIn("GRANTED", self.run_script("consent", "status").stdout)
        self.run_script("consent", "grant")
        self.run_script("consent", "revoke")
        c = json.loads(p.read_text())
        self.assertFalse(c["automatic_recording"])
        self.assertIn("granted_at", c)
        self.run_script("consent", "revoke")
        self.assertIn("REVOKED", self.run_script("consent", "status").stdout)

    def test_invalid_consent_is_denied_without_rewriting(self):
        for overrides in ({"version": 2}, {"version": True}, {"automatic_recording": "true"},
                          {"project": "sam"}, {"repository_root": str(self.root)},
                          {"unexpected": True}, {"granted_at": None}):
            p = self.policy(**overrides)
            before = p.read_bytes()
            self.assertNotIn("GRANTED", self.run_script("consent", "status").stdout)
            self.assertNotEqual(self.run_script("consent", "grant", ok=False).returncode, 0)
            self.assertEqual(p.read_bytes(), before)

    def test_malformed_consent_is_preserved(self):
        p = self.policy()
        p.write_text("{broken")
        self.assertNotIn("GRANTED", self.run_script("consent", "status").stdout)
        self.assertNotEqual(self.run_script("consent", "grant", ok=False).returncode, 0)
        self.assertEqual(p.read_text(), "{broken")

    def test_multiple_consent_records_are_invalid_even_if_last_grants(self):
        self.install()
        p = self.policy(automatic_recording=False)
        denied = p.read_text()
        granted = self.policy().read_text()
        p.write_text(denied + "\n" + granted)
        before = p.read_bytes()
        self.assertIn("INVALID", self.run_script("consent", "status").stdout)
        self.assertNotEqual(self.run_script("authorize", "sample", "auto", ok=False).returncode, 0)
        self.assertNotEqual(self.run_script("consent", "grant", ok=False).returncode, 0)
        self.assertEqual(p.read_bytes(), before)

    def test_failed_atomic_policy_write_preserves_original(self):
        p = self.policy(automatic_recording=False)
        before = p.read_bytes()
        self.executable("mv", "#!/bin/sh\nexit 7\n")
        self.assertNotEqual(self.run_script("consent", "grant", ok=False).returncode, 0)
        self.assertEqual(p.read_bytes(), before)
        self.assertEqual(list(self.project.glob(".basic-memory-workflow.json.tmp.*")), [])

    def test_authorize_denied_and_one_time_save_never_grants(self):
        self.install()
        before = self.snapshot()
        self.assertNotEqual(self.run_script("authorize", "sample", "auto", ok=False).returncode, 0)
        self.run_script("authorize", "sample", "once")
        self.assertEqual(before, self.snapshot())
        self.policy()
        self.run_script("authorize", "sample", "auto")
        self.assertNotEqual(self.run_script("authorize", "other", "once", ok=False).returncode, 0)

    def test_other_checkout_cannot_reuse_consent(self):
        self.install()
        self.policy(repository_root=str(self.root / "other-checkout"))
        self.assertNotEqual(self.run_script("authorize", "sample", "auto", ok=False).returncode, 0)

    def test_foreign_native_hooks_survive_install_update_apply(self):
        hooks = [{"matcher": "keep", "hooks": [{"type": "command", "command": c}]} for c in
                 ("bm hook session-start", "echo basic-memory", "echo session-reminder.sh",
                  "echo basic-memory-write-guard.sh", "echo crash-recovery-hook.sh")]
        self.settings({"custom": 17, "hooks": {"SessionStart": hooks}})
        self.install()
        self.run_script("update")
        self.run_script("apply", "write-guard-hook")
        p = self.project / ".claude/settings.local.json"
        c = json.loads(p.read_text())
        self.assertEqual(c["custom"], 17)
        self.assertEqual(c["hooks"]["SessionStart"][:len(hooks)], hooks)

    def test_owned_wrong_matcher_is_reported_and_repaired(self):
        cmd = PREFIX + "basic-memory-write-guard.sh"
        p = self.settings({"hooks": {"SessionStart": [{"matcher": "wrong", "hooks": [
            {"type": "command", "command": "echo keep"}, {"type": "command", "command": cmd}]}]}})
        self.install()
        self.run_script("update")
        c = json.loads(p.read_text())
        self.assertEqual(c["hooks"]["SessionStart"][0]["hooks"], [{"type": "command", "command": "echo keep"}])
        self.assertEqual(c["hooks"]["PreToolUse"][0]["matcher"], "Bash|Edit|Write")
        before = p.read_bytes()
        self.run_script("update")
        self.assertEqual(p.read_bytes(), before)

    def test_legacy_marker_hook_migrates_without_foreign_sibling(self):
        legacy = 'echo "SYSTEM REMINDER: This is the sample project. [setup-memory-workflow-version:8]"'
        p = self.settings({"hooks": {"UserPromptSubmit": [{"matcher": "", "hooks": [
            {"type": "command", "command": "echo keep"}, {"type": "command", "command": legacy}]}]}})
        self.install()
        c = json.loads(p.read_text())
        self.assertEqual(c["hooks"]["UserPromptSubmit"][0]["hooks"], [{"type": "command", "command": "echo keep"}])

    def test_real_multiline_v18_reminder_is_removed(self):
        # v18 canonical_hook_cmd echoed the rendered template plus live excerpt.
        legacy = (REPO / "tests/fixtures/memory-workflow/legacy-v18-command.txt").read_text().rstrip("\n")
        p = self.settings({"hooks": {"SessionStart": [{"matcher": "", "hooks": [
            {"type": "command", "command": legacy}, {"type": "command", "command": "echo keep"}]}]}})
        self.install()
        commands = [h["command"] for g in json.loads(p.read_text())["hooks"]["SessionStart"] for h in g["hooks"]]
        self.assertNotIn(legacy, commands)
        self.assertIn("echo keep", commands)

    def test_stale_version_cannot_authorize_until_explicit_update(self):
        self.install()
        p = self.project / ".claude/skills/save-session/SKILL.md"
        p.write_text(re.sub(r"workflow-version:\d+", "workflow-version:19", p.read_text()))
        self.policy()
        self.assertNotEqual(self.run_script("authorize", "sample", "auto", ok=False).returncode, 0)
        self.run_script("update")
        self.run_script("authorize", "sample", "auto")

    def test_identity_mismatch_is_not_repaired_by_update(self):
        self.install()
        p = self.project / ".claude/skills/save-session/SKILL.md"
        p.write_text(re.sub(r"workflow-version:\d+", "workflow-version:19",
                             p.read_text().replace("workflow-project:sample", "workflow-project:sam")))
        before = p.read_bytes()
        self.run_script("update")
        self.assertEqual(p.read_bytes(), before)
        self.assertIn("NAME-MISMATCH", self.run_script("check").stdout)

    def test_targeted_apply_preserves_unrelated_legacy_and_retired_content(self):
        p = self.settings({"hooks": {"SessionStart": [{"hooks": [
            {"command": 'echo "SYSTEM REMINDER: This is the sample project. [setup-memory-workflow-version:8]"'}]}]}})
        retired = self.project / ".claude/skills/sync-memory/SKILL.md"
        retired.parent.mkdir(parents=True)
        retired.write_text("user content")
        before = p.read_bytes()
        self.run_script("apply", "save-session-skill")
        self.assertEqual(p.read_bytes(), before)
        self.assertEqual(retired.read_text(), "user content")

    def test_unowned_retired_skill_survives_full_update(self):
        p = self.project / ".claude/skills/sync-memory/SKILL.md"
        p.parent.mkdir(parents=True)
        p.write_text("user content")
        self.run_script("update")
        self.assertEqual(p.read_text(), "user content")

    def test_custom_mcp_is_preserved_until_explicit_apply(self):
        p = self.project / ".mcp.json"
        p.write_text(json.dumps({"mcpServers": {"basic-memory": {"url": "https://example.test/mcp"}}, "other": 1}))
        before = p.read_bytes()
        self.install()
        self.run_script("update")
        self.assertEqual(p.read_bytes(), before)
        self.run_script("apply", "mcp-config")
        value = json.loads(p.read_text())
        self.assertEqual(value["mcpServers"]["basic-memory"], {"command": "basic-memory", "args": ["mcp"]})
        self.assertEqual(value["other"], 1)

    def test_profile_registration_is_scoped_and_prevents_duplicate_project_server(self):
        profile = Path(self.env["CLAUDE_CONFIG_DIR"])
        profile.mkdir()
        p = profile / ".claude.json"
        data = {"mcpServers": {"basic-memory": {"command": "basic-memory", "args": ["mcp"]}}}
        p.write_text(json.dumps(data))
        self.install()
        self.assertFalse((self.project / ".mcp.json").exists())
        self.assertEqual(json.loads(p.read_text()), data)
        self.assertIn("MCP (user:", self.run_script("check").stdout)

    def test_local_mcp_override_wins_over_project_and_user(self):
        profile = Path(self.env["CLAUDE_CONFIG_DIR"])
        profile.mkdir()
        local = {"url": "https://example.test/local"}
        (profile / ".claude.json").write_text(json.dumps({
            "projects": {str(self.project): {"mcpServers": {"basic-memory": local}}},
            "mcpServers": {"basic-memory": {"command": "basic-memory", "args": ["mcp"]}}}))
        p = self.project / ".mcp.json"
        p.write_text(json.dumps({"mcpServers": {"basic-memory": {"command": "basic-memory", "args": ["mcp"]}}}))
        r = self.run_script("check")
        self.assertIn("CUSTOM: MCP (local:", r.stdout)
        self.assertNotIn("UP-TO-DATE: MCP", r.stdout)
        self.assertNotIn("project override", r.stdout)

    def test_symlinked_consent_cannot_authorize_or_replace_another_record(self):
        self.install()
        p = self.policy()
        target = self.root / "another-policy.json"
        p.rename(target)
        p.symlink_to(target)
        before = target.read_bytes()
        self.assertNotEqual(self.run_script("authorize", "sample", "auto", ok=False).returncode, 0)
        self.assertNotEqual(self.run_script("consent", "grant", ok=False).returncode, 0)
        self.assertEqual(target.read_bytes(), before)

    def test_old_owned_retired_skill_is_removed_only_during_full_mutation(self):
        p = self.project / ".claude/skills/sync-memory/SKILL.md"
        p.parent.mkdir(parents=True)
        p.write_text("---\nname: sync-memory\n---\n<!-- setup-memory-workflow-version:15 -->\n")
        state = self.project / ".specstory/.sync-memory-state.json"
        state.parent.mkdir()
        state.write_text("{}")
        self.run_script("check")
        self.assertTrue(p.exists())
        self.run_script("update")
        self.assertFalse(p.exists())
        self.assertFalse(state.exists())

    def test_unsupported_registration_config_is_never_replaced(self):
        p = self.config / "config.json"
        p.write_text("{broken")
        before = self.snapshot()
        self.assertNotEqual(self.run_script("install", ok=False).returncode, 0)
        self.assertEqual(before, self.snapshot())

    def test_denial_diagnostic_works_without_lang(self):
        self.install()
        self.env.pop("LANG", None)
        r = self.run_script("authorize", "sample", "auto", ok=False)
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Automatic recording denied", r.stderr)
        self.assertNotIn("unbound variable", r.stderr)


if __name__ == "__main__":
    unittest.main()
