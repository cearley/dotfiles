## ADDED Requirements

### Requirement: Idempotent, drift-checked sync-memory skill installation via version marker
The skill SHALL render `.claude/skills/sync-memory/SKILL.md` from `assets/sync-memory-skill.md.template` using the same `__PROJECT__`/`__SMW_VERSION__` substitution and version-marker drift detection already used for the save-session skill.

#### Scenario: sync-memory skill absent
- **WHEN** `.claude/skills/sync-memory/SKILL.md` does not exist
- **THEN** the skill renders the canonical template and creates it, embedding the current `SMW_VERSION` marker

#### Scenario: sync-memory skill present and current
- **WHEN** `.claude/skills/sync-memory/SKILL.md` exists with a `setup-memory-workflow-version:N` marker equal to `SMW_VERSION` and still naming the current project
- **THEN** the skill reports it up to date and leaves it unchanged

#### Scenario: sync-memory skill present but drifted
- **WHEN** `.claude/skills/sync-memory/SKILL.md` exists with a version marker missing, older than `SMW_VERSION`, or naming a different project
- **THEN** the skill shows the current content against the canonical rendering and asks the user before replacing it — it SHALL NOT silently overwrite

### Requirement: Idempotent, drift-checked sync-memory script installation via version marker
The skill SHALL render `.claude/skills/sync-memory/scripts/sync-memory.py` from `scripts/sync-memory.py.template` using the same `__PROJECT__`/`__SMW_VERSION__` substitution and version-marker drift detection as the other three canonical assets, via the shared `check_templated_file()`/`apply_templated_file()` helpers, and SHALL set it executable.

#### Scenario: sync-memory script absent
- **WHEN** `.claude/skills/sync-memory/scripts/sync-memory.py` does not exist
- **THEN** the skill renders the canonical template to that path and marks it executable

#### Scenario: sync-memory script present and current
- **WHEN** the installed script has a `setup-memory-workflow-version:N` marker equal to `SMW_VERSION` and still names the current project
- **THEN** the skill reports it up to date and leaves it unchanged

#### Scenario: sync-memory script present but drifted
- **WHEN** the installed script's version marker is missing, older than `SMW_VERSION`, or names a different project
- **THEN** the skill shows the current content against the canonical rendering and asks the user before replacing it — it SHALL NOT silently overwrite

### Requirement: sync-memory script uses the same install-time templating as the other canonical assets
The canonical `sync-memory.py.template` source SHALL contain `__PROJECT__`/`__SMW_VERSION__` placeholders, rendered once at install time — consistent with `save-session-skill`, `sync-memory-skill`, and the hook message. The project's *filesystem* root (used to locate `.specstory/history` and the cursor state file) remains a separate, runtime-resolved concern, unaffected by this templating.

#### Scenario: Canonical template is project-agnostic until rendered
- **WHEN** the canonical `scripts/sync-memory.py.template` source is installed into a project
- **THEN** the rendered, installed copy has that project's identity baked in, and differs between projects the same way the other three canonical assets do

### Requirement: SMW_VERSION bump surfaces new pieces on existing installs
Introducing the sync-memory skill and script SHALL bump `SMW_VERSION`, so that a `check-drift.sh check` run against an install predating this change reports both new pieces as missing and creates them directly.

#### Scenario: Pre-existing install checked after this change ships
- **WHEN** `check-drift.sh check` runs in a project whose `setup-memory-workflow` install predates the sync-memory skill
- **THEN** it reports `.claude/skills/sync-memory/SKILL.md` and `.claude/skills/sync-memory/scripts/sync-memory.py` as missing and creates both directly, without prompting — consistent with how any other genuinely-missing piece is handled
