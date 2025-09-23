Always use:
- aws-knowledge-mcp-server to consult AWS knowledge, such as its docs, API references, architectural references, and well-architected guidance
- basic-memory to remember and recall previous conversations
- gemini-cli for large codebase analysis and multi-file comparisons
- sequential thinking for any decision making
- serena for semantic code retrieval and editing tools, and always update its symbols after any code changes
Read the CLAUDE.md root file before you do anything.

# Memory Consultation Protocol
When asked about memories or project context, ALWAYS check ALL available memory sources in this order:

1. **CLAUDE.md files** (configuration/instruction memory):
    - Read project CLAUDE.md (current working directory)
    - Read user CLAUDE.md (~/.claude/CLAUDE.md)
    - Focus: Project setup, development commands, architecture overview, user preferences, coding standards

2. **serena memories** (technical/code focus):
    - List available memories with `list_memories`
    - Read key memories like: project_overview, codebase_structure, tech_stack, code_style_conventions
    - Focus: Architecture, implementation details, recent code changes, technical decisions

3. **basic-memory** (strategic/conversation focus):
    - Check recent activity with `recent_activity`
    - Search for project-specific notes with `search_notes`
    - Focus: Strategic planning, business context, cross-session conversations, high-level insights

4. **Other memory sources** (if available):
    - Check any other MCP servers that might have memory capabilities
    - Look for README.md, documentation files, or other context files

# Response Format
When reporting memories, clearly identify:
- **Source** for each piece of information (CLAUDE.md, serena, basic-memory, etc.)
- **Type of memory** (configuration, technical, strategic, conversational)
- **Recency** of the information when relevant
- **Scope** (project-specific vs user-wide)
- **Gaps** where memory sources don't have information
#$ARGUMENTS
