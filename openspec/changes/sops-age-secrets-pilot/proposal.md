## Why

KeePassXC is the right home for secrets a human also uses outside this repo (GitHub PAT, SSH keys, AWS creds, etc.) — but it's overkill for secrets that exist *only* to template a handful of dotfiles, and it requires a live, unlocked database at `chezmoi apply` time even for those. This repo is public, so nothing can be committed in the clear, but SOPS+age lets the repo itself become the source of truth for genuinely repo-scoped secrets without weakening the exposure model: the age private key stays in KeePassXC, never the repo, so a leaked key remains a bounded, rotatable event rather than an unbounded one. This change pilots that model on one capability (Cloudflare Tunnel provisioning) before deciding whether to migrate the rest of the repo-scoped secrets identified in prior analysis (Context7 key, LocalStack token, GCP OAuth client, work-hosts JSON).

## What Changes

- Add SOPS + age as a supported encryption mechanism for repo-scoped secrets: generate an age keypair, store the **private** key in KeePassXC (new entry) so it never touches git, and commit only the **public** key via `.sops.yaml` creation rules.
- Add `sops` and `age` to `home/.chezmoidata/packages.yaml` (Homebrew), including the `trusted` list entries required by script 23 if either formula is third-party-tapped.
- Add a bootstrap step (script position TBD in design) that installs the age private key from KeePassXC into the location SOPS/age expects on a new machine, before any SOPS-encrypted template is rendered.
- Migrate the Cloudflare Tunnel origin cert (`cert.pem`) and tunnel credentials JSON — currently sourced via `keepassxcAttachment` — to SOPS+age-encrypted files committed in the repo, decrypted at `chezmoi apply` time.
- Update `secret-management` spec to define a two-tier model: **KeePassXC** for secrets used outside chezmoi (source of truth stays external), and **SOPS+age-in-repo** for secrets that exist solely to render chezmoi-managed files (repo becomes source of truth), plus the criteria for classifying a secret into each tier.
- Update `cloudflare-tunnel-management` spec to reflect the new SOPS+age provisioning path for `cert.pem` and the tunnel credentials JSON, replacing the `keepassxcAttachment`-based requirement.
- Add a test-harness equivalent to the existing KeePassXC mock (`tests/run-template`) so SOPS-encrypted templates can be rendered/tested without needing the real age private key — exact approach left to design.md.

**Non-goals (this change):**
- Does **not** migrate GitHub PAT, SSH keys, AWS credentials, Gemini/OpenAI keys, or Atuin credentials — these are used outside chezmoi and stay in KeePassXC indefinitely, independent of pilot outcome.
- Does **not** migrate the other repo-scoped secrets identified in prior analysis (Context7 API key, LocalStack token, GCP OAuth client/secret, work-hosts JSON) — those are candidates for a **follow-up change** only if this pilot proves out.
- Does **not** remove or deprecate the KeePassXC integration, mock test harness, or `secret-management` spec's existing KeePassXC requirements — it adds a second, narrower tier alongside them.

## Capabilities

### New Capabilities
- `sops-age-encryption`: SOPS+age-based encryption-at-rest for repo-scoped secrets — age keypair generation and custody (private key in KeePassXC, public key committed via `.sops.yaml`), package bootstrap, and the chezmoi decrypt-at-apply integration pattern.

### Modified Capabilities
- `secret-management`: adds the two-tier source-of-truth model (KeePassXC for broad-use secrets vs. SOPS+age-in-repo for repo-scoped-only secrets) and the classification criteria for choosing between them; existing KeePassXC requirements are unchanged.
- `cloudflare-tunnel-management`: `cert.pem` and tunnel credentials JSON are now provisioned from SOPS+age-encrypted files in the repo instead of `keepassxcAttachment`.

## Impact

- **Affected templates**: `home/private_dot_cloudflared/private_cert.pem.tmpl`, `home/private_dot_cloudflared/private_<tunnel-id>.json.tmpl` (or their replacements), `home/.chezmoiscripts/run_onchange_after_darwin-91-setup-cloudflare-tunnel.sh.tmpl`.
- **Affected data/config**: `home/.chezmoidata/packages.yaml` (new `sops`/`age` entries + `trusted` list), a new `.sops.yaml` at the repo root, a new KeePassXC entry for the age private key.
- **Affected specs**: `openspec/specs/secret-management/`, `openspec/specs/cloudflare-tunnel-management/`, new `openspec/specs/sops-age-encryption/`.
- **Affected tests**: `tests/` — needs a SOPS-equivalent to the existing `keepassxc-cli` mock harness so templates remain testable without a live secret.
- **Security implications**: the age private key is the single highest-value secret introduced by this change — it must never be written to a chezmoi-managed (and therefore potentially git-tracked or synced) path, only to KeePassXC and an ephemeral runtime location. `.sops.yaml` and the encrypted files themselves are safe to commit publicly by design (ciphertext + public key only). No SIP or permission changes are introduced. Bootstrap ordering matters: the age private key must be available *before* any SOPS-encrypted template renders, or `chezmoi apply` must degrade gracefully (consistent with the existing KeePassXC graceful-degradation requirement).
