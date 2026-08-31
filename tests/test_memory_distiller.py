"""Unit tests for the memory-distiller worker.

Run:  uv run --with pytest --with 'mcp>=2.1,<3' --with anthropic \\
          python -m pytest tests/test_memory_distiller.py -q

The MCP integration tests spawn tests/fake_mcp_server.py as a real stdio subprocess,
so `mcp` must be importable by the test interpreter. The worker itself imports mcp
lazily, so its pure functions stay testable without it.

The worker is deployed by chezmoi as an extensionless executable, so it is loaded
here straight from the chezmoi source tree by path.
"""
import importlib.util
import pathlib
import sys

WORKER = pathlib.Path(__file__).resolve().parents[1] / "home" / "dot_local" / "bin" / "executable_memory-distiller"


def _load():
    spec = importlib.util.spec_from_loader(
        "memory_distiller",
        importlib.machinery.SourceFileLoader("memory_distiller", str(WORKER)),
    )
    mod = importlib.util.module_from_spec(spec)
    sys.modules["memory_distiller"] = mod
    spec.loader.exec_module(mod)
    return mod


import importlib.machinery  # noqa: E402

md = _load()


class TestMangleProjectRoot:
    def test_leading_slash_and_separators_become_dashes(self):
        assert md.mangle_project_root("/Users/craig/work/api") == "-Users-craig-work-api"

    def test_dot_becomes_a_dash_producing_a_double_dash(self):
        # /Users/craig/.local/share/chezmoi is stored as -Users-craig--local-share-chezmoi
        assert (
            md.mangle_project_root("/Users/craig/.local/share/chezmoi")
            == "-Users-craig--local-share-chezmoi"
        )

    def test_trailing_slash_does_not_produce_a_trailing_dash(self):
        assert md.mangle_project_root("/Users/craig/work/api/") == "-Users-craig-work-api"


def _make_transcript(home, profile, project_root, name, content="{}\n"):
    d = home / profile / "projects" / md.mangle_project_root(project_root)
    d.mkdir(parents=True, exist_ok=True)
    p = d / name
    p.write_text(content)
    return p


class TestDiscoverTranscripts:
    def test_finds_transcripts_across_two_profiles(self, tmp_path):
        root = "/Users/craig/work/api"
        a = _make_transcript(tmp_path, ".claude", root, "aaa.jsonl")
        b = _make_transcript(tmp_path, ".claude-work", root, "bbb.jsonl")

        found = md.discover_transcripts(root, home=tmp_path)

        assert set(found) == {a, b}

    def test_a_newly_added_profile_is_picked_up_with_no_config_change(self, tmp_path):
        root = "/Users/craig/work/api"
        _make_transcript(tmp_path, ".claude", root, "aaa.jsonl")
        assert len(md.discover_transcripts(root, home=tmp_path)) == 1

        later = _make_transcript(tmp_path, ".claude-brand-new", root, "ccc.jsonl")

        assert later in md.discover_transcripts(root, home=tmp_path)

    def test_other_projects_are_not_returned(self, tmp_path):
        mine = _make_transcript(tmp_path, ".claude", "/Users/craig/work/api", "aaa.jsonl")
        _make_transcript(tmp_path, ".claude", "/Users/craig/work/other", "bbb.jsonl")

        assert md.discover_transcripts("/Users/craig/work/api", home=tmp_path) == [mine]

    def test_subagent_transcripts_are_excluded(self, tmp_path):
        """Subagent output is already summarised in the parent transcript; including it
        would pay for the same content twice (design.md Architecture)."""
        root = "/Users/craig/work/api"
        parent = _make_transcript(tmp_path, ".claude", root, "session.jsonl")
        sub = (
            tmp_path / ".claude" / "projects" / md.mangle_project_root(root)
            / "session" / "subagents"
        )
        sub.mkdir(parents=True)
        (sub / "agent-explore-abc123.jsonl").write_text("{}\n")

        assert md.discover_transcripts(root, home=tmp_path) == [parent]

    def test_missing_profile_directories_are_not_an_error(self, tmp_path):
        assert md.discover_transcripts("/Users/craig/work/api", home=tmp_path) == []


class TestIsEligible:
    """Quiescence: untouched >= quiet window AND unread bytes past the offset.

    `now` and mtime are injected so the test never depends on the wall clock.
    """

    def _transcript(self, tmp_path, size, mtime, now=1_000_000):
        p = tmp_path / "s.jsonl"
        p.write_bytes(b"x" * size)
        import os
        os.utime(p, (mtime, mtime))
        return p

    def test_recently_modified_transcript_is_excluded(self, tmp_path):
        now = 1_000_000
        t = self._transcript(tmp_path, size=500, mtime=now - 10)  # touched 10s ago
        assert md.is_eligible(t, offset=0, now=now) is False

    def test_quiet_transcript_with_unread_bytes_is_included(self, tmp_path):
        now = 1_000_000
        t = self._transcript(tmp_path, size=500, mtime=now - md.QUIET_WINDOW_SECONDS - 1)
        assert md.is_eligible(t, offset=0, now=now) is True

    def test_quiet_transcript_already_fully_read_is_excluded(self, tmp_path):
        now = 1_000_000
        t = self._transcript(tmp_path, size=500, mtime=now - md.QUIET_WINDOW_SECONDS - 1)
        assert md.is_eligible(t, offset=500, now=now) is False

    def test_exactly_at_the_quiet_window_is_included(self, tmp_path):
        now = 1_000_000
        t = self._transcript(tmp_path, size=500, mtime=now - md.QUIET_WINDOW_SECONDS)
        assert md.is_eligible(t, offset=0, now=now) is True

    def test_offset_beyond_current_size_is_excluded_not_negative(self, tmp_path):
        """A shrunk file must not read as 'has unread bytes'."""
        now = 1_000_000
        t = self._transcript(tmp_path, size=100, mtime=now - md.QUIET_WINDOW_SECONDS - 1)
        assert md.is_eligible(t, offset=500, now=now) is False


