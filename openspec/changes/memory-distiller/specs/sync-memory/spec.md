## REMOVED Requirements

The `sync-memory` capability is retired in full. Its input source (SpecStory session logs) is
removed from this repository, and `memory-distiller` supersedes it — running on a schedule against
first-party Claude Code transcripts, writing through the basic-memory MCP server rather than
directly to vault files. Several of its behaviours were sound and are re-expressed as requirements
of `memory-distiller`; those are named individually below.

### Requirement: User-invoked only
**Reason**: The replacement is unattended by design, so a requirement forbidding automatic
invocation contradicts its purpose. The user-invoked path it protected still exists as
`/save-session`, which remains explicitly invoked.
**Migration**: None needed. Users who want an on-demand distillation run invoke the worker
directly; nothing runs automatically that did not already.

### Requirement: Dual-mode operation
**Reason**: The in-session mode existed so an already-running Claude Code session could do the
distillation without an API call. That is precisely what `/save-session` is. Keeping two ways to
do it in-session was redundant, and the standalone mode is now the only mode.
**Migration**: In-session distillation is `/save-session`. Unattended distillation is
`memory-distiller`.

### Requirement: Cursor-based sync state tracking
**Reason**: Superseded, not abandoned. `memory-distiller` tracks progress per session rather than
by a single filesystem cursor, because it reads many transcripts across several profiles.
**Migration**: Re-expressed as `memory-distiller`'s "Progress is tracked per session and advances
only on verified success", which additionally requires the write to be verified before progress
advances.

### Requirement: Filesystem project root stays resolved at runtime
**Reason**: The worker is a single machine-level program that is not installed per project, so
there is no installed copy whose project root could be baked in or resolved at runtime. Project
roots come from the registry.
**Migration**: Re-expressed as `memory-distiller`'s "Projects opt in by explicit registration".

### Requirement: Dedicated note target
**Reason**: Superseded, not abandoned — this was the soundest constraint in the capability and is
strengthened in the replacement.
**Migration**: Re-expressed as `memory-distiller`'s "The worker writes exactly one note per project
and never curated content", which makes the prohibition on touching curated notes explicit rather
than implied.

### Requirement: Standalone mode requires ANTHROPIC_API_KEY from the environment
**Reason**: Superseded. The replacement has no non-API mode, so the key is required
unconditionally rather than per-mode, and absence must degrade gracefully rather than error,
because nothing interactive is watching.
**Migration**: Re-expressed as `memory-distiller`'s "Absent credentials degrade to a logged
no-op".

### Requirement: Cost-sane default model, overridable
**Reason**: Superseded. Cost control in the replacement is broader than model choice alone, since
it runs unattended on a schedule rather than when a user asks.
**Migration**: Re-expressed and widened as `memory-distiller`'s "Per-run cost is bounded", which
covers per-run session caps, content budgets, and usage recording as well as model selection.

### Requirement: Extraction criteria are exposed via a flag, shared between modes
**Reason**: The requirement existed to stop two execution modes drifting apart. With only one mode
remaining there is nothing to keep in sync.
**Migration**: None needed. The replacement's instructions live in a single versioned skill asset.

### Requirement: Backlog processing is capped per run
**Reason**: Superseded, not abandoned.
**Migration**: Re-expressed as part of `memory-distiller`'s "Per-run cost is bounded".

### Requirement: Cursor commit is a separate, explicit step in default mode
**Reason**: Superseded. The two-step commit existed so an interrupted in-session distillation left
logs unsynced rather than lost. With no in-session mode, the equivalent protection is that progress
advances only after a verified successful write.
**Migration**: Re-expressed as `memory-distiller`'s "Progress is tracked per session and advances
only on verified success".

### Requirement: Project identity is resolved at install/apply-time, baked into the installed copy
**Reason**: The worker is machine-level and not rendered per project, so there is no installed copy
to bake an identity into. Baking identity in was a property of per-project distribution, which this
component no longer uses.
**Migration**: Each registry entry names its basic-memory project explicitly, and
`memory-distiller` requires that project be named on every MCP call.
