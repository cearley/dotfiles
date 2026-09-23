# Proposal

## Why

The two user-level rules, `global-preferences.md` (loads in every session) and `claude-tooling.md` (path-scoped), both describe the persona model: what personas are, which files are shared, which are per persona, and how to reference `.claude.json`. The duplication costs context in every session, even ones unrelated to Claude tooling. It also costs context twice whenever both rules load. The copies have already drifted into a factual inconsistency about where `.claude.json` lives:

- `global-preferences.md` line 37 implies `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.claude.json`, which is `~/.claude/.claude.json` when the variable is unset. That's wrong.
- `global-preferences.md` line 40 says the unnamed default uses `~/.claude.json`. That's right.
- `claude-tooling.md` says `$CLAUDE_CONFIG_DIR/.claude.json` is correct "for all of these", which resolves to `/.claude.json` when the variable is unset. That's wrong.

The verified behavior: when `CLAUDE_CONFIG_DIR` is unset, the file is `~/.claude.json` in the home directory, not inside `~/.claude/`. When it's set, the file is `$CLAUDE_CONFIG_DIR/.claude.json`. The docs (settings page) name `~/.claude.json` for the default, and this session, running with `CLAUDE_CONFIG_DIR=~/.claude-personal`, updated `~/.claude-personal/.claude.json`.

## What Changes

- Give each persona fact exactly one home, following the steady-state writing principle: a sentence stays only if an agent would act wrongly without it.
- **`global-preferences.md`** keeps only what applies to every session:
  - what `$CLAUDE_CONFIG_DIR` is, and the `echo` check
  - the persona list
  - the instruction to confirm the active persona before diagnosing
  - the fork pre-brief instruction, with its trigger list aligned to `claude-tooling.md`'s `paths:`
- **`claude-tooling.md`** becomes the only home for:
  - the shared vs per-persona layout
  - the per-persona path rules
  - the `.claude.json` location, stated once and correctly for both the unset and set cases
  - "ask whether every persona is meant" for audits and cleanups
- Fix the `.claude.json` inconsistency everywhere it appears in these two files.
- Add `**/.claude*/projects/**` to `claude-tooling.md`'s `paths:`. Transcript reads are the one per-persona path that doesn't currently load the rule (design D1).

## Non-goals

- Changing any script behavior.
- **Out of scope, recorded for follow-up:** scripts 38 and 39 fall back to `CLAUDE_CONFIG_DIR=~/.claude` when a machine has no `claude_envs`. That writes `~/.claude/.claude.json`, not the `~/.claude.json` that an unset default session reads. This probably explains the stray `~/.claude/.claude.json` on this machine.
- Restructuring `claude-tooling.md` beyond the persona material.

## Capabilities

### New Capabilities
<!-- none -->

### Modified Capabilities
<!-- none. This is a content refactor of agent-read guidance, plus a factual fix. The existing
claude-tooling-rule "Content Coverage" requirement (the persona sharing model is documented)
is still met, and no requirement text changes. skip_specs: true is set in .openspec.yaml. -->

## Impact

- **Files:** `home/dot_claude/rules/global-preferences.md.tmpl` and `home/dot_claude/rules/claude-tooling.md.tmpl`.
- **Tags:** `ai` only.
- **Ordering:** this builds on `claude-md-tool-ownership`, which is committed (`40f32a1`) but not archived. There are no spec conflicts, because this change has no deltas.
- **Security:** none.
