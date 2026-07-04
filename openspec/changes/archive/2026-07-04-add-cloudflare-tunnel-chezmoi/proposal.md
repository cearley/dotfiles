## Why

A Cloudflare Tunnel (`ow-dev`, exposing `open-wearables` backend at `ow-dev.craigearley.software` → `localhost:8000`) was set up manually on this Mac Studio on 2026-07-04 (`brew install cloudflared`, `cloudflared tunnel create/login/route dns`, hand-edited `/usr/local/etc/cloudflared/config.yml`, and a hand-installed `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`). None of this is captured in chezmoi: the Homebrew package isn't in `packages.yaml`, the tunnel credentials (`cert.pem`, `<tunnel-id>.json`) exist only as unmanaged files in `~/.cloudflared/`, and the system config/plist are hand-written root-owned files. If this machine is rebuilt, the tunnel has to be manually reconstructed from memory/notes, and there's no secure backup of the tunnel credentials at all.

## What Changes

- Add `cloudflared` to the `dev` Homebrew formula list in `packages.yaml`.
- Add a `cloudflare_tunnels` list to the `Mac Studio` entry in `home/.chezmoidata/config.yaml` (mirrors the existing `syncthing_folders` per-machine list pattern), describing tunnel name, ID, hostname, target service, and KeePassXC entry name.
- Add two chezmoi-managed `private_` template files under `home/private_dot_cloudflared/` that restore the tunnel's `cert.pem` and credentials JSON from a KeePassXC entry via the `keepassxcAttachment` template function.
- Add a new `run_onchange_after_darwin-91-setup-cloudflare-tunnel.sh.tmpl` script that (idempotently, gracefully degrading when secrets/config are absent) writes `/usr/local/etc/cloudflared/config.yml` and `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` via `sudo`, and reloads the LaunchDaemon only when either file actually changed.
- Document the one-time manual step (creating the KeePassXC entry with the two file attachments) and the rollback procedure.

## Capabilities

### New Capabilities
- `cloudflare-tunnel-management`: chezmoi-managed setup, restoration, and teardown of Cloudflare Tunnels as root-level macOS LaunchDaemons, driven by per-machine config data and KeePassXC-backed secret files.

### Modified Capabilities
- `secret-management`: adds a requirement for retrieving whole-file secrets (not just single attribute values) via the `keepassxcAttachment` template function, for restoring binary/file-based credentials like tunnel certificate and credentials files.

## Impact

- `home/.chezmoidata/packages.yaml` — new `dev` brew entry (`cloudflared`).
- `home/.chezmoidata/config.yaml` — new `cloudflare_tunnels` list under `Mac Studio`.
- `home/private_dot_cloudflared/` — two new private template files (new directory).
- `home/.chezmoiscripts/` — one new `run_onchange_after_darwin-91-*` script.
- System-level (outside `$HOME`, requires `sudo`): `/usr/local/etc/cloudflared/config.yml`, `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist`.
- KeePassXC database: one new entry, "Cloudflare Tunnel (ow-dev)", with two file attachments (created manually by the user, not by chezmoi).
- Only affects the `dev` tag and the `Mac Studio` machine pattern; no other machines or tags are affected (graceful no-op elsewhere).
- Security: this is the first use of `keepassxcAttachment` in the repo (as opposed to `keepassxcAttribute`); the tunnel's `cert.pem` and credentials JSON are account/tunnel-level secrets and must never be committed in plaintext.

## Non-Goals

- Not automating the initial `cloudflared tunnel login` / `tunnel create` / `route dns` steps — these require an interactive browser OAuth flow and are one-time, already-completed actions for the existing `ow-dev` tunnel. This change only covers *restoring* an already-created tunnel's config/secrets/daemon on this machine.
- Not generalizing to other machines or a shared multi-tunnel abstraction beyond a plain per-machine list (YAGNI — only one tunnel, one machine, today).
- Not adding tunnel health-check/monitoring/alerting.
- Not changing the `open-wearables` backend or its CORS/allowed-hosts configuration (already verified unaffected).