def _jsonl(*records):
    import json
    return "\n".join(json.dumps(r) for r in records).encode()


def _user(content):
    return {"type": "user", "message": {"role": "user", "content": content}}


def _assistant(*blocks):
    return {"type": "assistant", "message": {"role": "assistant", "content": list(blocks)}}


class TestReduceKeepsConversation:
    def test_plain_user_string_is_kept_verbatim(self):
        out = md.reduce(_jsonl(_user("fix the failing test")), md.TOTAL_CHAR_BUDGET)
        assert "fix the failing test" in out

    def test_assistant_text_is_kept_verbatim(self):
        out = md.reduce(_jsonl(_assistant({"type": "text", "text": "I found the bug"})),
                        md.TOTAL_CHAR_BUDGET)
        assert "I found the bug" in out

    def test_assistant_thinking_is_dropped(self):
        out = md.reduce(_jsonl(_assistant({"type": "thinking", "thinking": "SECRETMUSING"})),
                        md.TOTAL_CHAR_BUDGET)
        assert "SECRETMUSING" not in out

    def test_tool_use_becomes_one_identifying_line(self):
        out = md.reduce(
            _jsonl(_assistant({"type": "tool_use", "name": "Read",
                               "input": {"file_path": "/etc/hosts"}})),
            md.TOTAL_CHAR_BUDGET)
        assert "Read" in out and "/etc/hosts" in out
        assert len(out.strip().splitlines()) == 1

    def test_non_conversation_record_types_are_dropped(self):
        out = md.reduce(_jsonl({"type": "attachment", "content": "BIGBLOB"},
                               {"type": "file-history-snapshot", "x": "SNAP"},
                               {"type": "mode", "mode": "MODEY"}),
                        md.TOTAL_CHAR_BUDGET)
        assert out.strip() == ""


class TestReduceDropsMachinery:
    def test_successful_tool_result_body_is_dropped(self):
        out = md.reduce(
            _jsonl(_user([{"type": "tool_result", "content": "HUGE OUTPUT", "is_error": False}])),
            md.TOTAL_CHAR_BUDGET)
        assert "HUGE OUTPUT" not in out

    def test_error_tool_result_keeps_a_capped_head(self):
        body = "E" * 5000
        out = md.reduce(
            _jsonl(_user([{"type": "tool_result", "content": body, "is_error": True}])),
            md.TOTAL_CHAR_BUDGET)
        assert "E" * 50 in out
        assert out.count("E") <= md.MAX_ERROR_CHARS

    def test_user_list_text_becomes_an_injection_marker_not_a_human_turn(self):
        injected = "Base directory for this skill: /x\n" + ("BODY " * 2000)
        out = md.reduce(_jsonl(_user([{"type": "text", "text": injected}])),
                        md.TOTAL_CHAR_BUDGET)
        assert "injected" in out.lower()
        assert "BODY BODY" not in out
        assert "Base directory for this skill: /x" in out

    def test_bash_input_becomes_a_dollar_prefixed_command(self):
        out = md.reduce(_jsonl(_user("<bash-input>git status</bash-input>")),
                        md.TOTAL_CHAR_BUDGET)
        assert "$ git status" in out

    def test_bash_stdout_is_dropped(self):
        out = md.reduce(_jsonl(_user("<bash-stdout>NOISE</bash-stdout>")), md.TOTAL_CHAR_BUDGET)
        assert "NOISE" not in out

    def test_local_command_stdout_is_dropped(self):
        out = md.reduce(_jsonl(_user("<local-command-stdout>NOISE</local-command-stdout>")),
                        md.TOTAL_CHAR_BUDGET)
        assert "NOISE" not in out

    def test_local_command_caveat_is_dropped(self):
        out = md.reduce(_jsonl(_user("<local-command-caveat>BOILERPLATE</local-command-caveat>")),
                        md.TOTAL_CHAR_BUDGET)
        assert "BOILERPLATE" not in out

    def test_task_notification_is_dropped(self):
        out = md.reduce(_jsonl(_user("<task-notification>BACKGROUND</task-notification>")),
                        md.TOTAL_CHAR_BUDGET)
        assert "BACKGROUND" not in out

    def test_slash_command_invocation_is_kept_as_a_marker(self):
        """Which command drove a session is decision-worthy; its boilerplate body is not."""
        out = md.reduce(_jsonl(_user("<command-name>/opsx:apply</command-name>")),
                        md.TOTAL_CHAR_BUDGET)
        assert "/opsx:apply" in out

    def test_command_message_duplicate_is_dropped(self):
        out = md.reduce(_jsonl(_user("<command-message>opsx:apply</command-message>")),
                        md.TOTAL_CHAR_BUDGET)
        assert out.strip() == ""


class TestReduceCaps:
    def test_oversized_user_turn_is_capped_and_marked(self):
        out = md.reduce(_jsonl(_user("U" * 50_000)), md.TOTAL_CHAR_BUDGET)
        assert out.count("U") <= md.MAX_USER_CHARS
        assert "truncated" in out

    def test_oversized_assistant_turn_is_capped_and_marked(self):
        out = md.reduce(_jsonl(_assistant({"type": "text", "text": "A" * 50_000})),
                        md.TOTAL_CHAR_BUDGET)
        assert out.count("A") <= md.MAX_ASSISTANT_CHARS
        assert "truncated" in out

    def test_a_single_oversized_entry_is_capped_independently_of_the_total_budget(self):
        """The 90.8%-of-a-session paste that motivated per-entry caps (design.md Decision 10)."""
        out = md.reduce(_jsonl(_user("P" * 500_000)), char_budget=md.TOTAL_CHAR_BUDGET)
        assert out.count("P") <= md.MAX_USER_CHARS

    def test_total_budget_truncates_oldest_first_with_a_leading_marker(self):
        records = [_user(f"turn{i} " + "x" * 500) for i in range(50)]
        out = md.reduce(_jsonl(*records), char_budget=2000)
        assert len(out) <= 2000 + 200          # marker allowance
        assert "turn49" in out                  # newest kept
        assert "turn0 " not in out              # oldest dropped
        assert out.lstrip().startswith("[")     # leading truncation marker

    def test_under_budget_output_has_no_leading_marker(self):
        out = md.reduce(_jsonl(_user("short")), md.TOTAL_CHAR_BUDGET)
        assert not out.lstrip().startswith("[")


