# Search Strategies

## When initial search returns no results

1. **Broaden terms**: "JWT authentication" -> "authentication" -> "auth" -> "security"
2. **Try title search**: `search_notes(query="auth", search_type="title")`
3. **Check recent activity**: `recent_activity(timeframe="30d")` to browse what exists
4. **Browse directories**: `list_directory(dir_name="/")` to see folder structure
5. **Wildcard context**: `build_context(url="memory://folder/*")` for entire folders

## When search returns too many results

1. **Add specificity**: "API" -> "API authentication JWT"
2. **Filter by date**: `search_notes(query="auth", after_date="2025-01-01")`
3. **Use title search**: `search_notes(query="Auth System", search_type="title")` for exact names

## Combining strategies for comprehensive recall

For important topics, combine multiple tool calls:

```
# 1. Find the main entity
results = search_notes(query="<topic>")

# 2. Build its context graph (2 hops)
context = build_context(url="memory://<permalink>", depth=2)

# 3. Search for related terms found in relations
search_notes(query="<related term from relations>")

# 4. Check for recent updates
recent_activity(timeframe="7d")
```

## Understanding search_type parameter

| Value | Behavior | Best for |
|-------|----------|----------|
| `"text"` (default) | Full-text search across all content | General topic queries |
| `"title"` | Matches against entity titles only | Finding specific notes by name |
| `"permalink"` | Matches against permalink patterns | Programmatic lookups, wildcards |

## Note on memory:// URLs

- `memory://title` — by title
- `memory://folder/title` — by folder + title
- `memory://permalink` — by permalink (hyphens, lowercase)
- `memory://folder/*` — all in folder
- Underscores auto-convert to hyphens: `memory://my_note` finds `my-note`
