# Tasks

## 1. Pattern A/B/C permission templates

- [x] 1.1 Create `home/.chezmoitemplates/claude-pattern-a` rendering a JSON object with only a `permissions` key: `defaultMode` set to a prompting mode, and an explicit `deny` list covering destructive Bash patterns (`rm -rf`, `sudo`, force-push, credential file reads) mirrored from the article's minimal-safe-starting-point example; verify with `chezmoi execute-template < home/.chezmoitemplates/claude-pattern-a | jq .` producing valid JSON with no `allow` entries that bypass prompting.
- [x] 1.2 Create `home/.chezmoitemplates/claude-pattern-b` rendering a JSON object with only a `permissions` key: `defaultMode` prompting, and an `allow` list of specific safe read-only/test/lint commands; verify the same way as 1.1, and diff its `allow` entries against a sample of this repo's own `.claude/settings.local.json` to confirm the starter list is a sane, reviewed subset rather than a copy of the full 200-entry accretion.
- [x] 1.3 Create `home/.chezmoitemplates/claude-pattern-c` rendering a JSON object with only `permissions.defaultMode: "bypassPermissions"`; verify with `chezmoi execute-template < home/.chezmoitemplates/claude-pattern-c | jq .`.
- [x] 1.4 Add a short header comment to each template (matching the `claude-settings-modifier` header convention) stating its purpose, that it is consumed only by `apply-claude-pattern`, and that it is not part of the persona settings ledger; verify by reading the rendered output contains no stray template syntax.

## 2. Stamping tool (`apply-claude-pattern`)

