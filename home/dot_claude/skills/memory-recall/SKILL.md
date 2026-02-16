---
name: memory-recall
description: "Build comprehensive context from Basic Memory on a topic. Use at the start of conversations when the user asks about a topic that may have prior knowledge, when switching topics mid-conversation, or when the user says 'what do we know about X', 'recall X', 'what have we discussed about X', 'continue our discussion on X', or 'catch me up on X'. Also use proactively when the user's question likely has relevant prior context in Basic Memory."
---

# Recall from Basic Memory

Build comprehensive context by searching with multiple strategies and traversing the knowledge graph.

## Workflow

### Step 1: Determine project

If project is unknown:
```
list_memory_projects()
```
Ask the user which project, or use the default. Remember their choice for the session.

### Step 2: Multi-strategy search

Run multiple searches to maximize recall. Don't stop at the first query.

```
# Primary: direct topic search
search_notes(query="<exact topic>", project="<project>")

# Broaden: alternate terms and synonyms
search_notes(query="<broader or alternate terms>", project="<project>")

# Title match: find by entity name
search_notes(query="<topic>", search_type="title", project="<project>")

# Recent: check if discussed recently
recent_activity(timeframe="30d", project="<project>")
```

### Step 3: Build context graph

For the most relevant results, traverse the knowledge graph to find connected knowledge:

```
build_context(url="memory://<best-match-permalink>", depth=2, project="<project>")
```

This returns:
- The root entity with observations and relations
- Related entities up to 2 hops away
- Connection paths between entities

### Step 4: Read key notes

Read the most relevant 2-3 notes in full to understand details:

```
read_note(identifier="<permalink>", project="<project>")
```

### Step 5: Present summary

Synthesize findings into a concise briefing for the user:

1. **What's known**: Key facts and decisions from prior sessions
2. **Connections**: How this topic relates to other knowledge
3. **Recent changes**: What's been updated recently
4. **Open items**: Unresolved questions or pending actions
5. **Forward references**: Entities referenced but not yet created

See [references/search-strategies.md](references/search-strategies.md) for advanced search patterns when initial searches return poor results.
