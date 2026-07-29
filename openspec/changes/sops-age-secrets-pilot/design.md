## Context

Today every secret is sourced from KeePassXC via `keepassxcAttribute`/`keepassxcAttachment` at `chezmoi apply` time — a single-tier model that works well for secrets a human also touches outside chezmoi, but adds a live-database bootstrap dependency and gives no version history for secrets that exist solely to render dotfiles. The repo is public, so nothing can ever be committed in the clear; this design has to make the repo a viable source of truth for a narrow set of secrets without weakening that exposure model.

A hard constraint discovered during proposal research: chezmoi's native `[encryption]` config block only understands `age` or `gpg` as whole-file backends — SOPS is not a first-class chezmoi encryption type. Any SOPS-based flow therefore has to be bespoke glue (a template partial invoking `sops` via the `output` function), not something chezmoi does natively.

Single-user, single-repo, multi-machine (currently the Mac Studio for the Cloudflare tunnel specifically) — no team/stakeholder coordination needed.

## Goals / Non-Goals

**Goals:**
- Prove the SOPS+age mechanism end-to-end on one real, already-templated capability (Cloudflare Tunnel provisioning) before deciding whether to migrate further secrets.
- The age private key never touches the repo or any git-tracked/synced path in plaintext — sourced from KeePassXC at bootstrap, exactly like every other secret today.
- No functional change to Cloudflare tunnel behavior — this is a secret-provisioning swap only.
- Migrated templates stay testable via `tests/run-template` without the real age key, mirroring the existing KeePassXC mock harness.

