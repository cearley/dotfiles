# Design: Extract Package-Layer Iteration Partial

## Context

Five package-layer scripts render install commands from `packages.yaml` by iterating tag categories. The iteration skeleton is duplicated ten times:

- Scripts 24 (SDKMAN), 25 (UV), 26 (Bun): identical skeleton — `$categories := prepend .tag_choices "core"`, then per category: `or (eq $category "core") (has $category $.tags)` eligibility check, `hasKey`/non-empty guard on the layer key, emit one command per item.
- Script 27 (Cargo): same skeleton minus the `core` prepend (cargo has no core packages; `dev`-tag gated), eligibility check reduced to `has $category $.tags`.
- Script 23 (Homebrew): the skeleton appears four times for list-valued keys (`taps`, `brews`, `casks`, `mas`) plus once more for the `brew_env` dict merge. Each instance renders a different line format (Brewfile syntax, `trusted:` annotations, iCloud-gated `mas`).

The knowledge being duplicated is *eligibility resolution*: "given the machine's tags, which categories contribute items for key K, in what order." The per-line rendering differs legitimately per layer and is NOT duplication (same syntax, different knowledge).

Existing precedent: `machine-settings` is a `.chezmoitemplates` partial that returns JSON for consumers to `fromJson` — established pattern for partials that return data rather than text.

## Goals / Non-Goals

**Goals:**
- Exactly one authoritative implementation of category/tag eligibility resolution.
- Byte-identical rendered script output for the current machine's tag set (verified by diff).
- Preserve script 27's no-core semantics as an explicit, documented parameter.

**Non-Goals:**
- Changing which packages install anywhere, `packages.yaml` structure, or tag semantics.
- Merging the five scripts into one (per-layer isolation is intentional).
- Extracting per-layer line rendering (trusted annotations, Brewfile syntax) — that is layer knowledge, not shared knowledge.

## Decisions

### D1: Partial returns JSON groups; consumers render their own lines

`package-layer-items` takes `(dict "key" "<yaml-key>" ...)` merged with the chezmoi context and returns JSON:

```json
[
  {"category": "core", "items": ["aria2", "atuin", "..."]},
  {"category": "dev", "items": ["..."]}
]
```

Consumers do `{{ $groups := includeTemplate "package-layer-items" (merge (dict "key" "bun") .) | fromJson }}` and range over groups, emitting their own command/line format and the existing `# Install {{ $category }} …` comments.

- *Alternative considered — partial renders final commands* (takes an `install` command string): simplest for scripts 24–26, but cannot serve script 23's four distinct line formats (Go templates have no callbacks), which would leave the worst duplication (4 internal copies) in place. Rejected.
- *Alternative considered — two partials* (command-renderer + JSON): more surface area, two things to keep in sync. Rejected.

The JSON-groups shape serves all ten call sites with one mechanism and follows the `machine-settings` precedent.

### D2: Value-agnostic `items`

The partial includes a category's entry whenever `hasKey $categoryData $key` and the value is non-empty, passing the value through as-is. JSON serialization handles both list values (`taps`, `brews`, `casks`, `mas`, `sdkman`, `uv`, `bun`, `cargo`) and the dict value (`brew_env`) uniformly — so script 23's `brew_env` merge loop also consumes the partial (ranging the groups and `set`-merging each dict) instead of keeping a residual inline eligibility check.

### D3: `includeCore` parameter (default `true`)

`(dict "key" "cargo" "includeCore" false)` reproduces script 27's semantics: iterate `.tag_choices` only, require `has $category $.tags`. Default `true` reproduces the `prepend "core"` + `or (eq $category "core") …` behavior of the other scripts. The deviation becomes a visible parameter instead of a divergent copy.

### D4: Category order preserved

The partial builds an ordered JSON *list* (not a map keyed by category) precisely to preserve `core`-first-then-`.tag_choices` order, so generated install order — and therefore script content hashes beyond the refactor itself — matches current behavior.

### D5: Verification by rendered-output diff

Before touching any script, capture `tests/run-template` output for all five scripts to a baseline directory. After the refactor, diff each rendered script against its baseline: required result is byte-identical (whitespace chomping included), for the current machine's tag set. The `template-reviewer` agent runs as a final convention check. Rationale: the rendered shell script is the real contract; diffing it is stronger than reviewing template code.

## Risks / Trade-offs

- [Go template whitespace chomping differs subtly after refactor] → byte-diff verification catches it; iterate `{{-`/`-}}` markers until diff is empty rather than accepting "close enough", since any diff both re-runs scripts and signals a semantic gap.
- [`toJson`/`fromJson` round-trips can mangle numeric values (float64 rendering)] → all current key values are strings or string lists (`mas` ids are embedded in strings); the byte-diff would expose any mangling. Note in the partial's header comment that values must be strings/maps of strings.
- [Editing five `run_onchange` scripts changes their hashes → all layers re-run on next apply] → accepted; runs are idempotent and the existing skip-prompt lets the user decline the slow layers.
- [Verification only covers the current machine's tag set] → the eligibility logic is exercised identically for every tag (same code path, data-driven), and template-reviewer plus the PostToolUse render hook cover template validity; residual risk accepted for a personal dotfiles repo. Bootstrap VM test remains the end-to-end backstop.

## Migration Plan

Single commit containing the new partial, all five script rewrites, the spec delta, and the CLAUDE.md template-list entry. Rollback is `git revert` of that commit; no state migration exists (scripts are stateless generators).

## Open Questions

None — semantics are fully determined by the existing scripts' behavior (byte-identical output is the acceptance test).
