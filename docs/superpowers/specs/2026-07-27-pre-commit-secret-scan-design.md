# Pre-Commit Secret-Scan Hook — Design

## Context

An audit of this repo against an external "AI-aware dotfiles" article's five-pillar
framework found that secrets hygiene here is architecturally strong — secrets live in
KeePassXC and are injected at `chezmoi apply` template-execution time via
`keepassxcAttribute`/`keepassxcAttachment`, never committed to git at all (see
`openspec/specs/secret-management/spec.md`) — but the enforcement half is missing.
The `private_` prefix + restrictive-permissions convention is documented, not
mechanically enforced. Nothing today stops a human from pasting a raw token into a
tracked file by mistake. This design closes that gap with a real git pre-commit hook.

This governs the chezmoi **source repo itself** — distinct from
`home/.chezmoiscripts/` (which configure the deployed target machine) and
`.claude/hooks/` (which only fire during Claude Code sessions and would not catch a
manual terminal `git commit`).

## Decisions

Made via clarifying questions during brainstorming:

- **Scanner: gitleaks**, installed via Homebrew. Mature ruleset (AWS/GitHub/GCP keys,
  private key blocks, generic high-entropy secrets), lower long-term false-positive
  maintenance burden than a hand-rolled regex script, fits the existing Homebrew-first
  package-management convention.
- **Activation: auto-configured via a chezmoi script.** A `run_onchange` script sets
  `core.hooksPath` on the source repo directly, so the hook goes live automatically on
  `chezmoi apply` — no manual step to remember or forget.
- **Enforcement: hard block.** A detected secret exits non-zero and rejects the
  commit. Consistent with the existing global policy of never casually bypassing
  hooks; `git commit --no-verify` remains the standard, deliberate escape hatch,
  identical to any other repo hook.

## Components

### 1. `.githooks/pre-commit`

A plain, tracked bash script — not go-templated, not routed through
`home/scripts/shared-utils.sh` (that helper is for chezmoi-deployed target scripts;
this is repo tooling that must work independent of any `chezmoi apply` having run).

Responsibilities:
- Check `gitleaks` is on `PATH`. If missing, print an error pointing at
  `brew install gitleaks` and exit 1 (fail closed — see Error Handling).
- Run `gitleaks protect --staged --redact -v --config .gitleaks.toml`, scoped to the
  currently staged diff only (not full history, not unstaged changes).
- Propagate gitleaks' exit code as the hook's exit code.

### 2. `.gitleaks.toml` (repo root)

Default gitleaks ruleset, plus one allowlist entry present from the start:
`tests/fixtures/keepassxc.json`, which contains a fake
`-----BEGIN OPENSSH PRIVATE KEY-----` block used by the mock KeePassXC CLI
(`tests/bin/keepassxc-cli`) for template testing. Without this entry the hook would
block on its own test fixtures on the very first run.

### 3. `packages.yaml` — add `gitleaks`

Add `gitleaks` to `packages.darwin.core.brews`. Core tag, so it installs on every
machine regardless of selected tags — the hook is only useful if the binary is
reliably present. It's a homebrew-core formula, so no tap and no `trusted:` entry is
needed.

### 4. New chezmoi script — activation

A `run_onchange_after` (or `_before`, TBD by convention) script, named and positioned
via the `/new-script` skill at implementation time. Expected to land near the existing
git/GitHub-auth scripts (45–46 range), and must run **after** position 23 (Homebrew
package install) so `gitleaks` is already present by the time `core.hooksPath` starts
taking effect within the same `chezmoi apply` run.

Behavior: `git -C {{ .chezmoi.sourceDir }} config core.hooksPath .githooks`. Idempotent
and cheap — safe to re-run every apply, which also makes it self-healing if
`core.hooksPath` is ever unset by accident.

## Data Flow

```
git commit
  → git invokes .githooks/pre-commit (via core.hooksPath)
    → checks `gitleaks` on PATH
    → gitleaks protect --staged --redact --config .gitleaks.toml
      → no findings  → exit 0 → commit proceeds
      → findings     → exit 1 → commit rejected, findings printed to stderr
```

## Error Handling

- **`gitleaks` not installed**: fail closed — block the commit with a clear
  remediation message. This is a deliberate asymmetry: silently letting commits
  through when the safety net itself is missing would defeat the purpose of adding it.
  `--no-verify` is the escape hatch for a deliberate, informed override.
- **`core.hooksPath` never configured** (e.g., repo cloned standalone, never
  `chezmoi apply`'d): the hook simply never activates. No behavior change from today,
  and out of scope — this design targets the primary chezmoi-managed use case.

## Testing

- Stage a scratch file containing a dummy high-confidence secret pattern (fake AWS
  access key shape) on a throwaway branch; confirm the commit is rejected and the
  finding is printed.
- Confirm a normal commit with no secrets passes cleanly.
- Confirm `tests/run-template` and `tests/fixtures/keepassxc.json` do **not** trigger
  a false positive once the allowlist entry is in place.
- On a clean checkout, run the new chezmoi script and confirm
  `git config core.hooksPath` reports `.githooks` afterward.

## Out of Scope

- Enterprise-style centralized policy distribution, CISO notification, or audit
  logging of blocked attempts — not applicable at this repo's single-user scale.
- Scanning full git history (only new commits going forward are in scope).
- Any change to the existing KeePassXC / `keepassxcAttribute` secret-injection model —
  this is purely an enforcement backstop, not a replacement.