class TestReduceRobustness:
    def test_malformed_lines_are_skipped_not_fatal(self):
        raw = b'not json\n' + _jsonl(_user("real turn")) + b'\n{"broken":\n'
        assert "real turn" in md.reduce(raw, md.TOTAL_CHAR_BUDGET)

    def test_empty_input_yields_empty_output(self):
        assert md.reduce(b"", md.TOTAL_CHAR_BUDGET).strip() == ""


class TestSessionState:
    def _transcript(self, tmp_path, data=b"line one\nline two\n"):
        p = tmp_path / "sess.jsonl"
        p.write_bytes(data)
        return p

    def test_absent_state_starts_at_zero_with_no_guard(self, tmp_path):
        st = md.load_state(tmp_path / "missing.json")
        assert st["offset"] == 0
        assert st["guard_sha"] is None

    def test_state_round_trips(self, tmp_path):
        f = tmp_path / "s.json"
        md.save_state(f, offset=42, guard_sha="deadbeef")
        st = md.load_state(f)
        assert st["offset"] == 42 and st["guard_sha"] == "deadbeef"

    def test_corrupt_state_file_falls_back_to_zero(self, tmp_path):
        f = tmp_path / "s.json"
        f.write_text("{not json")
        assert md.load_state(f)["offset"] == 0

    def test_reading_unread_bytes_does_not_advance_the_offset(self, tmp_path):
        t = self._transcript(tmp_path)
        f = tmp_path / "s.json"
        md.save_state(f, offset=0, guard_sha=None)

        md.read_unread(t, 0)

        assert md.load_state(f)["offset"] == 0

    def test_a_resumed_and_grown_session_yields_only_the_delta(self, tmp_path):
        t = self._transcript(tmp_path, b"OLD\n")
        offset = t.stat().st_size
        t.write_bytes(b"OLD\nNEW\n")

        assert md.read_unread(t, offset) == b"NEW\n"

    def test_guard_matches_so_the_stored_offset_is_trusted(self, tmp_path):
        t = self._transcript(tmp_path, b"OLD\n")
        offset = t.stat().st_size
        state = {"offset": offset, "guard_sha": md.compute_guard_sha(t, offset)}
        t.write_bytes(b"OLD\nNEW\n")

        assert md.resolve_start_offset(t, state) == offset

    def test_rewritten_prefix_is_detected_and_reprocesses_from_zero(self, tmp_path):
        """The runtime enforcement of the append-only assumption (design.md Decision 8)."""
        t = self._transcript(tmp_path, b"ORIGINAL\n")
        offset = t.stat().st_size
        state = {"offset": offset, "guard_sha": md.compute_guard_sha(t, offset)}
        t.write_bytes(b"REWRITTN\nNEW\n")  # same length prefix, different bytes

        assert md.resolve_start_offset(t, state) == 0

    def test_truncated_file_reprocesses_from_zero(self, tmp_path):
        t = self._transcript(tmp_path, b"A" * 500)
        state = {"offset": 500, "guard_sha": md.compute_guard_sha(t, 500)}
        t.write_bytes(b"A" * 100)

        assert md.resolve_start_offset(t, state) == 0

    def test_guard_covers_only_the_last_guard_bytes_of_a_long_prefix(self, tmp_path):
        t = self._transcript(tmp_path, b"H" * (md.GUARD_BYTES * 3))
        offset = md.GUARD_BYTES * 3
        sha = md.compute_guard_sha(t, offset)
        expected = md.hashlib.sha256(b"H" * md.GUARD_BYTES).hexdigest()
        assert sha == expected

    def test_guard_of_a_short_prefix_covers_the_whole_prefix(self, tmp_path):
        t = self._transcript(tmp_path, b"tiny")
        assert md.compute_guard_sha(t, 4) == md.hashlib.sha256(b"tiny").hexdigest()

    def test_zero_offset_has_no_guard(self, tmp_path):
        t = self._transcript(tmp_path)
        assert md.compute_guard_sha(t, 0) is None

    def test_state_filename_is_distinct_per_profile_for_the_same_session_id(self, tmp_path):
        """Two profiles can hold a transcript with the same session id."""
        a = tmp_path / ".claude" / "projects" / "-p" / "abc.jsonl"
        b = tmp_path / ".claude-work" / "projects" / "-p" / "abc.jsonl"
        for x in (a, b):
            x.parent.mkdir(parents=True, exist_ok=True)
            x.write_bytes(b"{}\n")

        assert md.session_state_path(tmp_path, a) != md.session_state_path(tmp_path, b)


NOTE_HEADER = "# Distilled Sessions — chezmoi\n\n## Maintenance signals\n\n- nothing to report\n\n"


def _note(*entries):
    body = NOTE_HEADER
    for date, text in entries:
        body += f"## {date} — session\n\n{text}\n\n"
    return body


class TestRollover:
    def test_note_below_threshold_yields_no_move(self):
        note = _note(("2026-08-26", "a"), ("2026-08-27", "b"))
        assert md.compute_rollover(note, threshold=10_000) is None

    def test_over_threshold_moves_all_but_the_newest_dated_entry(self):
        note = _note(("2026-08-26", "OLDEST" * 200),
                     ("2026-08-27", "MIDDLE" * 200),
                     ("2026-08-28", "NEWEST" * 200))

        kept, moved = md.compute_rollover(note, threshold=1000)

        assert "NEWEST" in kept and "OLDEST" not in kept and "MIDDLE" not in kept
        assert "OLDEST" in moved and "MIDDLE" in moved and "NEWEST" not in moved

    def test_non_dated_sections_are_never_moved(self):
        note = _note(("2026-08-26", "OLD" * 400), ("2026-08-28", "NEW" * 400))

        kept, moved = md.compute_rollover(note, threshold=1000)

        assert "# Distilled Sessions" in kept
        assert "## Maintenance signals" in kept
        assert "Maintenance signals" not in moved

    def test_a_single_dated_entry_is_never_moved_however_large(self):
        note = _note(("2026-08-28", "HUGE" * 5000))
        assert md.compute_rollover(note, threshold=100) is None

    def test_a_note_with_no_dated_entries_yields_no_move(self):
        assert md.compute_rollover(NOTE_HEADER, threshold=1) is None

    def test_newest_is_chosen_by_date_not_by_position(self):
        note = _note(("2026-08-28", "NEWEST" * 200), ("2026-08-26", "OLDEST" * 200))

        kept, moved = md.compute_rollover(note, threshold=1000)

        assert "NEWEST" in kept and "OLDEST" in moved


