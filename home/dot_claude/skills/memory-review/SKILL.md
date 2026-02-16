---
name: memory-review
description: "Audit and clean up the Basic Memory knowledge base. Use when the user says 'clean up memory', 'find duplicates', 'review knowledge base', 'memory health check', 'audit my notes', 'consolidate notes', or 'tidy up basic memory'. Also use when the user notices redundant or outdated notes and wants to improve knowledge base quality."
---

# Review Basic Memory

Audit the knowledge base for duplicates, quality issues, and consolidation opportunities.

## Workflow

### Step 1: Get project overview

```
list_memory_projects()
recent_activity(timeframe="30d", project="<project>")
list_directory(dir_name="/", depth=2, project="<project>")
```

Report: total notes, folder structure, recent activity volume.

### Step 2: Find potential duplicates

Search for topics that likely have overlapping notes:

```
search_notes(query="<common topic>", page_size=50, project="<project>")
```

**Duplicate indicators:**
- Multiple notes with similar titles (e.g., "API Design" and "API Design Discussion")
- Notes in different folders covering the same topic
- Conversation notes that overlap with decision/learning notes on the same subject

For each duplicate cluster, present to the user:
- The notes that overlap
- What's unique to each
- Recommendation: merge into one (using `edit_note` to consolidate) and `delete_note` the redundant one

### Step 3: Find quality issues

Read a sample of notes and check:

```
read_note(identifier="<permalink>", project="<project>")
```

**Quality checklist per note:**
- Has 3+ observations with `[category]` prefixes?
- Has 2+ relations with `[[wikilinks]]`?
- Uses specific categories (not generic `[note]` or `[info]`)?
- Uses specific relation types (not just `relates_to`)?
- Tags present on observations?
- Content still accurate/relevant?

### Step 4: Find orphaned notes

Look for notes with no relations (isolated from the graph):

```
list_directory(dir_name="<folder>", project="<project>")
read_note(identifier="<note>", project="<project>")
```

For orphans, suggest:
- Relations that should exist based on content
- Related notes they should link to (search to find candidates)

### Step 5: Present audit report

1. **Duplicates found**: list each cluster with merge recommendation
2. **Quality issues**: notes below threshold with specific fixes
3. **Orphans**: notes with no relations, with suggested connections
4. **Stale content**: notes that may be outdated
5. **Folder structure**: suggestions for better organization (defer to `/memory-organize`)

### Step 6: Execute fixes (with permission)

Ask the user before making changes. For each approved fix:

- **Merge duplicates**: `edit_note(operation="append")` on the keeper, `delete_note` the duplicate
- **Add relations**: `edit_note(operation="append")` to add missing relation entries
- **Improve observations**: `edit_note(operation="replace_section", section="## Observations")`
- **Archive stale notes**: defer to `/memory-organize` for moving to archive folders
