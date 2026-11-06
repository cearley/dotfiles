# Spec Delta

## REMOVED Requirements

### Requirement: User-invoked only
**Reason**: The `sync-memory` capability is retired — the note it produced was separate from the one `/save-session` actually maintains, nothing read it automatically, and it sat unused for 3 months even as a manual tool.
**Migration**: The actual missed-save problem this was meant to mitigate is addressed by the new `crash-recovery-hook` requirement in `setup-memory-workflow` instead. `.specstory/history/` remains on disk as a raw archival fallback if a manual retrospective dig is ever needed.

### Requirement: Dual-mode operation
**Reason**: Retired with the capability — see above.
**Migration**: None needed; no replacement for `--standalone`/default dual-mode distillation is introduced.

### Requirement: Cursor-based sync state tracking
**Reason**: Retired with the capability — see above.
**Migration**: `.specstory/.sync-memory-state.json` becomes an inert leftover file; safe to delete, not read by anything after this change.

### Requirement: Filesystem project root stays resolved at runtime
**Reason**: Retired with the capability — see above.
**Migration**: None needed.

### Requirement: Dedicated note target
**Reason**: Retired with the capability — see above.
**Migration**: The existing distilled-insights basic-memory note is left in place as a historical artifact; it will simply stop receiving new entries.

### Requirement: Standalone mode requires ANTHROPIC_API_KEY from the environment
**Reason**: Retired with the capability — see above.
**Migration**: None needed; the new `crash-recovery-hook` never calls an external API.

### Requirement: Cost-sane default model, overridable
**Reason**: Retired with the capability — see above.
**Migration**: None needed.

### Requirement: Extraction criteria are exposed via a flag, shared between modes
**Reason**: Retired with the capability — see above.
**Migration**: None needed.

### Requirement: Backlog processing is capped per run
**Reason**: Retired with the capability — see above.
**Migration**: None needed.

### Requirement: Cursor commit is a separate, explicit step in default mode
**Reason**: Retired with the capability — see above.
**Migration**: None needed.

### Requirement: Project identity is resolved at install/apply-time, baked into the installed copy
**Reason**: Retired with the capability — see above.
**Migration**: `setup-memory-workflow`'s own project-identity resolution (used by `save-session` and the new `crash-recovery-hook`) is unaffected; this requirement only ever governed `sync-memory.py`'s own `__PROJECT__` substitution.
