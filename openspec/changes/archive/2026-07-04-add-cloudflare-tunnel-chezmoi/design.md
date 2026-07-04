## Context

An `ow-dev` Cloudflare Tunnel was hand-configured on this Mac Studio on 2026-07-04 to give the `open-wearables` project's backend a stable HTTPS URL (`ow-dev.craigearley.software` → `localhost:8000`), replacing a drifting LAN IP. Everything about it currently lives outside chezmoi's control:

- `cloudflared` (Homebrew formula) — installed, undeclared in `packages.yaml`.
- `~/.cloudflared/cert.pem` and `~/.cloudflared/f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json` — the tunnel's actual secrets, unmanaged plaintext files under `$HOME`.
- `/usr/local/etc/cloudflared/config.yml` and `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` — root-owned files outside `$HOME`, hand-edited (chezmoi cannot manage files outside its source root directly; these must be written by a script).

Two prior chezmoi conventions apply directly:
- Per-machine list-shaped config, e.g. `syncthing_folders` in `config.yaml`, consumed via `includeTemplate "machine-settings"`.
- KeePassXC-backed `private_` template files for secrets, e.g. `private_dot_npmrc.tmpl`-style files using `keepassxcAttribute`. This change introduces the first use of the sibling function `keepassxcAttachment`, which returns a whole file's bytes from a KeePassXC entry attachment rather than a single attribute string — needed because the tunnel secrets are files (a PEM cert and a JSON credentials blob), not single values.

## Goals / Non-Goals

**Goals:**
- A fresh `chezmoi apply` on this Mac Studio restores the `ow-dev` tunnel to a fully working state (package installed, secrets restored, system config/plist written, daemon loaded) with one prerequisite one-time manual step (populating the KeePassXC entry).
- Idempotent and safe to re-run: no unnecessary sudo prompts or daemon restarts when nothing changed.
- Follows existing repo conventions exactly (machine-config list pattern, `private_` + KeePassXC secret pattern, `run_onchange` script pattern, shared-utils logging).

**Non-Goals:**
- Automating `cloudflared tunnel login`/`create`/`route dns` — these require interactive browser OAuth and are one-time actions already performed for `ow-dev`.
- Supporting machines other than this Mac Studio, or a fully generic N-tunnel abstraction beyond a plain list (only one tunnel exists today; the list shape accommodates more without redesign, but nothing in this change builds hooks for that).
- Tunnel monitoring/alerting/health checks.

## Decisions

**1. Secrets as KeePassXC file attachments, restored via `private_` templates under `$HOME`, not via the setup script.**
Alternative considered: have the setup script itself call `keepassxcAttribute`/write the files. Rejected because chezmoi already has a first-class mechanism for exactly this (`private_` files + template functions) that gets file permissions (600) and diff/apply semantics for free. Splitting "restore secrets" (declarative template) from "configure system daemon" (imperative script) also keeps the script simpler and testable independent of secret availability.

**2. System config (`config.yml`) and the LaunchDaemon plist are written by a script, not chezmoi-managed files.**
chezmoi's source root is `home/` → `$HOME` (`.chezmoiroot`); it cannot target `/usr/local/etc` or `/Library` directly. A `run_onchange_after_darwin-91-*` script renders both files from machine-config data and writes them with `sudo tee`, following the exact precedent of `run_onchange_after_darwin-90-update-hosts.sh.tmpl` (the only other script in this repo that edits a root-owned file outside `$HOME`).

**3. Script only rewrites/reloads when content actually changed.**
Both target files are compared (e.g. `diff -q` against a rendered temp file) before writing; `sudo launchctl bootout`/`bootstrap` only runs if a write occurred. This avoids a sudo password prompt and an unnecessary tunnel restart on every no-op `chezmoi apply` — important since this daemon is actively serving the `open-wearables` backend.

**4. Script position 91.**
Placed immediately after `run_onchange_after_darwin-90-update-hosts.sh.tmpl` — both scripts are "system network config" edits requiring `sudo`, run after the main tag-gated setup (35-46) and alongside other 80-99 "System Config" scripts, before Syncthing (94/95).

