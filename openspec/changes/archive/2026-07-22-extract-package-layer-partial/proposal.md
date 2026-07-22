# Extract Package-Layer Iteration Partial

## Why

The category/tag eligibility iteration (`$categories := prepend .tag_choices "core"` → range → `or (eq $category "core") (has $category $.tags)` → `hasKey` guard → emit per-item command) is duplicated across all five package-layer scripts (23–27), and repeated four more times *inside* script 23 for taps/brews/casks/mas. That is ten copies of the same knowledge: "which package entries are eligible for installation given the machine's tags." Any change to eligibility semantics (a new tag rule, a new category source) currently requires synchronized edits in five files — a DRY violation flagged in the 2026-07-22 Pragmatic Programmer review, and the same class of drift that already bit the package-management spec (cargo before/after drift, fixed 2026-07-22).

## What Changes

- Add a reusable template partial in `home/.chezmoitemplates/` that resolves the eligible package items for a given `packages.yaml` key (e.g. `bun`, `uv`, `sdkman`, `cargo`, `taps`, `brews`, `casks`, `mas`) across tag categories, returning them grouped by category (following the JSON-returning precedent set by `machine-settings`).
- Rewrite scripts 24 (SDKMAN), 25 (UV), 26 (Bun), and 27 (Cargo) to consume the partial instead of inlining the iteration. Generated script output SHALL be byte-identical (or semantically identical) to today's output.
- Rewrite the four internal iterations in script 23 (Homebrew) to consume the same partial while keeping its layer-specific line formats (trusted annotations, Brewfile syntax, iCloud gating for `mas`).
- Preserve script 27's intentional deviation (no `core` prepend, `dev`-tag-only) as an explicit partial parameter rather than a divergent copy.
- Document the new partial in CLAUDE.md's Reusable Templates list.

## Capabilities

### New Capabilities

None — this refactors the internals of an existing capability.

### Modified Capabilities

- `package-management`: Add a requirement that category/tag eligibility resolution SHALL be defined in exactly one reusable template partial, consumed by all package-layer installation scripts; per-layer scripts retain only layer-specific concerns (install command, tool bootstrap, skip-layer gate, output format).

## Non-goals

- No change to `packages.yaml` structure, tag semantics, or which packages get installed on any machine.
- No change to script numbering, naming, timing (`before`/`after`), or the skip-layer prompt system.
- No consolidation of the per-layer scripts into a single script — one script per package manager remains intentional (orthogonality: a Bun failure must not block SDKMAN).
- No change to the zshrc/bashrc shared-alias duplication (tracked separately as a session next-step).

## Impact

- **Affected code**: `home/.chezmoitemplates/` (new partial), `home/.chezmoiscripts/run_onchange_before_darwin-2{3,4,5,6,7}-*.sh.tmpl`, `openspec/specs/package-management/spec.md` (delta), `CLAUDE.md` (template list).
- **Affected tags**: all (core, dev, ai, work, personal, datascience, mobile) — the iteration underpins every tag's package resolution, so verification must cover representative tag combinations.
- **Behavioral risk**: template refactor only; the rendered shell scripts are the contract. Verification via `tests/run-template` diffing rendered output before/after for multiple tag sets.
- **Security implications**: none — no secrets, permissions, or SIP interaction; the partial only reorganizes template logic over static `.chezmoidata` values. The `trusted:` Brewfile annotations must be preserved exactly, since they gate Homebrew's tap-trust prompts.
- **`run_onchange` side effect**: editing these scripts changes their source hash, so all five layers will re-run on the next `chezmoi apply` (idempotent, but slow; users can decline via the existing skip prompt).
