# Design

## Context

This repo already has one working mechanism for chezmoi-managed Claude Code settings — the `claude-settings-ledger`/`claude-settings-modifier` pair — but its jurisdiction is `~/.claude*/settings.json` (persona, i.e. identity-scoped) and its `_chezmoiManaged` retraction machinery exists specifically because `chezmoi apply` re-runs against a *fixed, known* file on every machine. Neither property holds for the new target: an arbitrary project repo's `.claude/settings.local.json`, which chezmoi does not (and should not) know about ahead of time, is gitignored by convention, and is stamped on demand rather than on every `chezmoi apply`. See `proposal.md` - Why for the motivating gap (Pattern B accreting by accident, no reusable starting point).

`claude-tooling-write-guard` and `check-claude-overrides` are the existing precedent for "small standalone executable under `home/dot_local/bin/`, rendered via chezmoi templating for machine-specific values, callable directly by name once on `PATH`." This change follows that same shape rather than inventing a new one.

## Goals / Non-Goals

**Goals:**
- Reuse the existing `home/dot_local/bin/executable_<name>.tmpl` convention rather than a new delivery mechanism.
- Keep the merge logic simple (additive union, no retraction) since nothing here is re-applied automatically by `chezmoi apply` — a human runs the stamping command when they want a posture change.
- Make Pattern C's danger structurally hard to reach by accident (refuse without container evidence), not just documented.

