---
name: sync-memory
description: Distill unsynced SpecStory session logs into basic-memory. User-invoked only — run explicitly with /sync-memory when you want to capture insights from recent sessions.
disable-model-invocation: true
---

## Step 0 — Resolve the project

Run:
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/resolve-project-name.sh"
```
Use its stdout as `$PROJECT` for every step below. If it exits non-zero, stop — this
project has no git root to derive an identity from.

## Step 1 — Find unsynced logs

Run (this skill and its script are bundled in the `basic-memory-workflow` plugin, not
installed per-project):
```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/sync-memory.py"
```

This prints the content of any SpecStory session logs (`.specstory/history/`) modified
since the last sync, delimited by `--- BEGIN LOG: <path> ---` / `--- END LOG: <path> ---`
markers. If it reports "No unsynced logs found.", stop here — there's nothing to do.

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

Confirm the note title and permalink after saving.

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
