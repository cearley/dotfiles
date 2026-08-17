---
name: migrate-secret-to-sops
disable-model-invocation: true
description: Migrate a single chezmoi-managed secret from a KeePassXC attachment or attribute to SOPS+age encryption, so the repo itself (not an external database) becomes that secret's source of truth. Use this whenever the user wants to "migrate a secret to sops", "move X to sops+age", "convert this KeePassXC entry to sops", "encrypt this secret in the repo instead of keepassxc", or names a specific repo-scoped secret (an API key, token, credentials file, OAuth client) they want committed as SOPS ciphertext instead of pulled from KeePassXC at apply time. Assumes this repo's SOPS+age scaffolding (age key bootstrap script, .sops.yaml, the sopsDecrypt partial, sops/age packages) already exists — this skill migrates one additional secret into that existing system, it does not bootstrap the system itself.
---

# Migrate a Secret from KeePassXC to SOPS+age

This repo uses a two-tier secret model (see `openspec/specs/secret-management/`): KeePassXC for secrets used outside chezmoi, and SOPS+age for secrets that exist only to render chezmoi-managed files, where the repo itself is the source of truth. This skill migrates one secret from the KeePassXC tier to the SOPS tier, following the pattern established in the `sops-age-secrets-pilot` change.

## Step 0: Is SOPS actually the right move for this secret?

Before touching any files, sanity-check the two things that actually determine whether SOPS is a good fit here — getting this wrong is easy to miss and expensive to unwind later:

