## 1. Age Key Generation & Custody

- [x] 1.1 Generate the age keypair (`age-keygen`) — user ran this out-of-band to keep the private key out of the session transcript
- [x] 1.2 Create a new KeePassXC entry (e.g. "age (dotfiles)") and store the private key as an attribute
- [x] 1.3 Resolve the open design question on-disk key path (`~/.config/sops/age/keys.txt` vs. a repo-namespaced path) and document the decision — resolved to the SOPS default, see `design.md`

## 2. Package Bootstrap

- [x] 2.1 Add `sops` and `age` to `home/.chezmoidata/packages.yaml` in the appropriate tag category
- [x] 2.2 Add both to `packages.darwin.trusted` if either is a third-party tap/formula — confirmed via `brew info --json=v2` that both are `homebrew/core` formulae; no `trusted:` entries needed
- [x] 2.3 Create a bootstrap script in the 40-49 (Environment Setup) range — strictly before position 91 (`setup-cloudflare-tunnel`) — that fetches the private key via `keepassxcAttribute` and writes it to the path chosen in 1.3 with `0600` permissions, sourcing `scripts/shared-utils.sh` for messaging — `run_onchange_after_darwin-43-setup-age-key.sh.tmpl`
- [x] 2.4 Resolve the open design question on `run_once_` vs. `run_onchange_` semantics for this script and implement accordingly — resolved to `run_onchange_`, see `design.md`
- [x] 2.5 Verify the new script's position number doesn't collide with existing scripts (`ls home/.chezmoiscripts/`) — confirmed 43 was free

## 3. SOPS Integration Plumbing

- [x] 3.1 Create `.sops.yaml` at the repo root with the pilot's age public key as sole recipient, scoped via a `path_regex` matching only the two Cloudflare tunnel encrypted files
- [x] 3.2 Create the `sopsDecrypt` partial in `home/.chezmoitemplates/` wrapping `output "sops" "-d" ...`
- [x] 3.3 Document the new partial's usage pattern in `home/.chezmoitemplates/CLAUDE.md`

## 4. Migrate Cloudflare Tunnel Secrets

- [ ] 4.1 Encrypt the existing `cert.pem` with `sops`; commit as `home/private_dot_cloudflared/cert.pem.sops`
- [ ] 4.2 Encrypt the existing tunnel credentials JSON with `sops`; commit as `home/private_dot_cloudflared/<tunnel-id>.json.sops`
- [ ] 4.3 Update `home/private_dot_cloudflared/private_cert.pem.tmpl` to call the `sopsDecrypt` partial instead of `keepassxcAttachment`
- [ ] 4.4 Update `home/private_dot_cloudflared/private_<tunnel-id>.json.tmpl` the same way
- [ ] 4.5 Update the missing-secrets message in `home/.chezmoiscripts/run_onchange_after_darwin-91-setup-cloudflare-tunnel.sh.tmpl` to reference the age key requirement instead of the KeePassXC entry name

## 5. Test Harness

- [x] 5.1 Add `tests/bin/sops`, a mock mirroring `tests/bin/keepassxc-cli`
- [x] 5.2 Add a fixture file providing deterministic fake plaintext for the mock to return
- [x] 5.3 Wire the mock into `tests/run-template`
- [ ] 5.4 Run `tests/run-template` against both migrated templates and confirm they render without the real age key — blocked on 4.3/4.4 (templates not yet migrated)

## 6. Verification & Rollback Readiness

- [x] 6.1 Smoke-test the `sopsDecrypt` partial with `tests/run-template --inline`
- [ ] 6.2 Run `chezmoi diff` then `chezmoi apply` on the tunnel's actual host (Mac Studio); confirm `cert.pem` and the tunnel JSON match the pre-migration content
- [ ] 6.3 Confirm the LaunchDaemon reloads cleanly and the tunnel remains reachable at its configured hostname
- [ ] 6.4 Leave the original KeePassXC attachment entries in place; confirm rollback path (revert the two `.tmpl` files and the bootstrap script via git) works if needed

## 7. Documentation

- [x] 7.1 Update root `CLAUDE.md` secret-management notes to mention the new two-tier model and point to the `sops-age-encryption` spec
- [ ] 7.2 Write a key-rotation runbook (`sops updatekeys` + re-encrypt steps) covering the pilot's age key
- [ ] 7.3 Run `openspec validate` and confirm this change is ready for `/opsx:apply`
