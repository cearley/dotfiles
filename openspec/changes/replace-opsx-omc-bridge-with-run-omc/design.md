# Design

## Context

See `proposal.md` - Why. Two independent pieces: (1) a data removal (`opsx-omc-bridge` from `packages.yaml` plus matching local uninstall), and (2) a new project-local orchestrator (`/opsx:run-omc`). They ship together because the orchestrator is the reason the plugin is no longer needed, but neither depends on the other's implementation.

The orchestrator is a port of a proven-in-pieces pattern from `WES.ViewPoint.CommonMicro.API`'s `.claude/commands/opsx/run-omc.md` and `.claude/scripts/opsx-preflight.sh` (see that repo's `docs/AUTONOMOUS_OPENSPEC_RUNS.md`), adapted to chezmoi's domain. This repo already has: `openspec/config.yaml` (chezmoi-specific `context`/`rules`), the generated `.claude/commands/opsx/*.md` set, `.claude/hooks/validate-template.sh` (render-check), and the `template-reviewer` agent.

## Goals / Non-Goals

**Goals:**
- Match the source orchestrator's control flow (preflight → phase-by-phase executor → evidence-gated task marking → parallel verify → bounded fix loop → report) closely enough that lessons from the source project's "Things that bite" section (diff-based review misses untracked files, deferred MCP tools, stale `CLAUDE.md` in subagents) carry over directly.
- Keep the command read-only with respect to git history: no commit, push, or archive, matching the source project's hard rule.

**Non-Goals:**
- No build-test-gate hook, `shfmt`, or Bash secrets-guard (see proposal.md - Non-goals). The verify step uses only what already exists.
- No attempt to make the orchestrator reusable across repos. It is as project-local as the source one.

## Decisions

### Preflight script: drop C#-specific checks, add nothing language-specific in their place
The source `opsx-preflight.sh` checks `omnisharp` presence and counts uncommitted `*.cs` files because the C# quality layers (OmniSharp/Rider/dotnet) need to know their own availability up front. Chezmoi has no compiled language and no equivalent toolchain-presence question, so `opsx-preflight.sh` here drops those checks entirely rather than substituting a chezmoi-specific analog — there is nothing to substitute. It keeps: change validation (`openspec validate`), task progress/strategy (`openspec instructions apply --json`), stale `.omc/prd.json` detection, the untracked-file baseline (needed for the verify step's `git add -N`, same reason as the source), and a dirty-tree count across **all** tracked files (`git status --porcelain`) rather than one glob — there is no single file extension that defines "this repo's source."

### Verify step: reuse existing agents/skills, no new reviewer agent
The source project's `openspec-reviewer` agent owns build/analyzer/stub conformance — a role with no chezmoi equivalent, since there is no build step. Rather than inventing a parallel agent, the chezmoi verify step runs only: `code-review` skill (logic correctness — the only pass that asks whether the logic is right, same rationale as the source), `opsx:verify` skill (artifact conformance — task completion, spec scenario coverage), and `template-reviewer` conditionally when any `.tmpl` file changed (convention violations — the one role with a direct, already-built chezmoi equivalent). The CI invariant checks (duplicate script numbers, trusted-list sync) are not re-run locally in this cut; they already run in GitHub Actions on push, and duplicating them here is exactly the kind of extra layer deferred to the build-test-gate follow-up.

### Untracked-file handling: port `git add -N` intent-to-add verbatim
The source project's step 5 finding — `code-review` reads `git diff`, which excludes untracked files, so new files an executor creates go unreviewed unless intent-added first — applies identically here regardless of language. `opsx-preflight.sh` records the untracked-file baseline the same way; `run-omc.md` intent-adds only files not in that baseline, then resets the mark after verification, identically to the source.

### Model selection: no complexity-based opus bump
The source project bumps the executor to `opus` when remaining tasks exceed six or the design touches `Infrastructure/Fulcrum/` — a domain-risk signal specific to that codebase. Chezmoi has no equivalent high-risk subtree flagged in advance, so this cut omits the bump and always uses the executor's pinned default (sonnet). This can be revisited once the orchestrator has run enough times to know whether any chezmoi area (e.g. `.chezmoiscripts/`, `packages.yaml`) warrants it — an explicit open question below, not a silent gap.

### Plugin removal: direct CLI commands, not a chezmoi script
`opsx-omc-bridge@opsx-omc-bridge` is confirmed installed and its marketplace registered on this machine (`claude plugin list` / `claude plugin marketplace list`). Removal is two direct commands run once, now, rather than a new `chezmoi` script: `claude plugin uninstall opsx-omc-bridge@opsx-omc-bridge -y` then `claude plugin marketplace remove opsx-omc-bridge`. No other machine has it provisioned yet, so there is nothing else to converge; if one is added later, the already-edited `packages.yaml` simply never installs it (the install script only acts on declared entries).

## Risks / Trade-offs

- **Never exercised end-to-end, same as the source.** The source project's own doc states `/opsx:run-omc` has not yet completed a real change end to end there either. → Mitigation: this change's own `tasks.md` includes a supervised first run against a small, already-valid change in this repo (not this change itself, to avoid the orchestrator managing its own creation) before considering the port done.
- **No build/test signal at all in this cut.** Without a build-test-gate hook, a bad fix loop could cycle on findings the agents can't actually resolve without ever hitting a hard failure signal (the source project's Stop/SubagentStop gate). → Mitigation: `--max-iterations` (default 3) bounds the loop regardless; the follow-up change adding the gate is already scoped in proposal.md - Non-goals, not left as a vague someday.
- **Removing the plugin and marketplace now, before the new orchestrator is proven,** means there's no fallback to `opsx-omc-bridge` if `/opsx:run-omc` turns out to need more iteration than expected. → Mitigation: acceptable per `run-omc.md`'s own hard rule (inherited from the source) that bridge/autopilot/ralph/team are never invoked from it anyway — keeping the plugin installed was not providing a safety net, just dead weight.

## Open Questions

- Whether any chezmoi subtree (e.g. `.chezmoiscripts/`, `home/.chezmoidata/packages.yaml`) should trigger an opus bump for the executor, once there's enough run history to tell. Deferred — answering it now would be a guess, and doesn't change this change's specs, approach, or tasks.