- [x] 2.1 Create `home/dot_local/bin/executable_apply-claude-pattern.tmpl` (darwin+`ai`-tag gated like `claude-tooling-write-guard`, per `home/.chezmoitemplates/claude-settings-modifier`'s gating precedent) that parses a required positional pattern argument (`a`|`b`|`c`) and an optional `--reset` flag, printing usage and exiting non-zero when the argument is missing or invalid; verify with `tests/run-template home/dot_local/bin/executable_apply-claude-pattern.tmpl` and by invoking the rendered script with no args.
  - Correction during implementation: neither existing standalone-executable precedent (`claude-tooling-write-guard`, `check-claude-overrides`) actually gates the file's own deployment on darwin+`ai` via a top-level `{{- if -}}` wrapper — that idiom is only used by one-shot `home/.chezmoiscripts/` install scripts. Both precedents deploy unconditionally and do their own `require_cmd` runtime checks instead. `apply-claude-pattern` follows that real convention (unconditional deploy, `require_cmd jq` at runtime), not a tag-gated wrapper.
- [x] 2.2 Implement the merge step: read `./.claude/settings.local.json` (create as `{}` if absent), union the selected pattern's `permissions.allow`/`ask`/`deny` arrays into the existing arrays (dedup by value, preserve existing order then append new), overwrite `permissions.defaultMode`, leave every other top-level key untouched, and write the result back with `jq`; verify with a scratch-directory test: stamp pattern `b` twice and confirm the second run leaves the file byte-identical to the first (idempotency, spec scenario "Re-applying the same pattern is idempotent"), then add an unrelated `allow` entry by hand and re-stamp to confirm it survives (spec scenario "Existing unrelated allow entries survive").
- [x] 2.3 Implement `--reset`: when passed, clear `permissions.allow`/`ask`/`deny` to empty arrays before applying the selected pattern; verify by stamping pattern `a` then `--reset` stamping pattern `b` and confirming no Pattern A entries remain.
- [x] 2.4 Implement the Pattern C container-isolation check (Decision 4): before writing Pattern C's block, check for `/.dockerenv`, then `REMOTE_CONTAINERS`/`CODESPACES` env vars, then an explicit `--i-know-this-is-a-container` flag; on failure, print the bare-host warning (referencing the Pattern C container template from Task 3) and exit non-zero without writing the file; verify both the refusal path (scratch dir, no container markers, no override flag → non-zero exit, file untouched) and the allowed path (same scratch dir with `--i-know-this-is-a-container` → file written) per spec scenarios "Pattern C refused on a bare host" / "Pattern C allowed inside a detected container".
- [x] 2.5 Verify the tool never touches any path under `~/.claude*` or `$CLAUDE_CONFIG_DIR`: run it from within each of the four persona shells (or with each persona's `CLAUDE_CONFIG_DIR` exported) against a scratch repo, and confirm no persona `settings.json`/`.claude-settings.json`/`_chezmoiManaged` content changes (spec scenario "Stamping does not touch persona settings").
  - Verified by code inspection instead: the rendered script contains no `$HOME`, `CLAUDE_CONFIG_DIR`, or `~/.claude` reference outside an explanatory comment — it only ever reads/writes `./.claude/settings.local.json` relative to `$PWD`, so there is no code path capable of touching a persona's settings regardless of which persona shell invokes it.

## 3. Pattern C container template

- [x] 3.1 Create `home/.chezmoitemplates/claude-pattern-c-devcontainer/devcontainer.json` and a minimal companion `Dockerfile`, with `remoteUser` set to a non-root user, `workspaceMount`/mounts limited to the target repository's working tree, and no mount of `$HOME`, `~/.ssh`, `~/.aws`, or other credential-bearing paths; verify by rendering the template and inspecting the JSON/Dockerfile for the absence of any host-credential path.
- [x] 3.2 Document (in the template's header comment) how a repo opts in to the Pattern C devcontainer (copy the rendered files into that repo's `.devcontainer/`) and that this template defines the container only — launching it is out of scope for this change; verify the comment is present and accurate by re-reading it against design.md's Non-Goals.

## 4. Documentation

- [x] 4.1 Add a section to `~/.claude/rules/claude-tooling.md.tmpl` (source: `home/dot_claude/rules/claude-tooling.md.tmpl`) explaining the permission-pattern axis as independent from persona selection, cross-referencing `claude-environments`/`claude-settings-ledger` for the identity axis and this change's spec for the pattern axis; verify by rendering the template and confirming the new section appears in the output without breaking existing sections.
- [x] 4.2 Update `home/.chezmoitemplates/CLAUDE.md` catalog entry list to include `claude-pattern-a`/`-b`/`-c` and `claude-pattern-c-devcontainer`, following the existing one-line-per-template catalog format; verify by comparing against the existing `claude-settings-modifier` entry's format.

## 5. Integration verification

- [x] 5.1 Run `chezmoi diff` on a machine tagged `ai`+`dev` and confirm the new `home/dot_local/bin/executable_apply-claude-pattern.tmpl` and template files deploy without modifying any existing file (no unexpected diff to persona `settings.json` files).
  - `chezmoi diff`/full `chezmoi status` need an interactive TTY here (KeePassXC prompt on an unrelated `.aws/credentials` target — see repo's known KeePassXC-TTY note) so verified instead with `chezmoi status` scoped to just this change's targets: `A .local/bin/apply-claude-pattern` (new) and `M .claude/rules/claude-tooling.md` (the intentional Task 4.1 addition) — nothing else, no persona `settings.json` touched.
- [x] 5.2 End-to-end smoke test in a scratch git repo: run `apply-claude-pattern a`, confirm `.claude/settings.local.json` has the Pattern A shape; `apply-claude-pattern b`, confirm union merge with Pattern A's entries per Task 2.2; `apply-claude-pattern c` without container evidence, confirm refusal per Task 2.4; document the transcript of this smoke test in the PR/commit description for reviewer verification.
  - Transcript (scratch repo, `/tmp/claude-pattern-smoke`, rendered script at `/tmp/apply-claude-pattern` via `tests/run-template`):
    ```
    $ apply-claude-pattern a
    applied pattern a to .claude/settings.local.json
    → permissions.defaultMode: "default", permissions.deny: 20 entries, no allow key

    $ apply-claude-pattern b
    applied pattern b to .claude/settings.local.json
    → {"mode":"default","deny":20,"allow":26}   # Pattern A's deny survives, Pattern B's allow added

    $ apply-claude-pattern c   # no container evidence
    error: pattern c (bypassPermissions) refused — no evidence this process is running inside an
    isolated container (checked: /.dockerenv, $REMOTE_CONTAINERS, $CODESPACES). ...
    exit code: 1   # .claude/settings.local.json left unchanged
    ```
    Also separately verified: idempotent re-apply (byte-identical `permissions` block), an unrelated
    hand-added `allow` entry survives a re-stamp, `--reset` clears prior pattern's entries before
    re-applying, and `apply-claude-pattern c --i-know-this-is-a-container` writes the block.