**Non-Goals:**
- Auto-detection of pattern from repo signals (see proposal's Non-goals).
- Any retraction/ledger semantics for `.claude/settings.local.json` — see Decision 3.
- Launching or managing the Pattern C container at runtime — only its definition is templated here (see proposal's Non-goals; likely `project-session-manager` follow-up).

## Decisions

### Decision 1: Three flat templates, not one parameterized template
Each pattern (`claude-pattern-a`, `claude-pattern-b`, `claude-pattern-c`) is its own file under `home/.chezmoitemplates/`, holding a static (or lightly templated, e.g. machine-name interpolation in a comment) JSON `permissions` block — not one template branching on a `pattern` parameter.

**Alternative considered**: a single `claude-pattern` template taking `(dict "pattern" "a")` like `claude-settings-modifier` takes its sibling-file lookup. Rejected: the three patterns have materially different shapes (Pattern A is `deny`-heavy, Pattern B is `allow`-heavy, Pattern C is a single scalar), so a shared template would mostly be an `if/else/else` wrapper around three unrelated JSON blobs — no logic is actually shared, unlike `claude-settings-modifier` where the *merge algorithm* is what's shared across personas. Flat files are also easier for the user to hand-edit and diff over time (this repo's stated preference: "reasonable defaults, review before applying" per the article's own graduated-promotion framing).

### Decision 2: Stamping tool is a standalone executable, not a Claude Skill
Implemented as `home/dot_local/bin/executable_apply-claude-pattern.tmpl`, following the `claude-tooling-write-guard` / `check-claude-overrides` precedent, rather than as a new entry under `home/dot_claude/skills/`.

**Alternative considered**: a Claude Skill (invoked via `/apply-claude-pattern` inside a session). Rejected for v1: the stamping action needs to happen *before* or independent of a Claude Code session even starting (you want the posture set before you launch, not mid-session), and a plain shell script composes more simply with the "extend `project-session-manager`" launch-time integration flagged as a Non-goal follow-up. Nothing here prevents adding a thin Skill wrapper later that shells out to the same executable.

### Decision 3: Additive union merge, no ledger/retraction
The stamping tool reads the existing `.claude/settings.local.json` (or starts from `{}`), unions the pattern's `permissions.allow`/`ask`/`deny` arrays into the existing arrays (dedup by value), and overwrites only `permissions.defaultMode`. It does **not** track what it previously wrote and does **not** remove entries on a later run with a different pattern.

**Alternative considered**: reuse `claude-settings-modifier`'s `_chezmoiManaged`-style retraction so switching from Pattern A to Pattern B cleanly removes Pattern A's `deny` entries. Rejected for v1: that machinery exists in the ledger because `chezmoi apply` is the sole writer of persona `settings.json` and needs to distinguish "chezmoi wrote this" from "the user or Claude Code added this at runtime." Here, `.claude/settings.local.json` already has other writers (Claude Code's own `/permissions` UI, manual edits, this repo's own 200-entry accretion) with no ledger today, and introducing one is exactly the kind of cross-cutting complexity (proposal's `claude-settings-ledger` took three iterations to stabilize) this proposal explicitly avoids taking on for a project-repo-scoped tool. Switching patterns cleanly is accepted as a known limitation (see Risks); a `--reset` flag that clears `permissions` entirely before stamping is a cheap escape hatch to include in tasks.md.

### Decision 4: Container-isolation check is a best-effort heuristic, not a guarantee
`apply-claude-pattern c` checks for `/.dockerenv`, a devcontainer marker env var (`REMOTE_CONTAINERS` / `CODESPACES` / similar), or an explicit `--i-know-this-is-a-container` override flag, in that order. Absent any of these, it refuses and prints the warning from spec Requirement "Pattern C requires evidence of container isolation."

**Alternative considered**: no check at all, just document the risk (matches how the source article itself only documents the risk in prose). Rejected: the whole point raised in the chezmoi-flexibility evaluation that led to this proposal was that Pattern C's safety is easy to lose silently by copying just the JSON; a structural refusal costs one file check and directly prevents the failure mode the article warns about. This is explicitly a heuristic, not a security boundary — a determined user can pass the override flag on a bare host — and the spec and tasks should say so rather than imply it's foolproof.

### Decision 5: Pattern C container template is a devcontainer, not a bespoke Dockerfile-only setup
Template `home/.chezmoitemplates/claude-pattern-c-devcontainer/` (a `devcontainer.json` + minimal `Dockerfile`) rather than a standalone Dockerfile plus ad hoc run script.

**Alternative considered**: bespoke Dockerfile + shell wrapper script for `docker run`. Rejected: devcontainer.json is a widely-supported, inspectable format (VS Code, the `devcontainer` CLI, and Claude Code's own container workflows all read it), which reduces this proposal's own future maintenance surface compared to a hand-rolled `docker run` invocation with all its flags spelled out in a shell script. The non-root user and working-tree-only bind mount (spec requirement) are ordinary devcontainer.json fields (`remoteUser`, `workspaceMount`), not custom logic.

## Risks / Trade-offs

- **[Risk] Switching patterns leaves stale entries from the previous pattern** (Decision 3's accepted limitation) → Mitigation: `apply-claude-pattern --reset <pattern>` clears `permissions.allow`/`ask`/`deny` before applying; document that a plain re-run only adds.
- **[Risk] The container-isolation check (Decision 4) is spoofable** → Mitigation: named explicitly as best-effort in the spec/warning text; never presented as a security boundary; the real boundary is the container itself, which this proposal templates but does not enforce is actually what's running.
- **[Risk] A stale, hand-accumulated `.claude/settings.local.json` (like this repo's own ~200-entry file) makes "union merge" mostly a no-op improvement** → Mitigation: out of scope to retroactively clean existing files; `--reset` (above) gives an opt-in path to start clean per repo, at the user's discretion.
- **[Risk] Pattern definitions drift out of sync with actual best practice over time** (no automatic review mechanism) → Mitigation: accepted; these are plain chezmoi-tracked files, so `git log`/`git blame` on the template files is the review trail, same as any other chezmoi-managed config.

## Migration Plan

Purely additive — no existing file, script, or persona setting is modified or removed. Deploys like any other `home/dot_local/bin/executable_*.tmpl` on the next `chezmoi apply` for machines with the `ai` tag (and `dev` tag for the Pattern C container template). No rollback beyond `chezmoi apply` after reverting the commit; no data migration since `.claude/settings.local.json` files this tool has not yet touched are unaffected.
