## Why

The per-machine `keepassxc_entries` map in `home/.chezmoidata/config.yaml` only ever holds one thing per logical secret: the *true entry name* for that secret on the current machine (e.g. `ssh: "SSH (MacBook Pro)"`). Which retrieval mechanism actually queries that entry is a decision each consuming template already hardcodes (it calls `keepassxcAttribute` directly) — it doesn't vary per machine and doesn't need to live in this map. The `keepassxc_entries` name is therefore a misnomer: it implies the map itself is KeePassXC-specific, when only the call sites are. With 1Password and/or AWS Secrets Manager likely to be added as additional secret sources soon, renaming the key now to a manager-agnostic `secret_entries` avoids a name that will actively mislead once a different secret lives in a different backend, and is simply the clearer name regardless.

## What Changes

- **BREAKING** (internal data format only, no functional/behavioral effect): rename the `keepassxc_entries` key to `secret_entries` in every machine section of `home/.chezmoidata/config.yaml`.
- Update every template that reads this map (`home/private_dot_ssh/private_id_ed25519.tmpl`, `home/private_dot_ssh/id_ed25519.pub.tmpl`, `home/private_dot_ssh/known_hosts.tmpl`, `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl`) to look up `secret_entries` instead of `keepassxc_entries`, including renaming local template variables (e.g. `$keepassxcEntries` → `$secretEntries`) for consistency.
- Update doc comments and examples referencing `keepassxc_entries` in `home/.chezmoitemplates/machine-config`, `home/.chezmoitemplates/machine-settings`, `home/.chezmoitemplates/CLAUDE.md`, and `README.md`.
- No change to how the entry is actually retrieved: `keepassxcAttribute`/`keepassxcAttachment` calls at each call site are unchanged — only the map name and its key lookups change. All secrets in this repo remain KeePassXC-backed today.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `secret-management`: The "Machine-Specific KeePassXC Entries" requirement is renamed and generalized to describe a manager-agnostic per-machine entry-name map, rather than a KeePassXC-specific one.
- `machine-config`: Doc-level references to `keepassxc_entries` as the canonical dot-notation example are updated to `secret_entries`. No requirement behavior changes — this is a wording/example update only, included because the existing spec text names the literal property.

## Impact

- `home/.chezmoidata/config.yaml` — rename `keepassxc_entries` to `secret_entries` for all three machines (MacBook Pro, Mac Studio, Mac mini).
- `home/private_dot_ssh/private_id_ed25519.tmpl`, `id_ed25519.pub.tmpl`, `known_hosts.tmpl` — update key lookup and local variable name.
- `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` — update key lookup and local variable name.
- `home/.chezmoitemplates/machine-config`, `home/.chezmoitemplates/machine-settings` — update doc-comment examples.
- `home/.chezmoitemplates/CLAUDE.md`, `README.md` — update prose examples.
- `openspec/specs/secret-management/spec.md`, `openspec/specs/machine-config/spec.md` — requirement/example text updates via this change's spec deltas.
- Tags affected: none (secret-management and machine-config are not tag-gated capabilities).
- Security: none — this is a rename of a config key and template variable names; no secret values, retrieval mechanism, or file permissions change. The actual KeePassXC integration (bootstrap dependency, template functions, graceful-degradation behavior) is untouched.

## Non-goals

- Not adding 1Password or AWS Secrets Manager integration itself — this change only generalizes the naming so that a future addition doesn't require yet another rename.
- Not introducing a `manager` field per entry or any dispatch mechanism for choosing between secret backends — per earlier discussion, manager selection is a call-site decision (which template function is invoked), not per-machine data, so the map stays a flat `{logical_name: entry_name}` structure.
- Not changing which secrets exist, their values, or their KeePassXC entry names — only the key that maps to them.
- Not touching archived `openspec/changes/archive/**` history, which retains the old name as a historical record of past decisions.