class TestStateDirectory:
    def test_layout_is_under_local_state(self, tmp_path):
        d = md.state_dir(home=tmp_path)
        assert d == tmp_path / ".local" / "state" / "memory-distiller"

    def test_created_on_first_run_when_absent(self, tmp_path):
        d = md.ensure_state_dir(home=tmp_path)
        assert d.is_dir()

    def test_creating_twice_is_not_an_error(self, tmp_path):
        md.ensure_state_dir(home=tmp_path)
        assert md.ensure_state_dir(home=tmp_path).is_dir()

    def test_registry_and_log_live_in_the_state_directory(self, tmp_path):
        d = md.state_dir(home=tmp_path)
        assert md.registry_path(home=tmp_path) == d / "registry.json"
        assert md.log_path(home=tmp_path) == d / "distiller.log"


class TestRegistry:
    def test_absent_registry_is_empty(self, tmp_path):
        assert md.load_registry(tmp_path / "nope.json") == {}

    def test_register_then_list_round_trips(self, tmp_path):
        f = tmp_path / "registry.json"
        md.register_project(f, "/Users/craig/work/api", "api-notes")

        assert md.load_registry(f) == {"/Users/craig/work/api": {"bm_project": "api-notes"}}

    def test_unregister_removes_the_entry(self, tmp_path):
        f = tmp_path / "registry.json"
        md.register_project(f, "/Users/craig/work/api", "api-notes")
        md.unregister_project(f, "/Users/craig/work/api")

        assert md.load_registry(f) == {}

    def test_unregistering_an_absent_project_is_not_an_error(self, tmp_path):
        f = tmp_path / "registry.json"
        md.unregister_project(f, "/nope")
        assert md.load_registry(f) == {}

    def test_registering_twice_leaves_exactly_one_entry(self, tmp_path):
        f = tmp_path / "registry.json"
        md.register_project(f, "/Users/craig/work/api", "api-notes")
        md.register_project(f, "/Users/craig/work/api", "api-notes")

        assert len(md.load_registry(f)) == 1

    def test_re_registering_refreshes_the_basic_memory_project_name(self, tmp_path):
        f = tmp_path / "registry.json"
        md.register_project(f, "/Users/craig/work/api", "old-name")
        md.register_project(f, "/Users/craig/work/api", "new-name")

        assert md.load_registry(f)["/Users/craig/work/api"]["bm_project"] == "new-name"

    def test_trailing_slash_is_the_same_project(self, tmp_path):
        f = tmp_path / "registry.json"
        md.register_project(f, "/Users/craig/work/api", "api-notes")
        md.register_project(f, "/Users/craig/work/api/", "api-notes")

        assert len(md.load_registry(f)) == 1

    def test_corrupt_registry_reads_as_empty_rather_than_crashing(self, tmp_path):
        f = tmp_path / "registry.json"
        f.write_text("{{{")
        assert md.load_registry(f) == {}


class TestOnlyRegisteredProjectsAreRead:
    def test_unregistered_project_with_transcripts_is_never_read(self, tmp_path):
        """spec: 'Unregistered project is ignored'."""
        import os
        now = 1_000_000
        registered, ignored = "/Users/craig/work/api", "/Users/craig/work/secret"
        for root in (registered, ignored):
            t = _make_transcript(tmp_path, ".claude", root, "s.jsonl", "{}\n")
            os.utime(t, (now - 10_000, now - 10_000))

        reg = {registered: {"bm_project": "api-notes"}}
        found = md.eligible_sessions(reg, home=tmp_path, directory=tmp_path / "state", now=now)

        assert [s["project_root"] for s in found] == [registered]

    def test_enumeration_never_mutates_the_registry(self, tmp_path):
        """Pruning dead entries is task 8.4's job, in the run loop, and is a log-and-skip
        rather than a removal. Enumeration itself must leave the registry alone."""
        reg = {"/gone/away": {"bm_project": "x"}}
        assert md.eligible_sessions(reg, home=tmp_path, directory=tmp_path / "state",
                                    now=1_000_000) == []
        assert reg == {"/gone/away": {"bm_project": "x"}}

    def test_live_session_is_not_eligible(self, tmp_path):
        import os
        now = 1_000_000
        root = "/Users/craig/work/api"
        t = _make_transcript(tmp_path, ".claude", root, "s.jsonl", "{}\n")
        os.utime(t, (now - 5, now - 5))

        reg = {root: {"bm_project": "api-notes"}}
        assert md.eligible_sessions(reg, home=tmp_path, directory=tmp_path / "state",
                                    now=now) == []


class _Tool:
    """Stands in for an MCP tool descriptor."""
    def __init__(self, name, description="d", schema=None):
        self.name = name
        self.description = description
        self.inputSchema = schema or {"type": "object", "properties": {}}


