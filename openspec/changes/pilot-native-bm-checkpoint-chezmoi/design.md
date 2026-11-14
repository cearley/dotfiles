# Design

## Context

See [proposal.md](proposal.md) for motivation and the [spec delta](specs/setup-memory-workflow/spec.md) for the behavior contract.

`run_onchange_after_darwin-36-2-install-claude-skills.sh.tmpl` already runs `npx skills add <spec> -g -a claude-code -y` for each entry in `packages.darwin.ai.agents.claude_code.skills`. The four currently declared entries (`memory-defrag`, `memory-lifecycle`, `memory-notes`, `memory-schema`) point at `basicmachines-co/basic-memory-skills --skill <name>`.

A live, read-only `npx skills add basicmachines-co/basic-memory --list` (no `--full-depth` needed) against the upstream monorepo confirms `bm-checkpoint`, `bm-orient`, and `memory-doctor` are all discoverable there via the identical mechanism — along with `memory-defrag` and the other three already-declared skills, which now also exist in this newer, consolidated repo. This resolves what the proposal flagged as an open mechanism question: no new installer logic, no chezmoi external, no vendoring. It is a `packages.yaml` data change only.

The installer script hardcodes `-a claude-code`; it does not install for Codex. Extending it for Codex is out of scope here — the pilot targets Claude Code only, consistent with "pilot on `chezmoi` with the harness already in use for this work," and keeps this change a data-only addition rather than also touching the installer script.

## Goals / Non-Goals

**Goals:** make `bm-checkpoint`, `bm-orient`, `memory-doctor` installable for Claude Code via the existing mechanism; produce real pilot evidence (at least one checkpoint/orient cycle, one doctor run) in the `chezmoi` project; keep the existing consent boundary and chezmoi config ownership completely untouched.

**Non-Goals:** no Codex installation path in this change (installer script changes deferred to a later change if the pilot extends there); no change to the installer script's behavior for the four existing skills; no attempt to reconcile `basicmachines-co/basic-memory-skills` vs. the newer consolidated `basicmachines-co/basic-memory` repo as the long-term source for the existing four — noted as an observation, not resolved here, since changing a working declaration isn't needed to ship this pilot.

## Decisions

### 1. Add three new `skills` entries, same repo-and-flag pattern, new source repo

Add to `packages.darwin.ai.agents.claude_code.skills` in `home/.chezmoidata/packages.yaml`:
```yaml
- "basicmachines-co/basic-memory --skill bm-checkpoint"
- "basicmachines-co/basic-memory --skill bm-orient"
- "basicmachines-co/basic-memory --skill memory-doctor"
```
No change to the installer script: it already iterates `$skills` generically. A comment above the new entries should note they come from the main repo (not `-skills`) and link the commit used for pilot evaluation, mirroring how the existing four entries are commented.

Alternative considered: wait for upstream to converge the two repos, or re-point the existing four at the new repo too, for consistency. Rejected for this change — it would widen the diff beyond the pilot's scope and isn't needed to install the three new skills. Worth a follow-up once pilot evidence exists.

### 2. No hook or settings installation accompanies the skill declarations

`npx skills add ... --skill <name>` installs only that skill's `SKILL.md` and its assets — it does not install the plugin's `hooks.json` registrations or run `bm-setup`. The two new ADDED requirements in the spec delta ("Native lifecycle hooks remain disabled," "Native setup/configuration skills do not write chezmoi-owned settings") are therefore satisfied by the chosen installation mechanism itself, not by an extra suppression step: `npx skills add` has no code path that would install a Claude Code plugin's hook registrations. No `plugin_marketplaces`/`plugins` entry is added for `basic-memory`, which is what would be required to get its hooks active.

### 3. Pilot evaluation happens by using the skills for real, not by writing new tests

This is a pilot measuring real usefulness, not a piece of workflow infrastructure with its own test suite. The deliverable is evidence (a bm-checkpoint note from an actual session, a bm-orient resume, a memory-doctor report) plus a findings note in the `chezmoi` basic-memory project, feeding the Stage 3/4 decision. `tests/run-template` still covers the `packages.yaml`/installer template rendering; no new automated test is introduced for skill *usage* since that's inherently an interactive, agent-invoked action.

## Risks / Trade-offs

- [`npx skills add` behavior could differ by version, or the upstream repo could restructure before the pilot runs] → re-run the same read-only `--list` check immediately before `chezmoi apply`; if the skills have moved or been removed, stop and update the entries rather than letting the `run_onchange` script fail partway.
- [Running `chezmoi apply` re-triggers the `run_onchange` script for all `ai`-tagged skills, not just the three new ones, since the trigger is "packages.yaml changed"] → this is existing, pre-change behavior (`npx skills update -g -y` already runs unconditionally first); no new risk introduced.
- [Pilot evidence turns out to be unconvincing or the skills conflict with existing session-log conventions in practice] → that is a legitimate pilot outcome; Stage 3/4 remain non-goals of this change regardless of result.

## Open Questions

- Should the four existing skill declarations be re-pointed from `basic-memory-skills` to the consolidated `basic-memory` repo for consistency? Deferred — doesn't block this pilot and is better decided once it's clear whether upstream is actually deprecating the separate `-skills` repo.
- Should Codex get the same three skills in a follow-up? Deferred to after the Claude Code pilot produces evidence; would require extending the installer script for a second agent, which is a larger change than this one.
