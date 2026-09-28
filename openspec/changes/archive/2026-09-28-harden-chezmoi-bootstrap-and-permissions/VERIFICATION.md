# Verification Evidence: harden-chezmoi-bootstrap-and-permissions

Compiled per task 4.3, so a reviewer can verify all three findings without re-deriving them.

## 1. Shell-safe secret interpolation

**Confirmed shell-context `| quote` → `| shellQuote` sites (task 1.1-1.6):**

- `home/private_dot_zsh_secrets.tmpl` — `GEMINI_API_KEY`, `OPENAI_API_KEY`, `ANTHROPIC_API_KEY`, `DAGGER_CLOUD_TOKEN`, `GITHUB_TOKEN`, `AZURE_DEVOPS_EXT_PAT`, `AZURE_DEVOPS_EXT_PAT_PERSONAL`
- `home/private_dot_config/mcp-env/private_localstack-mcp-server.env.tmpl` — `LOCALSTACK_AUTH_TOKEN`
- `home/.chezmoiscripts/run_onchange_after_darwin-45-setup-github-auth.sh.tmpl` — `GITHUB_USERNAME`, `GH_PAT`
- `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` — `MACHINE_NAME`, `SSH_ENTRY_NAME`, `SSH_PASSPHRASE`
- `home/.chezmoiscripts/run_onchange_after_darwin-47-setup-azure-auth.sh.tmpl` — `AZURE_ORG`, `AZURE_USERNAME`, `AZURE_PAT`, `AZURE_ACR_REGISTRIES`
- `home/.chezmoiscripts/run_onchange_after_darwin-48-setup-azure-auth-personal.sh.tmpl` — `AZURE_ORG_PERSONAL`, `AZURE_USERNAME_PERSONAL`, `AZURE_PAT_PERSONAL`
- `home/.chezmoiscripts/run_once_after_darwin-83-login-atuin.sh.tmpl` — `$key` (rekey), `$username`/`$password`/`$key` (login)

**Exploit test (task 1.1):**
```
tests/run-template --inline '{{ "a$(echo INJECTED)b" | shellQuote }}'
→ 'a$(echo INJECTED)b'   (single-quoted, inert — was "a$(echo INJECTED)b" pre-change, live)
```

**Grep sweep (task 1.7)** — `grep -rn 'keepassxc.*| quote' home/` — confirmed remaining hits are exactly the documented JSON/TOML contexts, no shell-context site missed:
- `home/.chezmoi.toml.tmpl:80,105` (TOML value context — keepassxc_db path)
- `home/private_dot_gmail-mcp/gcp-oauth.keys.json.tmpl:2` (JSON)
- `home/private_dot_config/github-copilot/intellij/mcp.json.tmpl:36` (JSON)

**Rendering/syntax verification (task 1.8):** all 7 files rendered via `tests/run-template`; `bash -n` passed on all `.sh.tmpl` outputs; rendered `.zsh_secrets`/`.env.tmpl` outputs sourced cleanly with single-quoted values. Two files (`-46-setup-ssh-github`, `-83-login-atuin`) hit a pre-existing test-fixture gap in the `keepassxc` mock ("map has no entry for key Password/UserName") — confirmed via `git stash` to reproduce identically on the unmodified originals, so not caused by this change.

## 2. SOPS/age bootstrap ordering

**Before:** `private_cert.pem.tmpl` decrypts via `sopsDecrypt` at chezmoi template-render time (`Read()`), which runs before any script — including `run_onchange_after_darwin-43-setup-age-key.sh.tmpl`, the script that installs the age key `sopsDecrypt` depends on. No script-ordering number changes this, since template rendering during `Read()` is not interleaved with script execution at all. A fresh machine's first `chezmoi apply` had no guaranteed-safe path to reach script 43 before `cert.pem`'s template needed to decrypt.

**After:** `home/.chezmoiignore.tmpl` gained a conditional block:
```gotemplate
{{- $ageKeyPath := joinPath .chezmoi.homeDir "Library" "Application Support" "sops" "age" "keys.txt" }}
{{- if not (stat $ageKeyPath) }}
.cloudflared/cert.pem
.cloudflared/f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json
{{- end }}
```
(tunnel-id filename confirmed from `private_dot_cloudflared/private_f2ab9336-44f9-4bfc-8c2e-5696fc9bc2e4.json.tmpl`)