class TestToolAllowlist:
    def test_allowed_tools_are_converted(self):
        out = md.to_anthropic_tools([_Tool("read_note"), _Tool("search_notes")])
        assert [t["name"] for t in out] == ["read_note", "search_notes"]

    def test_worker_write_tools_are_never_offered_to_the_model(self):
        out = md.to_anthropic_tools([_Tool("write_note"), _Tool("edit_note")])
        assert out == []

    def test_destructive_tools_are_never_exposed(self):
        """The model has read-only access; worker writes are direct and preselected."""
        out = md.to_anthropic_tools(
            [_Tool("write_note"), _Tool("delete_note"),
             _Tool("delete_project"), _Tool("move_note")])
        assert out == []

    def test_unknown_future_tools_are_excluded_by_default(self):
        out = md.to_anthropic_tools([_Tool("some_new_tool_v3")])
        assert out == []

    def test_schema_is_carried_across_under_the_anthropic_key(self):
        schema = {"type": "object", "properties": {"project": {"type": "string"}}}
        out = md.to_anthropic_tools([_Tool("read_note", "reads", schema)])
        assert out[0]["input_schema"] == schema
        assert out[0]["description"] == "reads"


class _Block:
    def __init__(self, **kw):
        self.__dict__.update(kw)


class _Response:
    def __init__(self, content, stop_reason="end_turn"):
        self.content = content
        self.stop_reason = stop_reason
        self.usage = _Block(input_tokens=10, output_tokens=5)


class ScriptedClient:
    """Fake Anthropic client replaying canned responses; records requests."""
    def __init__(self, responses):
        self._responses = list(responses)
        self.requests = []

    @property
    def messages(self):
        return self

    async def create(self, **kwargs):
        self.requests.append(kwargs)
        return self._responses.pop(0)


def _run(coro):
    import asyncio
    return asyncio.run(coro)


FAKE_SERVER = pathlib.Path(__file__).resolve().parent / "fake_mcp_server.py"


class TestSystemPrompt:
    def test_repo_skill_carries_the_worker_invariants(self):
        prompt = md.load_system_prompt()

        assert "project=" in prompt
        assert "[category]" in prompt
        assert "[[wikilinks]]" in prompt
        assert "never write curated notes" in prompt.lower()

    def test_runtime_guide_is_included_when_the_server_provides_it(self):
        class Session:
            async def read_resource(self, uri):
                assert uri == "memory://ai_assistant_guide"
                return _Block(contents=[_Block(text="## Server guide\nUse project explicitly.")])

        prompt = _run(md.load_system_prompt(Session()))

        assert "## Server guide" in prompt

    def test_unavailable_runtime_guide_falls_back_to_the_repo_skill(self):
        class Session:
            async def read_resource(self, uri):
                raise RuntimeError("resource unavailable")

        prompt = _run(md.load_system_prompt(Session()))

        assert "never write curated notes" in prompt.lower()
        assert "resource unavailable" not in prompt

    def test_tool_loop_loads_the_runtime_prompt_when_one_is_not_supplied(self):
        class Session:
            async def read_resource(self, uri):
                return _Block(contents=[_Block(text="server guide")])

        client = ScriptedClient([_Response([_Block(type="text", text="done")])])

        _run(md.run_tool_loop(client, Session(), None, "prompt", []))

        assert "Memory distillation instructions" in client.requests[0]["system"]
        assert "server guide" in client.requests[0]["system"]


class TestToolUseLoopAgainstRealStdioServer:
    """The MCP side is a real stdio server subprocess -- only its behaviour is canned."""

    def _session(self, calls_file, **env):
        import os, sys
        return md.mcp_session(
            command=[sys.executable, str(FAKE_SERVER)],
            env={**os.environ, "FAKE_MCP_CALLS": str(calls_file), **env},
        )

    def _calls(self, calls_file):
        import json
        if not calls_file.exists():
            return []
        return [json.loads(x) for x in calls_file.read_text().splitlines() if x.strip()]

    def test_a_scripted_tool_call_round_trips(self, tmp_path):
        calls_file = tmp_path / "calls.jsonl"
        client = ScriptedClient([
            _Response([_Block(type="tool_use", id="t1", name="read_note",
                              input={"identifier": "Distilled", "project": "chezmoi"})],
                      stop_reason="tool_use"),
            _Response([_Block(type="text", text="done")]),
        ])

        async def go():
            async with self._session(calls_file) as session:
                tools = md.to_anthropic_tools((await session.list_tools()).tools)
                return await md.run_tool_loop(client, session, "sys", "prompt", tools)

        result = _run(go())

        assert [c["tool"] for c in self._calls(calls_file)] == ["read_note"]
        assert result["calls"][0]["name"] == "read_note"
        assert "done" in result["text"]

    def test_the_project_argument_reaches_the_server(self, tmp_path):
        """spec: every call names the target basic-memory project explicitly."""
        calls_file = tmp_path / "calls.jsonl"
        client = ScriptedClient([
            _Response([_Block(type="tool_use", id="t1", name="read_note",
                              input={"identifier": "T", "project": "chezmoi"})],
                      stop_reason="tool_use"),
            _Response([_Block(type="text", text="ok")]),
        ])

        async def go():
            async with self._session(calls_file) as session:
                tools = md.to_anthropic_tools((await session.list_tools()).tools)
                return await md.run_tool_loop(client, session, "sys", "prompt", tools)

        _run(go())

        assert self._calls(calls_file)[0]["arguments"]["project"] == "chezmoi"

    def test_the_destructive_tool_is_withheld_even_though_the_server_offers_it(self, tmp_path):
        calls_file = tmp_path / "calls.jsonl"

        async def go():
            async with self._session(calls_file) as session:
                offered = {t.name for t in (await session.list_tools()).tools}
                exposed = {t["name"] for t in md.to_anthropic_tools(
                    (await session.list_tools()).tools)}
                return offered, exposed

        offered, exposed = _run(go())

        assert "delete_note" in offered      # the server really does offer it
        assert "delete_note" not in exposed  # and the worker really does withhold it

    def test_a_model_call_to_a_withheld_tool_is_refused_not_executed(self, tmp_path):
        calls_file = tmp_path / "calls.jsonl"
        client = ScriptedClient([
            _Response([_Block(type="tool_use", id="t1", name="delete_note",
                              input={"identifier": "Session Notes", "project": "chezmoi"})],
                      stop_reason="tool_use"),
            _Response([_Block(type="text", text="understood")]),
        ])

        async def go():
            async with self._session(calls_file) as session:
                tools = md.to_anthropic_tools((await session.list_tools()).tools)
                return await md.run_tool_loop(client, session, "sys", "prompt", tools)

        _run(go())

        assert self._calls(calls_file) == []   # never reached the server

    def test_the_loop_stops_at_max_turns(self, tmp_path):
        calls_file = tmp_path / "calls.jsonl"
        forever = [_Response([_Block(type="tool_use", id=f"t{i}", name="search_notes",
                                     input={"query": "q", "project": "chezmoi"})],
                             stop_reason="tool_use") for i in range(50)]
        client = ScriptedClient(forever)

        async def go():
            async with self._session(calls_file) as session:
                tools = md.to_anthropic_tools((await session.list_tools()).tools)
                return await md.run_tool_loop(client, session, "sys", "prompt", tools,
                                              max_turns=3)

        result = _run(go())

        assert len(result["calls"]) == 3
        assert result["stopped_at_max_turns"] is True

    def test_usage_is_accumulated_across_turns(self, tmp_path):
        calls_file = tmp_path / "calls.jsonl"
        client = ScriptedClient([
            _Response([_Block(type="tool_use", id="t1", name="search_notes",
                              input={"query": "q", "project": "chezmoi"})],
                      stop_reason="tool_use"),
            _Response([_Block(type="text", text="ok")]),
        ])

        async def go():
            async with self._session(calls_file) as session:
                tools = md.to_anthropic_tools((await session.list_tools()).tools)
                return await md.run_tool_loop(client, session, "sys", "prompt", tools)

        result = _run(go())

        assert result["usage"]["input_tokens"] == 20   # two turns x 10
        assert result["usage"]["output_tokens"] == 10