**5. Graceful degradation when secrets aren't yet present.**
If the KeePassXC entry hasn't been populated yet (first-time setup on a rebuilt machine, before the user does the manual step), the script detects missing `~/.cloudflared/{cert.pem,<id>.json}` and prints a skip message naming the required KeePassXC entry, rather than failing the whole `chezmoi apply`. This matches the `secret-management` spec's existing "Graceful Degradation" requirement and the pattern used by the GitHub-auth script's `has_keepassxc_db` gating.

**6. `cloudflared` goes in the `dev` Homebrew tag, not `core`.**
It's a developer tool for exposing a local dev backend, consistent with the other tunneling/local-dev tools already in the `dev` tag (`localstack/tap`, `aws-sam-cli`, etc.).

**7. Filenames kept as cloudflared's own naming convention.**
`~/.cloudflared/cert.pem` and `~/.cloudflared/<tunnel-id>.json` keep the names `cloudflared` itself would generate, rather than renaming to something more mnemonic (e.g. `ow-dev-credentials.json`). This avoids any risk of touching the live, already-working path wiring on this machine, and keeps the restored state byte-for-byte identical to what's running now.

## Risks / Trade-offs

- **[Risk] The one manual KeePassXC step is a single point of failure for full restore.** → Mitigated by the script's graceful-degradation message naming the exact entry/attachment names needed; documented in the proposal and in a code comment in the script.
- **[Risk] `sudo` inside a `run_onchange` script means `chezmoi apply` can prompt for a password unexpectedly.** → Only triggers when config/plist content actually changes (Decision 3), and only for machines with `cloudflare_tunnels` configured (empty elsewhere).
- **[Risk] Restarting the LaunchDaemon interrupts the currently-serving tunnel** if a change is detected while the `open-wearables` backend is in active use. → Acceptable: changes to tunnel config are rare/deliberate, and the existing daemon has `KeepAlive`/auto-restart already, so any interruption is sub-second.
- **[Verified]** `keepassxcAttachment` was spiked against a throwaway entry/attachment before implementation: `chezmoi execute-template '{{ keepassxcAttachment "zz-spike-test" "spike.txt" }}'` reproduced the source file byte-for-byte (`diff` clean). This was the first use of `keepassxcAttachment` in this repo (only `keepassxcAttribute` was previously proven) — no encoding/newline surprises, so tasks 4.1-4.3 can proceed as designed.
- **[Verified]** The `run_onchange` re-trigger mechanism was confirmed directly rather than assumed: `chezmoi state dump`'s `scriptState` bucket keys are SHA-256 hashes of each script's *rendered* content (confirmed by rendering `run_onchange_after_darwin-36-install-specstory.sh.tmpl` locally and matching its SHA-256 against an existing state key), stored in `~/.config/chezmoi/chezmoistate.boltdb` — a local, non-git-tracked file. This confirms both (a) editing `cloudflare_tunnels` in `config.yaml` changes the rendered hash and re-triggers the script, and (b) a wiped/rebuilt machine has no prior state at all, so the new script runs unconditionally on first `chezmoi apply` — validating the "no manual steps beyond KeePassXC" goal.

## Migration Plan

1. User manually creates the KeePassXC entry "Cloudflare Tunnel (ow-dev)" with the two existing files as attachments (documented exact commands in tasks).
2. Land the `packages.yaml`, `config.yaml`, `private_dot_cloudflared/*`, and script changes.
3. Run `chezmoi apply` (dry-run via `chezmoi diff` first) and verify the restored `~/.cloudflared/*` files are byte-identical to what's already there (no-op on this already-configured machine), and that the script recognizes `config.yml`/plist are unchanged (no sudo prompt, no daemon restart).
4. Verify `curl https://ow-dev.craigearley.software/` still returns the expected health response after `chezmoi apply`.

**Rollback:** `sudo launchctl bootout system/com.cloudflare.cloudflared`; remove `/Library/LaunchDaemons/com.cloudflare.cloudflared.plist` and `/usr/local/etc/cloudflared/config.yml`; `brew uninstall cloudflared`; delete the KeePassXC entry and `~/.cloudflared/*`; revert the chezmoi changes.

## Open Questions

None outstanding — all prior clarifying questions (scope, secret-handling approach, script behavior) were resolved during brainstorming before this proposal was written.
