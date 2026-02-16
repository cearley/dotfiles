---
name: memory-organize
description: "Reorganize Basic Memory notes into a better folder structure. Use when the user says 'organize my notes', 'restructure folders', 'move notes', 'archive old notes', 'clean up folder structure', or 'reorganize knowledge base'. Also use when notes are accumulating in root or flat folders and would benefit from hierarchical organization."
---

# Organize Basic Memory

Reorganize notes into a coherent folder structure while preserving all knowledge graph relations.

## Workflow

### Step 1: Assess current structure

```
list_directory(dir_name="/", depth=3, project="<project>")
```

Map what exists: note counts per folder, naming patterns, any flat dumps.

### Step 2: Propose folder structure

Based on note types and topics found, propose a structure. Common pattern:

```
project/
  conversations/     # Session summaries, discussions
  decisions/         # Decision records with rationale
  discoveries/       # Troubleshooting, root cause findings
  learnings/         # Techniques, insights, knowledge gained
  planning/          # Roadmaps, action items, sprints
  specs/             # Technical specifications
  docs/              # Documentation, guides
  archive/           # Outdated or superseded content
    2025/            # Archived by year
```

Adapt to what the user actually has. Don't impose structure where it doesn't fit.

Present the proposed structure and get user approval before moving anything.

### Step 3: Execute moves

For each note being moved:

```
move_note(
    identifier="<exact title or permalink>",
    destination_path="<folder>/<filename>.md",
    project="<project>"
)
```

**Key rules:**
- `move_note` preserves all relations automatically — no manual re-linking needed
- Destination path must include filename with `.md` extension
- Use the existing permalink as the filename (e.g., `decisions/use-postgresql.md`)
- Folders auto-created when specifying nested paths

### Step 4: Archive stale content

For notes identified as outdated or superseded:

```
# Add deprecation notice
edit_note(
    identifier="<old note>",
    operation="prepend",
    content="**ARCHIVED** - Superseded by [[<New Note>]]\n\n---\n\n",
    project="<project>"
)

# Move to archive
move_note(
    identifier="<old note>",
    destination_path="archive/2025/<filename>.md",
    project="<project>"
)
```

### Step 5: Verify and report

```
list_directory(dir_name="/", depth=2, project="<project>")
```

Report to the user:
- Notes moved: count
- Notes archived: count
- New folder structure (visual tree)
- All relations preserved (automatic)