class TestWriteVerification:
    RESULT = "# write_note\nproject: chezmoi\npermalink: chezmoi/distilled-sessions\n"

    def test_matching_project_verifies(self):
        v = md.verify_write([{"name": "write_note", "arguments": {}, "result": self.RESULT}],
                            expected_project="chezmoi")
        assert v["ok"] is True
        assert v["permalink"] == "chezmoi/distilled-sessions"

    def test_mismatched_project_fails_verification(self):
        """spec: 'Write lands in the wrong project' -- a misfile, not an error."""
        wrong = self.RESULT.replace("project: chezmoi", "project: some-other-project")
        v = md.verify_write([{"name": "write_note", "arguments": {}, "result": wrong}],
                            expected_project="chezmoi")
        assert v["ok"] is False
        assert "some-other-project" in v["reason"]

    def test_no_write_at_all_fails_verification(self):
        v = md.verify_write([{"name": "search_notes", "arguments": {}, "result": "none"}],
                            expected_project="chezmoi")
        assert v["ok"] is False

    def test_empty_call_list_fails_verification(self):
        assert md.verify_write([], expected_project="chezmoi")["ok"] is False

    def test_an_edit_note_call_also_counts_as_a_write(self):
        result = "# edit_note\nproject: chezmoi\npermalink: chezmoi/x\n"
        assert md.verify_write([{"name": "edit_note", "arguments": {}, "result": result}],
                               expected_project="chezmoi")["ok"] is True

    def test_a_result_with_no_project_line_fails_verification(self):
        v = md.verify_write([{"name": "write_note", "arguments": {}, "result": "ok!"}],
                            expected_project="chezmoi")
        assert v["ok"] is False


class TestMachineOwnedOutput:
    """Tasks 7.1-7.4 use the real stdio fake server, not a mocked MCP session."""

    def _session(self, calls_file, **env):
        import os, sys
        return md.mcp_session(
            command=[sys.executable, str(FAKE_SERVER)],
            env={**os.environ, "FAKE_MCP_CALLS": str(calls_file), **env},
        )

    def _calls(self, calls_file):
        import json
        return [json.loads(line) for line in calls_file.read_text().splitlines() if line]

    def test_first_distillation_creates_the_machine_note_and_second_appends(self, tmp_path):
        from datetime import date
        calls_file = tmp_path / "calls.jsonl"

        async def go():
            async with self._session(calls_file) as session:
                await md.append_distillation(session, "scratch", "first observation", date(2026, 8, 30))
                await md.append_distillation(session, "scratch", "second observation", date(2026, 8, 31))

        _run(go())
        calls = self._calls(calls_file)
        writes = [call["tool"] for call in calls if call["tool"] in md.WRITING_TOOLS]

        assert writes == ["write_note", "edit_note"]
        assert calls[1]["arguments"]["title"] == md.MACHINE_NOTE_TITLE
        assert calls[-1]["arguments"]["identifier"] == md.MACHINE_NOTE_TITLE

    def test_rollover_writes_a_dated_archive_and_trims_the_live_note(self, tmp_path):
        from datetime import date
        calls_file = tmp_path / "calls.jsonl"
        body = _note(("2026-08-29", "OLDER" * 300), ("2026-08-31", "NEWEST" * 300))

        async def go():
            async with self._session(calls_file) as session:
                await md.rollover_machine_note(session, "scratch", body, threshold=1000,
                                               today=date(2026, 8, 31))

        _run(go())
        calls = self._calls(calls_file)

        archive = next(call for call in calls if call["tool"] == "write_note")
        trim = next(call for call in calls if call["tool"] == "edit_note")
        assert archive["arguments"]["title"] == "Distilled Sessions Archive — 2026-08-31"
        assert "OLDER" in archive["arguments"]["content"]
        assert trim["arguments"]["identifier"] == md.MACHINE_NOTE_TITLE
        assert "NEWEST" in trim["arguments"]["content"]
        assert "OLDER" not in trim["arguments"]["content"]

    def test_maintenance_signals_are_replaced_and_report_size_and_structure(self, tmp_path):
        import json
        calls_file = tmp_path / "calls.jsonl"
        notes = {
            md.MACHINE_NOTE_TITLE: NOTE_HEADER,
            "Chezmoi Current Status": "# Chezmoi Current Status\n" + "x" * 20_000,
            "Chezmoi Session Notes": "# Chezmoi Session Notes\n## 2026-08-31\n" + "y" * 60_000,
        }

        async def go():
            async with self._session(calls_file, FAKE_MCP_NOTES_JSON=json.dumps(notes)) as session:
                await md.refresh_maintenance_signals(session, "scratch")
                await md.refresh_maintenance_signals(session, "scratch")

        _run(go())
        calls = self._calls(calls_file)
        replacements = [call for call in calls if call["tool"] == "edit_note"
                        and call["arguments"].get("operation") == "replace_section"]

        assert len(replacements) == 2
        assert all(call["arguments"]["identifier"] == md.MACHINE_NOTE_TITLE for call in replacements)
        signal = replacements[-1]["arguments"]["content"]
        assert "Chezmoi Current Status" in signal and "20,000" in signal
        assert "Chezmoi Session Notes" in signal and "60,000" in signal
        assert "missing required sections: ## Status Summary, ## Open" in signal

    def test_curated_notes_are_read_only_across_output_operations(self, tmp_path):
        import json
        from datetime import date
        calls_file = tmp_path / "calls.jsonl"
        notes = {
            md.MACHINE_NOTE_TITLE: _note(("2026-08-29", "OLD" * 300),
                                         ("2026-08-31", "NEW" * 300)),
            "Chezmoi Current Status": "# Chezmoi Current Status\n## Status Summary\n## Open\n",
            "Chezmoi Session Notes": "# Chezmoi Session Notes\n## 2026-08-31\n",
        }

        async def go():
            async with self._session(calls_file, FAKE_MCP_NOTES_JSON=json.dumps(notes)) as session:
                await md.append_distillation(session, "scratch", "observation", date(2026, 8, 31))
                await md.rollover_machine_note(session, "scratch", notes[md.MACHINE_NOTE_TITLE],
                                               threshold=1000, today=date(2026, 8, 31))
                await md.refresh_maintenance_signals(session, "scratch")

        _run(go())
        writes = [call for call in self._calls(calls_file) if call["tool"] in md.WRITING_TOOLS]
        targets = {call["arguments"].get("identifier", call["arguments"].get("title"))
                   for call in writes}

        assert "Chezmoi Current Status" not in targets
        assert "Chezmoi Session Notes" not in targets


