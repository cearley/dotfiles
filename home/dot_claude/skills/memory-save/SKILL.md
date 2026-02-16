---
name: memory-save
description: "Save conversations, decisions, and insights to Basic Memory with proper deduplication and knowledge graph structure. Use when the user says 'save this', 'remember this', 'write to memory', 'document this conversation', 'capture this decision', or when a conversation contains important decisions, discoveries, or action items worth preserving. Also use at the end of productive sessions to offer saving key takeaways."
---

# Save to Basic Memory

Record conversations and insights as structured knowledge graph entries, avoiding duplicates and building rich connections.

## Workflow

### Step 1: Identify what to save

Determine the note type from the conversation:

| Type | When | Folder |
|------|------|--------|
| Decision | A choice was made with rationale | `decisions/` |
| Discovery | A problem was diagnosed or insight found | `discoveries/` |
| Conversation | General discussion worth preserving | `conversations/` |
| Plan | Action items or roadmap discussed | `planning/` |
| Learning | New technique or knowledge gained | `learnings/` |

### Step 2: Search for existing notes (MANDATORY)

Before creating anything, search for existing content:

```
search_notes(query="<topic keywords>", project="<project>")
search_notes(query="<alternate terms>", search_type="title", project="<project>")
```

**If existing note found on this topic**: use `edit_note(operation="append")` to add new observations and relations. Do NOT create a duplicate.

**If no existing note**: proceed to Step 3.

### Step 3: Structure the note

Use the templates in [references/note-templates.md](references/note-templates.md) for the appropriate note type.

**Required elements:**
- Title: descriptive, prefixed with type (e.g., "Decision: Use PostgreSQL")
- 3+ observations with `[category]` prefixes
- 2+ relations with `[[exact entity titles]]` from search results
- Relevant `#tags` on observations

**Category reference:**
`[decision]`, `[fact]`, `[technique]`, `[requirement]`, `[insight]`, `[problem]`, `[solution]`, `[action]`

**Relation type reference:**
`implements`, `requires`, `part_of`, `extends`, `contrasts_with`, `caused_by`, `leads_to`, `follows`, `affects`

### Step 4: Search for relation targets

Before writing, search for entities to reference in relations:

```
search_notes(query="<related topic>", project="<project>")
```

Use exact titles from results in `[[wikilinks]]`. Forward references (to entities that don't exist yet) are OK — they auto-resolve when the target is created later.

### Step 5: Save and confirm

```
write_note(title="...", content="...", folder="...", tags=[...], project="<project>")
```

After saving, confirm to the user:
- What was saved (title)
- Where it was saved (folder)
- How many observations and relations were captured
- Any forward references that will resolve later