**Does this secret need per-machine or per-tag conditional gating?** Most secrets in this repo do (a tunnel only exists on one machine, a tool's credentials only matter with a given tag). If so, SOPS is the right choice: it's decrypted via a plain `.tmpl` calling the `sopsDecrypt` partial, so the machine-conditional `{{ if ... }}` check runs *before* decryption is ever attempted, and gracefully skips the file entirely where it doesn't apply.

If the secret genuinely applies to *every* machine unconditionally, native chezmoi `age` encryption (the `encrypted_` file attribute) is worth considering instead — it's a true one-file mechanism (no separate `.tmpl` needed). But be aware chezmoi decrypts `encrypted_*.tmpl` files *before* executing the template, so combining native age with a conditional gate doesn't work the way it does with SOPS — this is exactly why this repo picked SOPS over native age for its first migration. Don't switch to native age speculatively; only do it if you've hit a concrete secret where the unconditional case is real. If in doubt, proceed with SOPS — it's the safer default here.

**Is this a small key/value secret, or a distinct whole file?** A whole file with its own target path (a cert, a credentials JSON, an SSH key) needs its own ciphertext + `.tmpl` pair — that's unavoidable, chezmoi maps one target path to one source template regardless of encryption backend. But a small string value (an API token, an OAuth client secret, one field of a larger config) does *not* need its own dedicated ciphertext file. Check two things, in this order, before deciding:

1. **Documented intent, not just physical files.** Search `openspec/changes/*/design.md` (especially the current pilot's design doc) and any project memory notes for this secret by name — a prior session may have already named it as a consolidation candidate and decided the shape, even if no physical consolidated file exists yet. Don't limit the check to "does a `*.sops.yaml`/`*.sops.json` file already exist" — a documented plan for a secret that hasn't been migrated yet is just as decisive as an existing file, and missing it means redoing analysis someone already did.
2. **An existing physical file** (search outside `private_dot_cloudflared/` — as of this writing none exists yet, but check anyway since this is exactly the kind of thing that gets added incrementally). If one exists, add this secret as a new key inside it and skip straight to updating the consuming template (step 5) — do not create a new ciphertext file.

If neither turns up a documented decision, this is a real fork in the design — ask the user before deciding — but two signals should push you toward *proposing* a shared file rather than defaulting to one-off pairs:
  - The secret is one of several *unrelated* small values that would otherwise each get their own pair (the scattered-across-templates case).
  - **A single existing file already makes several separate `keepassxcAttribute`/`keepassxcAttachment` calls** — e.g. a `modify_*.tmpl` script or one large config template pulling from multiple KeePassXC entries. This is actually the *stronger* signal: it's not hypothetical proliferation, it's a concrete file you're looking at right now with N separate secret lookups that could become one `sopsDecrypt` call plus N dict lookups (`index $secrets "profile-name" "field"`) into the decrypted structure. Don't migrate each `keepassxcAttribute` call in such a file as its own isolated ciphertext pair without at least raising this — it defeats the point of SOPS's structured encryption to fragment a naturally-structured secret set back into single-value files.

Whatever the consuming file's own shape (a plain `private_X.tmpl`, or a `modify_*.tmpl` script that renders a bash heredoc and merges with existing content) — `sopsDecrypt` is called through `includeTemplate` the same way either way, since Go-template rendering happens before the result is treated as anything else (bash, JSON, whatever). Don't assume the target is always a simple `private_` template; read the actual file first.

## Step 1: Gather the inputs

You need:
- The current `.tmpl` file's path, and whether it calls `keepassxcAttachment "<entry>" "<name>"` or `keepassxcAttribute "<entry>" "<attribute>"`.
- The target ciphertext path: `<same directory>/<basename>.sops` (or the shared consolidated file's path, per Step 0).
- Whether the plaintext is structured (JSON/YAML/dotenv/ini) or an opaque blob (PEM, arbitrary binary, or a single plain string). This decides the `type` you'll pass to `sopsDecrypt` and to `sops` during encryption:
  - **Structured** → use `type "json"` (or `"yaml"`/`"dotenv"`/`"ini"`). SOPS encrypts each leaf value individually, leaving keys/structure readable in git — this is the actual reason to prefer SOPS over native age for this kind of secret.
  - **Opaque or a single plain string** → omit `type` (defaults to `"binary"` in the `sopsDecrypt` partial).
- The KeePassXC database path (read from `home/.chezmoi.toml.tmpl`'s `[keepassxc] database` value, or `keepassxc_db` in the `[data]` block).

## Step 2: Add a `.sops.yaml` creation rule

Add a narrowly-scoped `path_regex` entry to the repo's `.sops.yaml`, matching *only* the new ciphertext file's exact path — never a directory-wide glob. Reuse the existing age recipient anchor already defined there. Example:

```yaml
creation_rules:
  - path_regex: ^home/private_dot_foo/bar\.json\.sops$
    age: *dotfiles_pilot
```

## Step 3: Extract the plaintext and encrypt it — hand this to the user

This step needs the KeePassXC master password. You have no TTY to supply it, and you must never ask the user for it directly — generate the exact command and have the user run it themselves (suggest the `!` prefix in Claude Code, or write it to a scratch script for them to run in their own terminal).

Use `scripts/extract-and-encrypt.sh` (bundled with this skill) rather than hand-rolling the pipeline — it encodes a gotcha that's easy to get wrong: **SOPS's `.sops.yaml` creation rules match against the file path argument given to `sops`, not the shell redirect target.** Piping through `/dev/stdin` means `sops` has no real filename to match against, so you must pass `--filename-override <real-target-path>` or it fails with `no matching creation rules found`. The script builds this correctly for both source types:

```bash
# Whole-file attachment (e.g. a cert or credentials JSON attached to a KeePassXC entry)
.claude/skills/migrate-secret-to-sops/scripts/extract-and-encrypt.sh \
  attachment "$HOME/Sync/data2.kdbx" "Entry Name" "attachment-name.json" \
  home/private_dot_foo/bar.json.sops json

# Single attribute value (e.g. a plain API token stored as a custom attribute)
.claude/skills/migrate-secret-to-sops/scripts/extract-and-encrypt.sh \
  attribute "$HOME/Sync/data2.kdbx" "Entry Name" "attribute-name" \
  home/private_dot_foo/token.sops binary

# Several values consolidated into one structured secret (Step 0's
# consolidation case — one KeePassXC lookup per field, combined into one
# JSON object before encryption). <path> is a dot-separated key path, so
# nested paths build nested objects:
.claude/skills/migrate-secret-to-sops/scripts/extract-and-encrypt.sh \
  combine "$HOME/Sync/data2.kdbx" home/dot_foo/secrets.json.sops json \
  "profile-a.client_id=Entry A:client-id" \
  "profile-a.client_secret=Entry A:client-secret" \
  "profile-b.client_id=Entry B:client-id"
```

Don't hand-roll a `jq`-based combining pipeline when a secret consolidates several values (per Step 0) — use `combine` mode instead. It exists specifically because this comes up whenever consolidation applies, and hand-rolling it fresh each time risks losing the same never-touch-disk / `--filename-override` guarantees the single-value modes already encode.

Never let the plaintext touch disk unencrypted — every mode pipes directly from `keepassxc-cli` into `sops`. If you ever need to *re-encrypt* an already-encrypted file (e.g. switching it from binary to structured mode later, or adding a field to an existing consolidated secret), do **not** write `sops -d file | sops -e ... > file` — redirecting to the same file you're reading truncates it before the read may complete. Decrypt to a temp file (or pipe straight into the second `sops` call without redirecting to the original path), then `mv` the result into place only after the new ciphertext is fully written.

## Step 4: Verify the round-trip without ever printing the real secret

Compare a hash of the decrypted content against what you expect (or, if re-encrypting existing ciphertext, against the old version) — never `cat` real secret plaintext into the conversation:

```bash
sops --decrypt --input-type <type> --output-type <type> <target>.sops | shasum -a 256
```

For structured formats, normalize before hashing so formatting differences (whitespace, key order) don't cause false mismatches: `sops --decrypt ... | jq -S . | shasum -a 256`.

## Step 5: Update the consuming `.tmpl`

Replace the `keepassxcAttachment`/`keepassxcAttribute` call with the `sopsDecrypt` partial:

```go-template
{{ includeTemplate "sopsDecrypt" (merge (dict "file" "private_dot_foo/bar.json.sops" "type" "json") .) -}}
```

Omit `"type"` entirely for binary/opaque secrets — don't pass `"type" "binary"` explicitly, since accessing a dict key that was never set (`.type`) errors in chezmoi's Go templates (`map has no entry for key "type"`) rather than returning empty; the partial handles the default via `index . "type" | default "binary"`, but only if the key is genuinely absent, not present-and-empty.

Keep any existing per-machine conditional gate (`{{ if $tunnels }}`-style) exactly as it was — it still runs before the `sopsDecrypt` call, same as before.

## Step 6: Check whether `.chezmoiignore` needs an entry

This is the step most likely to be forgotten, and it fails silently until someone runs `chezmoi status`. If the new `.sops` file lives inside a directory chezmoi already maps to a target (basically anywhere under `home/` that isn't a reserved name like `.chezmoitemplates/` or already covered by an existing `.chezmoiignore` rule like `scripts/`), chezmoi treats *every* file in it as something to apply — regardless of attribute prefixes — and will try to copy the raw ciphertext literally into the destination directory (e.g. `~/.cloudflared/bar.json.sops`).

**For a per-target ciphertext file (Step 0's whole-file case, e.g. `cert.pem.sops`)**, it has to live alongside its `.tmpl` under a real target directory, so you do need the ignore entry below. **For a *new* consolidated secrets file (Step 0's key/value case)**, though, there's no requirement it live near any particular `.tmpl` — put it under `home/.chezmoitemplates/` instead (e.g. `home/.chezmoitemplates/repo-secrets.yaml.sops`) and skip this step entirely: chezmoi never scans that directory for applyable targets (confirmed via `chezmoi managed`, which never lists anything under it, including the `sopsDecrypt` partial itself), so there's nothing to ignore. Only do this for a *new* file you're creating — don't move an existing consolidated secrets file that other `.tmpl` files already reference, since that changes its path and breaks them.

If you do need the ignore entry (per-target ciphertext, or a consolidated file someone already placed elsewhere), check first: `chezmoi execute-template < home/.chezmoiignore.tmpl | grep <target-relative-path>`. If it's not already covered, add a target-relative (not source-relative) entry under a clearly labeled section in `home/.chezmoiignore.tmpl`:

```
## SOPS+age ciphertext (source-only; decrypted via the sopsDecrypt partial,
## never applied directly — see openspec/specs/sops-age-encryption/)
.foo/bar.json.sops
```

Verify it renders: `chezmoi execute-template < home/.chezmoiignore.tmpl`.

## Step 7: Add a test-harness fixture and verify

Add an entry to `tests/fixtures/sops.json`, keyed by the ciphertext file's basename, with deterministic fake plaintext (matching the real structure/type if it's a structured secret, so the mock is a realistic stand-in):

```json
"bar.json.sops": "{\"client_id\":\"mock-client-id\",\"client_secret\":\"mock-secret\"}"
```

Then confirm the updated template renders using the mock, with no real key required:

```bash
tests/run-template home/private_dot_foo/private_bar.json.tmpl
```

## Step 8: Hand real verification back to the user

`chezmoi status`, `chezmoi diff`, and `chezmoi apply` all need the real KeePassXC master password and/or the real age key — run these yourself only if you already have a cached, non-interactive path to both (rare); otherwise hand the exact commands to the user and ask them to report the output. Confirm:
- No unexpected `A`/`M` entries for the ciphertext file itself (Step 6 working correctly)
- The target file's content is unchanged (or changes only in ways you expect, e.g. reformatting from a structured re-encrypt)
- If this secret is used by a running service, confirm it reloads/still works after `chezmoi apply`

## Step 9: Leave the rollback path intact

Don't delete the original KeePassXC entry. The rollback is always: revert the `.tmpl` file (and any `.chezmoiignore.tmpl`/`.sops.yaml` additions) via git — no data loss, since the KeePassXC entry is untouched.

## Reference

See `openspec/changes/archive/` (or the current in-progress `sops-age-secrets-pilot` change, if not yet archived) for a fully worked example covering both a whole-file attachment (`cert.pem`) and a structured attachment (a tunnel credentials JSON), including the design rationale (`design.md`) for every decision referenced above.