class TestRunOnce:
    def test_quiescent_session_is_written_by_the_worker_then_advances_its_offset(self, tmp_path):
        import json
        import os
        calls_file = tmp_path / "calls.jsonl"
        root = str(tmp_path / "scratch")
        pathlib.Path(root).mkdir()
        transcript = _make_transcript(tmp_path, ".claude", root, "session.jsonl",
                                      _jsonl(_user("capture this decision")).decode())
        now = 1_000_000
        os.utime(transcript, (now - md.QUIET_WINDOW_SECONDS - 1,) * 2)
        notes = {
            "Chezmoi Current Status": "# Chezmoi Current Status\n## Status Summary\n## Open\n",
            "Chezmoi Session Notes": "# Chezmoi Session Notes\n## 2026-08-31\n",
        }
        client = ScriptedClient([_Response([_Block(type="text", text="- [decision] Captured")])])

        result = _run(md.run_once(
            client, {root: {"bm_project": "scratch"}}, home=tmp_path,
            directory=tmp_path / "state", now=now,
            mcp_command=[sys.executable, str(FAKE_SERVER)],
            mcp_env={"FAKE_MCP_CALLS": str(calls_file), "FAKE_MCP_NOTES_JSON": json.dumps(notes)},
        ))

        assert result["distilled"] == 1
        assert md.load_state(md.session_state_path(tmp_path / "state", transcript))["offset"] == transcript.stat().st_size
        assert {tool["name"] for tool in client.requests[0]["tools"]} == {
            "read_note", "search_notes", "recent_activity",
        }
        calls = [json.loads(line) for line in calls_file.read_text().splitlines() if line]
        write_targets = {call["arguments"].get("identifier", call["arguments"].get("title"))
                         for call in calls if call["tool"] in md.WRITING_TOOLS}
        assert md.MACHINE_NOTE_TITLE in write_targets
        assert "Chezmoi Current Status" not in write_targets
        assert "Chezmoi Session Notes" not in write_targets

    def test_rate_limit_keeps_offset_and_defers_retry(self, tmp_path):
        import os
        root = str(tmp_path / "scratch")
        pathlib.Path(root).mkdir()
        transcript = _make_transcript(tmp_path, ".claude", root, "session.jsonl",
                                      _jsonl(_user("capture this decision")).decode())
        now = 1_000_000
        os.utime(transcript, (now - md.QUIET_WINDOW_SECONDS - 1,) * 2)

        class RateLimitError(Exception):
            retry_after = 123

        class RateLimitedClient(ScriptedClient):
            async def create(self, **kwargs):
                raise RateLimitError("slow down")

        result = _run(md.run_once(
            RateLimitedClient([]), {root: {"bm_project": "scratch"}}, home=tmp_path,
            directory=tmp_path / "state", now=now,
            mcp_command=[sys.executable, str(FAKE_SERVER)],
        ))

        state = md.load_state(md.session_state_path(tmp_path / "state", transcript))
        assert result["distilled"] == 0
        assert state["offset"] == 0
        assert state["retry_after"] == now + 123
        retry = _run(md.run_once(
            ScriptedClient([_Response([_Block(type="text", text="would write")])]),
            {root: {"bm_project": "scratch"}}, home=tmp_path,
            directory=tmp_path / "state", now=now + 122,
            mcp_command=[sys.executable, str(FAKE_SERVER)],
        ))
        assert retry["eligible"] == 0

    def test_missing_project_is_skipped_without_registry_mutation(self, tmp_path):
        missing = str(tmp_path / "gone")
        registry = {missing: {"bm_project": "gone"}}
        result = _run(md.run_once(ScriptedClient([]), registry, home=tmp_path,
                                  directory=tmp_path / "state", now=1_000_000))
        assert result["missing_projects"] == [missing]
        assert registry == {missing: {"bm_project": "gone"}}

    def test_broken_mcp_for_one_project_does_not_stop_another(self, tmp_path):
        import os
        bad_root, good_root = str(tmp_path / "bad"), str(tmp_path / "good")
        pathlib.Path(bad_root).mkdir(); pathlib.Path(good_root).mkdir()
        bad_transcript = _make_transcript(tmp_path, ".claude", bad_root, "session.jsonl",
                                          _jsonl(_user("will fail before model")).decode())
        transcript = _make_transcript(tmp_path, ".claude", good_root, "session.jsonl",
                                      _jsonl(_user("capture this decision")).decode())
        now = 1_000_000
        os.utime(bad_transcript, (now - md.QUIET_WINDOW_SECONDS - 1,) * 2)
        os.utime(transcript, (now - md.QUIET_WINDOW_SECONDS - 1,) * 2)

        def command_for(project_root):
            return ["definitely-not-a-command"] if project_root == bad_root else [sys.executable, str(FAKE_SERVER)]

        result = _run(md.run_once(
            ScriptedClient([_Response([_Block(type="text", text="- [decision] okay")])]),
            {bad_root: {"bm_project": "bad"}, good_root: {"bm_project": "good"}},
            home=tmp_path, directory=tmp_path / "state", now=now,
            mcp_command=command_for,
        ))
        assert result["distilled"] == 1
        assert any("MCP startup failed" in error for error in result["errors"])

    def test_max_sessions_cap_leaves_backlog_for_next_run(self, tmp_path):
        import os
        root = str(tmp_path / "scratch")
        pathlib.Path(root).mkdir()
        now = 1_000_000
        for name in ("one.jsonl", "two.jsonl"):
            transcript = _make_transcript(tmp_path, ".claude", root, name,
                                          _jsonl(_user("capture")).decode())
            os.utime(transcript, (now - md.QUIET_WINDOW_SECONDS - 1,) * 2)
        result = _run(md.run_once(
            ScriptedClient([_Response([_Block(type="text", text="- [decision] one")])]),
            {root: {"bm_project": "scratch"}}, home=tmp_path,
            directory=tmp_path / "state", now=now, max_sessions=1,
            mcp_command=[sys.executable, str(FAKE_SERVER)],
        ))
        assert result["eligible"] == result["distilled"] == 1


