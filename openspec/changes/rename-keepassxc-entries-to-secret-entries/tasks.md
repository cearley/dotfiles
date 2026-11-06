## 1. Rename the data key

- [x] 1.1 In `home/.chezmoidata/config.yaml`, rename `keepassxc_entries` to `secret_entries` for `MacBook Pro`, `Mac Studio`, and `Mac mini`
- [x] 1.2 Update the `keepassxc_entries` doc comment in the `machines:` section (around line 95-99) to describe `secret_entries` in manager-agnostic terms

## 2. Update consuming templates

- [x] 2.1 `home/private_dot_ssh/private_id_ed25519.tmpl` — rename `$keepassxcEntries` → `$secretEntries` and the `index $settings "keepassxc_entries"` lookup to `"secret_entries"`
- [x] 2.2 `home/private_dot_ssh/id_ed25519.pub.tmpl` — same rename
- [x] 2.3 `home/private_dot_ssh/known_hosts.tmpl` — same rename
- [x] 2.4 `home/.chezmoiscripts/run_onchange_after_darwin-46-setup-ssh-github.sh.tmpl` — same rename

## 3. Update reusable template docs

- [x] 3.1 `home/.chezmoitemplates/machine-config` — update the `keepassxc_entries.ssh` dot-notation example (comment + `Get nested SSH entry` example) to `secret_entries.ssh`
- [x] 3.2 `home/.chezmoitemplates/machine-settings` — update the `$keepassxcEntries`/`keepassxc_entries` example in the header comment to `secret_entries`

## 4. Update repo-level docs

- [x] 4.1 `home/.chezmoitemplates/CLAUDE.md` — update the `keepassxc_entries.ssh` example under the "Access machine config" section
- [x] 4.2 `README.md` — update the `keepassxc_entries.ssh` dot-notation example (around line 45)

## 5. Verify

- [x] 5.1 Run `grep -rn "keepassxc_entries" home README.md openspec/specs` and confirm zero matches (archived `openspec/changes/archive/**` is expected to still contain the old name and is out of scope) — `home` and `README.md` are clean; `openspec/specs` still has 7 matches in the live spec tree, which syncs from this change's delta specs (already correct) only at archive time, per normal OpenSpec workflow and the user's explicit confirmation
- [x] 5.2 Run `tests/run-template` against each of the four changed `.tmpl`/`.sh.tmpl` files and confirm they render without error
- [ ] 5.3 Run `chezmoi diff` (interactive TTY) or `chezmoi status` on a real machine and confirm no unexpected changes are proposed — rendered SSH key/known_hosts content must be byte-identical to before this change
- [x] 5.4 Run `openspec validate rename-keepassxc-entries-to-secret-entries --strict` before archiving
