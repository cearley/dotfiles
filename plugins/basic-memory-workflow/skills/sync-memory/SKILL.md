---
name: sync-memory
description: Distill unsynced SpecStory session logs into basic-memory. User-invoked only — run explicitly with /sync-memory when you want to capture insights from recent sessions.
disable-model-invocation: true
---

## Step 0 — Resolve and register the project

Run:
```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/ensure-project-registered.sh"
```
Use its stdout as `$PROJECT` for every step below. This also guarantees `$PROJECT` is
registered with basic-memory — don't rely on the `SessionStart` hook having already done
this; the plugin can become active mid-session (e.g. via `/reload-plugins`), in which case
`SessionStart` never fires and registration would otherwise be skipped. If it exits
non-zero, stop — either this project has no git root to derive an identity from, or the
`basic-memory` CLI isn't installed (`which basic-memory` to confirm).

## Step 1 — Find unsynced logs

Run (this skill and its script are bundled in the `basic-memory-workflow` plugin, not
installed per-project):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sync-memory.py"
```

This prints the content of any SpecStory session logs (`.specstory/history/`) modified
since the last sync, delimited by `--- BEGIN LOG: <path> ---` / `--- END LOG: <path> ---`
markers, followed by a final `--- CURSOR: <mtime> ---` line. If it reports "No unsynced
logs found.", stop here — there's nothing to do. Otherwise, remember the `<mtime>` value
verbatim — Step 4 needs it to commit the sync, and the cursor deliberately does not
advance until then, so an interrupted Step 3 leaves these logs unsynced rather than
silently lost.

## Step 2 — Distill each log

Run:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sync-memory.py" --print-extraction-prompt
```

Apply exactly those criteria to each log printed in Step 1 — this is the same prompt
`--standalone` mode sends to the API, kept in one place so the two paths can't drift
apart. Format each item as an observation with a `[category]` prefix (`[decision]`,
`[fact]`, `[technique]`, `[problem]`, `[solution]`, etc.) and link related entities with
`[[wikilinks]]`, per this project's basic-memory conventions.

## Step 3 — Append to the dedicated insights note

Pass `project="$PROJECT"` explicitly on every basic-memory MCP call in this step —
`search_notes`, `write_note`, and `edit_note` all silently default to whatever project
the server considers current (commonly a shared personal vault, not this project's) if
`project` is omitted. Omitting it is a silent misfile, not an error, so always pass it.

Search basic-memory project "$PROJECT" for a note titled "$PROJECT Distilled
SpecStory Insights" using search_notes.

Get the current timestamp for the section heading — run `date +"%Y-%m-%d %H:%M"` and use
its output verbatim; don't compose it from memory.

- If it exists, append the distilled content with `edit_note(operation="append")` under
  a new heading `## Synced <timestamp>`.
- If it doesn't exist yet, create it with `write_note` (title: "$PROJECT Distilled
  SpecStory Insights"), using the same heading structure.

Never write this content into the session-notes note that `/save-session` maintains —
the two notes are kept separate by design, so automated output never mixes with your
manually-curated log.

Read the tool result's own `project:`/`permalink:` fields back and confirm the project
matches `$PROJECT` before treating the write as successful — a mismatch means it went to
the wrong vault and needs to be deleted there (`delete_note`) and retried with an
explicit `project` before continuing to Step 4. Confirm the note title and permalink to
the user once the project match is verified.

## Step 4 — Commit the sync

Only after Step 3's write is confirmed against the correct project, run:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sync-memory.py" --mark-synced <mtime>
```
using the `<mtime>` value from Step 1's `--- CURSOR: ... ---` line. This is what advances
the sync cursor — do not skip it, and do not run it before Step 3 has actually succeeded,
or these logs will be marked synced without their content ever having been saved.

## Unattended / cron use

`sync-memory.py` also supports a fully self-contained `--standalone` mode for use with
no Claude Code session running (e.g. a cron job): it calls the Anthropic API directly
(requires `ANTHROPIC_API_KEY` in the environment) and writes straight to the vault file
itself. This skill does not configure any scheduling — if you want unattended syncing,
wire up your own cron entry or LaunchAgent. Unlike the steps above, cron doesn't start
with the project as its working directory, so `cd` into it explicitly, and reference the
script by its absolute installed path rather than `${CLAUDE_PLUGIN_ROOT}` (which is only
expanded inside Claude Code's own hook/skill execution context):

```bash
cd /path/to/this/project && /path/to/plugin/cache/basic-memory-workflow/scripts/sync-memory.py --standalone
```