**Non-Goals:**
- Migrating any other secret (see proposal's Non-goals) — Context7, LocalStack, GCP OAuth, and work-hosts JSON stay on KeePassXC pending this pilot's outcome.
- A general "any file can become SOPS-encrypted" convention — scope is exactly the two Cloudflare tunnel files.
- Automated age-key rotation — a manual runbook is sufficient for this change.

## Decisions

**D1 — Decrypt mechanism: SOPS via a template partial, not chezmoi's native `age` encryption.**
Use a `.chezmoitemplates/sopsDecrypt`-style partial that shells out to `sops -d` via the `output` template function, rather than chezmoi's built-in `[encryption] type = "age"` + `encrypted_` file convention.
*Rationale*: the pilot exists to validate the mechanism intended for *future* key/value secrets (Context7, LocalStack env values), which need SOPS's partial-file encryption — native chezmoi `age` only encrypts whole files. Building the whole-file pilot on native age now would mean building and testing two separate decrypt mechanisms instead of one.
*Alternative considered*: chezmoi native `age` for the pilot's whole files — simpler today (no `.sops.yaml`, no partial), but doesn't validate what future migrations actually need, and would require a second integration path (and second test harness) later anyway.

**D2 — Age private key custody: new KeePassXC entry, materialized to disk only by a bootstrap script.**
Store the private key as a new KeePassXC entry (e.g. "age (dotfiles)" / attribute `private-key`), fetched via `keepassxcAttribute` in a bootstrap script that writes it to a fixed, non-chezmoi-managed path with `0600` permissions, then exported via `SOPS_AGE_KEY_FILE`.
*Rationale*: reuses the bootstrap-ordering and graceful-degradation pattern already established for every other KeePassXC secret; avoids standing up a second secret store just to hold one key.
*Alternative considered*: generate the key once and let it live only via the user's existing file-sync mechanism — rejected, since an unencrypted key sitting outside any access-controlled store undermines the entire point of tightening custody.

**D3 — `.sops.yaml` scope: narrow, per-file creation rule, not a blanket path glob.**
Commit `.sops.yaml` at the repo root with one age recipient (the pilot's public key), scoped via a `path_regex` matching only the two Cloudflare tunnel encrypted source files.
*Rationale*: keeps the new mechanism's blast radius explicit and auditable — a future capability must opt in deliberately rather than being silently swept in by a broad glob.

**D4 — Encrypted file naming: plain `*.sops.<ext>` source files, decrypted at render time into the existing `private_`-prefixed targets.**
Store ciphertext as `home/private_dot_cloudflared/cert.pem.sops` and the equivalent for the tunnel credentials JSON — ordinary source files, *not* using chezmoi's `encrypted_` attribute (which implies native chezmoi decryption that doesn't apply here). The existing `.tmpl` files call the `sopsDecrypt` partial and continue to render the real `private_cert.pem` / `private_<tunnel-id>.json` targets with unchanged permissions.
*Rationale*: keeps ciphertext-vs-rendered-output an explicit, readable distinction rather than overloading chezmoi's native encryption semantics for a mechanism it doesn't actually know about.

**D5 — Test harness: extend the existing mock pattern with a `sops` mock.**
Add `tests/bin/sops` (mirroring `tests/bin/keepassxc-cli`) plus a fixture returning deterministic fake plaintext, wired into `tests/run-template` so the two migrated templates render without the real age key.

## Risks / Trade-offs

[Risk] Age private key loss makes every historical SOPS-encrypted commit permanently undecryptable, with no recovery. → Mitigation: key lives in KeePassXC, the user's existing durable/backed-up store; a key-rotation runbook (`sops updatekeys` + re-encrypt) is a required task, not optional polish.

[Risk] Running two parallel secret mechanisms (KeePassXC + SOPS+age) increases the chance of misclassifying a future secret into the wrong tier. → Mitigation: the `secret-management` spec update (this change's `specs` artifact) makes the classification criteria explicit; a template-reviewer check is a plausible follow-up, not required here.

[Risk] SOPS integration is bespoke glue, not chezmoi-supported behavior — future chezmoi releases could change `output`/template semantics underneath it. → Mitigation: isolate all SOPS invocation to one `.chezmoitemplates` partial so breakage has a single fix point; covered by the D5 test harness.

[Risk] Bootstrap ordering: if the age-key script runs after the tunnel setup script, decryption fails on a fresh machine. → Mitigation: place the age-key bootstrap script in the 40-49 (Environment Setup) range, strictly before position 91 (`setup-cloudflare-tunnel`); verify explicitly as a task.

[Risk] Committing `.sops.yaml` and ciphertext to a public repo discloses that a Cloudflare tunnel exists and its file structure (not its secret content). → Mitigation: accepted — no new information beyond what the already-public `cloudflare-tunnel-management` spec discloses.

## Migration Plan

1. Generate the age keypair; store the private key in KeePassXC; commit the public key via a narrowly-scoped `.sops.yaml`.
2. Add `sops`/`age` to `packages.yaml` (plus `trusted` entries if either is third-party-tapped) and a bootstrap script that installs the private key to its fixed path.
3. Add the `sopsDecrypt` `.chezmoitemplates` partial.
4. Encrypt the existing `cert.pem` and tunnel credentials JSON with `sops`; commit as `*.sops.*` source files; update the two `.tmpl` files to decrypt via the partial instead of `keepassxcAttachment`.
5. Add the `sops` test-harness mock; verify `tests/run-template` passes for both templates.
6. Verify end-to-end via `chezmoi apply` on the tunnel's actual host (Mac Studio); confirm the LaunchDaemon still starts correctly.
7. Leave the original KeePassXC attachment entries in place until the new path is proven stable.

**Rollback**: revert the two `.tmpl` files and the bootstrap script to their prior `keepassxcAttachment`-based versions (preserved in git history); no data loss, since the original KeePassXC entries are never deleted.

## Open Questions — Resolved (2026-07-29)

- `.sops.yaml` rule granularity: **per-file (D3), unchanged.** D3 already made this call; a future capability opts in deliberately rather than being swept in by a broad glob.
- On-disk key location: **SOPS's default `~/.config/sops/age/keys.txt`.** No custom `SOPS_AGE_KEY_FILE` env var needed — least surprising to anyone already familiar with sops, and sops auto-detects this path.
- Bootstrap script semantics: **`run_onchange_`.** Re-syncs the key file if the KeePassXC-stored key is ever rotated, matching the original leaning.
- Multi-recipient support: **deferred.** No second machine currently needs tunnel secrets; adding a second recipient now would be speculative scope beyond this pilot's stated goal of proving the mechanism on one capability. Revisit when an actual second machine exists (consistent with the Non-Goals section).