**Verification (task 2.1, 2.4):**
- Scratch `HOME`, no key file → both `.cloudflared/cert.pem` and the tunnel-credentials JSON appear in `chezmoi execute-template < home/.chezmoiignore.tmpl` output (ignored).
- Scratch `HOME` with a dummy key file at the exact path script 43 writes → both lines absent from the ignore output (no longer ignored).
- `private_cert.pem.tmpl` rendered directly via `chezmoi execute-template` with a patched dump-config (mock sops/keepassxc, `cloudflare_tunnels` injected) → `sopsDecrypt` is reached and returns the mock cert plaintext, confirming decrypt logic itself is unmodified.

**Supporting changes:** script 43 gained a `print_message "tip"` noting any skipped SOPS target applies on the next `chezmoi apply` (task 2.2). Script 91 (Cloudflare Tunnel setup, consumer of decrypted `cert.pem`) already had a graceful missing-file guard (`if [[ ! -f "$CERT_FILE" || ! -f "$CREDS_FILE" ]]` → warning, no `exit 1`) — confirmed via standalone extraction, no edit needed (task 2.3). `sopsDecrypt`'s header comment now documents the ordering constraint and points at this guard pattern (task 2.5).

## 3. Pattern C host-leak containment

**Devcontainer template** (`home/.chezmoitemplates/claude-pattern-c-devcontainer/devcontainer.json`, task 3.1) — added:
```json
"mounts": [
  "source=claude-pattern-c-dotclaude,target=${containerWorkspaceFolder}/.claude,type=volume"
]
```
layered on top of the existing `workspaceMount` bind, so `.claude/` writes inside the container never reach the host checkout. Verified via `chezmoi execute-template < .../devcontainer.json | jq .`.

**Isolation check** (`home/dot_local/bin/executable_apply-claude-pattern.tmpl`, task 3.2) — added `mount_point_for()` (parses `/proc/self/mountinfo`, longest-prefix match) and `has_claude_dir_isolation()` (compares the governing mount of `.` vs `.claude/`), wired in as a second, independent check after the existing container-evidence check. Refuses (returns false) if `/proc/self/mountinfo` is unreadable (non-Linux), per design.md's documented "cannot verify, refusing" fallback.

**Regression + new-scenario transcript (task 3.3):**
```
=== apply-claude-pattern a ===
applied pattern a to .claude/settings.local.json
{"defaultMode":"default","denyCount":13,"allowPresent":false}

=== apply-claude-pattern b (union merge) ===
applied pattern b to .claude/settings.local.json
{"mode":"default","deny":15,"allow":22}

=== apply-claude-pattern c (bare host, no container evidence) ===
error: pattern c (bypassPermissions) refused — no evidence this process is running inside an
isolated container (checked: /.dockerenv, $REMOTE_CONTAINERS, $CODESPACES). ...
exit code: 1
settings unchanged: {"mode":"default"}
```
↑ identical wording/behavior to the archived `claude-repo-permission-patterns` change's task 5.2 transcript — unmodified by this change.

```
=== .claude NOT isolated (same mount as working tree) -> refuse ===
error: pattern c (bypassPermissions) refused — ./.claude is not isolated from the host checkout. ...
exit code: 1
(no settings.local.json written)

=== .claude IS isolated (distinct volume mount, matches devcontainer template's shape) -> allow ===
applied pattern c to .claude/settings.local.json
exit code: 0
{"mode":"bypassPermissions"}

=== --i-know-this-is-a-container on real macOS host (no /proc/self/mountinfo) -> refuse via "cannot verify" fallback ===
error: pattern c (bypassPermissions) refused — ./.claude is not isolated from the host checkout. ...
exit code: 1
```
All four spec scenarios pass (bare-host refusal unmodified, new isolation-refusal, isolated-allow, non-Linux fallback refuses). `bash -n` clean on the full rendered script.

`home/dot_claude/rules/claude-tooling.md.tmpl`'s "Permission Patterns Are a Separate Axis from Persona Selection" section updated to document the `.claude/` volume-isolation requirement (task 3.4).

## 4. Integration verification

- `openspec validate --changes harden-chezmoi-bootstrap-and-permissions --strict` → 0 errors.
- Drift check: `chezmoi status` itself hit this repo's known non-interactive KeePassXC-TTY limitation on an unrelated `dot_aws` template; substituted `git status --short`, which showed exactly the 13 files owned by the three implementation phases above, no unrelated drift.
- `/opsx:verify` ran a full completeness/correctness/coherence pass: 17/20 (now 20/20) tasks, all 5 ADDED/MODIFIED requirements across the 4 delta specs spot-checked directly against source and confirmed implemented as designed. No CRITICAL, WARNING, or SUGGESTION issues found beyond the (now resolved) unchecked task-4 boxes.
