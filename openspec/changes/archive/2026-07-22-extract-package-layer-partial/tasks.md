# Tasks: Extract Package-Layer Iteration Partial

## 1. Baseline

- [x] 1.1 Render all five scripts (23–27) via `tests/run-template` and save outputs to a baseline directory (scratchpad) for byte-diff comparison
- [x] 1.2 Record the current machine's tag set alongside the baseline for reference

## 2. Partial

- [x] 2.1 Create `home/.chezmoitemplates/package-layer-items` implementing the JSON-groups contract (key, includeCore default true; ordered array of {category, items}; value-agnostic pass-through; header comment documenting parameters and the strings-only value constraint)
- [x] 2.2 Verify the partial standalone with `tests/run-template --inline` for at least: a default-core key (`bun`), the no-core key (`cargo` with includeCore false), and the dict key (`brew_env`)

## 3. Simple layer scripts

- [x] 3.1 Rewrite script 24 (SDKMAN) to consume the partial; diff rendered output against baseline until byte-identical
- [x] 3.2 Rewrite script 25 (UV) likewise
- [x] 3.3 Rewrite script 26 (Bun) likewise
- [x] 3.4 Rewrite script 27 (Cargo) with `includeCore` false; diff against baseline until byte-identical

## 4. Homebrew script

- [x] 4.1 Rewrite script 23's category-scoped taps iteration (pre-tap section and Brewfile section) to consume the partial, preserving `trusted:` handling
- [x] 4.2 Rewrite script 23's brews and casks Brewfile sections to consume the partial, preserving `trusted:` annotations
- [x] 4.3 Rewrite script 23's mas section to consume the partial, preserving the iCloud sign-in gate
- [x] 4.4 Rewrite script 23's `brew_env` merge to consume the partial's dict groups
- [x] 4.5 Diff script 23's rendered output against baseline until byte-identical

## 5. Documentation and verification

- [x] 5.1 Add `package-layer-items` to CLAUDE.md's Reusable Templates list with a one-line description and usage example
- [x] 5.2 Run the `template-reviewer` agent over the changed templates and resolve any convention findings
- [x] 5.3 Final full diff: all five rendered scripts byte-identical to baseline; `openspec validate extract-package-layer-partial`
