## 1. Prerequisite: KeePassXC secret entry (manual, one-time)

- [x] 1.1 With the KeePassXC database (`/Users/craig/Sync/data2.kdbx`) unlocked, create a new entry titled `Cloudflare Tunnel (ow-dev)`.
- [x] 1.2 Attach the existing `~/.cloudflared/cert.pem` to that entry as attachment `cert.pem` (GUI drag-in, or `keepassxc-cli attachment-import /Users/craig/Sync/data2.kdbx "Cloudflare Tunnel (ow-dev)" cert.pem ~/.cloudflared/cert.pem`).
- [x] 1.3 Attach the existing `~/.cloudflared/f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json` to the same entry as attachment `f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json`.
- [x] 1.4 Verify both attachments are readable: `keepassxc-cli attachment-export /Users/craig/Sync/data2.kdbx "Cloudflare Tunnel (ow-dev)" cert.pem -` (and same for the JSON attachment) and diff against the originals on disk.

## 2. Package declaration

- [x] 2.1 Add `'cloudflared'` to the `dev.brews` list in `home/.chezmoidata/packages.yaml`, alphabetically between `checkmake` and `dagger`.
- [x] 2.2 Run `chezmoi execute-template` (or `chezmoi diff`) to confirm `packages.yaml` still parses and no unrelated diff appears.

## 3. Machine config declaration

- [x] 3.1 Add a `cloudflare_tunnels` list under the `Mac Studio:` entry in `home/.chezmoidata/config.yaml`, with one entry: `name: ow-dev`, `id: f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4`, `hostname: ow-dev.craigearley.software`, `service: http://localhost:8000`, `keepassxc_entry: "Cloudflare Tunnel (ow-dev)"`.
- [x] 3.2 Verify via `tests/run-template --inline '{{ (includeTemplate "machine-settings" .) | fromJson }}'` (or equivalent) that `cloudflare_tunnels` resolves correctly for this machine and is absent/empty for other machine patterns.

## 4. Secret restoration templates

- [x] 4.1 Create `home/private_dot_cloudflared/private_cert.pem.tmpl` containing `{{ keepassxcAttachment "Cloudflare Tunnel (ow-dev)" "cert.pem" }}`.
- [x] 4.2 Create `home/private_dot_cloudflared/private_f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json.tmpl` containing `{{ keepassxcAttachment "Cloudflare Tunnel (ow-dev)" "f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json" }}`.
- [x] 4.3 Run `tests/run-template` against both new template files and diff the rendered output byte-for-byte against the existing `~/.cloudflared/cert.pem` and `~/.cloudflared/f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json` to confirm the KeePassXC round-trip is exact.
- [x] 4.4 Run `chezmoi diff` and confirm it reports no changes for these two paths (since the files already exist on disk with matching content) — proves this is a safe, non-destructive introduction on this machine.

## 5. Setup script

- [x] 5.1 Create `home/.chezmoiscripts/run_onchange_after_darwin-91-setup-cloudflare-tunnel.sh.tmpl`, wrapped in `{{- if eq .chezmoi.os "darwin" -}}`, sourcing `shared-utils.sh`, using `require_tools cloudflared`.
- [x] 5.2 In the script, read `cloudflare_tunnels` from `includeTemplate "machine-settings"`; if empty, `print_message "skip"` and `exit 0`.
- [x] 5.3 For each tunnel entry, check `~/.cloudflared/<id>.json` and `~/.cloudflared/cert.pem` exist; if not, `print_message "warning"` naming the `keepassxc_entry` and skip that tunnel (continue loop, do not exit non-zero).
- [x] 5.4 Render the expected `/usr/local/etc/cloudflared/config.yml` content (tunnel id, credentials-file path, ingress hostname/service, catch-all 404) to a temp file; compare against the current file with `diff -q`; only `sudo tee` it into place if different or missing.
- [x] 5.5 Render the expected `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` content (matching the currently-installed plist: label, `cloudflared tunnel run` args, `RunAtLoad`, `KeepAlive.SuccessfulExit=false`, log paths, `ThrottleInterval`); compare and conditionally `sudo tee` it into place the same way.
- [x] 5.6 Only when either file in 5.4/5.5 was actually written, run `sudo launchctl bootout system/com.cloudflare.cloudflared 2>/dev/null || true` followed by `sudo launchctl bootstrap system /Library/LaunchDaemons/com.cloudflare.cloudflared.plist`.
- [x] 5.7 On success, `print_message "success"` including the tunnel's `hostname`.

## 6. Verification

- [x] 6.1 Run `chezmoi diff` end-to-end and review the full diff before applying.
- [x] 6.2 Run `chezmoi apply` and confirm the script reports no config/plist change and does not prompt for `sudo` (since this machine's files already match) — proves idempotency on an already-configured machine.
- [x] 6.3 Run `curl -s https://ow-dev.craigearley.software/` and confirm it still returns `{"message":"Server is running!"}` after the apply.
- [~] 6.4 (Skipped) Temporarily edit the rendered ingress `service` value, re-run `chezmoi apply`, and confirm the script detects the change, writes both files, and reloads the daemon — then revert and re-apply to restore the original state. Skipped by user decision: byte-identical rendering was already proven twice (independent script reproduction + real `chezmoi diff`), so the deliberate daemon-restart test was judged low-value against the risk of touching the live tunnel.
- [x] 6.5 Update `openspec/specs/secret-management/spec.md` and create `openspec/specs/cloudflare-tunnel-management/spec.md` by running `/opsx:sync` (or manual archive) once this change is applied.