class TestObservability:
    def test_two_no_key_runs_exit_zero_and_log_once(self, tmp_path, monkeypatch):
        warnings = []
        monkeypatch.delenv("ANTHROPIC_API_KEY", raising=False)
        monkeypatch.setattr(md, "ensure_state_dir", lambda: tmp_path)
        monkeypatch.setattr(md, "configure_logging", lambda: tmp_path / "distiller.log")
        monkeypatch.setattr(md, "registry_path", lambda: tmp_path / "registry.json")
        monkeypatch.setattr(md.LOG, "warning", lambda message, *args: warnings.append(message % args))
        assert md.main(["run"]) == 0
        assert md.main(["run"]) == 0
        assert warnings == ["ANTHROPIC_API_KEY is absent; worker is a no-op until it is configured"]

    def test_log_rotation_is_size_bounded(self, tmp_path, monkeypatch):
        monkeypatch.setattr(md, "MAX_LOG_BYTES", 50)
        monkeypatch.setattr(md, "LOG_BACKUP_COUNT", 1)
        path = md.configure_logging(tmp_path)
        handler = next(handler for handler in md.LOG.handlers
                       if getattr(handler, "baseFilename", None) == str(path))
        md.LOG.info("x" * 100)
        md.LOG.info("y" * 100)
        handler.close()
        md.LOG.removeHandler(handler)
        assert path.with_name(path.name + ".1").exists()

    def test_startup_failure_is_logged(self, tmp_path, monkeypatch, caplog):
        import types
        monkeypatch.setenv("ANTHROPIC_API_KEY", "test-key")
        monkeypatch.setattr(md, "ensure_state_dir", lambda: tmp_path)
        monkeypatch.setattr(md, "configure_logging", lambda: tmp_path / "distiller.log")
        monkeypatch.setattr(md, "registry_path", lambda: tmp_path / "registry.json")

        class BrokenAnthropic:
            def __init__(self):
                raise RuntimeError("dependency start failure")

        monkeypatch.setitem(sys.modules, "anthropic", types.SimpleNamespace(AsyncAnthropic=BrokenAnthropic))
        assert md.main(["run"]) == 1
        assert "worker failed before distillation" in caplog.text


class TestOffsetDoesNotAdvanceOnMisfile:
    """End to end through the real stdio fake: a misfiled write must leave the offset alone."""

    def _go(self, tmp_path, fake_project):
        import os, sys, json
        calls_file = tmp_path / "calls.jsonl"
        state_file = tmp_path / "state.json"
        md.save_state(state_file, offset=0, guard_sha=None)

        async def go():
            async with md.mcp_session(
                command=[sys.executable, str(FAKE_SERVER)],
                env={**os.environ, "FAKE_MCP_CALLS": str(calls_file),
                     "FAKE_MCP_PROJECT": fake_project},
            ) as session:
                return await md._worker_write(session, "write_note", {
                    "title": "Distilled", "content": "body", "project": "chezmoi",
                })

        write = _run(go())
        verdict = md.verify_write([write], expected_project="chezmoi")
        if verdict["ok"]:
            md.save_state(state_file, offset=999, guard_sha="x")
        return verdict, md.load_state(state_file)

    def test_misfiled_write_leaves_the_offset_unchanged(self, tmp_path):
        verdict, state = self._go(tmp_path, fake_project="WRONG-PROJECT")
        assert verdict["ok"] is False
        assert state["offset"] == 0

    def test_correctly_filed_write_advances_the_offset(self, tmp_path):
        verdict, state = self._go(tmp_path, fake_project="chezmoi")
        assert verdict["ok"] is True
        assert state["offset"] == 999
