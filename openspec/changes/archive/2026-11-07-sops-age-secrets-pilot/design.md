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

**D4a — Encryption granularity: whole-file/binary for `cert.pem`, structured/partial-value for the tunnel credentials JSON (revised 2026-07-29).**
`cert.pem` is a PEM blob, not one of SOPS's structured formats (JSON/YAML/dotenv/ini) — whole-file `--input-type binary --output-type binary` is the only option SOPS offers for it. The tunnel credentials JSON *is* structured, though, so it's encrypted with `--input-type json --output-type json` instead: SOPS's default behavior walks the document and encrypts each leaf value individually (`AccountTag`, `TunnelSecret`, `TunnelID` each become their own `ENC[...]` blob) while keys and document structure stay visible in the committed file and in git diffs. The `sopsDecrypt` partial takes an optional `type` parameter (default `"binary"`) so both files share one decrypt implementation.
*Rationale*: originally both files used binary mode for a uniform code path (see prior D4 text), but that discards SOPS's actual headline feature — partial-value encryption — for the one file structured enough to use it. Structured mode costs nothing extra (same partial, one added parameter) and makes the committed ciphertext self-documenting instead of an opaque blob.
*Alternative considered*: selectively exempting non-sensitive fields (e.g. `TunnelID`, already public elsewhere in this repo) via `--unencrypted-regex` — rejected as unnecessary scope: SOPS's default (encrypt every leaf value) already achieves the structured/self-documenting goal without a second decision about which individual fields are "safe."

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

**Note for a follow-up migration (consolidated key/value secrets, added 2026-07-29):** this pilot's two secrets (`cert.pem`, tunnel credentials JSON) are each a distinct whole file chezmoi must place at its own target path, so a dedicated ciphertext + `.tmpl` pair per secret is unavoidable — that's inherent to chezmoi's per-target-file model, not a SOPS-specific cost (the prior KeePassXC-based templates had the same one-`.tmpl`-per-target count). The other repo-scoped secrets this pilot deliberately deferred (Context7 API key, LocalStack token, GCP OAuth client/secret, work-hosts JSON) are different in kind: plain key/value data, not distinct file targets. For those, do **not** repeat the one-ciphertext-per-secret pattern — instead consolidate all of them into a single SOPS-encrypted data file (structured YAML/JSON mode), decrypted **once** via the existing `sopsDecrypt` partial (`type "yaml"` or `"json"`) plus `fromYaml`/`fromJson`, with each consuming template pulling only the one field it needs (e.g. `index $secrets "context7_api_key"`). This collapses N future secrets into one additional ciphertext file rather than N, and matches the documented external pattern for SOPS+dotfiles (see the `sops-age-encryption` capability's prior art notes / basic-memory `sops-chezmoi-consolidation-pattern` for sources).

## Key Rotation Runbook

Rotate the pilot's age key if it's ever suspected of exposure, or on a routine schedule. Run entirely on the Mac Studio (currently the only machine with this key).

1. **Generate a new keypair**: `age-keygen -o /tmp/new-age-key.txt` (never write it into the chezmoi source tree). Note the new public key printed to stderr.
2. **Add the new recipient alongside the old one.** SOPS's `age:` field takes a single comma-separated string, and YAML aliases can't be concatenated inline (`*k1,*k2` is invalid YAML) — so put both keys as one anchor's value during the transition:
   ```yaml
   keys:
     - &dotfiles_pilot "age1xn4g43p4hpmvplqgzsn8tvrl48nv24vrqzksunum68v36ktlguusp6x6z8,age1...newkey..."
   ```
   (verified empirically 2026-07-29 with a real two-key rotation drill: `sops updatekeys` correctly re-wraps for both while both are listed, and dropping one from the string correctly revokes its decrypt access.)
3. **Re-wrap both ciphertext files for the new recipient** (does not require the plaintext, only the current private key to unwrap the existing data key):
   ```
   sops updatekeys home/private_dot_cloudflared/cert.pem.sops
   sops updatekeys home/private_dot_cloudflared/f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json.sops
   ```
4. **Store the new private key in KeePassXC**: update the "age (dotfiles)" entry's `private-key` attribute with the new key's contents (or create a new entry and repoint the bootstrap script, if preserving the old entry as a historical record is preferred). Securely delete `/tmp/new-age-key.txt` afterward.
5. **Materialize the new key on disk**: run `chezmoi apply` — the bootstrap script's `run_onchange_` trigger is a hash of the KeePassXC attribute value, so it re-fires automatically and rewrites `~/Library/Application Support/sops/age/keys.txt`.
6. **Verify decryption with the new key alone**: narrow the anchor's value in `.sops.yaml` down to just the new public key, run `sops updatekeys` on both files again (drops the old recipient's wrapped data key), then confirm `tests/run-template` and a real `chezmoi apply` both still succeed.
7. **Retire the old key**: once step 6 is confirmed, the old private key in KeePassXC is no longer needed for these two secrets — delete or archive that KeePassXC attribute per your own retention preference; there's no ciphertext left anywhere that depends on it.
8. **Commit**: `.sops.yaml` and both re-wrapped `.sops` files change; the plaintext they decrypt to does not.

## Open Questions — Resolved (2026-07-29)

- `.sops.yaml` rule granularity: **per-file (D3), unchanged.** D3 already made this call; a future capability opts in deliberately rather than being swept in by a broad glob.
- On-disk key location: **SOPS's default, `~/Library/Application Support/sops/age/keys.txt` on macOS** (verified empirically 2026-07-29 — sops uses Go's `os.UserConfigDir()`, which resolves to `Application Support` on Darwin, not the XDG-style `~/.config` originally assumed here). No custom `SOPS_AGE_KEY_FILE` env var needed — sops auto-detects this path. Since this repo targets macOS exclusively, no cross-platform branching is required.
- Bootstrap script semantics: **`run_onchange_`.** Re-syncs the key file if the KeePassXC-stored key is ever rotated, matching the original leaning.
- Multi-recipient support: **deferred.** No second machine currently needs tunnel secrets; adding a second recipient now would be speculative scope beyond this pilot's stated goal of proving the mechanism on one capability. Revisit when an actual second machine exists (consistent with the Non-Goals section).
